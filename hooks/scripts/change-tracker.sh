#!/usr/bin/env bash
# change-tracker.sh
# PostToolUse hook — appends a JSONL audit entry for every Edit/Write/NotebookEdit
# tool call to <project_root>/.conductor/change-log.jsonl.
#
# BRD: REQ-CDV-HERMES-001
# Hard limits enforced here:
#   - Append-only (>>) — no in-place mutation of the active log
#   - Non-blocking — always exits 0, even on internal failure
#   - 100ms total budget guard — degrades to minimal entry if exceeded
#   - Sensitive-path denylist (CISO-001)
#
# Budget strategy: the 100ms guard is implemented as a degradation trigger.
# Core metadata (ts, session_id, tool, file, agent, phase, trigger) is always
# written. Optional enrichment (SHA256, lines_changed, brd_ref, spec_ref) is
# skipped under budget pressure.  If the budget fires before the append, we
# write a minimal entry and exit 0. The hook NEVER exits non-zero.
#
# Environment variables consumed:
#   CLAUDE_PLUGIN_ROOT   — plugin install path
#   CLAUDE_PROJECT_DIR   — current project root (fallback: pwd)
#   CLAUDE_SESSION_ID    — session identifier (fallback: "unknown")
# Stdin: PostToolUse JSON payload { tool_name, tool_input, tool_response }

# NOTE: Intentionally NO set -e here. The hook is non-blocking and must never
# exit non-zero regardless of internal failures. All error handling is explicit.
# Hard limit: this script ALWAYS exits 0.

# ---------------------------------------------------------------------------
# Budget tracking — uses EPOCHREALTIME (bash 5+, no subprocess).
# Falls back to SECONDS (1s granularity) on older bash.
# ---------------------------------------------------------------------------
if [[ -n "${EPOCHREALTIME:-}" ]]; then
  CT_START_EPOCH="${EPOCHREALTIME}"
  CT_USE_EPOCH=true
else
  CT_START_SECONDS="${SECONDS}"
  CT_USE_EPOCH=false
fi

# ct_elapsed_ms — sets CT_ELAPSED_MS to integer milliseconds since start
ct_elapsed_ms() {
  if [[ "${CT_USE_EPOCH}" == "true" ]]; then
    local now="${EPOCHREALTIME}"
    # Integer arithmetic: strip fractional part from both, compute difference in ms.
    # EPOCHREALTIME format: "1779284885.998018" — we need (now-start)*1000 as integer.
    # Use bash integer arithmetic on the epoch truncated to milliseconds.
    local now_ms start_ms
    # Strip the decimal point and take 13 significant digits (seconds * 1000 = ms)
    now_ms="${now//./}"    # e.g. "1779284885998018" (microseconds)
    start_ms="${CT_START_EPOCH//./}"
    # Trim to milliseconds (drop last 3 digits = microseconds → milliseconds)
    now_ms="${now_ms%???}"      # last 3 chars = microseconds, keep milliseconds
    start_ms="${start_ms%???}"
    CT_ELAPSED_MS=$(( now_ms - start_ms ))
  else
    CT_ELAPSED_MS=$(( (SECONDS - CT_START_SECONDS) * 1000 ))
  fi
}

# ct_budget_ok — returns 0 if under budget, 1 if over.
# Budget threshold: 80ms for enrichment; 100ms hard abort.
ct_budget_ok() {
  ct_elapsed_ms
  if (( CT_ELAPSED_MS >= 100 )); then
    return 1
  fi
  return 0
}

# ct_enrichment_ok — returns 0 if enrichment window still open (< 70ms)
ct_enrichment_ok() {
  ct_elapsed_ms
  if (( CT_ELAPSED_MS >= 70 )); then
    return 1
  fi
  return 0
}

# ---------------------------------------------------------------------------
# Source helpers
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPERS="${SCRIPT_DIR}/lib/change-tracker-helpers.sh"
if [[ ! -f "${HELPERS}" ]]; then
  echo "change-tracker: WARNING: helpers not found at ${HELPERS}" >&2
  exit 0
fi
# shellcheck source=./lib/change-tracker-helpers.sh
source "${HELPERS}"

# ---------------------------------------------------------------------------
# Parse environment / stdin
# ---------------------------------------------------------------------------
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
SESSION_ID="${CLAUDE_SESSION_ID:-unknown}"

# Read stdin (PostToolUse payload)
PAYLOAD=""
if [[ -t 0 ]]; then
  PAYLOAD="{}"
else
  PAYLOAD=$(cat)
fi

# Extract fields from payload using jq if available, else grep fallback
if command -v jq &>/dev/null; then
  TOOL_NAME=$(echo "${PAYLOAD}" | jq -r '.tool_name // ""' 2>/dev/null || echo "")
  FILE_PATH=$(echo "${PAYLOAD}" | jq -r '.tool_input.file_path // .tool_input.notebook_path // ""' 2>/dev/null || echo "")
else
  TOOL_NAME=$(echo "${PAYLOAD}" | grep -o '"tool_name"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*:[[:space:]]*"\([^"]*\)"/\1/')
  FILE_PATH=$(echo "${PAYLOAD}" | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*:[[:space:]]*"\([^"]*\)"/\1/')
fi

# Only handle Edit, Write, NotebookEdit
case "${TOOL_NAME}" in
  Edit|Write|NotebookEdit) ;;
  *)
    exit 0
    ;;
esac

# ---------------------------------------------------------------------------
# Resolve file path
# ---------------------------------------------------------------------------
if [[ -z "${FILE_PATH}" ]]; then
  exit 0
fi

if [[ "${FILE_PATH}" != /* ]]; then
  FILE_PATH="${PROJECT_DIR}/${FILE_PATH}"
fi
ABS_FILE_PATH="${FILE_PATH}"

REL_FILE_PATH="${ABS_FILE_PATH#"${PROJECT_DIR}/"}"
if [[ "${REL_FILE_PATH}" == "${ABS_FILE_PATH}" ]]; then
  REL_FILE_PATH="${ABS_FILE_PATH}"
fi

# ---------------------------------------------------------------------------
# Sensitive-path denylist check (CISO-001)
# ---------------------------------------------------------------------------
ct_load_denylist
IS_REDACTED=false
REDACT_REASON=""

if ct_is_denied "${ABS_FILE_PATH}"; then
  IS_REDACTED=true
  REDACT_REASON="${CT_DENIED_REASON}"
fi

# ---------------------------------------------------------------------------
# Read conductor-state.json
# ---------------------------------------------------------------------------
WORKFLOW_ID="null"
CURRENT_PHASE="null"
ACTIVE_AGENT="null"
PARENT_DISPATCH_ID="null"
BRD_SOURCE=""

STATE_FILE="${PROJECT_DIR}/conductor-state.json"
if [[ -f "${STATE_FILE}" ]] && command -v jq &>/dev/null; then
  # Collapse 5 jq invocations into one @tsv read — saves ~12ms per hook fire on
  # macOS (5×3ms jq startup → 1×3ms). Fields emitted in fixed order; "\t" is the
  # tab separator. jq emits literal "null" string for missing/absent fields so
  # the downstream "null" comparisons keep working unchanged.
  CT_TSV=$(jq -r '
    [
      (.project_name // "null"),
      (
        if .current_phase == null then "null"
        elif (.current_phase | type) == "object" then ((.current_phase.number // "null") | tostring)
        else (.current_phase | tostring)
        end
      ),
      (
        (.current_step | if type == "object" then .assigned_agent else null end) //
        (.agents_invoked | if type == "array" and length > 0 then last | if type == "string" then . else .agent end else null end) //
        "null"
      ),
      (
        (.agent_instances | if type == "array" and length > 0 then last | (.nhi_id // .id // "null") else "null" end)
      ),
      (.brd_source // "")
    ] | @tsv
  ' "${STATE_FILE}" 2>/dev/null) || CT_TSV=""

  if [[ -n "${CT_TSV}" ]]; then
    IFS=$'\t' read -r WORKFLOW_ID CURRENT_PHASE ACTIVE_AGENT PARENT_DISPATCH_ID BRD_SOURCE <<< "${CT_TSV}"
  fi
fi

[[ "${WORKFLOW_ID}" == "null" ]] && WORKFLOW_ID_JSON="null" || WORKFLOW_ID_JSON=$(ct_json_str "${WORKFLOW_ID}")
[[ "${ACTIVE_AGENT}" == "null" ]] && AGENT_JSON="null" || AGENT_JSON=$(ct_json_str "${ACTIVE_AGENT}")
[[ "${PARENT_DISPATCH_ID}" == "null" ]] && DISPATCH_JSON="null" || DISPATCH_JSON=$(ct_json_str "${PARENT_DISPATCH_ID}")

# ---------------------------------------------------------------------------
# Ensure .conductor/ directory exists
# ---------------------------------------------------------------------------
CONDUCTOR_DIR="${PROJECT_DIR}/.conductor"
LOG_FILE="${CONDUCTOR_DIR}/change-log.jsonl"
ARCHIVE_DIR="${CONDUCTOR_DIR}/change-log-archive"

mkdir -p "${CONDUCTOR_DIR}" "${ARCHIVE_DIR}" 2>/dev/null || true

# ---------------------------------------------------------------------------
# Optional enrichment: SHA256 + lines_changed + BRD/spec refs
# Skipped under budget pressure (> 70ms elapsed); graceful degradation per spec.
# ---------------------------------------------------------------------------
BEFORE_SHA="null"
AFTER_SHA="null"
LINES_CHANGED="[]"
LINES_NOTES=""
BRD_REF="null"
SPEC_REF="null"
BUDGET_DEGRADED=false

if [[ "${IS_REDACTED}" == "false" ]] && ct_enrichment_ok; then
  # Fast enrichers first (pure-JSON / pure-bash, <5ms each) so they survive the
  # 70ms gate even on machines where git operations are slow. Per QA AC-E6-4 fix
  # 2026-05-20: BRD/spec resolution must complete before SHA256 git subprocess
  # calls push CT_ELAPSED_MS past the gate.
  ct_resolve_brd_ref "${ABS_FILE_PATH}" "${PROJECT_DIR}"
  BRD_REF="${CT_BRD_REF}"
  ct_resolve_spec_ref "${PROJECT_DIR}" "${BRD_SOURCE}"
  SPEC_REF="${CT_SPEC_REF}"

  if ct_enrichment_ok; then
    ct_sha256_head "${REL_FILE_PATH}" "${PROJECT_DIR}"
    [[ -n "${CT_BEFORE_SHA}" ]] && BEFORE_SHA="\"${CT_BEFORE_SHA}\"" || BEFORE_SHA="null"
    ct_sha256_disk "${ABS_FILE_PATH}"
    [[ -n "${CT_AFTER_SHA}" ]] && AFTER_SHA="\"${CT_AFTER_SHA}\"" || AFTER_SHA="null"
  fi

  if ct_enrichment_ok; then
    ct_lines_changed "${REL_FILE_PATH}" "${PROJECT_DIR}"
    LINES_CHANGED="${CT_LINES_CHANGED}"
    LINES_NOTES="${CT_LINES_CHANGED_NOTES}"
  fi
else
  if ! ct_budget_ok; then
    echo "change-tracker: WARNING: 100ms budget exceeded — writing minimal entry for ${REL_FILE_PATH}" >&2
    BUDGET_DEGRADED=true
  fi
fi

# ---------------------------------------------------------------------------
# Trigger classification (attempt even under moderate budget pressure,
# skip only if truly over budget)
# ---------------------------------------------------------------------------
TRIGGER="unknown"
TRIGGER_DETAIL=""

if ct_budget_ok; then
  ct_classify_trigger
  TRIGGER="${CT_TRIGGER}"
  TRIGGER_DETAIL="${CT_TRIGGER_DETAIL}"
fi

# ---------------------------------------------------------------------------
# Rotation check
# ---------------------------------------------------------------------------
if ct_budget_ok; then
  ct_maybe_rotate "${LOG_FILE}" "${ARCHIVE_DIR}"
fi

# ---------------------------------------------------------------------------
# Build and append JSONL entry
# ---------------------------------------------------------------------------
# Timestamp: use EPOCHREALTIME for sub-second precision if available
if [[ "${CT_USE_EPOCH}" == "true" ]]; then
  # Convert epoch float to ISO8601 using printf and date
  TS=$(date -u '+%Y-%m-%dT%H:%M:%S.000Z' 2>/dev/null || date -u '+%Y-%m-%dT%H:%M:%SZ')
else
  TS=$(date -u '+%Y-%m-%dT%H:%M:%S.000Z' 2>/dev/null || date -u '+%Y-%m-%dT%H:%M:%SZ')
fi

# Notes fragment (budget degradation marker + lines elided note)
NOTES_PARTS=()
[[ "${BUDGET_DEGRADED}" == "true" ]] && NOTES_PARTS+=("budget_degraded: enrichment skipped")
[[ -n "${LINES_NOTES}" ]] && NOTES_PARTS+=("${LINES_NOTES}")
NOTES_FRAGMENT=""
if [[ ${#NOTES_PARTS[@]} -gt 0 ]]; then
  local_notes="${NOTES_PARTS[*]}"
  NOTES_JSON=$(ct_json_str "${local_notes}")
  NOTES_FRAGMENT=",\"notes\":${NOTES_JSON}"
fi

if [[ "${IS_REDACTED}" == "true" ]]; then
  REDACT_MSG="REDACTED:${REDACT_REASON}"
  FILE_JSON=$(ct_json_str "${REDACT_MSG}")
  TOOL_JSON=$(ct_json_str "${TOOL_NAME}")
  TS_JSON=$(ct_json_str "${TS}")
  SESSION_JSON=$(ct_json_str "${SESSION_ID}")
  TRIGGER_JSON=$(ct_json_str "${TRIGGER}")

  JSON_LINE="{\"ts\":${TS_JSON},\"session_id\":${SESSION_JSON},\"workflow_id\":${WORKFLOW_ID_JSON},\"phase\":${CURRENT_PHASE},\"agent\":${AGENT_JSON},\"parent_dispatch_id\":${DISPATCH_JSON},\"tool\":${TOOL_JSON},\"file\":${FILE_JSON},\"before_sha256\":null,\"after_sha256\":null,\"lines_changed\":[],\"brd_ref\":null,\"spec_ref\":null,\"trigger\":${TRIGGER_JSON},\"trigger_detail\":null}"
else
  FILE_JSON=$(ct_json_str "${REL_FILE_PATH}")
  TOOL_JSON=$(ct_json_str "${TOOL_NAME}")
  TS_JSON=$(ct_json_str "${TS}")
  SESSION_JSON=$(ct_json_str "${SESSION_ID}")
  TRIGGER_JSON=$(ct_json_str "${TRIGGER}")

  if [[ "${#TRIGGER_DETAIL}" -gt 200 ]]; then
    TRIGGER_DETAIL="${TRIGGER_DETAIL:0:197}..."
  fi
  TRIGGER_DETAIL_JSON=$(ct_json_str "${TRIGGER_DETAIL}")

  JSON_LINE="{\"ts\":${TS_JSON},\"session_id\":${SESSION_JSON},\"workflow_id\":${WORKFLOW_ID_JSON},\"phase\":${CURRENT_PHASE},\"agent\":${AGENT_JSON},\"parent_dispatch_id\":${DISPATCH_JSON},\"tool\":${TOOL_JSON},\"file\":${FILE_JSON},\"before_sha256\":${BEFORE_SHA},\"after_sha256\":${AFTER_SHA},\"lines_changed\":${LINES_CHANGED},\"brd_ref\":${BRD_REF},\"spec_ref\":${SPEC_REF},\"trigger\":${TRIGGER_JSON},\"trigger_detail\":${TRIGGER_DETAIL_JSON}${NOTES_FRAGMENT}}"
fi

# Sanity-check: truncate if line exceeds 4KB (PIPE_BUF / O_APPEND atomicity guard)
if [[ ${#JSON_LINE} -gt 4096 ]]; then
  TS_JSON=$(ct_json_str "${TS}")
  SESSION_JSON=$(ct_json_str "${SESSION_ID}")
  TOOL_JSON=$(ct_json_str "${TOOL_NAME}")
  JSON_LINE="{\"ts\":${TS_JSON},\"session_id\":${SESSION_JSON},\"workflow_id\":${WORKFLOW_ID_JSON},\"phase\":${CURRENT_PHASE},\"agent\":${AGENT_JSON},\"tool\":${TOOL_JSON},\"file\":\"<TRUNCATED>\",\"notes\":\"entry exceeded 4KB PIPE_BUF limit; abbreviated\"}"
fi

# Append-only write (O_APPEND)
if ! printf '%s\n' "${JSON_LINE}" >> "${LOG_FILE}" 2>/dev/null; then
  echo "change-tracker: WARNING: could not write to ${LOG_FILE}" >&2
fi

exit 0
