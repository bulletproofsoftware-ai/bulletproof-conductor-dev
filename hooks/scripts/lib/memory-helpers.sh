#!/usr/bin/env bash
# memory-helpers.sh
# Shared helpers for memory-note.sh and session-start.sh.
# Sourced; NOT executed directly.
#
# BRD: REQ-CDV-HERMES-003, REQ-CDV-HERMES-004
# Hard limit: writes are ONLY to the Live Notes region (between markers).

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

MEMORY_FILE="${MEMORY_FILE:-${HOME}/.claude/memory/MEMORY.md}"
LIVE_NOTES_CAP=2200
LIVE_NOTES_START="<!-- LIVE_NOTES_START -->"
LIVE_NOTES_END="<!-- LIVE_NOTES_END -->"
CAPACITY_HEADER_PREFIX="## Live Notes (agent-curated, 2200 char cap)"

# ---------------------------------------------------------------------------
# mn_check_markers
# Verify both region markers exist exactly once in MEMORY.md.
# Returns 0 if valid, sets MN_MARKER_ERROR with message and returns non-zero:
#   2  — one or both markers missing or duplicated
#   3  — file unreadable/missing
# ---------------------------------------------------------------------------
mn_check_markers() {
    MN_MARKER_ERROR=""
    if [[ ! -r "${MEMORY_FILE}" ]]; then
        MN_MARKER_ERROR="MEMORY.md unreadable or missing: ${MEMORY_FILE}"
        return 3
    fi
    local start_count end_count
    # grep -c prints "0" on no-match but exits 1; the previous `|| echo 0` idiom
    # double-printed "0\n0" causing the subsequent arithmetic test to fail.
    # Use `|| var=0` post-assignment instead — assigns only if grep failed.
    start_count=$(grep -cF "${LIVE_NOTES_START}" "${MEMORY_FILE}" 2>/dev/null) || start_count=0
    end_count=$(grep -cF "${LIVE_NOTES_END}" "${MEMORY_FILE}" 2>/dev/null) || end_count=0
    if [[ "${start_count}" -ne 1 || "${end_count}" -ne 1 ]]; then
        MN_MARKER_ERROR="Region markers missing or duplicated: START=${start_count} END=${end_count} in ${MEMORY_FILE}"
        return 2
    fi
    return 0
}

# ---------------------------------------------------------------------------
# mn_extract_live_notes
# Extracts the content between LIVE_NOTES_START and LIVE_NOTES_END (exclusive
# of the marker lines themselves). Stores result in MN_LIVE_NOTES_CONTENT.
# Caller must have already called mn_check_markers successfully.
# ---------------------------------------------------------------------------
mn_extract_live_notes() {
    MN_LIVE_NOTES_CONTENT=$(awk \
        "/^${LIVE_NOTES_START}$/{found=1; next} /^${LIVE_NOTES_END}$/{found=0} found{print}" \
        "${MEMORY_FILE}" 2>/dev/null)
}

# ---------------------------------------------------------------------------
# mn_extract_notes_body
# From MN_LIVE_NOTES_CONTENT, strips the capacity header (first non-empty
# line starting with "## Live Notes (agent-curated") to get the raw entries.
# Stores result in MN_NOTES_BODY.
# ---------------------------------------------------------------------------
mn_extract_notes_body() {
    MN_NOTES_BODY=$(printf '%s\n' "${MN_LIVE_NOTES_CONTENT}" | awk '
        /^## Live Notes \(agent-curated/{header_seen=1; next}
        header_seen{print}
    ')
}

# ---------------------------------------------------------------------------
# mn_count_chars <text>
# Counts characters in <text> using wc -m (UTF-8 safe).
# Stores result in MN_CHAR_COUNT.
# ---------------------------------------------------------------------------
mn_count_chars() {
    local text="${1}"
    if [[ -z "${text}" ]]; then
        MN_CHAR_COUNT=0
        return
    fi
    # printf does not add a trailing newline that would inflate the count
    MN_CHAR_COUNT=$(printf '%s' "${text}" | wc -m | tr -d '[:space:]')
}

# ---------------------------------------------------------------------------
# mn_format_capacity_header <chars>
# Formats the capacity header line with percentage and absolute count.
# Stores in MN_CAPACITY_HEADER.
# ---------------------------------------------------------------------------
mn_format_capacity_header() {
    local chars="${1:-0}"
    local pct
    if command -v bc &>/dev/null; then
        pct=$(printf "%.0f" "$(echo "scale=4; ${chars} * 100 / ${LIVE_NOTES_CAP}" | bc 2>/dev/null)" 2>/dev/null || echo 0)
    else
        # Fallback: integer arithmetic (rounds down)
        pct=$(( chars * 100 / LIVE_NOTES_CAP ))
    fi
    MN_CAPACITY_HEADER="${CAPACITY_HEADER_PREFIX} [${pct}% — ${chars}/${LIVE_NOTES_CAP} chars]"
}

# ---------------------------------------------------------------------------
# rewrite_capacity_header
# Public function: recompute char count for Live Notes body and update the
# capacity header line in-place (within the region only).
# Non-blocking — logs warning to stderr and returns 0 on any failure.
# ---------------------------------------------------------------------------
rewrite_capacity_header() {
    if ! mn_check_markers 2>/dev/null; then
        echo "memory-helpers: WARNING: ${MN_MARKER_ERROR}" >&2
        return 0
    fi

    # Best-effort lock against memory-note.sh. Same lock dir (POSIX mkdir-atomic).
    # 2s budget; if a memory-note.sh add/replace/remove is mid-write we skip the
    # capacity-header rewrite — SessionStart's rewrite is non-blocking by design
    # and the next session start will recompute. Without this lock, SessionStart
    # and memory-note.sh could race on the mv-replace, clobbering each other's
    # write.
    local mh_lock_dir="/tmp/memory-note.lock.d"
    local mh_lock_held=0 mh_deadline
    mh_deadline=$(( $(date +%s) + 2 ))
    while ! mkdir "${mh_lock_dir}" 2>/dev/null; do
        if (( $(date +%s) > mh_deadline )); then
            echo "memory-helpers: WARNING: lock contention on ${mh_lock_dir} — skipping capacity-header rewrite (will refresh next SessionStart)" >&2
            return 0
        fi
        sleep 0.05
    done
    mh_lock_held=1
    # Ensure lock is released on every return path of this function
    trap "if [[ \${mh_lock_held:-0} -eq 1 ]]; then rm -rf '${mh_lock_dir}' 2>/dev/null; fi" RETURN

    mn_extract_live_notes
    mn_extract_notes_body
    mn_count_chars "${MN_NOTES_BODY}"
    mn_format_capacity_header "${MN_CHAR_COUNT}"

    # Build sed pattern to replace any existing capacity header line in the file.
    # We use a temp-file approach for atomicity.
    local tmpfile
    tmpfile=$(mktemp "${MEMORY_FILE}.capheader.XXXXXX") || {
        echo "memory-helpers: WARNING: could not create tempfile for capacity header rewrite" >&2
        return 0
    }

    # Replace the capacity header line (the first line inside the region that
    # starts with CAPACITY_HEADER_PREFIX) with the new header.
    # Capture awk's exit code explicitly: `[[ $? -ne 0 ]]` after the redirection
    # would otherwise reflect the open() of tmpfile (which succeeded), not awk.
    local awk_rc
    awk -v new_hdr="${MN_CAPACITY_HEADER}" \
        -v start="${LIVE_NOTES_START}" \
        -v end="${LIVE_NOTES_END}" \
        -v prefix="${CAPACITY_HEADER_PREFIX}" '
        /^<!-- LIVE_NOTES_START -->/{in_region=1}
        /^<!-- LIVE_NOTES_END -->/{in_region=0}
        in_region && substr($0, 1, length(prefix)) == prefix {
            print new_hdr
            next
        }
        {print}
    ' "${MEMORY_FILE}" > "${tmpfile}" 2>/dev/null
    awk_rc=$?

    if [[ ${awk_rc} -ne 0 ]]; then
        rm -f "${tmpfile}" 2>/dev/null
        echo "memory-helpers: WARNING: awk substitution failed for capacity header" >&2
        return 0
    fi

    # Validate tmpfile still has both markers before committing
    local sc ec
    sc=$(grep -cF "${LIVE_NOTES_START}" "${tmpfile}" 2>/dev/null) || sc=0
    ec=$(grep -cF "${LIVE_NOTES_END}" "${tmpfile}" 2>/dev/null) || ec=0
    if [[ "${sc}" -ne 1 || "${ec}" -ne 1 ]]; then
        rm -f "${tmpfile}" 2>/dev/null
        echo "memory-helpers: WARNING: tempfile marker validation failed; aborting capacity header rewrite" >&2
        return 0
    fi

    # Atomic overwrite (requires same filesystem as MEMORY_FILE; mktemp in same dir)
    mv "${tmpfile}" "${MEMORY_FILE}" 2>/dev/null || {
        rm -f "${tmpfile}" 2>/dev/null
        echo "memory-helpers: WARNING: mv failed for capacity header rewrite" >&2
        return 0
    }

    return 0
}
