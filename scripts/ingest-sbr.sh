#!/usr/bin/env bash
#
# ingest-sbr.sh — Subclass Brain Registry ingestion
#
# Reads the project's conductor-state.json, finds gemini_validations[] entries with
# verdict == "PASS" and completion_pct >= 80, resolves the original prompt from
# handoff_history[], sanitizes it, embeds it via Ollama (nomic-embed-text, 768-dim),
# and upserts the result to the Qdrant `sbr` collection via direct HTTP.
#
# Idempotent: point ID is a UUID derived from SHA-256(prompt_text + "|" + agent +
# "|" + project), so re-running the script overwrites existing points in place
# rather than duplicating. Qdrant requires u64 or UUID for point IDs — raw hex
# is rejected with HTTP 400.
#
# Talks directly to Qdrant (port 6334 by default) and Ollama (port 11434).
# Does NOT use mcp__claude-memory__memory_store — that tool does not accept a
# `collection` parameter (verified against claude-memory-mcp/src/index.ts:380-403),
# and SBR is owned by the sbr skill, not by claude-memory-plugin.
#
# Usage:
#   ./scripts/ingest-sbr.sh [--dry-run] [--state PATH] [--min-completion PCT]
#
# Flags:
#   --dry-run            Print candidate points to stdout; do not contact Qdrant.
#   --state PATH         Path to conductor-state.json (default: ./conductor-state.json).
#   --min-completion N   Override completion_pct floor (default: 80).
#   --qdrant URL         Qdrant base URL (default: http://localhost:6334).
#   --ollama URL         Ollama base URL (default: http://localhost:11434).
#   --model NAME         Ollama embedding model (default: nomic-embed-text).
#
# Exit codes:
#   0  Success or graceful no-op (qdrant_unreachable, ollama_unreachable,
#      no_eligible_validations) — the parent workflow is not crashed.
#   2  Usage / missing dependency error.
#   3  Required input (e.g., state file) missing or malformed.

set -euo pipefail

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

DRY_RUN=false
STATE_FILE="${PWD}/conductor-state.json"
MIN_COMPLETION=80
QDRANT_URL="http://localhost:6334"
OLLAMA_URL="http://localhost:11434"
EMBED_MODEL="nomic-embed-text"
COLLECTION="sbr"
EXPECTED_DIM=768

# ---------------------------------------------------------------------------
# Arg parsing
# ---------------------------------------------------------------------------

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)         DRY_RUN=true; shift ;;
    --state)           STATE_FILE="$2"; shift 2 ;;
    --min-completion)  MIN_COMPLETION="$2"; shift 2 ;;
    --qdrant)          QDRANT_URL="$2"; shift 2 ;;
    --ollama)          OLLAMA_URL="$2"; shift 2 ;;
    --model)           EMBED_MODEL="$2"; shift 2 ;;
    -h|--help)
      sed -n '2,30p' "$0"
      exit 0
      ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

# ---------------------------------------------------------------------------
# Dependency checks
# ---------------------------------------------------------------------------

for cmd in curl jq python3; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "ERROR: required command not found: $cmd" >&2
    exit 2
  fi
done

# sha256 utility detection (macOS uses shasum; Linux uses sha256sum).
if command -v sha256sum >/dev/null 2>&1; then
  SHA256_CMD="sha256sum"
elif command -v shasum >/dev/null 2>&1; then
  SHA256_CMD="shasum -a 256"
else
  echo "ERROR: neither sha256sum nor shasum available" >&2
  exit 2
fi

sha256_hex() {
  # Returns 64-char lowercase hex of $1 on stdout.
  printf '%s' "$1" | $SHA256_CMD | awk '{print $1}'
}

sha256_uuid() {
  # Returns a deterministic UUID-formatted point ID derived from the SHA-256
  # of $1. Qdrant accepts ONLY u64 integers or UUID strings as point IDs
  # (raw 64-char hex returns 400). We format the first 32 hex chars as
  # xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx. Idempotency is preserved: same
  # input -> same hash -> same UUID.
  local hex
  hex="$(sha256_hex "$1")"
  printf '%s-%s-%s-%s-%s' \
    "${hex:0:8}" \
    "${hex:8:4}" \
    "${hex:12:4}" \
    "${hex:16:4}" \
    "${hex:20:12}"
}

# ---------------------------------------------------------------------------
# State-file checks
# ---------------------------------------------------------------------------

if [[ ! -f "$STATE_FILE" ]]; then
  echo "ERROR: state file not found: $STATE_FILE" >&2
  echo "Hint: run from the project root, or pass --state PATH" >&2
  exit 3
fi

if ! jq empty "$STATE_FILE" >/dev/null 2>&1; then
  echo "ERROR: state file is not valid JSON: $STATE_FILE" >&2
  exit 3
fi

PROJECT_NAME="$(jq -r '.project_name // empty' "$STATE_FILE")"
if [[ -z "$PROJECT_NAME" ]]; then
  echo "ERROR: state file missing project_name" >&2
  exit 3
fi

# Allow operator to disable SBR via sbr_state.enabled=false.
SBR_ENABLED="$(jq -r '.sbr_state.enabled // true' "$STATE_FILE")"
if [[ "$SBR_ENABLED" != "true" ]]; then
  echo "SBR is disabled for this workflow (sbr_state.enabled == false). Exiting."
  exit 0
fi

# ---------------------------------------------------------------------------
# Liveness checks (Qdrant + Ollama) — only when not dry-running
# ---------------------------------------------------------------------------

set_state_status() {
  # Update conductor-state.json sbr_state with the given fields.
  # Args: <status_value> <message> [<extra_jq_assignments>]
  local status="$1"
  local message="$2"

  if $DRY_RUN; then
    echo "[DRY RUN] Would set sbr_state.last_run_status=$status"
    return
  fi

  local now
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  local tmp
  tmp="$(mktemp)"
  jq --arg s "$status" \
     --arg m "$message" \
     --arg now "$now" \
     --arg col "${QDRANT_URL}/collections/${COLLECTION}" \
     --arg model "$EMBED_MODEL" \
     '.sbr_state = (.sbr_state // {}) |
      .sbr_state.last_run_status = $s |
      .sbr_state.last_run_message = $m |
      .sbr_state.last_ingested_at = $now |
      .sbr_state.collection_url = (.sbr_state.collection_url // $col) |
      .sbr_state.embedding_model = (.sbr_state.embedding_model // $model) |
      .sbr_state.enabled = (.sbr_state.enabled // true) |
      .sbr_state.points_ingested = (.sbr_state.points_ingested // 0) |
      .sbr_state.points_skipped_dedup = (.sbr_state.points_skipped_dedup // 0) |
      .sbr_state.points_skipped_sanitization = (.sbr_state.points_skipped_sanitization // 0)' \
     "$STATE_FILE" > "$tmp"
  mv "$tmp" "$STATE_FILE"
}

bump_state_counter() {
  # Args: <counter_name> <delta>
  local counter="$1"
  local delta="$2"
  if $DRY_RUN; then return; fi
  local tmp
  tmp="$(mktemp)"
  jq --arg c "$counter" --argjson d "$delta" \
     '.sbr_state = (.sbr_state // {}) |
      .sbr_state[$c] = ((.sbr_state[$c] // 0) + $d)' \
     "$STATE_FILE" > "$tmp"
  mv "$tmp" "$STATE_FILE"
}

if ! $DRY_RUN; then
  if ! curl -fsS -o /dev/null -m 5 "${QDRANT_URL}/collections"; then
    echo "Qdrant unreachable at ${QDRANT_URL}. SBR ingestion skipped." >&2
    set_state_status "qdrant_unreachable" "Cannot reach ${QDRANT_URL}/collections"
    exit 0
  fi
  if ! curl -fsS -o /dev/null -m 5 "${OLLAMA_URL}/api/tags"; then
    echo "Ollama unreachable at ${OLLAMA_URL}. SBR ingestion skipped." >&2
    set_state_status "ollama_unreachable" "Cannot reach ${OLLAMA_URL}/api/tags"
    exit 0
  fi
fi

# ---------------------------------------------------------------------------
# Collection bootstrap — idempotent create
# ---------------------------------------------------------------------------

ensure_collection() {
  if $DRY_RUN; then
    echo "[DRY RUN] Would ensure collection '${COLLECTION}' exists with size=${EXPECTED_DIM}, distance=Cosine"
    return
  fi

  local code
  code="$(curl -s -o /dev/null -w '%{http_code}' "${QDRANT_URL}/collections/${COLLECTION}")"
  if [[ "$code" == "200" ]]; then
    return
  fi

  # 404 → create. Any other code → log and proceed (the upsert will surface the error).
  echo "Creating Qdrant collection: ${COLLECTION}"
  local resp
  resp="$(curl -s -X PUT "${QDRANT_URL}/collections/${COLLECTION}" \
          -H 'Content-Type: application/json' \
          -d "{\"vectors\":{\"size\":${EXPECTED_DIM},\"distance\":\"Cosine\"}}")"
  local status
  status="$(echo "$resp" | jq -r '.status // "unknown"')"
  if [[ "$status" != "ok" && "$status" != "acknowledged" ]]; then
    # Already-exists race is reported as 400 — tolerate it.
    if echo "$resp" | grep -qi 'already exists'; then
      return
    fi
    echo "WARNING: collection create returned status '$status': $resp" >&2
  fi
}

ensure_collection

# ---------------------------------------------------------------------------
# Sanitization (deterministic regex — no LLM)
# ---------------------------------------------------------------------------
# Returns the sanitized text on stdout. Exits 1 (via printf '__SKIP__') if the
# content contains disqualifying markers (T2-Confidential / T3-Restricted).

sanitize_text() {
  # Delegate to a standalone python helper. We can't use `python3 - <<'PY'`
  # here because `python3 -` reads its program from stdin, which means the
  # heredoc IS consumed as the program — leaving sys.stdin.read() empty.
  # See scripts/lib/sanitize.py for the actual logic.
  python3 "${SCRIPT_DIR}/lib/sanitize.py"
}

# ---------------------------------------------------------------------------
# Build spec_summary heuristically (first H1 + first paragraph, truncated)
# ---------------------------------------------------------------------------

build_spec_summary() {
  # Delegate to a standalone python helper (same heredoc-stdin issue as
  # sanitize_text). See scripts/lib/build_spec_summary.py.
  python3 "${SCRIPT_DIR}/lib/build_spec_summary.py"
}

# ---------------------------------------------------------------------------
# Embedding via Ollama
# ---------------------------------------------------------------------------

embed_text() {
  # Stdin: text to embed. Stdout: JSON array of floats (the embedding).
  local text="$1"
  local payload
  payload="$(jq -nc --arg m "$EMBED_MODEL" --arg p "$text" '{model:$m, prompt:$p}')"
  local resp
  resp="$(curl -fsS -X POST "${OLLAMA_URL}/api/embeddings" \
           -H 'Content-Type: application/json' \
           -d "$payload")"
  echo "$resp" | jq -c '.embedding // empty'
}

# ---------------------------------------------------------------------------
# Main: iterate gemini_validations, build candidate points, upsert
# ---------------------------------------------------------------------------

# Extract eligible validations as JSON lines. We need verdict==PASS,
# completion_pct >= MIN_COMPLETION. We also pull the matching handoff_history
# row by (phase, step, agent_name) so we have the original prompt body.

eligible_count="$(jq --argjson m "$MIN_COMPLETION" \
  '[.gemini_validations[]? | select(.verdict == "PASS" and (.completion_pct // 0) >= $m)] | length' \
  "$STATE_FILE")"

if [[ "$eligible_count" -eq 0 ]]; then
  echo "No eligible gemini_validations (PASS, completion_pct >= ${MIN_COMPLETION}). Nothing to ingest."
  if ! $DRY_RUN; then
    set_state_status "no_eligible_validations" "Zero PASS validations >= ${MIN_COMPLETION}% completion"
  fi
  exit 0
fi

echo "Found ${eligible_count} eligible validation(s) at completion >= ${MIN_COMPLETION}%."

INGESTED=0
SKIPPED_DEDUP=0
SKIPPED_SANITIZATION=0
ERRORS=0

# Pull a stream of {validation, handoff?} objects using jq joining logic.
# Match handoff by phase + step + (agent OR agent_name) when present.
ELIGIBLE_JSON="$(jq -c --argjson m "$MIN_COMPLETION" '
  [
    .gemini_validations[]? |
    select(.verdict == "PASS" and (.completion_pct // 0) >= $m) |
    . as $v |
    {
      validation: $v,
      handoff: (
        ([.. | objects | select(has("from_agent") and has("to_agent"))] // [])
        | map(select(
            (.phase // null) == ($v.phase // null) and
            (.step // null)  == ($v.step  // null) and
            (((.to_agent // .agent // "") | ascii_downcase) ==
             (($v.agent // $v.agent_name // "") | ascii_downcase))
          ))
        | .[0]
      )
    }
  ] | .[]' "$STATE_FILE")"

INGESTED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

while IFS= read -r row; do
  [[ -z "$row" ]] && continue

  VAL_ID="$(echo "$row" | jq -r '.validation.validation_id // .validation.id // empty')"
  AGENT="$(echo "$row" | jq -r '.validation.agent // .validation.agent_name // empty')"
  COMPLETION="$(echo "$row" | jq -r '.validation.completion_pct // 0')"
  TIER="$(jq -r '.tier // empty' "$STATE_FILE")"

  # Resolve prompt text. Preference order:
  #   1. handoff.prompt | handoff.spec | handoff.task_description
  #   2. validation.prompt | validation.task | validation.spec_summary
  PROMPT_RAW="$(echo "$row" | jq -r '
    .handoff.prompt //
    .handoff.spec //
    .handoff.task_description //
    .handoff.task //
    .validation.prompt //
    .validation.task //
    .validation.spec_summary //
    empty')"

  if [[ -z "$PROMPT_RAW" || -z "$VAL_ID" || -z "$AGENT" ]]; then
    echo "  SKIP validation '$VAL_ID' — no prompt body or missing identity fields" >&2
    ERRORS=$((ERRORS + 1))
    continue
  fi

  # Sanitize.
  PROMPT_CLEAN="$(printf '%s' "$PROMPT_RAW" | sanitize_text)"
  if [[ "$PROMPT_CLEAN" == "__SKIP__" ]]; then
    echo "  SKIP validation '$VAL_ID' — sanitization rejected (restricted classification)" >&2
    SKIPPED_SANITIZATION=$((SKIPPED_SANITIZATION + 1))
    continue
  fi

  if [[ -z "$PROMPT_CLEAN" ]]; then
    echo "  SKIP validation '$VAL_ID' — sanitization produced empty content" >&2
    SKIPPED_SANITIZATION=$((SKIPPED_SANITIZATION + 1))
    continue
  fi

  SUMMARY="$(printf '%s' "$PROMPT_CLEAN" | build_spec_summary)"

  # Compute content-derived point ID. Qdrant requires u64 or UUID — we use
  # a UUID derived from the SHA-256 of (prompt|agent|project) so re-ingesting
  # the same content overwrites in place. See sha256_uuid() above.
  ID_INPUT="${PROMPT_CLEAN}|${AGENT}|${PROJECT_NAME}"
  POINT_ID="$(sha256_uuid "$ID_INPUT")"

  # Build human-readable sbr_id.
  SBR_ID="sbr_${INGESTED_AT}_${VAL_ID}"

  # Optional fields.
  DOMAIN="$(echo "$row" | jq -r '.handoff.domain // .validation.domain // empty')"
  RELATED_REQ="$(echo "$row" | jq -r '.handoff.brd_requirement // .validation.brd_requirement // empty')"
  FILES_CHANGED_JSON="$(jq -c --arg vid "$VAL_ID" '
    [.completed_tasks[]?
     | select((.validation_id // .gemini_validation_id // "") == $vid)
     | (.files_changed // .files // [])
     | .[]]
    | map(sub("^/Users/[^/]+/"; "~/") | sub("^/home/[^/]+/"; "~/"))
    | unique' "$STATE_FILE")"

  if $DRY_RUN; then
    echo "----- DRY RUN candidate -----"
    echo "  point_id: $POINT_ID"
    echo "  sbr_id:   $SBR_ID"
    echo "  agent:    $AGENT"
    echo "  project:  $PROJECT_NAME"
    echo "  summary:  $SUMMARY"
    echo "  files:    $FILES_CHANGED_JSON"
    INGESTED=$((INGESTED + 1))
    continue
  fi

  # Check whether point already exists (for dedup counter accuracy).
  EXISTS_CODE="$(curl -s -o /dev/null -w '%{http_code}' \
    -X POST "${QDRANT_URL}/collections/${COLLECTION}/points" \
    -H 'Content-Type: application/json' \
    -d "$(jq -nc --arg id "$POINT_ID" '{ids:[$id], with_payload:false, with_vector:false}')")"
  EXISTS=false
  if [[ "$EXISTS_CODE" == "200" ]]; then
    EXISTS_BODY="$(curl -s -X POST "${QDRANT_URL}/collections/${COLLECTION}/points" \
      -H 'Content-Type: application/json' \
      -d "$(jq -nc --arg id "$POINT_ID" '{ids:[$id], with_payload:false, with_vector:false}')")"
    EXISTS_LEN="$(echo "$EXISTS_BODY" | jq -r '.result | length // 0')"
    if [[ "$EXISTS_LEN" -gt 0 ]]; then
      EXISTS=true
    fi
  fi

  # Generate embedding.
  VECTOR_JSON="$(embed_text "$PROMPT_CLEAN" || true)"
  if [[ -z "$VECTOR_JSON" || "$VECTOR_JSON" == "null" ]]; then
    echo "  ERROR validation '$VAL_ID' — embedding failed; skipping" >&2
    ERRORS=$((ERRORS + 1))
    continue
  fi

  # Verify dimension.
  VEC_LEN="$(echo "$VECTOR_JSON" | jq -r 'length')"
  if [[ "$VEC_LEN" != "$EXPECTED_DIM" ]]; then
    echo "  ERROR validation '$VAL_ID' — embedding dim ${VEC_LEN} != expected ${EXPECTED_DIM}" >&2
    ERRORS=$((ERRORS + 1))
    continue
  fi

  # Build payload.
  PAYLOAD_JSON="$(jq -nc \
    --arg sbr_id "$SBR_ID" \
    --arg agent "$AGENT" \
    --arg project "$PROJECT_NAME" \
    --arg prompt "$PROMPT_CLEAN" \
    --arg summary "$SUMMARY" \
    --arg val_id "$VAL_ID" \
    --argjson completion "$COMPLETION" \
    --arg ingested_at "$INGESTED_AT" \
    --arg tier "$TIER" \
    --arg domain "$DOMAIN" \
    --arg req "$RELATED_REQ" \
    --argjson files "$FILES_CHANGED_JSON" '
    {
      sbr_id: $sbr_id,
      agent: $agent,
      project: $project,
      prompt_text: $prompt,
      spec_summary: $summary,
      outcome_validation_id: $val_id,
      completion_pct: $completion,
      verdict: "PASS",
      ingested_at: $ingested_at
    }
    + (if $tier   != "" then {tier: $tier} else {} end)
    + (if $domain != "" then {domain: $domain} else {} end)
    + (if $req    != "" then {related_brd_req: $req} else {} end)
    + (if ($files | length) > 0 then {file_paths_changed: $files} else {} end)
  ')"

  UPSERT_BODY="$(jq -nc \
    --arg id "$POINT_ID" \
    --argjson vec "$VECTOR_JSON" \
    --argjson payload "$PAYLOAD_JSON" '
    {points:[{id:$id, vector:$vec, payload:$payload}]}')"

  UPSERT_RESP="$(curl -s -X PUT "${QDRANT_URL}/collections/${COLLECTION}/points?wait=true" \
    -H 'Content-Type: application/json' \
    -d "$UPSERT_BODY")"
  UPSERT_STATUS="$(echo "$UPSERT_RESP" | jq -r '.status // .result.status // "unknown"')"

  case "$UPSERT_STATUS" in
    ok|acknowledged|completed)
      if $EXISTS; then
        echo "  REPLACED  $SBR_ID  (agent=$AGENT, completion=$COMPLETION)"
        SKIPPED_DEDUP=$((SKIPPED_DEDUP + 1))
      else
        echo "  INGESTED  $SBR_ID  (agent=$AGENT, completion=$COMPLETION)"
        INGESTED=$((INGESTED + 1))
      fi
      ;;
    *)
      echo "  ERROR upsert returned status '$UPSERT_STATUS' for $SBR_ID: $UPSERT_RESP" >&2
      ERRORS=$((ERRORS + 1))
      ;;
  esac

done <<< "$ELIGIBLE_JSON"

# ---------------------------------------------------------------------------
# Summary + state writeback
# ---------------------------------------------------------------------------

echo ""
echo "=== SBR Ingestion Summary ==="
echo "Project:                  $PROJECT_NAME"
echo "Eligible validations:     $eligible_count"
echo "Ingested (new):           $INGESTED"
echo "Replaced (dedup):         $SKIPPED_DEDUP"
echo "Skipped (sanitization):   $SKIPPED_SANITIZATION"
echo "Errors:                   $ERRORS"

if $DRY_RUN; then
  echo ""
  echo "[DRY RUN] No data written to Qdrant. Run without --dry-run to ingest."
  exit 0
fi

# Aggregate status.
if [[ "$ERRORS" -gt 0 && "$INGESTED" -eq 0 && "$SKIPPED_DEDUP" -eq 0 ]]; then
  set_state_status "error" "All ${eligible_count} candidates failed (errors=$ERRORS)"
  exit 0
elif [[ "$ERRORS" -gt 0 ]]; then
  set_state_status "partial" "Ingested=$INGESTED replaced=$SKIPPED_DEDUP errors=$ERRORS"
else
  set_state_status "ok" "Ingested=$INGESTED replaced=$SKIPPED_DEDUP skipped_sanitization=$SKIPPED_SANITIZATION"
fi

# Update cumulative counters.
bump_state_counter "points_ingested" "$INGESTED"
bump_state_counter "points_skipped_dedup" "$SKIPPED_DEDUP"
bump_state_counter "points_skipped_sanitization" "$SKIPPED_SANITIZATION"

exit 0
