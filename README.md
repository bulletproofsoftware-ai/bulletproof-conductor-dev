# conductor-dev (Dev Domain Orchestrator) for Claude Code

> **As of v1.1.0:** This is the dev-domain plugin built on top of `conductor-kernel`. It supplies architect, builder, QA, devops, and 14 other software-development agents. All orchestration primitives (tier classification, validation, gate enforcement, state persistence) and 19 kernel agents (critic, ciso, gemini-validator, completeness-validator, etc.) live in the sibling plugin `conductor-kernel`. conductor-dev requires `conductor-kernel >= 0.1.0`.

Multi-agent workflow orchestrator with **programmatic phase-gate enforcement**, **independent Gemini validation**, BRD requirement tracking, and persistent state. Built for compliance-grade software development workflows that need a verifiable audit trail.

![bulletproof-conductor-dev — overview](docs/media/infographic.png)

> **Media:** a system-overview [explainer video](media/system-overview.mp4) and [technical briefing](media/system-overview.md) accompany this README. Full docs live in [`docs/`](docs/OVERVIEW.md).

## What It Does

The Conductor classifies every request into a tier (TRIVIAL → MAJOR), then routes the work through a phase pipeline with verification gates that are programmatically enforced — not advisory. State persists in `conductor-state.json` (validated against the kernel JSON schema on every write) and every requirement is tracked from extraction through completion in `BRD-tracker.json` (location governed by `domains/dev/tracker.yaml`).

Key design properties:

- **Strict sequencing** — no phase or step skipped or reordered (PostToolUse hook blocks invalid transitions for STANDARD/MAJOR tiers)
- **Independent verification** — agent self-reporting is not trusted; an independent Gemini validator runs after every dispatch
- **No placeholders** — every requirement must be fully implemented before it advances; stubs are rejected at the critic gate
- **Audit trail by construction** — NHI tracking, handoff history, gate decisions, Gemini verdicts, prohibited-behavior detections all emit to `conductor-state.json` and optionally to an external syslog
- **Cost ceilings** — denial-of-wallet protection halts the workflow when budget caps are hit
- **Intent engineering** — objectives, trade-offs, delegation boundaries, hard limits, and prohibited behaviors live in `intent` block and feed kill-switch enforcement

## Installation

`conductor-dev` is the development-workflow domain plugin. It requires
[`conductor-kernel`](https://github.com/bulletproofsoftware-ai/bulletproof-conductor-kernel),
which supplies the shared agents and orchestration primitives. **Install the
kernel first** — `/conduct` dispatches kernel agents and will not work without it.

Run these in Claude Code:

```
/plugin marketplace add bulletproofsoftware-ai/bulletproof-conductor-kernel
/plugin install conductor-kernel@bulletproof-conductor-kernel

/plugin marketplace add bulletproofsoftware-ai/bulletproof-conductor-dev
/plugin install conductor-dev@bulletproof-conductor-dev
```

Verify both are enabled:

```
/plugin list
```

### Prerequisites

| Requirement | Status | Notes |
|-------------|--------|-------|
| `conductor-kernel` | **Required** | Supplies the agents `/conduct` dispatches. |
| `git` | **Required** | Ratchet commits at phase boundaries. |
| `jq`, `python3` | Recommended | Used by hooks and the validation suite. |
| [Gemini CLI](https://github.com/google-gemini/gemini-cli) | Optional | Independent validation after agent dispatches. Without it, validation steps are skipped and recorded as `GEMINI:UNAVAILABLE` — the workflow continues. |
| [Code Hardener](https://github.com/bulletproofsoftware-ai/bulletproof-codehardener) | Optional | Powers the hardening gate. Without it, the gate degrades per the tier rules in [`commands/conduct.md`](commands/conduct.md). |
| `shellcheck`, `gitleaks` | Optional | Needed for full coverage in `tests/validate-plugin.sh`. |

Neither Gemini CLI nor Code Hardener is bundled. See
[Optional integrations](#optional-integrations) for how each degrades when absent.

### Verify the install

From a clone of this repository:

```bash
bash tests/validate-plugin.sh
```

This runs shellcheck (matching CI severity), JSON-schema validation, agent
frontmatter checks, hook smoke tests, and a secrets scan. Checks whose tooling
is missing report SKIP rather than failing.

## Quick Start

```bash
# Initialize a new workflow
/conduct new Build a task management API with user authentication

# Resume after a session break
/conduct resume

# Workflow status (tier, phase, step, verification gate states, Gemini stats, cost)
/conduct status

# Validate completeness before release
/conduct validate

# Reset (deletes conductor-state.json — irreversible)
/conduct reset
```

## Tier Classification

Five-signal weighted matrix (scope 0.25 + type 0.20 + risk 0.20 + ambiguity 0.15 + intent_sensitivity 0.20):

| Tier      | Score   | Workflow profile |
|-----------|---------|------------------|
| TRIVIAL   | 1.0–1.5 | analyze → builder(plan-and-implement) → verify |
| MINOR     | 1.6–2.3 | analyze → builder(plan) → spec-alignment → builder(readback + implement) → ciso(advisory) → critic(advisory) → verify |
| STANDARD  | 2.4–3.2 | Full Phase 0–7, advisory critic gates, **blocking** PRE-RELEASE + POST-PENTEST + COMPLETENESS + supply-chain + adversarial review |
| MAJOR     | 3.3–4.0 | Full Phase 0–7, **all** critic gates blocking, hardening loop to score 1000, dual-AI adversarial review |

Auto-escalation: any task touching the `intent.hard_limits[]` jumps to STANDARD minimum.

## Dev-Domain Agents (17 agents + the dispatcher = 18 files)

Dispatched as `conductor-dev:<name>`. (For v1.0.x backward compatibility, bare `conductor-<name>` still resolves to the same files.)

### Software development (9)
`conductor-architect`, `conductor-builder`, `conductor-code-reviewer`, `conductor-refactor`, `conductor-database`, `conductor-api-design`, `conductor-api-docs`, `conductor-doc-gen`, `conductor-frontend-designer`

### Quality and operations (5)
`conductor-qa`, `conductor-qa-review`, `conductor-performance`, `conductor-observability`, `conductor-devops`

### Workflow and interop (3)
`conductor-project-setup`, `conductor-n8n`, `conductor-agent-gateway`

### Dispatcher
`conductor.md` — orchestrator entry point.

## Kernel Agents (referenced via `conductor-kernel:<name>`)

These live in the `conductor-kernel` plugin, not here. Dispatched on every workflow:

- `critic` — gate validator
- `ciso` — security reviewer
- `gemini-validator` — independent verification
- `completeness-validator` — artifact verification
- `analyze-codebase`, `bug-find`, `compliance`, `compliance-overview`, `llm-security`, `supply-chain-security`, `pentest-coordinator`, `secrets-lifecycle`, `research`, `retrospective`, `outcome-collector`, `checkpoint`, `event-router`, `prediction-engine`, `recovery-engine`

## Skills

As of v1.1.0, conductor-dev exports **no skills directly**. All 14 skills (context-management, retry-policy, self-healing, state-management, event-automation, outcome-measurement, predictive-scaling, process-knowledge, sbr, dashboard-integration, brd-tracking, workflow-reference, agent-capabilities, agent-interop) moved to `conductor-kernel/skills/`. Agents in this plugin invoke them as `conductor-kernel:<skill-name>`.

## Hooks (programmatic enforcement)

### `SessionStart`
Detects active `conductor-state.json` and writes a status summary to `conductor-last-status.txt` for `/conduct status` to display. Silent if no workflow is active.

### `PostToolUse` (Write/Edit)
On every write to `conductor-state.json`:

1. Validates the file against `schemas/conductor-state.schema.json` (Draft 2020-12)
2. **Phase gate enforcement** — for STANDARD/MAJOR tiers, blocks the write (exit 1) if a phase transition occurred without all required `verification_status` gates being `pass`
3. **Git ratcheting** — for STANDARD/MAJOR tiers, blocks phase transitions when uncommitted changes exist
4. **Fail-open on hook errors** — never breaks legitimate writes due to internal hook bugs

This makes phase-gate bypass attempts visible at the LLM tier — the conductor cannot just decide to skip ahead.

## Hermes-inspired enhancements (E1–E6)

Six enhancements derived from Anthropic's Hermes agentic-runtime paper (commits `1e7fdef` → `afae373`, REQ-CDV-HERMES-001–015):

**New PostToolUse / SessionStart capabilities** (in `hooks/scripts/`):

- **change-tracker** (E6) — `change-tracker.sh` writes an append-only JSONL audit log to `.conductor/change-log.jsonl` after every Write/Edit/MultiEdit: file path, sha256 before/after, lines changed, trigger classification, BRD-ref. Denylist redaction for `*.env` and other CISO-001 patterns.
- **memory-note** (E4) — `memory-note.sh add|replace|remove` edits the `<!-- LIVE_NOTES_START -->` ... `<!-- LIVE_NOTES_END -->` region of `~/.claude/memory/MEMORY.md` only (2200-char hard cap, mkdir-atomic lock, index-block contamination check). SessionStart hook recomputes the in-region capacity header.
- **skill-index** (E2) — `build-skill-index.sh` aggregates skill frontmatter across user + kernel + clue-soc + marketplace into `~/.claude/skill-index.json` (50KB cap → category-only fallback). Reference launchd plist provided for nightly rebuild.

**New `/conduct` subcommands**:

- `/conduct promote-skill <slug>` (E1) — review and promote an agent-drafted skill from `~/.claude/skills/_proposed/`. Operator APPROVE/REJECT stdin gate; never auto-promotes. CISO-003 prompt-injection sanitization is fail-closed.
- `/conduct promote-skill-patch <patch_path>` (E1) — apply a skill self-improvement patch from `~/.claude/skills/_patches/`. Same operator gate + writing-skills shape-check + sanitization.
- `/conduct refresh-skill-index` (E2) — regenerate the skill index on demand.
- `/conduct skill publish <slug>` (E5) — validate a skill against the agentskills.io open spec and bundle it into a portable archive at `~/.claude/skills/<slug>/.publish/`.

**E3 Programmatic Tool Calling (code-mode)** ships as kernel-side scripts in `conductor-kernel/scripts/` (code-mode-dispatch.sh, code-mode-template.js, code-mode-audit-mcp.py) plus envelope-template additions in `agents/conductor.md` and `agents/critic.md`.

**E5 agentskills.io standard alignment** also adds `agentskills-validator.sh` (against the local snapshot at `conductor-kernel/scripts/references/agentskills-spec-v1.json`) and the companion `writing-skills-agentskills-extension` skill.

**Verification**: The Hermes enhancements passed a Code Hardener standard scan and Claude adversarial review with all HIGH findings remediated. The current published scan artifacts for this repo live in [`docs/scan/`](docs/scan/scan-report.md).

## Deterministic Workflows (opt-in)

Two self-contained, loop-shaped phases run as `Workflow`-tool scripts under `workflows/`:
`hardening-loop.js` (Code Hardener scan-fix-rescan, ≤5 iterations) and `adversarial-review.js`
(parallel Claude+Gemini review, ≤5-round debate). They encode sequencing and fan-out as code so
no mandatory step can be skipped. Trigger with `/conduct workflow hardening` or
`/conduct workflow adversarial`. The conductor keeps ownership of `conductor-state.json`, gate
enforcement, human-approval gates, and the git ratchet; the scripts return validated JSON the
conductor persists. Verified structurally and at the Code Hardener `/api/v1` contract level.
See `workflows/README.md` for authoring rules.

## Hookify Enforcement (operator-installed)

Five `.claude/hookify.*.local.md` rules ship with this repo to enforce conductor-protocol compliance:

- `conductor-prompt-detection` — flags conductor-protocol prompts in user messages
- `require-conductor-state` — blocks writes to `agents/`, `skills/`, `hooks/`, `schemas/` unless an active `conductor-state.json` exists
- `enforce-phase-sequence` — blocks implementation writes until BRD extraction + spec alignment + correct phase
- `require-gemini-validation` — blocks `Stop` event until every agent dispatch has a corresponding Gemini validation
- `verify-before-claiming-done` — blocks `Stop` until verification evidence is shown

These rules require the a hookify plugin. Disable per-rule via `/hookify configure`.

## Schema (`schemas/conductor-state.schema.json`)

2,415 lines covering:

- Tier classification + signals + override tracking
- NHI (Non-Human Identity) registry — every agent dispatch tracked with spawn/terminate times, parent lineage, tool usage, token consumption
- Handoff history — source/target/expected/received deliverables/checkpoint IDs/rollback status
- Gemini validations — verdicts, completion %, per-finding RESOLVED/UNRESOLVED/REGRESSED status, attempt counts, aggregate stats
- Verification gates — 10 named gates with pass/fail/pending/advisory/skipped states
- Audit sink — external syslog destination + emit count
- Secrets policy — vault enforcement, allowed credential sources, violation count
- Cost tracking — budget cap, total tokens in/out, estimated cost, exceeded flag
- Intent block — objectives, trade-offs, delegation_boundaries, hard_limits, prohibited_behaviors
- Recovery state (PRD 12) — last_recovery, MTTR per category, health snapshot, recovery_history
- Event routing (PRD 13) — events emitted/routed/failed, DLQ count, throughput by category
- Outcome metrics (PRD 15) — task completion rate, TTR, first-pass success rate, rework, cost per outcome, quality trend, recovery rate, context efficiency
- Predictive scaling (PRD 16) — session prediction, cost forecast, model routing override, routing log
- Agent gateway (PRD 17) — active jobs, total external invocations, rate limit hits
- Circuit breaker — state, failure count, opens_at threshold
- Governance — manifest_id/version/hash, trust_level, session_classification, audit_session_id, autonomy depth

## PRD Coverage

This plugin implements or integrates with all 17 [BulletproofSoftware PRDs](https://bulletproofsoftware.ai/code/prds/):

| # | PRD | Conductor responsibility |
|---|-----|--------------------------|
| 1 | Plugin Ecosystem | Reference implementation |
| 2 | **Multi-Agent Orchestration** | **Owner** — see `agents/conductor.md` |
| 3 | Context Management | `context-management` skill |
| 4 | Persistent Vector Memory | Sister plugin (bulletproof-memory) — conductor uses it |
| 5 | Agent Governance | Sister plugin (governance-plugin) — `governance` schema block integrates |
| 6 | Memory Dashboard | External — schema supports event emission |
| 7 | Markdown for Agents | External |
| 8 | Code Assurance Platform | Integrated via `/conduct` Code Hardener phase |
| 9 | Agentic Data Plane | External |
| 10 | Agent Economics | `cost_tracking` schema field |
| 11 | Runtime Security | Integrated via `audit_sink` + prohibited-behavior monitoring |
| 12 | Self-Healing Workflows | `conductor-recovery-engine` + `self-healing` skill |
| 13 | Event-Driven Automation | `conductor-event-router` + `event-automation` skill |
| 14 | Process Knowledge Base | `process-knowledge` skill (YAML-direct interface; MCP tools roadmapped) |
| 15 | Outcome Measurement | `conductor-outcome-collector` + `outcome-measurement` skill |
| 16 | Predictive Scaling | `conductor-prediction-engine` + `predictive-scaling` skill |
| 17 | A2A Interoperability | `conductor-agent-gateway` + `agent-interop` skill |

## Compliance Frameworks Supported

The `conductor-ciso` agent maps controls to:

- **NIST SSDF** (SP 800-218 v1.1/1.2) — full PO/PS/PW/RV practice areas
- **OWASP Top 10 2025** — Web, API, and LLM versions
- **CISA SBOM Requirements** — supply chain
- **SOC 2** Type II, **ISO/IEC 27001:2022**, **ISO/IEC 42001** (AI management)
- **GDPR, HIPAA, PCI-DSS, FedRAMP** (when configured via `project_characteristics.compliance_requirements`)
- **SLSA Levels 1–4** — via `conductor-supply-chain-security`
- **EU AI Act** — via governance plugin integration
- **Zero Trust Architecture** — default-deny, continuous verification
- **PQC readiness** — Cryptographic Bill of Materials (C-BOM) generation

## Validation

Run `tests/validate-plugin.sh` to verify locally before commits:

- `shellcheck` on every hook
- JSON Schema Draft 2020-12 validity + state-against-schema validation
- Agent frontmatter completeness (name + description + model)
- Agent registry consistency (every implemented registry agent has a file)
- Skill reference file existence (every `references/...` mentioned in `SKILL.md` exists)
- Hook runtime smoke tests (including injection attempt)
- Secrets scan (gitleaks)
- Plugin manifest sanity

CI runs the same checks via `.github/workflows/validate.yml`.

## Architecture

```
.claude-plugin/
  plugin.json                Plugin manifest (declares conductor-dev v1.1.0 + requires conductor-kernel >= 0.1.0)
  marketplace.json           Marketplace entry
commands/
  conduct.md                 /conduct slash command (BEGIN_CANONICAL block duplicates conductor-kernel/lib/dispatcher-core.md verbatim)
agents/                      18 agent definitions (17 agents + dispatcher) (.md with YAML frontmatter)
hooks/
  hooks.json                 Hook trigger manifest
  scripts/
    session-start.sh         SessionStart hook
    post-state-write.sh      PostToolUse hook (validate + enforce phase gates)
    lib/state-utils.sh       Shared bash utilities
schemas/
  conductor-state.schema.json    Legacy v2.0 schema (kernel v3.0 schema lives in conductor-kernel/schemas/)
domains/dev/
  tracker.yaml               BRD tracker location for dev domain
agent-cards/                 10 dev-agent JSON identity manifests (agent_id: conductor-dev:<name>)
tests/
  validate-plugin.sh         Local CI mirror
.github/workflows/
  validate.yml               CI: shellcheck + schema + yamllint + consistency + secrets
docs/                        Architecture decisions, retrospectives, runbooks
```

## Optional integrations

Two external tools sharpen the workflow. Neither is bundled, and the plugin
states plainly when one is missing rather than pretending the gate ran.

### Gemini CLI

Used to independently validate agent output after a dispatch. Install
[gemini-cli](https://github.com/google-gemini/gemini-cli) and ensure `gemini`
is on `PATH`.

When absent, validation steps are recorded as `GEMINI:UNAVAILABLE` in
`conductor-state.json` and the workflow continues. A skipped validation is
never recorded as a pass.

### Code Hardener

Powers the hardening gate (scan → fix → rescan, up to 5 iterations). Run
[bulletproof-codehardener](https://github.com/bulletproofsoftware-ai/bulletproof-codehardener)
per its own README.

| Variable | Default | Purpose |
|----------|---------|---------|
| `CODEHARDENER_URL` | `http://localhost:7002` | Base URL of the backend. API paths hang off `/api/v1`. |
| `CODEHARDENER_USER` | `dev@codehardener.local` | Identity sent as the `X-User-Id` header. |

The gate is **mandatory by default** and degrades by tier when the service is
unreachable — MAJOR blocks, STANDARD blocks with an explicit override, MINOR
records `hardening.status = "skipped_unavailable"` and continues. The full
rules live in [`commands/conduct.md`](commands/conduct.md).

### Other environment variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `CONDUCTOR_KERNEL_ROOT` | — | Absolute path to the installed `conductor-kernel`, used when invoking kernel helper scripts directly. |
| `MEMORY_FILE` | `~/.claude/memory/MEMORY.md` | File the `memory_note` hook edits. Must already exist with the Live Notes markers. |
| `CONDUCTOR_DOC_SYNC_HOOK` | — | Executable invoked with a generated document path after `templates/scaffold-compliance.sh` runs. Unset means no sync. |

## Companion Tools

- **[conductor-kernel](https://github.com/bulletproofsoftware-ai/bulletproof-conductor-kernel)** — required dependency (>= 0.1.0). Supplies orchestration primitives, 19 kernel agents, and 14 skills.
- **conductor-dashboard *(companion, not yet open-sourced)*** — real-time UI watching `conductor-state.json` via filesystem events
- **[claude-memory-plugin](https://github.com/bulletproofsoftware-ai/bulletproof-memory)** — Qdrant-backed persistent memory used by `conductor-kernel:retrospective`
- **[governance-plugin](https://github.com/bulletproofsoftware-ai/bulletproof-governance-plugin)** — identity manifests, constitutional contracts, audit bus integration
- **hookify-plugin *(external)*** — required for the `.claude/hookify.*.local.md` enforcement rules

## Reporting Issues / Vulnerabilities

Functional bugs: open an issue on GitHub.
Security vulnerabilities: see [`SECURITY.md`](SECURITY.md) — do not open public issues.

## License

Apache-2.0 © 2026 bulletproofsoftware-ai. See [LICENSE](LICENSE) and [NOTICE](NOTICE).
