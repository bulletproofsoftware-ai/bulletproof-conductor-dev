#!/usr/bin/env bash
# change-tracker-helpers.sh
# Shared helpers for change-tracker.sh — SHA256, BRD-ref resolution,
# trigger classification, denylist matching, rotation logic.
# Sourced by change-tracker.sh; not executed directly.
#
# BRD: REQ-CDV-HERMES-001
# Hard limits: append-only, non-blocking, 100ms budget guard

# ---------------------------------------------------------------------------
# DENYLIST — sensitive-path patterns (CISO-001 remediation 2026-05-19)
# Case-insensitive fnmatch globs.  Supplemented at runtime by operator
# override file ~/.claude/scripts/change-tracker-denylist.txt (one glob per
# line; lines starting with # are comments).
# ---------------------------------------------------------------------------

CT_BUILTIN_DENYLIST=(
  "*/.env"
  "*/.env.*"
  "*.env"
  "*.env.*"
  "*.env.local"
  "*.env.production"
  "*.env.staging"
  "*/secrets/*"
  "*/credentials*"
  "*credentials.json"
  "*credentials.yaml"
  "*/private-key*"
  "*.pem"
  "*.key"
  "*_rsa"
  "*_dsa"
  "*_ed25519"
  "*/.ssh/*"
  "*/.aws/credentials"
  "*/.gnupg/*"
  "*/customers/*/private/*"
)

# ct_load_denylist — populates CT_EFFECTIVE_DENYLIST combining built-in +
# operator override file.  Emits stderr warning if override file is present
# but unreadable (fails-open on override layer only).
ct_load_denylist() {
  CT_EFFECTIVE_DENYLIST=("${CT_BUILTIN_DENYLIST[@]}")
  local override_file="${HOME}/.claude/scripts/change-tracker-denylist.txt"
  if [[ -e "${override_file}" ]]; then
    if [[ -r "${override_file}" ]]; then
      while IFS= read -r line || [[ -n "${line}" ]]; do
        # strip leading/trailing whitespace; skip blank lines and comments
        line="${line#"${line%%[! ]*}"}"
        line="${line%"${line##*[! ]}"}"
        [[ -z "${line}" || "${line}" == \#* ]] && continue
        CT_EFFECTIVE_DENYLIST+=("${line}")
      done < "${override_file}"
    else
      echo "change-tracker: WARNING: override denylist ${override_file} exists but is unreadable; applying built-in list only" >&2
    fi
  fi
}

# ct_is_denied <path> — returns 0 (match/denied) or 1 (not denied).
# Uses bash's built-in [[ == ]] glob matching (case-insensitive via nocasematch).
ct_is_denied() {
  local path="${1}"
  local pattern denied_reason=""
  local saved_nocasematch
  saved_nocasematch=$(shopt -p nocasematch 2>/dev/null)
  shopt -s nocasematch
  for pattern in "${CT_EFFECTIVE_DENYLIST[@]}"; do
    # shellcheck disable=SC2254
    if [[ "${path}" == ${pattern} ]]; then
      denied_reason="${pattern}"
      eval "${saved_nocasematch}"
      CT_DENIED_REASON="${denied_reason}"
      return 0
    fi
  done
  eval "${saved_nocasematch}"
  CT_DENIED_REASON=""
  return 1
}

# ---------------------------------------------------------------------------
# SHA256 helpers
# ---------------------------------------------------------------------------

# ct_sha256_head <rel_path> <project_root>
# Returns sha256 of file at git HEAD, or empty string on any failure.
# Sets CT_BEFORE_SHA to the result.
ct_sha256_head() {
  local rel_path="${1}"
  local project_root="${2}"
  CT_BEFORE_SHA=""
  if ! command -v git &>/dev/null; then return 0; fi
  # git show exits non-zero if path not in HEAD (new/untracked file)
  local sha
  sha=$(cd "${project_root}" && git show "HEAD:${rel_path}" 2>/dev/null | shasum -a 256 2>/dev/null | awk '{print $1}')
  CT_BEFORE_SHA="${sha}"
}

# ct_sha256_disk <abs_path>
# Returns sha256 of file as it exists on disk now.
# Sets CT_AFTER_SHA to the result.
ct_sha256_disk() {
  local abs_path="${1}"
  CT_AFTER_SHA=""
  if [[ ! -f "${abs_path}" ]]; then return 0; fi
  local sha
  sha=$(shasum -a 256 "${abs_path}" 2>/dev/null | awk '{print $1}')
  CT_AFTER_SHA="${sha}"
}

# ---------------------------------------------------------------------------
# Lines-changed parsing via git diff
# ---------------------------------------------------------------------------

# ct_lines_changed <rel_path> <project_root>
# Parses @@ hunks from git diff --unified=0.
# Sets CT_LINES_CHANGED to a JSON array of changed line numbers (capped at 100).
# On any failure or binary/large diff, sets CT_LINES_CHANGED to "[]".
# Sets CT_LINES_CHANGED_NOTES to a note string if lines were elided.
ct_lines_changed() {
  local rel_path="${1}"
  local project_root="${2}"
  CT_LINES_CHANGED="[]"
  CT_LINES_CHANGED_NOTES=""

  if ! command -v git &>/dev/null; then return 0; fi
  if [[ -z "${CT_BEFORE_SHA}" ]]; then return 0; fi  # no HEAD state → empty

  local diff_out
  diff_out=$(cd "${project_root}" && git diff --unified=0 HEAD -- "${rel_path}" 2>/dev/null)
  if [[ -z "${diff_out}" ]]; then return 0; fi

  # Parse @@ hunk headers: @@ -a,b +c,d @@ or @@ -a +c @@
  # We capture the new-file (+) line ranges and expand them.
  local lines=()
  while IFS= read -r line; do
    if [[ "${line}" =~ ^\@\@[[:space:]]+-[0-9]+(,[0-9]+)?[[:space:]]\+([0-9]+)(,([0-9]+))? ]]; then
      local start="${BASH_REMATCH[2]}"
      local count="${BASH_REMATCH[4]}"
      [[ -z "${count}" ]] && count=1
      local i
      for (( i=0; i<count; i++ )); do
        lines+=("$(( start + i ))")
        if (( ${#lines[@]} > 100 )); then
          CT_LINES_CHANGED="[]"
          CT_LINES_CHANGED_NOTES="lines_changed elided — diff too large"
          return 0
        fi
      done
    fi
  done <<< "${diff_out}"

  if (( ${#lines[@]} == 0 )); then return 0; fi

  # Build JSON array
  local json="["
  local first=true
  for n in "${lines[@]}"; do
    [[ "${first}" == "true" ]] && first=false || json+=","
    json+="${n}"
  done
  json+="]"
  CT_LINES_CHANGED="${json}"
}

# ---------------------------------------------------------------------------
# BRD-ref resolution
# ---------------------------------------------------------------------------

# ct_resolve_brd_ref <abs_file_path> <project_root>
# Reads BRD-tracker.json, finds the requirement whose implementation_files[]
# contains the longest-prefix match for abs_file_path.
# Sets CT_BRD_REF to the requirement id, or empty string if not found.
ct_resolve_brd_ref() {
  local abs_path="${1}"
  local project_root="${2}"
  CT_BRD_REF="null"

  local brd_file="${project_root}/BRD-tracker.json"
  if [[ ! -f "${brd_file}" ]]; then return 0; fi
  if ! command -v jq &>/dev/null; then return 0; fi

  local best_id=""
  local best_len=0

  # Iterate requirements and their implementation_files arrays (preferred match)
  # AND todo_file (fallback match for spec_created/extracted-stage entries that
  # haven't yet populated implementation_files[]). Implementation files win on
  # ties via longest-prefix match. Per AC-E6-4 spec-stage fix 2026-05-20.
  while IFS=$'\t' read -r req_id impl_file; do
    [[ -z "${req_id}" || -z "${impl_file}" ]] && continue
    # Resolve impl_file relative to project_root if not absolute
    local resolved_impl
    if [[ "${impl_file}" == /* ]]; then
      resolved_impl="${impl_file}"
    else
      resolved_impl="${project_root}/${impl_file}"
    fi
    # Longest-prefix match: abs_path starts with resolved_impl prefix OR exact match
    if [[ "${abs_path}" == "${resolved_impl}" || "${abs_path}" == "${resolved_impl}"/* ]]; then
      local match_len="${#resolved_impl}"
      if (( match_len > best_len )); then
        best_len="${match_len}"
        best_id="${req_id}"
      fi
    fi
  done < <(jq -r '.requirements[]? | . as $r | ((.implementation_files // [])[], (.todo_file // empty)) | [$r.id // $r.req_id // "", .] | @tsv' "${brd_file}" 2>/dev/null)

  if [[ -n "${best_id}" ]]; then
    CT_BRD_REF="\"${best_id}\""
  fi
}

# ---------------------------------------------------------------------------
# Spec-ref resolution
# ---------------------------------------------------------------------------

# ct_resolve_spec_ref <project_root> <brd_source>
# Finds the newest docs/plans/*.md by mtime, comparing against brd_source
# in conductor-state.json.  Sets CT_SPEC_REF.
ct_resolve_spec_ref() {
  local project_root="${1}"
  local brd_source="${2}"
  CT_SPEC_REF="null"

  local plans_dir="${project_root}/docs/plans"
  if [[ ! -d "${plans_dir}" ]]; then return 0; fi

  # If brd_source is set and the file exists, use it
  if [[ -n "${brd_source}" && "${brd_source}" != "null" && -f "${project_root}/${brd_source}" ]]; then
    # Make path project-relative
    local rel="${brd_source#"${project_root}/"}"
    CT_SPEC_REF="\"${rel}\""
    return 0
  fi

  # Fallback: newest .md by mtime
  local newest
  newest=$(find "${plans_dir}" -maxdepth 1 -name "*.md" -printf '%T@\t%p\n' 2>/dev/null | sort -rn | head -1 | awk '{print $2}')
  # macOS find doesn't support -printf; use stat instead
  if [[ -z "${newest}" ]]; then
    newest=$(find "${plans_dir}" -maxdepth 1 -name "*.md" -exec stat -f "%m %N" {} \; 2>/dev/null | sort -rn | head -1 | awk '{print $2}')
  fi

  if [[ -n "${newest}" ]]; then
    local rel="${newest#"${project_root}/"}"
    CT_SPEC_REF="\"${rel}\""
  fi
}

# ---------------------------------------------------------------------------
# Trigger classification via governance audit.db
# ---------------------------------------------------------------------------

# ct_classify_trigger
# Queries audit.db for most recent event in the last 60s.
# Sets CT_TRIGGER and CT_TRIGGER_DETAIL.
# On any failure (sqlite3 missing, db absent, query timeout, 0 rows), sets
# CT_TRIGGER="unknown" and CT_TRIGGER_DETAIL="".
ct_classify_trigger() {
  CT_TRIGGER="spec_implementation"
  CT_TRIGGER_DETAIL=""

  local db_path="${HOME}/.claude/plugins/cache/governance/governance/0.1.0/state/audit.db"

  if ! command -v sqlite3 &>/dev/null; then
    CT_TRIGGER="unknown"
    return 0
  fi

  if [[ ! -f "${db_path}" ]]; then
    CT_TRIGGER="unknown"
    return 0
  fi

  local query_result rc
  # sqlite3's own `.timeout` busy-timeout works in milliseconds — 80ms here.
  # Previously called `timeout 0.08 sqlite3 ...` which depends on GNU coreutils
  # `timeout`, NOT installed by default on macOS — the call silently failed and
  # every entry classified as `unknown`, killing the trigger-classification
  # feature documented in agents/conductor.md §"CHANGE ATTRIBUTION".
  query_result=$(sqlite3 -cmd '.timeout 80' "${db_path}" \
    "SELECT event_type, detail FROM audit_events \
     WHERE timestamp > datetime('now', '-60 seconds') \
     ORDER BY timestamp DESC LIMIT 20" 2>/dev/null)
  rc=$?

  if [[ ${rc} -ne 0 || -z "${query_result}" ]]; then
    CT_TRIGGER="unknown"
    return 0
  fi

  # Parse first row: event_type|detail
  local first_row
  first_row=$(echo "${query_result}" | head -1)
  local event_type="${first_row%%|*}"
  local detail="${first_row#*|}"

  case "${event_type}" in
    gemini_validation)
      # Check if detail JSON has verdict: PARTIAL
      if command -v jq &>/dev/null; then
        local verdict
        verdict=$(echo "${detail}" | jq -r '.verdict // ""' 2>/dev/null)
        if [[ "${verdict}" == "PARTIAL" ]]; then
          CT_TRIGGER="gemini_correction"
          CT_TRIGGER_DETAIL="Gemini PARTIAL verdict triggered re-dispatch"
          return 0
        fi
      fi
      CT_TRIGGER="spec_implementation"
      ;;
    qa_finding)
      CT_TRIGGER="qa_finding"
      CT_TRIGGER_DETAIL="QA agent identified a finding"
      ;;
    critic_block)
      CT_TRIGGER="critic_block"
      CT_TRIGGER_DETAIL="Critic gate remediation"
      ;;
    operator_directive)
      CT_TRIGGER="operator_directive"
      CT_TRIGGER_DETAIL="Direct operator instruction"
      ;;
    *)
      CT_TRIGGER="spec_implementation"
      ;;
  esac

  # Truncate trigger_detail to 200 chars (R6 PIPE_BUF guard)
  if [[ ${#CT_TRIGGER_DETAIL} -gt 200 ]]; then
    CT_TRIGGER_DETAIL="${CT_TRIGGER_DETAIL:0:197}..."
  fi
}

# ---------------------------------------------------------------------------
# Log rotation
# ---------------------------------------------------------------------------

# ct_maybe_rotate <log_path> <archive_dir>
# If log_path >= 100MB, gzip it into archive_dir with an ISO8601 filename,
# then recreate an empty active log.
# Non-blocking: any failure is silent (stderr warning only).
ct_maybe_rotate() {
  local log_path="${1}"
  local archive_dir="${2}"

  if [[ ! -f "${log_path}" ]]; then return 0; fi

  local size
  # BSD stat (macOS) uses -f%z; GNU stat (Linux) uses -c%s. Try BSD first, fall
  # back to GNU. Without the fallback the rotation check silently no-ops on
  # Linux and the change-log grows unbounded.
  size=$(stat -f%z "${log_path}" 2>/dev/null || stat -c%s "${log_path}" 2>/dev/null)
  if [[ -z "${size}" ]]; then return 0; fi

  if (( size >= 104857600 )); then
    mkdir -p "${archive_dir}" 2>/dev/null || true
    local ts
    ts=$(date -u '+%Y%m%dT%H%M%SZ' 2>/dev/null || date -u '+%Y%m%dT%H%M%SZ')
    local archive_path="${archive_dir}/change-log-${ts}.jsonl.gz"
    if gzip -c "${log_path}" > "${archive_path}" 2>/dev/null; then
      # Truncate active log by recreating it empty (O_CREAT + O_TRUNC)
      # This is the ONLY place we truncate; the log has been archived first.
      : > "${log_path}" 2>/dev/null || true
    else
      echo "change-tracker: WARNING: rotation failed — could not write ${archive_path}" >&2
      rm -f "${archive_path}" 2>/dev/null || true
    fi
  fi
}

# ---------------------------------------------------------------------------
# JSON string escaping
# ---------------------------------------------------------------------------

# ct_json_str <value> — outputs a JSON-safe double-quoted string or null.
# Handles embedded double-quotes, backslashes, newlines, tabs.
ct_json_str() {
  local val="${1}"
  if [[ -z "${val}" ]]; then
    echo "null"
    return
  fi
  # Escape backslash first, then quotes, then control chars
  val="${val//\\/\\\\}"
  val="${val//\"/\\\"}"
  val="${val//$'\n'/\\n}"
  val="${val//$'\t'/\\t}"
  val="${val//$'\r'/\\r}"
  echo "\"${val}\""
}
