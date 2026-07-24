#!/usr/bin/env bash
# test-audit-emitter.sh — smoke test the audit emitter
set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EMITTER="$PLUGIN_ROOT/hooks/scripts/lib/audit_emitter.py"

[ -x "$EMITTER" ] || { echo "FAIL: emitter not executable"; exit 1; }

PASS=0
FAIL=0

# ---- Test 1: file transport ----
TESTDIR=$(mktemp -d)
OUT="/tmp/conductor-emitter-test-$$.jsonl"
cat > "$TESTDIR/conductor-state.json" <<JSON
{
  "project_name": "emitter-test",
  "initiated_at": "2026-01-01T00:00:00Z",
  "last_updated": "2026-01-01T00:00:00Z",
  "current_phase": {"number": 1, "name": "Test", "started_at": "2026-01-01T00:00:00Z"},
  "current_step": {"number": 1, "name": "test", "status": "in_progress"},
  "task_queue": [], "completed_tasks": [], "verification_status": {},
  "audit_sink": {
    "enabled": true, "transport": "file", "syslog_target": "$OUT",
    "events_to_emit": ["phase_transition", "gate_pass"],
    "emit_count": 0
  }
}
JSON

# Baseline (emits initial phase_transition because prior=empty)
python3 "$EMITTER" "$TESTDIR/conductor-state.json"
INITIAL_LINES=$(wc -l < "$OUT" 2>/dev/null || echo 0)

# Trigger
python3 -c "
import json
p = '$TESTDIR/conductor-state.json'
s = json.load(open(p))
s['current_phase']['number'] = 2
s['verification_status']['post_extraction'] = 'pass'
json.dump(s, open(p, 'w'), indent=2)
"
python3 "$EMITTER" "$TESTDIR/conductor-state.json"
FINAL_LINES=$(wc -l < "$OUT" 2>/dev/null || echo 0)

if [ "$FINAL_LINES" -gt "$INITIAL_LINES" ]; then
    echo "PASS  file transport: $FINAL_LINES events emitted"
    PASS=$((PASS+1))
else
    echo "FAIL  file transport: no events emitted"
    FAIL=$((FAIL+1))
fi

# Verify events are valid JSON
if python3 -c "
import json, sys
for line in open('$OUT'):
    json.loads(line)
" 2>/dev/null; then
    echo "PASS  emitted events are valid JSON"
    PASS=$((PASS+1))
else
    echo "FAIL  emitted events are not valid JSON"
    FAIL=$((FAIL+1))
fi

# Verify emit_count incremented
COUNT=$(python3 -c "import json; print(json.load(open('$TESTDIR/conductor-state.json'))['audit_sink']['emit_count'])")
if [ "$COUNT" -gt 0 ]; then
    echo "PASS  emit_count incremented to $COUNT"
    PASS=$((PASS+1))
else
    echo "FAIL  emit_count not incremented"
    FAIL=$((FAIL+1))
fi

# ---- Test 2: disabled sink emits nothing ----
TESTDIR2=$(mktemp -d)
OUT2="/tmp/conductor-emitter-test-disabled-$$.jsonl"
cat > "$TESTDIR2/conductor-state.json" <<JSON
{
  "project_name": "disabled-test", "initiated_at": "2026-01-01T00:00:00Z",
  "last_updated": "2026-01-01T00:00:00Z",
  "current_phase": {"number": 5, "name": "X", "started_at": "2026-01-01T00:00:00Z"},
  "current_step": {"number": 1, "name": "x", "status": "in_progress"},
  "task_queue": [], "completed_tasks": [], "verification_status": {},
  "audit_sink": {"enabled": false, "transport": "file", "syslog_target": "$OUT2",
                 "events_to_emit": ["phase_transition"], "emit_count": 0}
}
JSON
python3 "$EMITTER" "$TESTDIR2/conductor-state.json"
if [ ! -f "$OUT2" ]; then
    echo "PASS  disabled sink emits nothing"
    PASS=$((PASS+1))
else
    echo "FAIL  disabled sink wrote events"
    FAIL=$((FAIL+1))
fi

# ---- Test 3: empty events_to_emit emits nothing ----
TESTDIR3=$(mktemp -d)
OUT3="/tmp/conductor-emitter-test-empty-$$.jsonl"
cat > "$TESTDIR3/conductor-state.json" <<JSON
{
  "project_name": "empty-events-test", "initiated_at": "2026-01-01T00:00:00Z",
  "last_updated": "2026-01-01T00:00:00Z",
  "current_phase": {"number": 5, "name": "X", "started_at": "2026-01-01T00:00:00Z"},
  "current_step": {"number": 1, "name": "x", "status": "in_progress"},
  "task_queue": [], "completed_tasks": [], "verification_status": {},
  "audit_sink": {"enabled": true, "transport": "file", "syslog_target": "$OUT3",
                 "events_to_emit": [], "emit_count": 0}
}
JSON
python3 "$EMITTER" "$TESTDIR3/conductor-state.json"
if [ ! -f "$OUT3" ]; then
    echo "PASS  empty events_to_emit emits nothing"
    PASS=$((PASS+1))
else
    echo "FAIL  empty events_to_emit emitted events"
    FAIL=$((FAIL+1))
fi

# Cleanup
rm -rf "$TESTDIR" "$TESTDIR2" "$TESTDIR3" "$OUT" "$OUT2" "$OUT3" 2>/dev/null

echo ""
echo "=== Audit emitter smoke test summary: $PASS pass / $FAIL fail ==="
exit "$FAIL"
