#!/usr/bin/env python3
"""
conductor-prefill.py — Read conductor-state.json + BRD-tracker.json from a project
and pre-fill as many fields as possible in COMPLIANCE-OVERVIEW.md.

Usage:
  conductor-prefill.py <project-root>

Outputs the modified template content to stdout. The scaffolder pipes this in.

Read-only on the source state files; write happens in the scaffolder.
"""

import json
import re
import sys
import subprocess
import os
from datetime import datetime, timezone
from pathlib import Path


def load(p):
    try:
        with open(p) as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return None


def safe_get(d, *keys, default=""):
    """Walk nested dict keys safely."""
    for k in keys:
        if not isinstance(d, dict):
            return default
        d = d.get(k)
        if d is None:
            return default
    return d if d is not None else default


def git_revision(project_root):
    try:
        return subprocess.check_output(
            ["git", "-C", project_root, "rev-parse", "--short", "HEAD"],
            stderr=subprocess.DEVNULL,
            text=True,
        ).strip()
    except Exception:
        return ""


def git_tag(project_root):
    try:
        return subprocess.check_output(
            ["git", "-C", project_root, "describe", "--tags", "--abbrev=0"],
            stderr=subprocess.DEVNULL,
            text=True,
        ).strip()
    except Exception:
        return ""


def main():
    if len(sys.argv) != 2:
        print("usage: conductor-prefill.py <project-root>", file=sys.stderr)
        sys.exit(2)

    project_root = os.path.abspath(sys.argv[1])
    state_path = os.path.join(project_root, "conductor-state.json")
    brd_path = os.path.join(project_root, "BRD-tracker.json")
    template_path = os.path.join(
        os.path.dirname(os.path.abspath(__file__)), "COMPLIANCE-OVERVIEW.md"
    )

    template = Path(template_path).read_text()
    state = load(state_path) or {}
    brd = load(brd_path) or {}

    # ---------- Derived values ----------
    project_name = state.get("project_name") or os.path.basename(project_root)
    short_code = re.sub(r"[^A-Z0-9]", "", project_name.upper())[:8] or "PROJ"
    today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    today_compact = datetime.now(timezone.utc).strftime("%Y%m%d")
    semver = git_tag(project_root).lstrip("v") or "0.0.0"
    git_sha = git_revision(project_root)
    tier = state.get("tier", "")
    workflow_started = state.get("initiated_at", "")
    last_updated = state.get("last_updated", "")

    # Compliance frameworks from project_characteristics
    compliance_reqs = safe_get(state, "project_characteristics", "compliance_requirements", default=[])
    compliance_str = ", ".join(compliance_reqs) if compliance_reqs else "(none declared in conductor-state.json)"

    # Crypto inventory
    crypto_impls = safe_get(state, "project_characteristics", "crypto_implementations", default=[])
    pqc_status = safe_get(state, "project_characteristics", "pqc_readiness", default="not_assessed")

    # Verification gates
    vs = state.get("verification_status", {})
    gates_passed = [k for k, v in vs.items() if v == "pass"]
    gates_advisory = [k for k, v in vs.items() if v == "advisory_pass_with_findings"]
    gates_failed = [k for k, v in vs.items() if v == "fail"]

    # Agents invoked
    agents_invoked = state.get("agents_invoked", [])
    agent_instances = state.get("agent_instances", [])

    # Gemini validation stats
    gv_stats = state.get("gemini_validation_stats", {})

    # Cost tracking
    cost = state.get("cost_tracking", {})

    # BRD requirements summary
    total_reqs = brd.get("total_requirements", 0) if isinstance(brd, dict) else 0
    reqs_by_status = {}
    if isinstance(brd, dict):
        for r in brd.get("requirements", []):
            s = r.get("status", "unknown")
            reqs_by_status[s] = reqs_by_status.get(s, 0) + 1

    # Recovery + outcome metrics
    total_recoveries = safe_get(state, "recovery", "total_recoveries", default=0)
    completion_rate = safe_get(state, "outcome_metrics", "task_completion_rate", default=None)
    first_pass_rate = safe_get(state, "outcome_metrics", "first_pass_success_rate", default=None)

    # ---------- Build replacements ----------
    replacements = {
        "{{ PROJECT_NAME }}": project_name,
        "{{ PROJECT_SHORT_CODE }}": short_code,
        "{{ SEMVER }}": semver,
        "{{ YYYY-MM-DD }}": today,
        "{{ YYYYMMDD }}": today_compact,
    }

    for old, new in replacements.items():
        template = template.replace(old, new)

    # ---------- Append a "Conductor-Generated Pre-Fill Block" section ----------
    # This documents what was auto-detected and gives the operator a fast verification path.
    prefill_block = f"""

---

## APPENDIX A: Conductor-Generated Pre-Fill Data

> This section is auto-generated from `conductor-state.json` and `BRD-tracker.json` at compliance overview generation time. It records the workflow's audit-trail snapshot at the moment of issuance. Do **not** edit; instead, regenerate by re-running the conductor-compliance-overview agent.

**Generation timestamp:** {today} (UTC)
**Project root:** `{project_root}`
**Git revision:** `{git_sha or '(no git)'}`

### A.1 Workflow Summary

| Field | Value |
|-------|-------|
| Workflow initiated | {workflow_started or '(not recorded)'} |
| Last state update | {last_updated or '(not recorded)'} |
| Tier | {tier or '(not classified)'} |
| Tier override | {state.get('tier_override', False)} |
| Total agents invoked (unique) | {len(agents_invoked)} |
| Total NHI instances | {len(agent_instances)} |

### A.2 Verification Gates Snapshot

| Gate | Status |
|------|--------|
{chr(10).join(f'| {k} | {v or "(not run)"} |' for k, v in vs.items()) if vs else '| (no verification_status data) | — |'}

**Summary:** {len(gates_passed)} passed, {len(gates_advisory)} advisory, {len(gates_failed)} failed, {len([k for k,v in vs.items() if v == 'pending'])} pending.

### A.3 Independent Validation (Gemini) Statistics

| Metric | Value |
|--------|-------|
| Total validations run | {gv_stats.get('total_validations', 0)} |
| Pass | {gv_stats.get('pass_count', 0)} |
| Fail | {gv_stats.get('fail_count', 0)} |
| Partial | {gv_stats.get('partial_count', 0)} |
| Error (Gemini unavailable) | {gv_stats.get('error_count', 0)} |
| Re-dispatches triggered | {gv_stats.get('re_dispatches_triggered', 0)} |
| Escalations to operator | {gv_stats.get('escalations_triggered', 0)} |
| Average completion % | {gv_stats.get('avg_completion_pct', 'N/A')} |

### A.4 BRD Traceability Snapshot

| Field | Value |
|-------|-------|
| Total requirements extracted | {total_reqs} |
| Requirements by status | {', '.join(f'{s}={c}' for s, c in sorted(reqs_by_status.items())) if reqs_by_status else '(no BRD-tracker.json)'} |

### A.5 Detected Compliance Requirements (from project_characteristics)

{compliance_str}

### A.6 Cryptographic Inventory (from C-BOM in conductor-state)

{chr(10).join(f'- {a}' for a in crypto_impls) if crypto_impls else '(none recorded — populate §8.1 manually)'}

**PQC readiness:** {pqc_status}

### A.7 Cost Tracking

| Field | Value |
|-------|-------|
| Budget limit (USD) | {cost.get('budget_limit_usd', 'not set')} |
| Total input tokens | {cost.get('total_tokens_input', 0):,} |
| Total output tokens | {cost.get('total_tokens_output', 0):,} |
| Estimated cost (USD) | ${cost.get('estimated_cost_usd', 0):.2f} |
| Budget exceeded | {cost.get('budget_exceeded', False)} |

### A.8 Self-Healing Recovery Activity

| Field | Value |
|-------|-------|
| Total recovery events | {total_recoveries} |
| Total escalations | {safe_get(state, 'recovery', 'total_escalations', default=0)} |
| Active degradations | {len(safe_get(state, 'recovery', 'active_degradations', default=[]))} |

### A.9 Outcome Metrics (PRD 15)

| Metric | Value |
|--------|-------|
| Task completion rate | {completion_rate if completion_rate is not None else '(not yet computed)'} |
| First-pass success rate | {first_pass_rate if first_pass_rate is not None else '(not yet computed)'} |
| Avg TTR (minutes) | {safe_get(state, 'outcome_metrics', 'avg_ttr_minutes', default='(not computed)')} |
| Total rework cycles | {safe_get(state, 'outcome_metrics', 'total_rework_cycles', default=0)} |
| Cost per outcome (USD) | {safe_get(state, 'outcome_metrics', 'cost_per_outcome_usd', default='(not computed)')} |

### A.10 Audit Sink Configuration

| Field | Value |
|-------|-------|
| Enabled | {safe_get(state, 'audit_sink', 'enabled', default=False)} |
| Syslog target | {safe_get(state, 'audit_sink', 'syslog_target', default='(not configured)')} |
| Events emitted (cumulative) | {safe_get(state, 'audit_sink', 'emit_count', default=0)} |
| Event types subscribed | {', '.join(safe_get(state, 'audit_sink', 'events_to_emit', default=[])) or '(none)'} |

---

> **Operator action items after auto-generation:**
> 1. Verify A.5 matches the frameworks declared in §3 of this document
> 2. Verify A.6 C-BOM aligns with §8.1 — fill any gaps
> 3. Confirm A.10 audit_sink is enabled for production workloads
> 4. Walk the manual-fill checklist (§1, §4, §5, §13, §14, §15, §17 if AI, §18, §20, §25)
> 5. Obtain signatures per §25 before declaring this document effective
"""

    print(template + prefill_block)


if __name__ == "__main__":
    main()
