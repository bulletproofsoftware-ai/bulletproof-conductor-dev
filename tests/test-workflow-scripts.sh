#!/usr/bin/env bash
# Validates every conductor-dev Workflow script under workflows/ with check-workflow.mjs.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HARNESS="$ROOT/tests/lib/check-workflow.mjs"
shopt -s nullglob
files=("$ROOT"/workflows/*.js)
if [ ${#files[@]} -eq 0 ]; then
  echo "no workflow scripts found in $ROOT/workflows" >&2
  exit 1
fi
fail=0
for f in "${files[@]}"; do
  if ! node "$HARNESS" "$f"; then fail=1; fi
done
exit "$fail"
