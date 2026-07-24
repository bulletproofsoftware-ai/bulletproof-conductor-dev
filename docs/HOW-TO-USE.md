# How To Use — bulletproof-conductor-dev

Everything runs through the `/conduct` slash command. The Conductor owns `conductor-state.json` in your current working directory and tracks requirements in `BRD-tracker.json` (location from `domains/dev/tracker.yaml`).

## Core lifecycle

```bash
# Start a new workflow — classifies the request into a tier and begins the pipeline
/conduct new Build a task management API with user authentication

# Resume after a session break (reads conductor-state.json and continues)
/conduct resume

# Status: tier, phase, step, verification-gate states, Gemini stats, cost
/conduct status

# Validate completeness before release (BRD gap check + gate review)
/conduct validate

# Reset — deletes conductor-state.json. IRREVERSIBLE.
/conduct reset
```

If you run `/conduct` with **no arguments**, it detects whether a workflow is active: if so it prints a brief status and asks what to do; if not it asks for a project description.

## What happens on `new`

1. **Tier classification** — the 5-signal weighted matrix scores the request (scope, type, risk, ambiguity, intent_sensitivity) into TRIVIAL / MINOR / STANDARD / MAJOR. Any task touching `intent.hard_limits[]` auto-escalates to STANDARD minimum.
2. **State creation** — `conductor-state.json` is written and validated against `schemas/conductor-state.schema.json`.
3. **Pipeline execution** — the tier-appropriate phase pipeline runs. Dev agents (`conductor-dev:<name>`) do the work; kernel agents (`conductor-kernel:critic`, `:ciso`, `:gemini-validator`, `:completeness-validator`, …) validate it. For STANDARD/MAJOR, phase transitions are blocked by the PostToolUse hook unless the required verification gates pass.

You do not manually drive phases — the Conductor sequences them. You can steer with free-text directives (see "Steering" below).

## Deterministic workflow sub-phases

```bash
# Code Hardener scan → fix → rescan loop (≤5 iterations)
/conduct workflow hardening

# Dual-AI (Claude + Gemini) independent review + debate (≤5 rounds)
/conduct workflow adversarial
```

These run as sandboxed `Workflow`-tool scripts that return validated JSON. The Conductor persists results into `conductor-state.json` (`hardening.scanHistory`, `adversarialReview`) and dispatches fix agents for any `mustFix` items.

## Agent lifecycle controls

```bash
# List every NHI (dispatched agent) with status
/conduct agent-status

# Suspend / un-suspend a specific agent by name
/conduct agent-suspend conductor-builder
/conduct agent-unsuspend conductor-builder
```

## Skill pipeline (Hermes E1/E2/E5)

```bash
# Rebuild the aggregated skill index on demand
/conduct refresh-skill-index

# Validate a skill against the agentskills.io open spec and bundle it
/conduct skill publish <slug>

# Review + promote an agent-drafted skill (operator APPROVE/REJECT gate)
/conduct promote-skill <slug>

# Apply a skill self-improvement patch (same operator gate)
/conduct promote-skill-patch <patch_path>
```

`promote-skill` and `promote-skill-patch` never auto-promote — they require an explicit operator **APPROVE**/**REJECT** on stdin, and prompt-injection sanitization is fail-closed.

## Steering an active workflow

Any other free text is treated as a directive for the current workflow, for example:

```bash
/conduct override tier to MAJOR
/conduct add requirement REQ-050 rate-limit the login endpoint
```

## Reading the audit trail

- **`conductor-state.json`** — the live workflow record: tier, phase, gates, NHI registry, handoff history, Gemini verdicts, cost, intent block.
- **`BRD-tracker.json`** — every requirement from extraction through completion.
- **`.conductor/change-log.jsonl`** — append-only JSONL of every Write/Edit/MultiEdit (path, sha256 before/after, lines changed, trigger classification, BRD-ref), written by the `change-tracker` hook with secret redaction.

## Optional hookify enforcement

Five `.claude/hookify.*.local.md` rules ship to harden protocol compliance (require an active state file for agent/schema writes, enforce phase sequence, require Gemini validation before `Stop`, require verification evidence before claiming done). They need the external hookify plugin and can be disabled per-rule via `/hookify configure`.

---

Apache-2.0 © 2026 bulletproofsoftware-ai. See [LICENSE](../LICENSE) and [NOTICE](../NOTICE).
