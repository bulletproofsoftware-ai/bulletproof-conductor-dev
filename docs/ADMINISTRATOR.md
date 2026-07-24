# Administrator Guide — bulletproof-conductor-dev

This guide covers the operational surface: hooks, state-schema blocks, the audit sink, and validation. For end-user command usage see [HOW-TO-USE.md](HOW-TO-USE.md).

## Hooks (`hooks/hooks.json`)

### `SessionStart` → `session-start.sh`
Detects an active `conductor-state.json` and writes a status summary to `conductor-last-status.txt` for `/conduct status` to display. Silent when no workflow is active. 5-second timeout.

### `PostToolUse` (matcher `Write|Edit`) → `post-state-write.sh`
Runs on every write. When the written file is `conductor-state.json` it:

1. **Validates** the file against `schemas/conductor-state.schema.json` (Draft 2020-12).
2. **Enforces phase gates** — for STANDARD/MAJOR tiers, blocks the write (exit 1) if a phase transition occurred without all required `verification_status` gates being `pass`.
3. **Git ratcheting** — for STANDARD/MAJOR tiers, blocks phase transitions when uncommitted changes exist.
4. **Fails open on internal hook errors** — a bug in the hook never breaks a legitimate write.

Writes to any other file are ignored. This is what makes phase-gate bypass visible at the LLM tier — the Conductor cannot simply decide to skip ahead. 10-second timeout.

### `PostToolUse` (matcher `Write|Edit|NotebookEdit`) → `change-tracker.sh`
Appends a JSONL record to `.conductor/change-log.jsonl` after every write: file path, sha256 before/after, lines changed, trigger classification, and BRD-ref attribution. A denylist redacts secrets (`*.env` and other CISO-001 patterns) before logging. 5-second timeout.

## State schema (`schemas/conductor-state.schema.json`)

A 2,415-line JSON Schema (Draft 2020-12) — the **product schema** every `conductor-state.json` is validated against. Notable blocks:

- **Tier classification** — tier, per-signal scores, override tracking.
- **NHI registry** — every agent dispatch tracked with spawn/terminate times, parent lineage, tool usage, token consumption.
- **Handoff history** — source/target, expected vs received deliverables, checkpoint IDs, rollback status.
- **Gemini validations** — verdicts, completion %, per-finding RESOLVED/UNRESOLVED/REGRESSED status, attempt counts, aggregate stats.
- **Verification gates** — 10 named gates with `pass` / `fail` / `pending` / `advisory` / `skipped` states.
- **Audit sink** — external SIEM destination + emit count (see below).
- **Secrets policy** — vault enforcement, allowed credential sources, violation count.
- **Cost tracking** — budget cap, total tokens in/out, estimated cost, exceeded flag (denial-of-wallet halt).
- **Intent block** — objectives, trade-offs, delegation_boundaries, hard_limits, prohibited_behaviors (feeds kill-switch enforcement).
- **Recovery state** — last_recovery, MTTR per category, health snapshot, recovery_history.
- **Event routing** — events emitted/routed/failed, DLQ count, throughput by category.
- **Outcome metrics** — task completion rate, TTR, first-pass success rate, rework, cost per outcome, quality trend.
- **Predictive scaling** — session prediction, cost forecast, model-routing override, routing log.
- **Agent gateway** — active jobs, total external invocations, rate-limit hits.
- **Circuit breaker** — state, failure count, opens_at threshold.
- **Governance** — manifest_id/version/hash, trust_level, session_classification, audit_session_id, autonomy depth.

## Audit sink (external SIEM)

Conductor can emit audit events to an external SIEM (Wazuh, Splunk, syslog, file, or HTTP webhook) when `audit_sink.enabled = true` in `conductor-state.json`. The emitter (`hooks/scripts/lib/audit_emitter.py`) is standard-library-only and supports syslog, file, and HTTP transports with HMAC integrity.

Full transport configuration, field mapping, and examples are in **[AUDIT-SINK-CONFIG.md](AUDIT-SINK-CONFIG.md)**.

## BRD tracker location

`domains/dev/tracker.yaml` tells the `conductor-kernel:brd-tracking` skill where to read/write the requirement tracker for dev-domain workflows:

```yaml
brd_tracker_path: "BRD-tracker.json"   # project root
default_format: "json"
```

Other domains supply their own `domains/<domain>/tracker.yaml`.

## Agent cards

`agent-cards/*.json` are the 10 dev-agent JSON identity manifests (`agent_id: conductor-dev:<name>`), validated against `schemas/agent-card-schema.json`. They describe capabilities and `external_callable` status used by `conductor-agent-gateway` for A2A exposure.

## Compliance scaffolding (product templates)

- `templates/COMPLIANCE-OVERVIEW.md` — a reusable auditor-grade compliance-summary template the `conductor-kernel:compliance-overview` agent fills in at Phase 7 closeout.
- `templates/scaffold-compliance.sh` — bootstraps the compliance-evidence layout.
- `compliance-evidence/README.md` — describes the evidence directory structure (architecture, policies, pentest, sbom, attestations, etc.). These are scaffolds; populate per project.

## Validation and CI

Run `tests/validate-plugin.sh` locally before commits; `.github/workflows/validate.yml` runs the same gates in CI (shellcheck, JSON schema validity + state validation, agent frontmatter, registry consistency, hook runtime smoke tests, gitleaks secret scan, manifest sanity).

## Security posture

The repository passes an independent Code Hardener standard scan with **0 critical / 0 high** findings and a clean gitleaks pass — see [scan/scan-report.md](scan/scan-report.md). Report vulnerabilities via [`SECURITY.md`](../SECURITY.md), not public issues.

---

Apache-2.0 © 2026 bulletproofsoftware-ai. See [LICENSE](../LICENSE) and [NOTICE](../NOTICE).
