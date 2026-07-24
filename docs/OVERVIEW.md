# Overview — bulletproof-conductor-dev

## What this is

`bulletproof-conductor-dev` is the **dev-domain orchestrator** plugin for [Claude Code](https://claude.com/claude-code). It is one half of a two-plugin system: the domain-agnostic orchestration engine lives in the sibling plugin [`conductor-kernel`](https://github.com/bulletproofsoftware-ai/bulletproof-conductor-kernel) (required dependency, `>= 0.1.0`), and this plugin binds that engine to software-development work by supplying the dev agents, the `/conduct` command surface, the dev BRD-tracker location, and enforcement hooks.

The Conductor takes a request, classifies it into a **tier** (TRIVIAL → MAJOR), and drives the work through a **phase pipeline with verification gates that are programmatically enforced** — not advisory. Every requirement is tracked from extraction to completion, every agent dispatch is independently validated, and the whole run leaves an audit trail in `conductor-state.json`.

## Why it exists

Agentic development workflows tend to fail in predictable ways: an agent claims a task is done when it is not, a phase gets skipped "to go faster", a requirement quietly falls off the list, or an agent racks up unbounded cost. conductor-dev is built to make those failures structurally impossible for the tiers that demand it:

- **Strict sequencing** — a `PostToolUse` hook blocks any write to `conductor-state.json` that advances a phase without the required verification gates passing (STANDARD/MAJOR tiers).
- **Independent verification** — agent self-reporting is not trusted; the kernel's `gemini-validator` runs after every dispatch.
- **No placeholders** — every requirement must be fully implemented before it advances; stubs are rejected at the critic gate.
- **Audit trail by construction** — NHI (non-human identity) tracking, handoff history, gate decisions, Gemini verdicts, and prohibited-behavior detections all emit to state and optionally to an external SIEM.
- **Cost ceilings** — denial-of-wallet protection halts the workflow when the budget cap is hit.

## How the pieces fit

```
User → /conduct new "<request>"
          │
          ▼
   Tier classification (5-signal weighted matrix, in conductor-kernel)
          │
          ▼
   Phase pipeline (0–7) with verification gates
          │   dispatches ↓                      validates ↓
   conductor-dev agents            conductor-kernel agents
   (architect, builder, qa, …)     (critic, ciso, gemini-validator, …)
          │
          ▼
   conductor-state.json  ←── PostToolUse hook validates every write
   BRD-tracker.json      ←── requirement tracking (path from domains/dev/tracker.yaml)
```

- **conductor-dev supplies** the 17 dev agents + the dispatcher, the `/conduct` slash command, the `domains/dev/tracker.yaml` BRD location, the `conductor-state.schema.json` product schema, and the SessionStart / PostToolUse hooks.
- **conductor-kernel supplies** tier classification, dispatch/validation/gate-enforcement/state-persistence semantics, 19 kernel agents (`critic`, `ciso`, `gemini-validator`, `completeness-validator`, and 15 others), and 14 skills. conductor-dev references them as `conductor-kernel:<name>`.

## Tier classification

Five-signal weighted matrix: `scope` 0.25 + `type` 0.20 + `risk` 0.20 + `ambiguity` 0.15 + `intent_sensitivity` 0.20.

| Tier | Score | Workflow profile |
|------|-------|------------------|
| TRIVIAL | 1.0–1.5 | analyze → builder(plan-and-implement) → verify |
| MINOR | 1.6–2.3 | analyze → builder(plan) → spec-alignment → builder(readback + implement) → ciso(advisory) → critic(advisory) → verify |
| STANDARD | 2.4–3.2 | Full Phase 0–7, advisory critic gates, **blocking** PRE-RELEASE + POST-PENTEST + COMPLETENESS + supply-chain + adversarial review |
| MAJOR | 3.3–4.0 | Full Phase 0–7, **all** critic gates blocking, hardening loop to score 1000, dual-AI adversarial review |

Any task touching `intent.hard_limits[]` auto-escalates to STANDARD minimum.

## The dev agents (17 + dispatcher)

Dispatched as `conductor-dev:<name>` (bare `conductor-<name>` still resolves, for v1.0.x compatibility). Models are set per agent in frontmatter (`opus[1m]` for the architect/builder/dispatcher, `sonnet` for most specialists, `haiku` for doc-gen and project-setup).

**Software development (9):** `conductor-architect` (exhaustive implementation-ready specs with BRD integration), `conductor-builder` (plan-only / implement-only / plan-and-implement modes), `conductor-code-reviewer`, `conductor-refactor`, `conductor-database` (Postgres/MySQL/MongoDB/Redis + ORMs), `conductor-api-design` (OpenAPI/GraphQL/contract testing), `conductor-api-docs`, `conductor-doc-gen`, `conductor-frontend-designer`.

**Quality and operations (5):** `conductor-qa` (final gatekeeper, BRD gap analysis, 25+ testing tools), `conductor-qa-review` (multi-model Claude+Gemini+Codex adversarial review with consensus engine), `conductor-performance` (K6/Locust/Artillery/Lighthouse), `conductor-observability` (Prometheus/Grafana/OpenTelemetry), `conductor-devops` (CI/CD, Docker, Kubernetes).

**Workflow and interop (3):** `conductor-project-setup`, `conductor-n8n` (idea → importable n8n workflow JSON), `conductor-agent-gateway` (A2A interop — exposes agents via REST/MCP/A2A adapters).

**Dispatcher:** `conductor` — the orchestrator entry point (`agents/conductor.md`).

## The state schema

`schemas/conductor-state.schema.json` (JSON Schema Draft 2020-12) is a **product schema** that every `conductor-state.json` write is validated against. It defines tier classification + signals, the NHI registry, handoff history, Gemini validations, 10 named verification gates, audit sink, secrets policy, cost tracking, the `intent` block, and the recovery / event-routing / outcome / predictive-scaling / agent-gateway / circuit-breaker / governance blocks. See the [ADMINISTRATOR](ADMINISTRATOR.md) doc for the operational blocks.

## Deterministic workflows (opt-in)

Two loop-shaped phases run as `Workflow`-tool scripts under `workflows/`: `hardening-loop.js` (Code Hardener scan-fix-rescan, ≤5 iterations) and `adversarial-review.js` (parallel Claude+Gemini review, ≤5-round debate). They encode sequencing and fan-out as code so no mandatory step can be skipped. Trigger with `/conduct workflow hardening` or `/conduct workflow adversarial`. The conductor retains ownership of state, gates, human-approval gates, and the git ratchet; the scripts return validated JSON the conductor persists.

## Related docs

- [INSTALL.md](INSTALL.md) — installation and dependency setup
- [HOW-TO-USE.md](HOW-TO-USE.md) — the `/conduct` command surface, end to end
- [ADMINISTRATOR.md](ADMINISTRATOR.md) — hooks, audit sink, state schema operations, validation
- [SBOM.md](SBOM.md) — dependency inventory (zero runtime deps)
- [scan/scan-report.md](scan/scan-report.md) — independent security scan (0 critical / 0 high)
- [AUDIT-SINK-CONFIG.md](AUDIT-SINK-CONFIG.md) — external SIEM configuration

---

Apache-2.0 © 2026 bulletproofsoftware-ai. See [LICENSE](../LICENSE) and [NOTICE](../NOTICE).
