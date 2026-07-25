---
description: "Orchestrate multi-agent development workflows with tiered quality gates"
argument-hint: "[new <desc> | resume | status | reset | validate | agent-status | agent-suspend <name> | agent-unsuspend <name> | refresh-skill-index | skill publish <slug>]"
allowed-tools: ["Read", "Write", "Edit", "Glob", "Grep", "Bash", "Task", "TaskCreate", "TaskUpdate", "TaskList", "TaskGet", "AskUserQuestion"]
---

# /conduct — Multi-Agent Workflow Orchestrator (dev domain)

You are the Conductor for the **dev** domain. The orchestration semantics (tier classification, agent dispatch, validation, gate enforcement, state persistence, context management, outcome emission) are the **canonical kernel prose** duplicated verbatim below from `conductor-kernel/lib/dispatcher-core.md` per `API.md §9`. Domain-specific routing (argument parsing, Code Hardener loop, adversarial dual-AI review) lives outside the canonical block.

Parse `$ARGUMENTS` to determine the action.

## Argument Routing

**Parse `$ARGUMENTS` to determine the mode:**

### If `$ARGUMENTS` is empty or blank:
1. Check if `conductor-state.json` exists in the current working directory
2. **If exists**: Display a brief status summary (project, tier, phase, step, completion %) and ask user what they want to do (resume, status details, or reset)
3. **If not exists**: Ask user for a project description to start a new workflow

### If `$ARGUMENTS` starts with "new":
1. Extract the project description from the rest of the arguments
2. If no description provided after "new", ask for one
3. Initialize a new workflow:
   a. Run tier classification using the 5-signal weighted matrix (canonical block §1)
   b. Create `conductor-state.json` with initial state (see canonical block §4)
   c. Display tier classification results
   d. Begin the tier-appropriate workflow (canonical block §7)

### If `$ARGUMENTS` is "resume":
1. Read `conductor-state.json`
2. If not found, error: "No active workflow. Use `/conduct new <description>` to start one."
3. Display current position (phase, step, assigned agent)
4. Verify no steps were skipped
5. Continue from the current step

### If `$ARGUMENTS` is "status":
1. Read `conductor-state.json`
2. If not found, report no active workflow
3. Display comprehensive status:
   - Project name, tier, tier score
   - Current phase and step
   - Task queue (pending tasks)
   - Completed tasks count
   - Verification gate status (pass/fail/pending for each)
   - BRD progress (if BRD-tracker.json exists)
   - Remediation loops and critic rejections
   - Agents invoked
   - Gemini validation stats (total/pass/fail/partial/error, re-dispatches triggered, avg completion %)
   - Token budget: total cost, breakdown by model tier (opus/sonnet/haiku), breakdown by phase
   - Spec alignment check result (if run)
   - Builder readback verdict (if run)

### If `$ARGUMENTS` is "reset":
1. Check if `conductor-state.json` exists
2. Ask for confirmation: "This will delete conductor-state.json and reset the workflow. Are you sure?"
3. If confirmed, delete conductor-state.json
4. Report: "Workflow reset. Use `/conduct new <description>` to start fresh."

### If `$ARGUMENTS` is "validate":
1. Check if `conductor-state.json` exists in the current working directory
2. **If exists**: Read `project_characteristics` and `project_name` from state
3. **If not exists**: Detect project type from file patterns (package.json, requirements.txt, Dockerfile, etc.)
4. If no project files found at all, error: "No project detected. Run from a project directory."
5. Dispatch `conductor-kernel:completeness-validator` agent via Task tool:
   ```
   Task(subagent_type="conductor-kernel:completeness-validator", prompt="Run completeness validation for this project. Project root: {cwd}. Conductor state: {exists|absent}.", description="Completeness validation")
   ```
6. When agent returns, display:
   - Verdict (PASS/FAIL)
   - Domain summary (checked/skipped/failed counts)
   - Any CRITICAL or HIGH findings with file locations
   - Path to completeness-report-<timestamp>.json
7. If conductor-state.json exists, update `verification_status.completeness_validation` with the result

### If `$ARGUMENTS` starts with "workflow":

Run a phase-scoped deterministic Workflow script. **Opt-in only** — never auto-invoked by `/conduct new`.

**Invocation**: `/conduct workflow <hardening|adversarial>`

**Behavior**:
1. Parse the workflow name from `$ARGUMENTS` (after the literal `workflow`). Accept `hardening` or `adversarial`. If empty/unknown, list the two valid names and stop.
2. Resolve the script path with an explicit name→file mapping (do NOT template the filename): `hardening` → `$CLAUDE_PLUGIN_ROOT/workflows/hardening-loop.js`; `adversarial` → `$CLAUDE_PLUGIN_ROOT/workflows/adversarial-review.js`. Expand `$CLAUDE_PLUGIN_ROOT` via `bash -c 'echo "$CLAUDE_PLUGIN_ROOT"'`.
3. Build `args`:
   - `hardening`: `{ projectName, projectPath, codehardenerUrl, codehardenerUser }` — `projectName` and `projectPath` from `conductor-state.json` (`project_name`, cwd); `codehardenerUrl` from `$CODEHARDENER_URL` and `codehardenerUser` from `$CODEHARDENER_USER` (read via `bash -c 'echo "$CODEHARDENER_URL"'`), each omitted when unset so the script falls back to `http://localhost:7002` / `dev@codehardener.local`.
   - `adversarial`: `{ diff }` — build the diff payload exactly as the Adversarial Code Review Phase Step 1 prescribes (`git diff main...HEAD`, fallback `git diff HEAD~10..HEAD`).
4. Invoke `Workflow({ scriptPath: "<resolved path>", args })`.
5. On the completion notification, read the returned JSON and persist via `state_advance` (the workflow does NOT write state). Field mapping is the conductor's job:
   - `hardening`: the workflow returns `{ history, lastScanId, finalScore, converged, iterations }`. Write `history` → `conductor-state.json.hardening.scanHistory` (inject a `timestamp` per entry as you write — the sandboxed workflow cannot produce timestamps), and record `finalScore`, `converged`, `lastScanId`. If `converged` is false after 5 iterations, the `history` entries carry only counts (`openFindings`), so re-fetch the actual remaining findings via `GET /api/v1/scans/<lastScanId>/findings?status=open` to populate `hardening.unfixableFindings` before surfacing them to the operator.
   - `adversarial`: dispatch fix agents for `mustFix` (same pattern as the Hardening Loop), document `disputed` only, then re-run `/conduct workflow hardening` to confirm the score still holds; record `mustFix`/`disputed`/`debateRoundsUsed` into `conductor-state.json.adversarialReview`.
6. Commit the state update (git ratchet) — the conductor owns this, not the workflow.

**Prerequisite (hardening)**: a reachable Code Hardener backend. Resolve the base URL from `$CODEHARDENER_URL`, defaulting to `http://localhost:7002`. If unreachable, apply the degradation rules in [Prerequisites](#prerequisites) below — never silently skip.

### If `$ARGUMENTS` starts with "agent-status":
1. Read `data/agent-quality-registry.json` (relative to plugin root)
2. Display all agents and their quality scores, routing status, first-pass rates, and common failure modes
3. If registry doesn't exist or is empty, report: "No agent quality data yet. Registry builds from Gemini validation results."

### If `$ARGUMENTS` starts with "agent-suspend":
1. Extract agent name from arguments
2. Read `data/agent-quality-registry.json`
3. Set the agent's `routing_status` to `"suspended"`
4. Write updated registry
5. Report: "{agent} suspended. It will be blocked from dispatch until unsuspended."

### If `$ARGUMENTS` starts with "agent-unsuspend":
1. Extract agent name from arguments
2. Read `data/agent-quality-registry.json`
3. Set the agent's `routing_status` to `"active"`
4. Write updated registry
5. Report: "{agent} unsuspended. Routing status reset to active."

### If `$ARGUMENTS` is "refresh-skill-index":

Regenerate `~/.claude/skill-index.json` from current skill directories.

**Invocation**: `/conduct refresh-skill-index`

**Behavior**:
1. Run `bash ${CLAUDE_PLUGIN_ROOT}/../conductor-kernel/scripts/build-skill-index.sh`
2. Capture stdout (new `skills_count`) and `generated_at`
3. Report to operator: `Skill index refreshed: <N> skills indexed at <ts>. Source dirs scanned: <list>.`
4. On non-zero exit: surface the error message and the partial state of the index file

**Exit**: 0 on success, non-zero on script failure (operator is informed and may inspect the script output)

### If `$ARGUMENTS` starts with "skill publish":

Generate an agentskills.io-compliant portable bundle for a skill.

**Invocation**: `/conduct skill publish <slug>`

**Background**: Hermes E5 (REQ-CDV-HERMES-008). Validates the skill's frontmatter against the local snapshot of the [agentskills.io open specification](https://agentskills.io/specification) (snapshot at `conductor-kernel/scripts/references/agentskills-spec-v1.json`) and bundles `SKILL.md` + `references/` + `scripts/` + `assets/` into `~/.claude/skills/<slug>/.publish/` with a sha256 manifest and a README. The bundle is suitable for upload to any agentskills.io-compatible skills hub. The script never modifies the source skill — `.publish/` is a copy.

**Behavior**:
1. Parse `<slug>` from `$ARGUMENTS` (after the literal `skill publish`). If empty, ask the operator for one.
2. Verify the slug shape: lowercase alphanumeric + single hyphens (per agentskills.io `name` field regex). If invalid, surface the regex and exit.
3. Run `bash ${CLAUDE_PLUGIN_ROOT}/../conductor-kernel/scripts/skill-publish.sh <slug>`
4. Capture the NDJSON compliance report and the `bundle_summary` JSON from stdout.
5. Display the compliance report (PASS / WARN / FAIL with `required_missing`, `recommended_missing`, `forbidden_present` field lists).
6. **On PASS or WARN (exit 0)**: report the bundle location (`<bundle_path>`), file count, total bytes, and the resulting `compliance_status`. Suggest next-step `tar -czf <slug>.tgz -C <bundle_path>/.. <bundle_dir_name>` if the operator wants a tarball for upload.
7. **On FAIL (exit 2)**: surface the `required_missing` and `forbidden_present` lists; explicitly note that NO bundle was written; suggest adding the missing fields per `conductor-kernel:writing-skills-agentskills-extension` and re-running.
8. **On IO error (exit 1 or 3)**: surface the underlying error and the path that failed.
9. If the validator reports `snapshot_stale: true`, advise the operator to refresh the spec via `firecrawl scrape https://agentskills.io/specification --only-main-content -o /tmp/agentskills-fetch/spec.md` and update `conductor-kernel/scripts/references/agentskills-spec-v1.json` accordingly.

**Exit**: 0 on PASS/WARN bundle, non-zero on FAIL or filesystem error (operator is informed and may inspect the script output).

**Hard limit**: writes ONLY to `~/.claude/skills/<slug>/.publish/`. Never to MEMORY.md, CLAUDE.md, or the source `SKILL.md`. Per CLAUDE.md §3.6.

### If `$ARGUMENTS` starts with "promote-skill-patch":

Review and apply a skill self-improvement patch from `~/.claude/skills/_patches/`.

**Invocation**: `/conduct promote-skill-patch <patch_path>`

**Background**: Hermes E1 — REQ-CDV-HERMES-011. The retrospective agent's Section 4 mining detects skills whose own SKILL.md exhibits ≥3 re-edit clusters in the 90-day change-log window (instructions repeatedly revised by agents → likely ambiguous). When detected, the agent drafts a unified diff to clarify the ambiguous section and writes it to `~/.claude/skills/_patches/<slug>-<ISO8601>.patch`. This subcommand reviews and applies that patch with operator approval.

**Behavior**:
1. Parse `<patch_path>` from `$ARGUMENTS` (after the literal `promote-skill-patch`). Expand `~` to `$HOME`.
2. Run `bash ${CLAUDE_PLUGIN_ROOT}/../conductor-kernel/scripts/skill-promote-patch.sh <patch_path>`.
3. The script:
   - Verifies the patch applies cleanly to a temp copy of the target skill.
   - Runs the writing-skills file-level shape check on the post-patch SKILL.md (frontmatter + seven-section).
   - Runs CISO-003 prompt-injection sanitization on the post-patch text.
   - Displays the original-vs-patched diff.
   - **Waits for operator decision on stdin**: `APPROVE` to apply, `REJECT` to archive (with reason), anything else to cancel.
4. On `APPROVE`: applies the patch in-place, moves the patch file to `~/.claude/skills/_patches/applied/`, emits `skill_patched` audit event, refreshes `~/.claude/skill-index.json`.
5. On `REJECT`: moves the patch to `~/.claude/skills/_patches/rejected/` with a `.REJECTION.txt` sidecar, emits `skill_patch_rejected` audit event.
6. On cancel: leaves the patch in `_patches/` untouched.

**Exit codes**: 0 success/reject/cancel, 1 missing patch / argument error, 2 validator or sanitization failure, 4 filesystem error, 5 patch did not apply cleanly.

**Hard limits (CLAUDE.md §3.6)**:
- NEVER auto-applies — operator must type literal `APPROVE` on stdin.
- NEVER deletes existing skills — patch is applied in place; the prior content is captured in the audit event's `before_sha256` if upstream change-log is active.
- Sanitization is fail-closed — any post-patch text matching prompt-injection regex blocks application.

### If `$ARGUMENTS` starts with "promote-skill":

Review and promote an agent-drafted skill from `~/.claude/skills/_proposed/<slug>/` to the active skill directory.

**Invocation**: `/conduct promote-skill <slug>`

**Background**: Hermes E1 — REQ-CDV-HERMES-009/010. The retrospective agent's Section 4 mining detects trajectory patterns that occur ≥3 times in the rolling 90-day Qdrant window with all-success outcome, that are novel against the existing skill catalog, and that span ≥5 tool calls. When detected, the agent drafts a SKILL.md (seven-section template) to `~/.claude/skills/_proposed/<slug>/SKILL.md`. This subcommand reviews and promotes that draft with operator approval.

**Behavior**:
1. Parse `<slug>` from `$ARGUMENTS` (after the literal `promote-skill`). If empty, ask the operator. The slug shape must be `^[a-z0-9]+(-[a-z0-9]+)*$`.
2. Run `bash ${CLAUDE_PLUGIN_ROOT}/../conductor-kernel/scripts/skill-promote.sh <slug>`.
3. The script:
   - Loads `~/.claude/skills/_proposed/<slug>/SKILL.md` (exit 1 if missing).
   - Runs the writing-skills file-level shape check (frontmatter + seven-section). FAIL = exit 2.
   - Runs `agentskills-validator.sh` (E5 validator). FAIL = exit 2; WARN = print and continue.
   - Generates the CISO-003 rendered preview ("When To Use" + "Process" sections with zero-width chars stripped and RTL/LTR overrides normalized).
   - Runs prompt-injection sanitization on the draft text. FAIL = exit 2.
   - Displays the diff against any pre-existing skill of the same slug, plus the full draft contents.
   - **Waits for operator decision on stdin**: `APPROVE` to promote, `REJECT` to archive (with reason), anything else to cancel.
4. On `APPROVE`: moves `_proposed/<slug>/` → `~/.claude/skills/<slug>/`, appends/updates the entry in `~/.claude/skill-registry.json` (atomic with rollback on registry-write failure), emits `skill_promoted` audit event with `trajectory_ids[]` and the new skill path, refreshes `~/.claude/skill-index.json`.
5. On `REJECT`: moves `_proposed/<slug>/` → `~/.claude/skills/_rejected/<slug>-<ISO8601>/` with a `REJECTION.txt` containing the operator's reason, emits `skill_promotion_rejected` audit event.
6. On cancel: leaves `_proposed/<slug>/` untouched.

**Exit codes**: 0 success/reject/cancel, 1 missing draft / argument error, 2 validator or sanitization failure, 3 reviewer blocking (reserved), 4 filesystem error.

**Hard limits (CLAUDE.md §3.6)**:
- NEVER auto-promotes — operator must type literal `APPROVE` on stdin. Closed stdin without `SKILL_PROMOTE_NONINTERACTIVE_DECISION` (test-only env var) errors out rather than auto-deciding.
- NEVER deletes existing skills — rejection archives to `_rejected/`; overwriting an existing skill at the target path first backs it up to `.backup-<slug>-<ts>/`.
- Auto-promotion of trajectory → skill without ≥3 successful invocations of the same pattern is PROHIBITED (enforced upstream in `sm_check_promotion_threshold`).
- Sanitization is fail-closed — any draft text matching prompt-injection regex blocks promotion.

### If `$ARGUMENTS` is anything else:
1. Check if `conductor-state.json` exists
2. **If exists**: Treat the arguments as a directive for the current workflow (e.g., "override tier to MAJOR", "skip to Phase 3", "add requirement REQ-050")
3. **If not exists**: Treat as a new project description and start a new workflow

---

<!--
  CANONICAL SOURCE: conductor-kernel/lib/dispatcher-core.md
  Duplicated here verbatim per API.md §9 design decision.
  DO NOT EDIT this block in isolation — edit the canonical source first,
  then run scripts/ci-dispatcher-diff.sh to regenerate.
  Last sync:     2026-05-12T00:00:00Z
  Kernel version: 0.1.0
  sync_hash:     230e675920520fcf98d5b0834814298983d4ed432f3314f2a96f83bfb14f7bdb
-->

<!-- BEGIN_CANONICAL source="conductor-kernel/lib/dispatcher-core.md" sync_hash="230e675920520fcf98d5b0834814298983d4ed432f3314f2a96f83bfb14f7bdb" -->

# Dispatcher Core — Canonical Orchestration Prose

**Canonical source for `conductor-kernel` orchestration semantics.**

This file is the canonical, domain-agnostic prose that domain command files (`conductor-dev/commands/conduct.md`, `clue-soc/commands/clue.md`, and any future 3rd-domain command) duplicate verbatim via the `<!-- BEGIN_CANONICAL ... -->` / `<!-- END_CANONICAL -->` marker pattern documented in `API.md §9`. Drift between this file and any duplicating domain file is caught by `scripts/ci-dispatcher-diff.sh` (RC-16 hash gate + content diff).

Per directive D3.2 in `directive-resolutions.md`, this file covers the **how** of orchestration: tier classification, agent dispatch, token-budget accounting, spec-alignment, builder readback, the Gemini-validation loop, gate enforcement, state persistence, context management, the workflow-template summaries, and the critical rules. Domain-specific **what** prose (BRD-tracker hooks, phase ladders, `/conduct` and `/clue` argument routing) belongs in the consuming command file, OUTSIDE the canonical block.

---

## 1. Tier Classification

Score the request using 5 signals. The signal vocabulary is domain-supplied via `domains/<domain>/tier-matrix.yaml`; the dev domain uses the matrix below.

| Signal | Weight | Scale |
|--------|--------|-------|
| Scope | 0.25 | 1 (single file) → 4 (new repo) |
| Type | 0.20 | 1 (bugfix) → 4 (greenfield) |
| Risk | 0.20 | 1 (reversible) → 4 (irreversible) |
| Ambiguity | 0.15 | 1 (crystal clear) → 4 (unknowns) |
| Intent Sensitivity | 0.20 | 1 (no hard limits touched) → 4 (intersects multiple hard limits) |

`weighted_score = (scope × 0.25) + (type × 0.20) + (risk × 0.20) + (ambiguity × 0.15) + (intent_sensitivity × 0.20)`

| Score | Tier |
|-------|------|
| 1.0–1.5 | TRIVIAL |
| 1.6–2.3 | MINOR |
| 2.4–3.2 | STANDARD |
| 3.3–4.0 | MAJOR |

SOC and other domains supply their own 5-signal vocabularies and weights via `tier-matrix.yaml`; both pass through `kernel.workflow.tier_classify` (API.md §4) with the same primitive contract.

The primitive emits a `workflow.tier_classified` audit event with the full result (`score`, `tier`, `rationale`, signals, weights). Tier classification weights MUST sum to 1.0 (±0.001 tolerance); violations produce `KER-TC-002`.

---

## 2. Agent Dispatch

All kernel agents are dispatched via qualified `<plugin>:<agent>` names through the Task tool:

```
Task(subagent_type="conductor-kernel:critic", prompt="...", description="Critic review")
```

Domain-plugin agents follow the same pattern (`conductor-dev:architect`, `clue-soc:root-cause-coder`, etc.). External agents not bundled in any plugin are dispatched without a prefix and degrade gracefully if unavailable.

Cross-plugin dispatch is mediated by `kernel.dispatch_agent(qualified_name, prompt, expectation, budget?)` and its envelope-form sibling `kernel.dispatch_agent_v2(qualified_name, prompt_envelope, expectation, budget?)`. The envelope form (API.md §6) is **mandatory** whenever any untrusted content (logs, user input, external alert content, file contents from disputed sources) is interpolated into the prompt; CLUE Phase 4 binds this requirement on its destructive-containment paths.

A runtime collision check enforces that the resolved agent's source plugin matches the prefix in `qualified_name`. Mismatch → `KER-DA-006 namespace_collision` (RC for F-01).

### 2.1 Token Budget Tracking (MANDATORY — Every Agent Dispatch)

After every agent dispatch returns, record token usage in the workflow-state file under `token_budget`:

```json
{
  "token_budget": {
    "total_input_tokens": 0,
    "total_output_tokens": 0,
    "total_cost_usd": 0.00,
    "dispatches": [
      {
        "agent": "<plugin>:<agent>",
        "model": "opus|sonnet|haiku",
        "phase": "Phase 1",
        "input_tokens": 12500,
        "output_tokens": 8200,
        "cost_usd": 0.80,
        "timestamp": "ISO-8601"
      }
    ],
    "by_phase": { "Phase 1": { "input": 0, "output": 0, "cost": 0.00, "dispatches": 0 } },
    "by_model": { "opus": { "input": 0, "output": 0, "cost": 0.00, "dispatches": 0 } }
  }
}
```

**Cost rates** (per 1M tokens) — operator-adjustable in deployment config:

| Model  | Input    | Output   |
|--------|----------|----------|
| opus   | $15.00   | $75.00   |
| sonnet | $3.00    | $15.00   |
| haiku  | $0.80    | $4.00    |

**Recording flow:**
1. Before dispatch, note the agent name and its model tier (from agent frontmatter).
2. After agent returns, estimate tokens from output length (chars / 4 ≈ tokens) or use actual counts if available.
3. Compute cost: `(input_tokens / 1M × input_rate) + (output_tokens / 1M × output_rate)`.
4. Append to `dispatches[]`, increment `by_phase` and `by_model` accumulators.
5. Update `total_*` fields.

**Denial-of-wallet protection (RC-7 / F-09).** Per `lib/budget-defaults.yaml`, every dispatch is bounded by a per-trace budget (`max_input_tokens`, `max_output_tokens`, `max_cost_usd`, `max_dispatches_per_minute_per_trace`). Budget exceeded → audit event `dispatch.budget_exceeded` + return code `KER-DA-005`. Stream-mode amplifies this risk and MUST supply a stream-level budget at `kernel.stream.init` time (`KER-SI-006` if absent).

### 2.2 Spec Alignment Check (MANDATORY — After Architect, Before Builder)

After an architecture/plan agent produces output, validate it against the original user description BEFORE any implementation begins. This catches comprehension errors early.

**Dispatch flow:**
1. The architecture/plan agent returns its document.
2. Before dispatching the implementer, dispatch `conductor-kernel:critic` in spec-alignment mode with the prompt:

   > **SPEC ALIGNMENT CHECK** — Compare architect output against original request.
   >
   > ORIGINAL USER REQUEST: `{original project description}`
   > ARCHITECT OUTPUT: `{first ~3000 chars of architecture document}`
   >
   > Check for:
   > a) Does the architecture address ALL stated requirements?
   > b) Does it introduce scope not requested?
   > c) Are there ambiguities that could cause the builder to make wrong assumptions?
   > d) Are there requirements the architect appears to have misunderstood?
   >
   > Respond with one of:
   > - **ALIGNED** — Architecture matches intent. Proceed.
   > - **DRIFT** — `[list specific mismatches]`. Recommend re-dispatch architect with corrections.
   > - **AMBIGUOUS** — `[list items needing clarification]`. Recommend asking the user before proceeding.

3. If `DRIFT` → re-dispatch architect with specific corrections.
4. If `AMBIGUOUS` → escalate to the operator with the specific questions.
5. If `ALIGNED` → proceed to the implementer.

Record the result in `state.spec_alignment`:

```json
{
  "spec_alignment": {
    "verdict": "ALIGNED|DRIFT|AMBIGUOUS",
    "issues": [],
    "checked_at": "ISO-8601",
    "re_dispatches": 0
  }
}
```

### 2.3 Builder Readback (MANDATORY — Before Implementation Starts)

Before any implementer agent begins writing code, require it to echo back its understanding. Aviation-style readback catches handoff ambiguity before code is written.

**Inject into implementer dispatch prompt:**

> **READBACK REQUIRED** — Before writing any code, respond with a Readback section:
>
> ## Readback
> 1. **My understanding of the task** (1-3 sentences)
> 2. **Key files I will create/modify** (list)
> 3. **Approach** (1-2 sentences on implementation strategy)
> 4. **Assumptions I'm making** (list any gaps you're filling with assumptions)
> 5. **Questions (if any)** (anything unclear)
>
> Then proceed with implementation.

**Orchestrator checks the readback:**
1. If the implementer lists assumptions → flag for operator review before continuing.
2. If the implementer lists questions → escalate to operator.
3. If the readback contradicts the architecture → halt and re-dispatch with corrections.
4. If the readback aligns → implementation proceeds.

Record in `state.builder_readback`:

```json
{
  "builder_readback": {
    "understanding_summary": "...",
    "files_planned": [],
    "assumptions": [],
    "questions": [],
    "verdict": "PROCEED|ESCALATE|CORRECT",
    "checked_at": "ISO-8601"
  }
}
```

### 2.4 Gemini Validation Protocol (MANDATORY — Every Agent Run)

After EVERY agent dispatch returns, run independent Gemini validation before proceeding. Agents do not grade their own homework. This protocol is the contract documented at `kernel.gemini_validate` (API.md §6).

**Per RC-10 / F-17**, every invocation MUST declare a `data_classification` argument (`public` | `internal` | `confidential` | `regulated`). Default operator policy refuses `regulated` without an explicit `operator_override`. The primitive emits `validation.gemini` audit events with the classification recorded.

#### Dispatch flow (for every agent):

1. Record pre-dispatch state (expected deliverables, files snapshot).
2. Dispatch the agent via Task tool.
3. Agent returns output.
4. Collect evidence: `files_changed` (git diff --name-only), agent-output summary.
5. Dispatch `conductor-kernel:gemini-validator` with the evidence package.
6. Record validation result in `state.gemini_validations[]`.
7. Apply verdict (proceed / re-dispatch / escalate).

#### Validation dispatch template:

```
Task(subagent_type="conductor-kernel:gemini-validator", prompt="
  agent_name:            {agent that just ran (qualified name)}
  task_description:      {what it was asked to do}
  expected_deliverables: {from handoff.expectations[]}
  actual_output_summary: {first ~2000 chars of agent output}
  project_root:          {cwd}
  files_changed:         {git diff --name-only output}
  data_classification:   {public|internal|confidential|regulated}
", description="Gemini validation: {agent_name}")
```

#### Verdict actions:

| Verdict | Completion | Action |
|---------|-----------|--------|
| PASS    | 100%      | Proceed to next step |
| PARTIAL | ≥70%      | Log advisory, proceed with warning |
| PARTIAL | <70%      | BLOCK — re-dispatch agent with gaps from Gemini's evidence |
| FAIL    | any       | BLOCK — re-dispatch (attempt 1) or escalate to operator (attempt 2+) |
| ERROR   | n/a       | Log Gemini unavailability, proceed (non-blocking degradation) |

#### Remediation loop (finding-level resolution):

When Gemini returns FAIL or PARTIAL(<70%), run the **finding resolution loop**:

```
FOR each issue in gemini_validation.issues[]:
  1. DISPATCH remediation agent (same agent type that originally ran) with prompt:

     "REMEDIATION TASK — Gemini validation found this specific issue:

      FINDING:       {issue text}
      FILE(S):       {relevant files from Gemini's evidence}
      ORIGINAL TASK: {original task_description}

      You MUST:
      a) Read the file(s) cited
      b) Fix the specific issue described
      c) Respond with EVIDENCE of resolution:
         - What you changed (file:line)
         - Why it resolves the finding
         - Any side effects

      Do NOT re-implement the entire task. Fix ONLY this finding."

  2. RECORD the agent's resolution evidence.

  3. After ALL findings are addressed, run TARGETED re-validation:
     DISPATCH conductor-kernel:gemini-validator with:
       mode:                "targeted"
       original_issues:     {the specific issues from the first validation}
       resolution_evidence: {what the remediation agent reported for each}
       files_changed:       {git diff --name-only since remediation started}

  4. IF targeted re-validation returns PASS → proceed
     IF targeted re-validation returns FAIL → increment attempt counter
       - Attempt 2: re-run remediation loop for remaining failures
       - Attempt 3+: ESCALATE to operator with full finding history
```

**Key principle**: the remediation agent addresses each finding individually with cited evidence; Gemini re-validates only the specific findings, not a full re-review. Tight, focused loop.

#### Attempt limits:

- Max 2 full remediation loops per agent per step.
- After 2 loops with unresolved findings, escalate to operator with:
  - Original task description.
  - All Gemini findings (with PASS/FAIL per finding across attempts).
  - The remediation agent's resolution evidence for each attempt.
  - Gemini's re-validation responses.
- Track attempt counts in `state.gemini_validations[]` entries.

#### Exceptions (validation skipped):

- `conductor-kernel:gemini-validator` itself (no recursive validation).
- Agents that produce no file artifacts (pure advisory/status agents).
- When Gemini CLI is unavailable (degrade gracefully, log warning).

---

## 3. Gate Enforcement

At every phase transition:
1. Run inline discipline checks (SEQUENCE, DRIFT, SCOPE, LOOP, SCHEDULE).
2. Invoke `conductor-kernel:critic` at defined verification checkpoints.
3. Gate mode (advisory / blocking / skip) is determined by tier.

Verification gates the kernel recognizes (the canonical list maps to `state.verification_status[*]`):

```
post_architect, post_ciso, post_qa, post_implementation,
post_pentest, post_supply_chain, pre_release, completeness_validation
```

Domain plugins may add additional gate ids under `state.verification_status` freely.

**PostToolUse hook enforcement**. Phase transitions are programmatically enforced by `hooks/scripts/post-state-write.sh`. When the state file is written with a new `current_phase.number`, the hook checks all required verification gates for the previous phase. For STANDARD and MAJOR tiers, missing or non-`pass` gates cause the write to be **blocked** (exit 1). MINOR and TRIVIAL tiers receive advisory warnings only. The hook also blocks phase transitions when uncommitted git changes are detected (git ratcheting). This ensures mandatory gates cannot be bypassed by the orchestrating LLM.

**HUMAN_GATE invariant (RC-3 / F-07)**. Destructive-containment gates use `kernel.workflow.gates_evaluate_and_enforce` (API.md §4). The enforce form BLOCKS on `human_gate`, dispatches governance, waits for resolution, and writes the resulting state itself. A caller-written `state_advance({kind: "gate_pass"})` lacking a prior gate-resolution audit row fails with `KER-GE-002 unresolved_gate_pass`. The advisory `kernel.workflow.gates_evaluate` form is deprecated at v0.1.0 and removed at v1.0.0.

---

## 4. State Persistence

After every significant action:
- Update the workflow-state file with the current position via `kernel.workflow.state_advance` (API.md §4).
- Record completed tasks, handoffs, and gate results.
- Commit state files to git (atomic checkpoint pattern).

Direct file edits to the state file are non-conforming and will cause `post-state-write.sh` to fail (RC-13 / F-18 + state-machine invariant). All mutations go through `state_advance`.

The base state schema is `schemas/workflow-state.schema.json` (kernel v3.0). Domain plugins extend via `domain_extensions` per REQ-KER-003; the kernel never reads or writes inside `domain_extensions`. Top-level `additionalProperties: false` enforces that all forward-compatible extensions land in `domain_extensions`.

---

## 5. Context Management

The `conductor-kernel:context-management` skill is the canonical reference for context-budget rules. Key invariants:

- Maximum 3 specs per planning session.
- Monitor context budget (60% rule — the orchestrator stops absorbing new context at 60% of the model's window and starts shedding via handoff documents).
- Generate handoff documents at phase boundaries.
- Spawn subagents with fresh context for each TODO spec.

The skill's SKILL.md prescribes the handoff template; the orchestrator's responsibility is to invoke it at the right moments.

---

## 6. Outcome Emission

On workflow completion (terminal phase reached), `kernel.workflow.complete(state)` (API.md §4 REQ-KER-009) dispatches:

1. `conductor-kernel:outcome-collector` — computes the 10 outcome metrics (completion rate, TTR, first-pass rate, rework frequency, quality trend, recovery rate, context efficiency, cost per successful outcome, capacity hours released, escalation rate).
2. `conductor-kernel:retrospective` — captures KU/KI lessons learned, mines the trajectory for reusable patterns, writes `docs/ku-ki-<project>.yaml`.

Both dispatches are synchronous and emit `agent.dispatch` audit events. The aggregate output is the `outcome_report` returned from `kernel.workflow.complete`.

---

## 7. Workflow Template Summaries

The tier-appropriate workflow shapes summarized below are domain-agnostic; concrete agent choice depends on the domain.

```
TRIVIAL:  analyze-codebase
          → implementer (plan-and-implement)
          → verify

MINOR:    analyze-codebase
          → implementer (plan)
          → SPEC-ALIGNMENT-CHECK
          → implementer (READBACK + implement)
          → conductor-kernel:ciso (advisory)
          → conductor-kernel:critic (advisory)
          → verify
          → COMPLETENESS-VALIDATION (advisory)

STANDARD: Full multi-phase ladder.
          SPEC-ALIGNMENT-CHECK after architect.
          BUILDER-READBACK before implementer.
          critic advisory except PRE-RELEASE + POST-PENTEST blocking.
          → DOMAIN-HARDENING (domain-specific quality loop)
          → DOMAIN-ADVERSARIAL-REVIEW (dual-model review)
          → DOCUMENTATION
          → COMPLETENESS-VALIDATION (blocking)

MAJOR:    Same as STANDARD but ALL critic gates blocking.
```

`conductor-kernel:analyze-codebase`, `:critic`, `:ciso`, `:completeness-validator`, `:gemini-validator`, `:bug-find`, and the security/compliance/retrospective agents are the kernel-side participants. Domain plugins supply the architect, implementer, QA, and domain-specific hardening / adversarial-review phases.

---

## 8. Critical Rules

1. **NO PLACEHOLDERS** — Every function fully implemented, every integration actually connects.
2. **REQUIREMENT TRACEABILITY** — Every domain-specific requirement (BRD entry for dev, alert entry for SOC, etc.) tracked from extraction to completion. The kernel-side `conductor-kernel:brd-tracking` skill provides the lifecycle; the tracker location is per-domain.
3. **INDEPENDENT VERIFICATION** — Agent self-reporting is not trusted; the orchestrator verifies via `conductor-kernel:critic` and `:gemini-validator`.
4. **STRICT SEQUENCING** — No step skipped or reordered.
5. **MAX 2 RETRIES** — Then escalate to operator.
6. **GIT RATCHETING** — Commit after every logical change for recovery. The `post-state-write.sh` hook blocks phase transitions when uncommitted changes are detected.

---

*End of dispatcher-core.md v0.1.0. CI hash gate enforces this file's sha256 against the `sync_hash:` field in every duplicating domain file (`scripts/ci-dispatcher-diff.sh`).*

<!-- END_CANONICAL -->

---

## Dev-Domain Specifics

The dev domain binds the canonical kernel agents above to concrete `conductor-dev:` agents at dispatch time:

| Kernel role        | Dev-domain agent                  |
|--------------------|-----------------------------------|
| architect          | `conductor-dev:architect`         |
| implementer        | `conductor-dev:builder`           |
| QA                 | `conductor-dev:qa`, `conductor-dev:qa-review` |
| reviewer           | `conductor-dev:code-reviewer`     |
| devops             | `conductor-dev:devops`            |
| performance        | `conductor-dev:performance`       |
| observability      | `conductor-dev:observability`     |
| api-design         | `conductor-dev:api-design`        |
| api-docs           | `conductor-dev:api-docs`          |
| doc-gen            | `conductor-dev:doc-gen`           |
| database           | `conductor-dev:database`          |
| refactor           | `conductor-dev:refactor`          |
| frontend-designer  | `conductor-dev:frontend-designer` |
| n8n                | `conductor-dev:n8n`               |
| project-setup      | `conductor-dev:project-setup`     |
| agent-gateway      | `conductor-dev:agent-gateway`     |
| advisor            | `conductor-dev:advisor`           |

Kernel-side roles (critic, ciso, completeness-validator, gemini-validator, analyze-codebase, bug-find, compliance, compliance-overview, llm-security, supply-chain-security, pentest-coordinator, secrets-lifecycle, research, retrospective, outcome-collector, checkpoint, event-router, prediction-engine, recovery-engine) are always dispatched as `conductor-kernel:<name>`.

BRD-tracker location for dev is governed by `domains/dev/tracker.yaml` (default: `BRD-tracker.json` at project root).

---

## Code Hardener QA Phase (STANDARD + MAJOR tiers)

This is dev-domain hardening, bound to the local Code Hardener service. SOC and other domains supply their own hardening loop.

After all implementation and verification phases complete, run the Code Hardener hardening loop.

**Deterministic execution (opt-in).** This loop is also available as a deterministic Workflow script at `workflows/hardening-loop.js`, invoked via `/conduct workflow hardening`. The script encodes the scan-fix-rescan loop, the 5-iteration cap, the per-file fan-out, and the per-iteration git ratchet as code so no step can be skipped. The prose algorithm below remains the canonical spec the script implements; when the operator opts into workflow execution, prefer the script and consume its returned `{ history, finalScore, converged }`.

### Prerequisites

- **Code Hardener backend.** Resolve the base URL from `$CODEHARDENER_URL`,
  defaulting to `http://localhost:7002`. The API base path is `/api/v1`, so
  requests go to `${CODEHARDENER_URL:-http://localhost:7002}/api/v1/...`.
  Code Hardener is a separate, optional service:
  [bulletproof-codehardener](https://github.com/bulletproofsoftware-ai/bulletproof-codehardener).
  Start it per its own README (it ships a Docker stack) and export
  `CODEHARDENER_URL` if you publish it on a different host or port.
- The `X-User-Id` identity (from `$CODEHARDENER_USER`, default
  `dev@codehardener.local`) must have an active plan with available **scan
  quota** — `POST /api/v1/scans` is gated by `enforceScanLimit`; an exhausted
  or zero quota rejects scans before they start.

#### When Code Hardener is unreachable

Probe once with a short timeout
(`curl -sf --max-time 5 "${CODEHARDENER_URL:-http://localhost:7002}/api/v1/health"`).
The gate is **mandatory by default** — it degrades, it is never silently
skipped, and the outcome is always recorded in `conductor-state.json`:

| Tier | Behaviour when unreachable |
|------|----------------------------|
| **MAJOR** | **BLOCK.** Report the resolved URL and stop. Hardening evidence is required at this tier. The operator either starts the service, sets `CODEHARDENER_URL`, or explicitly overrides (below). |
| **STANDARD** | **BLOCK by default**, with an explicit operator override available. |
| **MINOR** | **DEGRADE.** Record `hardening.status = "skipped_unavailable"` with the resolved URL and a timestamp, warn plainly, and continue. |
| **TRIVIAL** | Gate does not run. |

Record the outcome in `conductor-state.json.hardening`:

```json
{
  "status": "skipped_unavailable",
  "reason": "codehardener_unreachable",
  "resolved_url": "http://localhost:7002",
  "tier": "MINOR",
  "observed_at": "<ISO-8601>"
}
```

An operator may override a blocking tier for a single run with
`/conduct workflow hardening --allow-unavailable`. Doing so records
`status: "skipped_operator_override"` alongside the same fields, so the
release evidence shows the gate did not run and who chose that. Never record
a skipped gate as a pass.

### Hardening Loop Algorithm

Execute scan-fix-rescan cycles until quality score = 1000 and zero open findings, max 5 iterations.

**For each iteration:**

1. **Trigger scan** via curl:
```bash
# Get or create project
PROJECT_ID=$(curl -s -X POST "${CODEHARDENER_URL:-http://localhost:7002}"/api/v1/projects \
  -H "Content-Type: application/json" \
  -H "X-User-Id: ${CODEHARDENER_USER:-dev@codehardener.local}" \
  -d '{"name": "PROJECT_NAME", "repoPath": "PROJECT_PATH"}' | jq -r '.data.id // empty')

# Start comprehensive scan
SCAN_ID=$(curl -s -X POST "${CODEHARDENER_URL:-http://localhost:7002}"/api/v1/scans \
  -H "Content-Type: application/json" \
  -H "X-User-Id: ${CODEHARDENER_USER:-dev@codehardener.local}" \
  -d "{\"projectId\": \"$PROJECT_ID\", \"profile\": \"comprehensive\"}" | jq -r '.data.id')
```

2. **Poll until complete** (max 600s):
```bash
curl -s "${CODEHARDENER_URL:-http://localhost:7002}"/api/v1/scans/$SCAN_ID \
  -H "X-User-Id: ${CODEHARDENER_USER:-dev@codehardener.local}" | jq '.data.status, .data.score, .data.findingsCount'
```

3. **Check score**: If score = 1000 and total open findings = 0 → exit loop, proceed to adversarial review.

4. **Fetch open findings**:
```bash
curl -s "${CODEHARDENER_URL:-http://localhost:7002}/api/v1/scans/$SCAN_ID/findings?status=open" \
  -H "X-User-Id: ${CODEHARDENER_USER:-dev@codehardener.local}" | jq '.data'
```

5. **Group findings by file** and dispatch fix agents via Task tool:
   - Each agent receives: file path, array of findings (title, description, line, fix description)
   - Prompt: "Read the file, understand each finding, apply the fix. Do not introduce new issues."

6. **Git checkpoint** before each iteration:
```bash
git add -A && git commit -m "chore: hardening iteration N — fix K findings"
```

7. **Safety rails**:
   - Max 5 iterations total
   - Max 2 fix attempts per finding — after 2 failures, flag for human review
   - Track attempt counts in conductor-state.json

### State Tracking

Update conductor-state.json with:
```json
{
  "hardening": {
    "status": "in_progress|completed|failed",
    "iteration": 2,
    "maxIterations": 5,
    "scanHistory": [
      { "scanId": "...", "score": 780, "openFindings": 12, "timestamp": "..." }
    ],
    "unfixableFindings": [],
    "lastScanId": "..."
  },
  "adversarialReview": {
    "status": "pending|in_progress|completed|failed",
    "claudeReviewComplete": false,
    "geminiReviewComplete": false,
    "agreedFindings": 0,
    "disputedFindings": 0,
    "resolvedViaDebate": 0,
    "debateRoundsUsed": 0,
    "remediationComplete": false,
    "finalScore": null,
    "reportPath": null
  }
}
```

---

## Adversarial Code Review Phase (STANDARD + MAJOR tiers)

This is dev-domain adversarial review (dual-AI on git diff). After hardening loop achieves score 1000, run adversarial dual-AI review.

**Deterministic execution (opt-in).** Also available as `workflows/adversarial-review.js` via `/conduct workflow adversarial`. The conductor builds the diff payload (Step 1) and passes it as `args.diff`; the script runs the two independent reviews in parallel, classifies AGREED vs disputed in code, runs the ≤5-round debate per dispute, and returns `{ mustFix, disputed, debateRoundsUsed }`. The conductor remediates `mustFix`, documents `disputed`, and re-runs the hardening workflow to verify the score holds.

### Step 1: Build Diff Payload

```bash
DIFF_PAYLOAD=$(git diff main...HEAD --no-color 2>/dev/null)
if [ -z "$DIFF_PAYLOAD" ]; then
  DIFF_PAYLOAD=$(git diff HEAD~10..HEAD --no-color 2>/dev/null)
fi
```

If diff exceeds 30KB, split by directory and review in batches.

### Step 2: Independent Reviews (Parallel)

**Claude review** — dispatch via Task tool (subagent_type: "general-purpose"):

Prompt: "You are a senior staff engineer performing an independent code review. Examine every changed file. For each issue cite exact file and line.

REVIEW DOMAINS: 1. SECURITY 2. CODE QUALITY 3. PERFORMANCE 4. ARCHITECTURE 5. MAINTAINABILITY 6. EDGE CASES

FORMAT each finding as: [SEVERITY: CRITICAL/HIGH/MEDIUM/LOW/INFO] [DOMAIN] [FILE:LINE] Issue description. Fix: recommendation.

End with: total findings by severity, risk assessment (PASS / PASS WITH NOTES / NEEDS CHANGES / BLOCK), top 3 items.

HERE ARE THE CHANGES: {DIFF_PAYLOAD}"

**Gemini review** — via Bash (use stdin to avoid shell injection from diff content):

```bash
TMPFILE=$(mktemp)
trap 'rm -f "$TMPFILE"' EXIT
cat <<REVIEW_EOF > "$TMPFILE"
You are a senior staff engineer performing an independent third-party code review.
[same prompt as Claude]

HERE ARE THE CHANGES:
$(cat <<'DIFF_EOF'
${DIFF_PAYLOAD}
DIFF_EOF
)
REVIEW_EOF
gemini -p "$(cat "$TMPFILE")" -o text 2>&1 | grep -v '^Loading\|^Server\|^🔔\|^Resources\|^Prompts\|^Tools\|^Hook\|^\[INFO\]'
rm -f "$TMPFILE"
```

**IMPORTANT**: Never interpolate `$DIFF_PAYLOAD` directly into a gemini -p argument string.
Write the full prompt (including the diff) to a temp file first, then pass via `$(cat "$TMPFILE")`.
This prevents shell metacharacters in the diff from being interpreted.

Timeout: 300s for each.

### Step 3: Merge & Classify

Parse both outputs. Classify findings:
- **AGREED**: Both flagged same file/line/domain — high confidence, must fix
- **CLAUDE-ONLY**: Needs debate
- **GEMINI-ONLY**: Needs debate

### Step 4: Debate Rounds (Max 5 per finding)

For each disputed finding, run up to 5 rounds:

1. **Presenter** (whichever AI found it) states the case with evidence
2. **Challenger** responds: AGREE or DISAGREE with counter-evidence

Claude's turn: Task subagent with the finding + Gemini's position.
Gemini's turn (use temp file to avoid shell injection):
```bash
DEBATE_TMP=$(mktemp)
cat > "$DEBATE_TMP" <<DEBATE_EOF
A code review found this issue:
${FINDING}

The other reviewer responded:
${CLAUDE_RESPONSE}

Do you AGREE or DISAGREE? Provide evidence.
DEBATE_EOF
gemini -p "$(cat "$DEBATE_TMP")" -o text
rm -f "$DEBATE_TMP"
```

After 5 rounds with no consensus: mark as DISPUTED, flag for human review.

### Step 5: Remediate

- All AGREED + consensus findings → dispatch fix agents (same pattern as hardening loop)
- DISPUTED findings → document only, do not auto-fix
- After fixes → re-run Code Hardener scan to verify score remains 1000

### Step 6: Save Adversarial Review Document

Write verbose dialog to `docs/adversarial-review-YYYY-MM-DD.md` with format:

```markdown
# Adversarial Code Review: [Project Name]

**Date:** YYYY-MM-DD
**Reviewers:** Claude (Opus 4.6), Gemini CLI (0.30.0)

## Summary
| Metric | Value |
|--------|-------|
| Agreement Rate | X% |
| Findings (Agreed) | N |
| Findings (Resolved via Debate) | M |
| Findings (Disputed) | K |
| Debate Rounds Used | R |
| All Findings Remediated | Yes/No |
| Final Quality Score | 1000 |

## Independent Reviews
### Claude's Review
[Full verbatim output]

### Gemini's Review
[Full verbatim output]

## Agreed Findings
| # | Severity | Domain | File:Line | Description | Fix Applied |

## Disagreements & Debate
### Finding: [title] (Source: [claude/gemini])
**Round 1:**
> **Claude:** [position + evidence]
> **Gemini:** [position + evidence]

**Resolution:** AGREED / DISPUTED
**Action:** [fixed / human review]

## Final Disposition
| # | Finding | Claude | Gemini | Resolution | Action Taken |

## Integrity Check
- [ ] All agreed findings remediated
- [ ] Disputed findings documented
- [ ] Score verified at 1000
```

### Step 7: Generate Final PDF Report

```bash
# Generate report via API
REPORT_ID=$(curl -s -X POST "${CODEHARDENER_URL:-http://localhost:7002}"/api/v1/reports \
  -H "Content-Type: application/json" \
  -H "X-User-Id: ${CODEHARDENER_USER:-dev@codehardener.local}" \
  -d "{\"title\": \"Final Hardening Report\", \"reportType\": \"scan_detail\", \"format\": \"markdown\", \"scanId\": \"$LAST_SCAN_ID\"}" | jq -r '.data.id')

# Download report
curl -s "${CODEHARDENER_URL:-http://localhost:7002}"/api/v1/reports/$REPORT_ID/download \
  -H "X-User-Id: ${CODEHARDENER_USER:-dev@codehardener.local}" > docs/hardening-report-$(date +%Y-%m-%d).md
```

---

Now parse `$ARGUMENTS` and execute the appropriate action.
