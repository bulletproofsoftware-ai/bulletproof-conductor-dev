#!/usr/bin/env bash
# SessionStart hook: detect conductor-state.json and report status
# Outputs JSON systemMessage if active workflow found, silent otherwise

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091  # sourced file is sibling, not in shellcheck CWD
source "$SCRIPT_DIR/lib/state-utils.sh"
# shellcheck disable=SC1091  # sourced file is sibling, not in shellcheck CWD
source "$SCRIPT_DIR/lib/memory-helpers.sh"

# Recompute Live Notes capacity header (E4 Bounded Memory — REQ-CDV-HERMES-003)
# Runs unconditionally — must precede any early exit so every session start
# keeps the capacity header current regardless of workflow state.
rewrite_capacity_header 2>/dev/null || true

# Try to find conductor-state.json
STATE_FILE="$(find_state_file 2>/dev/null)" || exit 0

# State file exists — read status
STATUS="$(get_status_summary 2>/dev/null)" || exit 0

if [ -n "$STATUS" ]; then
    # Write status to state file for /conduct status — don't print to stdout
    echo "$STATUS" > "$(dirname "$STATE_FILE")/conductor-last-status.txt" 2>/dev/null
fi

# Silent — no stdout output
echo "{}"

exit 0
