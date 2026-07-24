# Changelog

All notable changes to this plugin are documented here. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] — 2026-05-12

### Changed (BREAKING for downstream callers — see Migration)
- **Renamed plugin** `conductor` → `conductor-dev`. Plugin directory renamed from `~/Code/conductor-plugin` to `~/Code/conductor-dev`. Git history preserved via `mv`.
- **Split off conductor-kernel**: 19 domain-agnostic agents and all 14 skills migrated to the new sibling plugin `conductor-kernel` (v0.1.0). conductor-dev now declares `"requires": { "conductor-kernel": ">= 0.1.0" }` in `plugin.json`.
- **/conduct command**: the orchestration prose (tier classification, dispatch, validation, gates, state, context, outcomes, workflow templates, critical rules) is now a `BEGIN_CANONICAL`/`END_CANONICAL` block duplicating `conductor-kernel/lib/dispatcher-core.md` verbatim. Domain-specific argument routing, Code Hardener QA Phase, and Adversarial Code Review Phase remain in conductor-dev. Edit canonical source first, then re-run `scripts/ci-dispatcher-diff.sh` (REQ-CDV-004).
- **Kernel agent references**: all `conductor-critic`, `conductor-gemini-validator`, `conductor-completeness-validator`, etc. references in conduct.md now use the qualified form `conductor-kernel:<name>`. Dev agents remain available as `conductor-dev:<name>`.
- **Agent cards**: 4 kernel-bound cards (ciso, compliance, pentest-coordinator, research) removed from `agent-cards/`. The 11 remaining dev cards have their `agent_id` field rewritten from `conductor-<name>` to `conductor-dev:<name>`. Card hashes will be recomputed in a follow-up commit.
- **`.claude-plugin/marketplace.json`** updated to reflect new plugin name and `requires` declaration.

### Removed (moved to conductor-kernel)
- **Agents (19)**: `conductor-analyze-codebase`, `conductor-bug-find`, `conductor-checkpoint`, `conductor-ciso`, `conductor-completeness-validator`, `conductor-compliance-overview`, `conductor-compliance`, `conductor-critic`, `conductor-event-router`, `conductor-gemini-validator`, `conductor-llm-security`, `conductor-outcome-collector`, `conductor-pentest-coordinator`, `conductor-prediction-engine`, `conductor-recovery-engine`, `conductor-research`, `conductor-retrospective`, `conductor-secrets-lifecycle`, `conductor-supply-chain-security`. Dispatch as `conductor-kernel:<short-name>`.
- **Skills (14)**: `context-management`, `retry-policy`, `self-healing`, `state-management`, `event-automation`, `outcome-measurement`, `predictive-scaling`, `process-knowledge`, `sbr`, `dashboard-integration`, `brd-tracking`, `workflow-reference`, `agent-capabilities`, `agent-interop`. All now live in `conductor-kernel/skills/`. conductor-dev no longer exports any skills.

### Added
- `domains/dev/tracker.yaml` — dev-domain BRD tracker location (REQ-CDV-003).

### Compatibility
- Existing `conductor-state.json` files (schema_version "1.0" or "1.0.0") load against `conductor-kernel/schemas/workflow-state.schema.json` without modification (REQ-CDV-002, G-1).
- Live in-flight workflow `~/Code/conductor-dev/conductor-state.json` validates against the kernel schema (verified at v1.1.0 release).
- Plugin cache at `~/.claude/plugins/cache/conductor/conductor/1.0.0/` may need refresh to pick up the rename; flagged for operator follow-up.

### Migration Notes
- Hooks (`hooks/hooks.json` + `hooks/scripts/`) retained verbatim. They reference paths inside this plugin (`${CLAUDE_PLUGIN_ROOT}/...`); no kernel-aware rewrite needed for v1.1.0. Future Phase 3+ may move hook scripts to kernel.
- Agent quality registry (`data/agent-quality-registry.json`) retained verbatim; its agent name keys are dev-domain only (kernel agents track their own quality in `conductor-kernel`).
- Schema file `schemas/conductor-state.schema.json` retained at v2.0 for legacy validation. New workflows should target `conductor-kernel/schemas/workflow-state.schema.json` v3.0.

## [Unreleased]

### Added
- **Deterministic Workflow scripts** (`workflows/`): the Code Hardener hardening loop (`hardening-loop.js`) and dual-AI adversarial review (`adversarial-review.js`) run as `Workflow`-tool scripts, making their mandatory steps unskippable code. Invoked opt-in via `/conduct workflow <hardening|adversarial>`. Structural validation via `tests/test-workflow-scripts.sh`. The conductor remains the spine (state, gates, human approvals); scripts are phase-scoped muscle. Verified structurally and at the Code Hardener `/api/v1` contract level; full live scan deferred pending CH scan-quota (see `docs/verification/2026-06-01-workflow-live-run.md`).
- **Hermes-inspired enhancements (E1–E6, REQ-CDV-HERMES-001–015)** — six enhancements derived from Anthropic's Hermes agentic-runtime paper, delivered as a single MAJOR-tier workflow (`hermes-inspired-enhancements`):
  - **E6 Change Tracker** (commit `1e7fdef`, REQ-CDV-HERMES-001/002) — PostToolUse hook writes an append-only JSONL audit log of every Write/Edit/MultiEdit call to `.conductor/change-log.jsonl` with file path, SHA-256 before/after, lines changed, trigger classification, and BRD-ref attribution. CISO-001 denylist redacts secrets (`*.env`, credentials).
  - **E4 Bounded Memory with capacity awareness** (commit `f2f0c74`, REQ-CDV-HERMES-003/004) — region-marker-aware Live Notes edits in `~/.claude/memory/MEMORY.md` via `memory-note.sh` (add/replace/remove). 2200-char hard cap. SessionStart hook recomputes capacity header. mkdir-atomic locking + index-block contamination check.
  - **E2 Progressive Disclosure of skills** (commit `30f1f32`, REQ-CDV-HERMES-005/006) — `build-skill-index.sh` aggregates 124 skills across user + kernel + clue-soc + marketplace into `~/.claude/skill-index.json` (50KB cap with category-only fallback). New subcommand `/conduct refresh-skill-index`. Reference launchd plist for nightly rebuild.
  - **E3 Programmatic Tool Calling (code-mode)** + **E5 agentskills.io alignment** (commit `77c47a6`, REQ-CDV-HERMES-007/008/012-015) — code-mode dispatch via `mcp__MCP_DOCKER__code-mode` with envelope template + audit MCP; `agentskills-validator.sh` + new subcommand `/conduct skill publish` for portable agentskills.io-compliant skill bundles; companion `writing-skills-agentskills-extension` skill.
  - **E1 Agent-Authored Skills promotion pipeline** (commit `afae373`, REQ-CDV-HERMES-009/010/011) — retrospective agent drafts SKILL.md for trajectories with ≥3 successful invocations (CISO-003 prompt-injection sanitization). New subcommands `/conduct promote-skill <slug>` and `/conduct promote-skill-patch <patch_path>` with operator APPROVE/REJECT stdin gate. Schema `skill_promotion` block (candidates[] + patches[]) with strict `additionalProperties: false` on array items.
  - **Hardening (commits `2ef0a81`, `e26fdb1`)** — Code Hardener score 1000/1000 across 12 scanners (trivy, gitleaks, opengrep, checkov, grype, syft, ruff, oxlint, actionlint, jscpd, typos, package-validator). Claude adversarial review remediated 3 HIGH (grep-cF idiom causing silent marker-validation failure, macOS-missing `timeout` killing trigger classification, jq fan-out on PostToolUse hot path) + 3 MEDIUM + 2 LOW. Gemini-CLI structurally unavailable (agy is agent-mode shape, not one-shot); documented as single-reviewer degradation. See `docs/hardening-report-2026-05-20.md` and `docs/adversarial-review-2026-05-20.md`.
- `SECURITY.md` with vulnerability disclosure policy, supported-version matrix, scope, and trust model
- `CHANGELOG.md` (this file) for compliance-grade change history
- `.github/workflows/validate.yml` CI workflow: shellcheck on hooks, JSON schema validation, YAML lint, agent registry consistency check
- `tests/validate-plugin.sh` local validation runner for pre-commit verification
- `.gitignore` covering auto-generated artifacts (`conductor-last-status.txt`, `.conductor-cache/`)
- `agents/conductor-secrets-lifecycle.md` — credential lifecycle agent (rotation, vault enforcement, leak prevention)
- `agents/conductor-supply-chain-security.md` — SLSA provenance + artifact signing agent
- `agents/conductor-retrospective.md` — workflow retrospective + process-knowledge mining agent

### Fixed
- `hooks/scripts/post-state-write.sh`: replaced `${SESSION_DIR:-/tmp}/conductor_last_phase` with per-project `.conductor-cache/` to eliminate symlink race condition on shared hosts. Symlinks at the cache path are now rejected before write.

### Changed
- Code Hardener API calls in `conduct.md` migrated from the legacy `/api/*` routes to the redesigned `/api/v1/*` contract (`repoUrl`→`repoPath`, findings nested under scans).
- `README.md` rewritten to reflect actual plugin contents: 34 agents (was claimed 13), 13 skills (was claimed 7), full PRDs 12-17 implementation, Gemini validation, and hookify enforcement integration
- `skills/process-knowledge/SKILL.md` clarifies that the YAML-direct interface is v1 (current) and PRD-aligned MCP tools (`process_query`, `process_lookup`, `process_validate`) are tracked as v2
- `.claude-plugin/plugin.json` restored explicit `hooks`, `commands`, `agents`, `skills` declarations for clearer compliance auditing

### Documentation
- Added cross-reference to PRDs 12-17 in `README.md`
- Documented agent count source-of-truth as `skills/agent-interop/references/agent-registry.yaml`

## [1.0.0] — 2026-04-16

### Added
- Initial plugin release with 31 agents, 13 skills, schema, hooks
- `conductor-state.json` schema (v2.0.0, 1,913 lines)
- PostToolUse hook with programmatic phase-gate enforcement for STANDARD/MAJOR tiers
- Independent Gemini validation framework via `conductor-gemini-validator`
- 4 hookify enforcement rules: `require-conductor-state`, `enforce-phase-sequence`, `require-gemini-validation`, `conductor-prompt-detection`
- BRD tracking via `BRD-tracker.json` schema and extraction methodology
- Tier-based critic gate enforcement (advisory for MINOR, blocking for STANDARD/MAJOR)
- Cost tracking and denial-of-wallet protection
- Intent engineering layer (objectives, trade-offs, delegation_boundaries, hard_limits)

### Security
- All hook scripts have `chmod 700` permissions
- No hardcoded secrets in repository (verified via gitleaks)
- Audit sink for external syslog emission survives agent compromise
- Prohibited behavior monitoring with kill-switch via PostToolUse hook
- NIST SSDF + OWASP Top 10 2025 + supply chain + container + Zero Trust coverage in `conductor-ciso`

### Compliance
- Schema covers SOC 2, GDPR, HIPAA, PCI-DSS, ISO27001, FedRAMP frameworks
- C-BOM (Cryptographic Bill of Materials) generation in `conductor-ciso`
- PQC readiness assessment field in `project_characteristics`

[Unreleased]: https://github.com/bulletproofsoftware-ai/conductor-plugin/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/bulletproofsoftware-ai/conductor-plugin/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/bulletproofsoftware-ai/conductor-plugin/releases/tag/v1.0.0
