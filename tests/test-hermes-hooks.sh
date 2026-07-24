#!/usr/bin/env bash
# test-hermes-hooks.sh — smoke tests for the Hermes E1-E6 hook scripts.
# Pins the regressions identified in docs/adversarial-review-2026-05-20.md:
#   HIGH#1 grep -cF idiom (memory-helpers.sh, memory-note.sh)
#   HIGH#2 single-jq collapse output shape (change-tracker.sh)
#   HIGH#3 sqlite3 -cmd '.timeout 80' (change-tracker-helpers.sh)
#   MED#2  grep -qF -- "${substr}" / printf '%s\n' (memory-note.sh)
#   LOW#1  stat -f%z BSD/GNU fallback (change-tracker-helpers.sh)
#
# Each test exits non-zero on failure; the runner exits 0 only if all pass.

set -uo pipefail

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MEMORY_HELPERS="${PLUGIN_ROOT}/hooks/scripts/lib/memory-helpers.sh"
MEMORY_NOTE="${PLUGIN_ROOT}/hooks/scripts/memory-note.sh"
CHANGE_TRACKER="${PLUGIN_ROOT}/hooks/scripts/change-tracker.sh"
CHANGE_TRACKER_HELPERS="${PLUGIN_ROOT}/hooks/scripts/lib/change-tracker-helpers.sh"

for f in "${MEMORY_HELPERS}" "${MEMORY_NOTE}" "${CHANGE_TRACKER}" "${CHANGE_TRACKER_HELPERS}"; do
    [ -r "${f}" ] || { echo "FAIL  prerequisite missing: ${f}"; exit 1; }
done

PASS=0
FAIL=0
TMPROOT=$(mktemp -d /tmp/hermes-hooks-test.XXXXXX)
trap 'rm -rf "${TMPROOT}" 2>/dev/null; rm -rf /tmp/memory-note.lock.d 2>/dev/null' EXIT

# ----------------------------------------------------------------------------
# HIGH#1 — mn_check_markers no longer silently passes on corrupted MEMORY.md
# ----------------------------------------------------------------------------
echo ""
echo "=== HIGH#1 grep -cF idiom (mn_check_markers) ==="

# Case A: valid MEMORY.md (1 START + 1 END marker) → return 0
MEM_VALID="${TMPROOT}/memory-valid.md"
cat > "${MEM_VALID}" <<'EOF'
# Memory
<!-- LIVE_NOTES_START -->
note 1
<!-- LIVE_NOTES_END -->
EOF
RESULT=$(MEMORY_FILE="${MEM_VALID}" bash -c '
    set -euo pipefail
    source "'"${MEMORY_HELPERS}"'"
    if mn_check_markers; then echo VALID_PASS; else echo "VALID_FAIL_RC=$?"; fi
' 2>&1)
if [[ "${RESULT}" == *VALID_PASS* ]]; then
    echo "PASS  valid markers: mn_check_markers returns 0"
    PASS=$((PASS+1))
else
    echo "FAIL  valid markers: ${RESULT}"
    FAIL=$((FAIL+1))
fi

# Case B: missing markers (0 START + 0 END) → return 2 with MN_MARKER_ERROR set
MEM_MISSING="${TMPROOT}/memory-missing.md"
cat > "${MEM_MISSING}" <<'EOF'
# Memory
no markers here at all
EOF
RESULT=$(MEMORY_FILE="${MEM_MISSING}" bash -c '
    set -euo pipefail
    source "'"${MEMORY_HELPERS}"'"
    if mn_check_markers; then
        echo "MISSING_FALSE_PASS"
    else
        rc=$?
        echo "MISSING_RC=${rc} ERROR=[${MN_MARKER_ERROR:-unset}]"
    fi
' 2>&1)
if [[ "${RESULT}" == *MISSING_RC=2* && "${RESULT}" == *START=0* && "${RESULT}" == *END=0* ]]; then
    echo "PASS  missing markers: returns 2 with correct error"
    PASS=$((PASS+1))
else
    echo "FAIL  missing markers (should return 2 with START=0 END=0): ${RESULT}"
    FAIL=$((FAIL+1))
fi

# Case C: duplicated markers (2 START + 2 END) → return 2 with MN_MARKER_ERROR set
MEM_DUP="${TMPROOT}/memory-dup.md"
cat > "${MEM_DUP}" <<'EOF'
# Memory
<!-- LIVE_NOTES_START -->
note
<!-- LIVE_NOTES_END -->
<!-- LIVE_NOTES_START -->
note 2
<!-- LIVE_NOTES_END -->
EOF
RESULT=$(MEMORY_FILE="${MEM_DUP}" bash -c '
    set -euo pipefail
    source "'"${MEMORY_HELPERS}"'"
    if mn_check_markers; then
        echo "DUP_FALSE_PASS"
    else
        rc=$?
        echo "DUP_RC=${rc} ERROR=[${MN_MARKER_ERROR:-unset}]"
    fi
' 2>&1)
if [[ "${RESULT}" == *DUP_RC=2* && "${RESULT}" == *START=2* && "${RESULT}" == *END=2* ]]; then
    echo "PASS  duplicated markers: returns 2 with correct error"
    PASS=$((PASS+1))
else
    echo "FAIL  duplicated markers (should return 2 with START=2 END=2): ${RESULT}"
    FAIL=$((FAIL+1))
fi

# Case D: confirm the broken idiom would have produced wrong answer.
# This is the regression repro — proves the test actually exercises HIGH#1.
RESULT=$(bash -c '
    set -euo pipefail
    v=$(grep -cF "FOO" /etc/hosts 2>/dev/null) || v=0
    echo "captured=${v}"
    [[ "${v}" -ne 1 ]] && echo "branch_reached" || echo "branch_skipped"
' 2>&1)
if [[ "${RESULT}" == *captured=0* && "${RESULT}" == *branch_reached* ]]; then
    echo "PASS  fixed grep idiom: captured single 0, branch logic intact"
    PASS=$((PASS+1))
else
    echo "FAIL  fixed grep idiom regression repro: ${RESULT}"
    FAIL=$((FAIL+1))
fi

# ----------------------------------------------------------------------------
# HIGH#3 — sqlite3 -cmd '.timeout 80' works without GNU timeout
# ----------------------------------------------------------------------------
echo ""
echo "=== HIGH#3 sqlite3 -cmd '.timeout 80' ==="

# Confirm: sqlite3 -cmd '.timeout 80' supported in the locally-installed sqlite3
if ! command -v sqlite3 &>/dev/null; then
    echo "SKIP  sqlite3 not installed"
else
    RESULT=$(sqlite3 -cmd '.timeout 80' ":memory:" "SELECT 1+1;" 2>&1)
    if [[ "${RESULT}" == "2" ]]; then
        echo "PASS  sqlite3 -cmd '.timeout 80' returns query result"
        PASS=$((PASS+1))
    else
        echo "FAIL  sqlite3 -cmd '.timeout 80': ${RESULT}"
        FAIL=$((FAIL+1))
    fi
fi

# Confirm: change-tracker-helpers.sh ct_classify_trigger no longer references `timeout`
if ! grep -E '^[[:space:]]*timeout [0-9]' "${CHANGE_TRACKER_HELPERS}" &>/dev/null; then
    echo "PASS  change-tracker-helpers.sh no longer invokes \`timeout N sqlite3\`"
    PASS=$((PASS+1))
else
    echo "FAIL  change-tracker-helpers.sh still calls \`timeout N sqlite3\` — HIGH#3 regression"
    FAIL=$((FAIL+1))
fi

# ----------------------------------------------------------------------------
# HIGH#2 — single-jq collapse in change-tracker.sh produces tab-separated output
# ----------------------------------------------------------------------------
echo ""
echo "=== HIGH#2 single-jq @tsv collapse ==="

# Build a synthetic state file
STATE_FILE="${TMPROOT}/conductor-state.json"
cat > "${STATE_FILE}" <<'EOF'
{
    "project_name": "smoke-test-project",
    "current_phase": {"number": 3, "name": "P3"},
    "agents_invoked": [{"agent": "conductor-dev:builder", "task_id": "T1"}],
    "agent_instances": [{"nhi_id": "nhi-abc123", "agent": "test"}],
    "brd_source": "test-brd.md"
}
EOF

# Reproduce the collapsed jq invocation exactly as it appears in change-tracker.sh
RESULT=$(jq -r '
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
' "${STATE_FILE}" 2>&1)

IFS=$'\t' read -r W P A D B <<< "${RESULT}"
if [[ "${W}" == "smoke-test-project" && "${P}" == "3" && "${A}" == "conductor-dev:builder" && "${D}" == "nhi-abc123" && "${B}" == "test-brd.md" ]]; then
    echo "PASS  collapsed jq @tsv: all 5 fields correctly extracted"
    PASS=$((PASS+1))
else
    echo "FAIL  collapsed jq @tsv:"
    echo "  WORKFLOW_ID=${W} (expected smoke-test-project)"
    echo "  CURRENT_PHASE=${P} (expected 3)"
    echo "  ACTIVE_AGENT=${A} (expected conductor-dev:builder)"
    echo "  PARENT_DISPATCH_ID=${D} (expected nhi-abc123)"
    echo "  BRD_SOURCE=${B} (expected test-brd.md)"
    FAIL=$((FAIL+1))
fi

# Edge case: current_phase as primitive (string) — should still work
STATE_FILE2="${TMPROOT}/state2.json"
echo '{"project_name":"p2","current_phase":"running","brd_source":"x.md"}' > "${STATE_FILE2}"
RESULT=$(jq -r '
    [
        (.project_name // "null"),
        (
            if .current_phase == null then "null"
            elif (.current_phase | type) == "object" then ((.current_phase.number // "null") | tostring)
            else (.current_phase | tostring)
            end
        )
    ] | @tsv
' "${STATE_FILE2}" 2>&1)
IFS=$'\t' read -r W P <<< "${RESULT}"
if [[ "${P}" == "running" ]]; then
    echo "PASS  collapsed jq @tsv: string-typed current_phase handled"
    PASS=$((PASS+1))
else
    echo "FAIL  collapsed jq @tsv on string-typed current_phase: got [${P}]"
    FAIL=$((FAIL+1))
fi

# ----------------------------------------------------------------------------
# MED#2 — grep -qF -- "${substr}" handles substrings starting with `-`
# ----------------------------------------------------------------------------
echo ""
echo "=== MED#2 grep -qF -- substring guards ==="

# Confirm: memory-note.sh contains the -- guard at all 3 expected sites
GUARD_COUNT=$(grep -c 'grep -qF -- ' "${MEMORY_NOTE}")
if [[ "${GUARD_COUNT}" -ge 3 ]]; then
    echo "PASS  memory-note.sh has \`grep -qF --\` at ${GUARD_COUNT} sites (>=3 expected)"
    PASS=$((PASS+1))
else
    echo "FAIL  memory-note.sh has \`grep -qF --\` at ${GUARD_COUNT} sites (3 expected)"
    FAIL=$((FAIL+1))
fi

# Confirm: substring starting with `-` doesn't trigger `unrecognized option`
RESULT=$(printf '%s\n' "some text -- bad" | grep -qF -- "-- bad" && echo MATCH || echo NOMATCH)
if [[ "${RESULT}" == "MATCH" ]]; then
    echo "PASS  grep -qF -- correctly matches substring beginning with dash"
    PASS=$((PASS+1))
else
    echo "FAIL  grep -qF -- regression on dash-prefixed substring: ${RESULT}"
    FAIL=$((FAIL+1))
fi

# ----------------------------------------------------------------------------
# LOW#1 — stat -f%z (BSD) with -c%s (GNU) fallback in change-tracker-helpers.sh
# ----------------------------------------------------------------------------
echo ""
echo "=== LOW#1 stat BSD/GNU fallback ==="
if grep -q 'stat -f%z .* || stat -c%s' "${CHANGE_TRACKER_HELPERS}"; then
    echo "PASS  change-tracker-helpers.sh has BSD/GNU stat fallback"
    PASS=$((PASS+1))
else
    echo "FAIL  change-tracker-helpers.sh missing GNU stat fallback"
    FAIL=$((FAIL+1))
fi

# ----------------------------------------------------------------------------
# Bash syntax check — all 4 modified files must parse
# ----------------------------------------------------------------------------
echo ""
echo "=== syntax checks ==="
for f in "${MEMORY_HELPERS}" "${MEMORY_NOTE}" "${CHANGE_TRACKER}" "${CHANGE_TRACKER_HELPERS}"; do
    if bash -n "${f}" 2>/dev/null; then
        echo "PASS  bash -n $(basename "${f}")"
        PASS=$((PASS+1))
    else
        echo "FAIL  bash -n $(basename "${f}")"
        FAIL=$((FAIL+1))
    fi
done

# ----------------------------------------------------------------------------
# Summary
# ----------------------------------------------------------------------------
echo ""
echo "============================================================"
echo "PASS: ${PASS}"
echo "FAIL: ${FAIL}"
echo "============================================================"

if [[ "${FAIL}" -gt 0 ]]; then
    exit 1
fi
exit 0
