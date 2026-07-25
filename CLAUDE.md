# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

**conductor-dev** is the dev-domain orchestrator plugin, built on top of `conductor-kernel`. It is a **declarative plugin** — no build system, no tests, no compilation. All files are markdown agents, YAML configs, JSON schemas, and bash hook scripts.

As of v1.1.0, conductor-dev REQUIRES `conductor-kernel >= 0.1.0`. The kernel supplies the orchestration primitives (tier classification, agent dispatch, validation, gate enforcement, state persistence, context management, outcome emission, and 19 kernel-side agents — critic, ciso, completeness-validator, gemini-validator, analyze-codebase, bug-find, compliance, compliance-overview, llm-security, supply-chain-security, pentest-coordinator, secrets-lifecycle, research, retrospective, outcome-collector, checkpoint, event-router, prediction-engine, recovery-engine — plus 14 skills). conductor-dev binds those primitives to dev-specific concerns (BRD-tracker.json at project root, software-development agents, Code Hardener loop, dual-AI adversarial review).

## Plugin Structure

```
commands/conduct.md        Slash command — wraps kernel dispatcher-core via BEGIN_CANONICAL block
agents/conductor*.md       19 dev-domain agent definitions (18 specialists + conductor.md orchestrator)
hooks/hooks.json           Hook manifest (SessionStart + PostToolUse)
hooks/scripts/             Bash scripts for hook execution
schemas/                   conductor-state.schema.json (legacy v2.0 — kernel v3.0 schema lives in conductor-kernel/schemas/)
agent-cards/               JSON identity manifests for gateway-exposed dev agents
domains/dev/tracker.yaml   Dev-domain BRD tracker location (BRD-tracker.json at project root)
plugin.json                Plugin manifest — declares "requires": { "conductor-kernel": ">= 0.1.0" }
```

## Architecture

### Tier System
Inherited from `conductor-kernel/lib/dispatcher-core.md §1` (canonical block duplicated in `commands/conduct.md`). Five signals — scope, type, risk, ambiguity, intent_sensitivity — weighted to a 1.0–4.0 score mapped to TRIVIAL/MINOR/STANDARD/MAJOR. Dev-specific tier-matrix weights live in `domains/dev/tier-matrix.yaml` (Phase 3 deliverable; currently inline in conduct.md).

### Workflow Flow
`/conduct new <desc>` → kernel `workflow.tier_classify` → phase sequencing → agent dispatch via Task tool → **Gemini validation (every agent)** → quality gates via `conductor-kernel:critic` → state persistence in `conductor-state.json`. Additional subcommands: `/conduct promote-skill`, `/conduct promote-skill-patch`, `/conduct refresh-skill-index`, `/conduct skill publish` (Hermes E1–E5, REQ-CDV-HERMES-005/009-015).

### Gemini Validation (Agent Accountability)
Every agent dispatch is followed by an independent `conductor-kernel:gemini-validator` run. Gemini receives the agent's task, expected deliverables, and actual file changes, then returns a structured PASS/FAIL/PARTIAL verdict. Results are recorded in `conductor-state.json.gemini_validations[]` with aggregate stats in `gemini_validation_stats`. FAIL/PARTIAL(<70%) blocks progression and triggers re-dispatch. Gemini unavailability degrades gracefully (non-blocking).

### Dev-Domain Agents (18 in this plugin + conductor.md)

**Dispatcher**: `conductor.md` (orchestrator entry)

**Software development**: conductor-architect, conductor-builder, conductor-code-reviewer, conductor-refactor, conductor-database, conductor-api-design, conductor-api-docs, conductor-doc-gen, conductor-frontend-designer

**Quality / ops**: conductor-qa, conductor-qa-review, conductor-performance, conductor-observability, conductor-devops

**Workflow / interop**: conductor-project-setup, conductor-n8n, conductor-agent-gateway, conductor-advisor

### Kernel Agents (referenced as `conductor-kernel:<name>`)

`critic`, `ciso`, `completeness-validator`, `gemini-validator`, `analyze-codebase`, `bug-find`, `compliance`, `compliance-overview`, `llm-security`, `supply-chain-security`, `pentest-coordinator`, `secrets-lifecycle`, `research`, `retrospective`, `outcome-collector`, `checkpoint`, `event-router`, `prediction-engine`, `recovery-engine` — all live in the installed `conductor-kernel` plugin under `agents/`.

### State Files (generated at runtime in target projects)
- `conductor-state.json` — workflow state. Backward compatible: schema_version "1.0" / "1.0.0" loads against `conductor-kernel/schemas/workflow-state.schema.json` (REQ-CDV-002).
- `BRD-tracker.json` — requirement tracking from extraction through completion (path governed by `domains/dev/tracker.yaml`).

### Skills
Skills moved to `conductor-kernel` (14 skills: context-management, retry-policy, self-healing, state-management, event-automation, outcome-measurement, predictive-scaling, process-knowledge, sbr, dashboard-integration, brd-tracking, workflow-reference, agent-capabilities, agent-interop). conductor-dev no longer exports skills directly.

### Hooks
- **SessionStart**: Detects active `conductor-state.json` and injects status into system message
- **PostToolUse** (Write/Edit): Validates `conductor-state.json` against schema after writes

## Key Design Constraints

- **No placeholders** — every function fully implemented, every integration actually connects
- **BRD traceability** — every requirement tracked from extraction to completion
- **Independent verification** — agent self-reporting is not trusted; conductor verifies via `conductor-kernel:critic` and `:gemini-validator`
- **Strict sequencing** — no phase/step skipped or reordered
- **Max 2 retries** — then escalate to user
- **Context budget** — 60% rule, max 3 specs per planning session, fresh context per TODO spec
- **Git ratcheting** — commit after every logical change for rollback

## Working on This Codebase

When editing agents: each `.md` file in `agents/` is a self-contained agent prompt with YAML frontmatter. The agent name must match the filename (e.g., `conductor-builder.md` defines the `conductor-builder` agent — dispatched as `conductor-dev:builder`).

When editing kernel agents/skills: edit them in your `conductor-kernel` checkout, NOT here.

When editing the canonical orchestration prose: edit `conductor-kernel/lib/dispatcher-core.md` FIRST, then re-run `scripts/ci-dispatcher-diff.sh` to refresh the sync_hash in `commands/conduct.md`. Editing the canonical block inside conduct.md directly breaks the CI hash gate (RC-16).

When editing the schema: `conductor-state.schema.json` here is the legacy v2.0 schema; the kernel v3.0 schema is at `conductor-kernel/schemas/workflow-state.schema.json` and accepts v1.0/v2.0 files for backward compatibility (REQ-CDV-002).

When editing hooks: `hooks.json` defines hook triggers; actual logic lives in `hooks/scripts/`. The `CLAUDE_PLUGIN_ROOT` variable resolves to the plugin root at runtime.

Path resolution: All paths in `plugin.json` and `hooks.json` are relative to the repository root (the directory containing `plugin.json`). At runtime, `${CLAUDE_PLUGIN_ROOT}` expands to this absolute path.

Agent dispatch uses Task tool with qualified names: `conductor-dev:<name>` for agents in this plugin, `conductor-kernel:<name>` for kernel agents. The capability matrix in `conductor-kernel/skills/agent-capabilities/references/capabilities.yaml` defines which agents handle which task types, their trust levels, and required permissions.
