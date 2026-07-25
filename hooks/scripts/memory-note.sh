#!/usr/bin/env bash
# memory-note.sh
# memory_note hook helper — add / replace / remove Live Notes in MEMORY.md.
#
# BRD: REQ-CDV-HERMES-003, REQ-CDV-HERMES-004
# Usage:
#   memory-note.sh add     <text>
#   memory-note.sh replace <substring> <new_text>
#   memory-note.sh remove  <substring>
#
# Environment:
#   MEMORY_FILE   Path to the MEMORY.md this hook edits.
#                 Default: ~/.claude/memory/MEMORY.md
#                 The file must already exist and contain the
#                 <!-- LIVE_NOTES_START --> / <!-- LIVE_NOTES_END --> markers;
#                 this hook edits only the region between them and never
#                 creates the file.
#
# Exit codes:
#   0  success
#   1  would exceed 2200-char cap (add/replace)
#   2  region markers missing or duplicated
#   3  MEMORY.md unreadable/missing
#   4  block-script veto (MEMORY_NOTE_LIVE_NOTES_WRITE not accepted)
#   5  substring not found (replace/remove)
#   6  region boundary violation (substring target found in Index block)
#   7  lock timeout (concurrent write)
#   9  unknown/internal error

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/memory-helpers.sh
source "${SCRIPT_DIR}/lib/memory-helpers.sh"

# ---------------------------------------------------------------------------
# Lock (R-E4-D: concurrent write protection)
# Uses mkdir-based locking (POSIX atomic, macOS-compatible; no flock needed).
# ---------------------------------------------------------------------------
LOCK_DIR="/tmp/memory-note.lock.d"
_LOCK_HELD=0

_acquire_lock() {
    local deadline
    deadline=$(( $(date +%s) + 2 ))
    while ! mkdir "${LOCK_DIR}" 2>/dev/null; do
        if (( $(date +%s) > deadline )); then
            echo "memory-note: ERROR: lock timeout — another memory-note.sh call is in progress" >&2
            exit 7
        fi
        sleep 0.1
    done
    _LOCK_HELD=1
    echo $$ > "${LOCK_DIR}/pid" 2>/dev/null || true
}

_release_lock() {
    if [[ "${_LOCK_HELD}" -eq 1 ]]; then
        rm -rf "${LOCK_DIR}" 2>/dev/null || true
        _LOCK_HELD=0
    fi
}

# Always release lock on exit (covers set -e early exits and signals)
trap '_release_lock' EXIT INT TERM

# ---------------------------------------------------------------------------
# _atomic_write <new_content>
# Writes new_content to MEMORY.md via tempfile → mv.
# MEMORY_NOTE_LIVE_NOTES_WRITE=1 is exported to satisfy the PreToolUse hook
# bypass check (belt-and-suspenders; the script writes directly to the
# filesystem so the env var is informational for any wrapping layer).
# ---------------------------------------------------------------------------
_atomic_write() {
    local new_content="${1}"

    # Tempfile in same directory as target for same-filesystem mv
    local tmpfile
    tmpfile=$(mktemp "${MEMORY_FILE}.memnotetmp.XXXXXX") || {
        echo "memory-note: ERROR: could not create tempfile" >&2
        exit 9
    }

    printf '%s' "${new_content}" > "${tmpfile}" 2>/dev/null || {
        rm -f "${tmpfile}" 2>/dev/null
        echo "memory-note: ERROR: write to tempfile failed" >&2
        exit 9
    }

    # Validate tempfile still has both markers before committing
    local sc ec
    sc=$(grep -cF "${LIVE_NOTES_START}" "${tmpfile}" 2>/dev/null) || sc=0
    ec=$(grep -cF "${LIVE_NOTES_END}" "${tmpfile}" 2>/dev/null) || ec=0
    if [[ "${sc}" -ne 1 || "${ec}" -ne 1 ]]; then
        rm -f "${tmpfile}" 2>/dev/null
        echo "memory-note: ERROR: tempfile lost region markers; aborting write" >&2
        exit 9
    fi

    export MEMORY_NOTE_LIVE_NOTES_WRITE=1
    mv "${tmpfile}" "${MEMORY_FILE}" 2>/dev/null || {
        unset MEMORY_NOTE_LIVE_NOTES_WRITE
        rm -f "${tmpfile}" 2>/dev/null
        echo "memory-note: ERROR: mv failed; MEMORY.md unchanged" >&2
        exit 9
    }
    unset MEMORY_NOTE_LIVE_NOTES_WRITE
}

# ---------------------------------------------------------------------------
# _rebuild_file <new_notes_body>
# Reconstructs MEMORY.md: Index block unchanged, Live Notes region updated
# with capacity header + new_notes_body.
# ---------------------------------------------------------------------------
_rebuild_file() {
    local new_body="${1}"

    # Count chars and build capacity header
    mn_count_chars "${new_body}"
    mn_format_capacity_header "${MN_CHAR_COUNT}"
    local cap_header="${MN_CAPACITY_HEADER}"

    # Python3 does the reliable file reconstruction.
    # new_body is passed as argv[4] to avoid stdin/heredoc conflicts.
    local new_content
    new_content=$(python3 -c "
import sys, os

cap_header  = sys.argv[1]
start_m     = sys.argv[2]
end_m       = sys.argv[3]
new_body    = sys.argv[4]

memory_file = os.environ.get('MEMORY_FILE',
    os.path.expanduser('~/.claude/memory/MEMORY.md'))

with open(memory_file, 'r') as f:
    original = f.read()

if start_m not in original or end_m not in original:
    sys.exit(9)

before, rest = original.split(start_m, 1)
_,      after = rest.split(end_m,   1)

if new_body.strip():
    region = start_m + '\n' + cap_header + '\n\n' + new_body + '\n\n' + end_m
else:
    region = start_m + '\n' + cap_header + '\n\n' + end_m

result = before + region + after
# Exactly one trailing newline
result = result.rstrip('\n') + '\n'
sys.stdout.write(result)
" "${cap_header}" "${LIVE_NOTES_START}" "${LIVE_NOTES_END}" "${new_body}" 2>/dev/null)

    local py_exit=$?
    if [[ "${py_exit}" -ne 0 || -z "${new_content}" ]]; then
        echo "memory-note: ERROR: file reconstruction failed (python exit ${py_exit})" >&2
        exit 9
    fi

    # Validate rebuilt content has both markers exactly once
    local sc ec
    sc=$(printf '%s' "${new_content}" | grep -cF "${LIVE_NOTES_START}" 2>/dev/null) || sc=0
    ec=$(printf '%s' "${new_content}" | grep -cF "${LIVE_NOTES_END}" 2>/dev/null) || ec=0
    if [[ "${sc}" -ne 1 || "${ec}" -ne 1 ]]; then
        echo "memory-note: ERROR: rebuilt content failed marker validation" >&2
        exit 9
    fi

    _atomic_write "${new_content}"
}

# ---------------------------------------------------------------------------
# _check_index_contamination <substring>
# Exits 6 if substring is found in the Index block (above LIVE_NOTES_START).
# ---------------------------------------------------------------------------
_check_index_contamination() {
    local substr="${1}"
    local index_block
    index_block=$(awk "/^<!-- LIVE_NOTES_START -->$/{exit} {print}" "${MEMORY_FILE}" 2>/dev/null)
    # `--` ends grep options so substrings starting with `-` aren't treated as flags.
    # printf preferred over echo because notes may contain backslashes / -n / -e
    # that bash's echo would otherwise interpret.
    if printf '%s\n' "${index_block}" | grep -qF -- "${substr}" 2>/dev/null; then
        echo "memory-note: ERROR: substring '${substr}' found in Index block (above <!-- LIVE_NOTES_START -->). Region boundary violation — refusing write." >&2
        exit 6
    fi
    return 0
}

# ---------------------------------------------------------------------------
# ACTION: add
# ---------------------------------------------------------------------------
_action_add() {
    local text="${1}"

    mn_check_markers || exit $?
    mn_extract_live_notes
    mn_extract_notes_body

    local current_body="${MN_NOTES_BODY}"

    # Build proposed new body
    local new_body
    if [[ -z "${current_body}" || "${current_body}" =~ ^[[:space:]]*$ ]]; then
        new_body="${text}"
    else
        new_body="${current_body}
§
${text}"
    fi

    mn_count_chars "${new_body}"
    local proposed_chars="${MN_CHAR_COUNT}"

    if (( proposed_chars > LIVE_NOTES_CAP )); then
        mn_count_chars "${current_body}"
        local current_chars="${MN_CHAR_COUNT}"
        echo "memory-note: ERROR: add would exceed ${LIVE_NOTES_CAP}-char cap (current: ${current_chars} chars, proposed total: ${proposed_chars} chars). Replace or remove existing entries first." >&2
        exit 1
    fi

    _rebuild_file "${new_body}"
}

# ---------------------------------------------------------------------------
# ACTION: replace
# ---------------------------------------------------------------------------
_action_replace() {
    local substr="${1}"
    local new_text="${2}"

    mn_check_markers || exit $?
    _check_index_contamination "${substr}"
    mn_extract_live_notes
    mn_extract_notes_body

    local current_body="${MN_NOTES_BODY}"

    if ! printf '%s\n' "${current_body}" | grep -qF -- "${substr}" 2>/dev/null; then
        echo "memory-note: ERROR: substring '${substr}' not found in Live Notes region" >&2
        exit 5
    fi

    # Split on §-separator, replace first matching entry, rejoin
    local new_body
    new_body=$(python3 -c "
import sys

substr   = sys.argv[1]
new_text = sys.argv[2]
body     = sys.argv[3]

entries = body.split('\n§\n')
replaced = False
new_entries = []
for entry in entries:
    if not replaced and substr in entry:
        new_entries.append(new_text)
        replaced = True
    else:
        new_entries.append(entry)

sys.stdout.write('\n§\n'.join(new_entries))
" "${substr}" "${new_text}" "${current_body}" 2>/dev/null)

    mn_count_chars "${new_body}"
    if (( MN_CHAR_COUNT > LIVE_NOTES_CAP )); then
        echo "memory-note: ERROR: replace would exceed ${LIVE_NOTES_CAP}-char cap (proposed: ${MN_CHAR_COUNT} chars). Free space by removing other entries first." >&2
        exit 1
    fi

    _rebuild_file "${new_body}"
}

# ---------------------------------------------------------------------------
# ACTION: remove
# ---------------------------------------------------------------------------
_action_remove() {
    local substr="${1}"

    mn_check_markers || exit $?
    _check_index_contamination "${substr}"
    mn_extract_live_notes
    mn_extract_notes_body

    local current_body="${MN_NOTES_BODY}"

    if ! printf '%s\n' "${current_body}" | grep -qF -- "${substr}" 2>/dev/null; then
        echo "memory-note: ERROR: substring '${substr}' not found in Live Notes region" >&2
        exit 5
    fi

    # Split on §-separator, remove first matching entry, rejoin
    local new_body
    new_body=$(python3 -c "
import sys

substr = sys.argv[1]
body   = sys.argv[2]

entries = body.split('\n§\n')
removed = False
new_entries = []
for entry in entries:
    if not removed and substr in entry:
        removed = True
    else:
        new_entries.append(entry)

sys.stdout.write('\n§\n'.join(new_entries))
" "${substr}" "${current_body}" 2>/dev/null)

    # Strip leading/trailing blank lines from the result
    new_body=$(printf '%s' "${new_body}" | awk '
        /[^ \t]/{found=1}
        found{lines[++n]=$0}
        END{
            while(n>0 && lines[n]~/^[[:space:]]*$/) n--;
            for(i=1;i<=n;i++) print lines[i]
        }
    ')

    _rebuild_file "${new_body}"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

if [[ $# -lt 2 ]]; then
    echo "Usage: memory-note.sh <add|replace|remove> <args...>" >&2
    echo "  add <text>                   — append a note (max ${LIVE_NOTES_CAP} chars total)" >&2
    echo "  replace <substring> <text>  — replace first entry containing substring" >&2
    echo "  remove <substring>          — remove first entry containing substring" >&2
    exit 9
fi

ACTION="${1}"

_acquire_lock

case "${ACTION}" in
    add)
        _action_add "${2}"
        ;;
    replace)
        if [[ $# -lt 3 ]]; then
            echo "memory-note: ERROR: 'replace' requires <substring> <new_text>" >&2
            _release_lock
            exit 9
        fi
        _action_replace "${2}" "${3}"
        ;;
    remove)
        _action_remove "${2}"
        ;;
    *)
        echo "memory-note: ERROR: unknown action '${ACTION}'. Must be add, replace, or remove." >&2
        _release_lock
        exit 9
        ;;
esac

_release_lock
exit 0
