# bulletproof-conductor-dev Technical Briefing

## 1. Product Overview and Core Purpose

### 1.1 System Definition
`bulletproof-conductor-dev` is a specialized dev-domain orchestrator plugin architected for Claude Code. It functions as the primary interface for software development workflows, operating as a mandatory extension of the `conductor-kernel` (version 0.1.0 or higher). While the kernel provides the underlying orchestration primitives and state persistence, `conductor-dev` supplies the domain-specific agent roster, commands, and programmatic enforcement hooks required for high-integrity engineering.

### 1.2 Problem Alignment: The Architecture of Failure Prevention
Autonomous development agents frequently suffer from predictable failure modes that compromise enterprise-grade repositories. This system is engineered to solve:
*   **Self-Reporting Errors:** Preventing agents from falsely claiming task completion.
*   **Phase Skipping:** Blocking the bypass of critical validation steps to ensure quality is never traded for speed.
*   **Requirement Loss:** Ensuring the initial request's intent is preserved throughout the lifecycle via the **BRD Tracker**, which maintains a strict link between requirements and implementation.
*   **Unbounded Cost:** Mitigating "denial-of-wallet" scenarios through integrated budget caps and token monitoring.

### 1.3 Core Design Philosophy
The system adheres to five architectural invariants:
*   **Strict Sequencing:** Phase transitions are programmatically gated; no step is advisory.
*   **Independent Verification:** Dispatches are validated by independent kernel agents (e.g., `gemini-validator`) rather than trusting the primary agent's self-assessment.
*   **No Placeholders:** Stubs, "TODOs," and incomplete implementations are rejected at the structural level.
*   **Audit Trail by Construction:** Every state change and gate decision is captured in a verifiable, append-only log.
*   **Cost Ceilings:** Hard limits on expenditure trigger immediate workflow halts.

## 2. System Architecture: The Two-Plugin Split

### 2.1 Component Distribution
The orchestration logic is decoupled between the domain-specific `conductor-dev` and the domain-agnostic `conductor-kernel`.

**Orchestration Responsibilities**

| `conductor-dev` (Dev Domain) | `conductor-kernel` (Kernel Engine) |
| :--- | :--- |
| 17 Specialized Dev Agents + Dispatcher | 19 Kernel Agents (Critic, CISO, etc.) |
| `/conduct` Command Surface | Orchestration Primitives & State Persistence |
| Dev-specific Enforcement Hooks | 14 Core Skills (Context, Retry, State mgmt) |
| `domains/dev/tracker.yaml` Pointer | Tier Classification & Validation Semantics |
| 2,415-line Product Schema | Dispatch and Gate Enforcement Logic |

### 2.2 Agent & Skill Referencing
Inter-plugin communication utilizes a specific nomenclature. Dev agents invoke kernel-level resources using the `conductor-kernel:<name>` syntax. For example, a dev agent requiring security oversight invokes `conductor-kernel:ciso`.

### 2.3 The BRD Tracker
The `domains/dev/tracker.yaml` file identifies the location of the requirement tracker for dev-domain workflows. This allows the kernel's `brd-tracking` skill to synchronize requirements from extraction through to final verification, ensuring no requirement is dropped during agent handoffs.

## 3. Tier Classification & Workflow Profiles

### 3.1 The Weighted Matrix
The system calculates a complexity score for every request using a five-signal weighted matrix:
*   **Scope (0.25):** Breadth of changes.
*   **Type (0.20):** Nature of the task (e.g., refactor vs. new feature).
*   **Risk (0.20):** Potential impact on stability/security.
*   **Ambiguity (0.15):** Clarity of instructions.
*   **Intent Sensitivity (0.20):** Alignment with core objectives and constraints.

### 3.2 Tier Definitions
The score maps to one of four tiers, defining the rigor of the enforcement pipeline.

| Tier | Score Range | Workflow Profile |
| :--- | :--- | :--- |
| **TRIVIAL** | 1.0–1.5 | `analyze` → `builder(plan-and-implement)` → `verify`. |
| **MINOR** | 1.6–2.3 | `analyze` → `builder(plan)` → `spec-alignment` → `builder(readback + implement)` → `ciso(advisory)` → `critic(advisory)` → `verify`. |
| **STANDARD** | 2.4–3.2 | Full Phases 0–7. **Blocking Gates:** PRE-RELEASE, POST-PENTEST, COMPLETENESS, supply-chain, and adversarial review. |
| **MAJOR** | 3.3–4.0 | Full Phases 0–7. **All** critic gates are blocking. Includes hardening loop and dual-AI adversarial review. |

### 3.3 Escalation Logic
Any request touching parameters defined in `intent.hard_limits[]` triggers an "auto-escalation" to a minimum of **STANDARD** tier, regardless of the matrix score, ensuring maximum oversight for sensitive operations.

## 4. The Dev-Domain Agent Roster

### 4.1 Software Development Specialists (9)
*   **conductor-architect:** Generates exhaustive, implementation-ready specifications integrated with the BRD.
*   **conductor-builder:** Highly versatile agent operating in three distinct modes: `plan-only`, `implement-only`, or `combined`.
*   **conductor-code-reviewer:** Analyzes changes against quality standards.
*   **conductor-refactor:** restructuring specialist focusing on non-breaking code improvements.
*   **conductor-database:** Manages schema migrations and ORM integrations (Postgres/MySQL/MongoDB/Redis).
*   **conductor-api-design:** Architect for OpenAPI/GraphQL contracts and testing.
*   **conductor-api-docs:** Generates endpoint documentation.
*   **conductor-doc-gen:** Manages general project and system documentation.
*   **conductor-frontend-designer:** UI/UX implementation and frontend architectural logic.

### 4.2 Quality and Operations Specialists (5)
*   **conductor-qa:** Final gatekeeper performing BRD gap analysis with 25+ testing tools.
*   **conductor-qa-review:** Multi-model consensus engine (Claude + Gemini + Codex) for adversarial review.
*   **conductor-performance:** Load/perf testing using K6, Locust, and Lighthouse.
*   **conductor-observability:** Configures Prometheus, Grafana, and OpenTelemetry.
*   **conductor-devops:** Manages CI/CD, Docker, and Kubernetes orchestration.

### 4.3 Workflow and Interoperability (3)
*   **conductor-project-setup:** Repository bootstrapping and environment config.
*   **conductor-n8n:** Converts ideas into importable n8n workflow JSON.
*   **conductor-agent-gateway:** Facilitates Agent-to-Agent (A2A) capabilities via REST, MCP, or adapters.

### 4.4 The Dispatcher
The **conductor** agent (`agents/conductor.md`) serves as the primary orchestrator entry point, managing initial request handling and overall pipeline coordination.

## 5. Programmatic Enforcement: Hooks and Gates

### 5.1 SessionStart Hook
`session-start.sh` executes at the start of a session, detecting active `conductor-state.json` files and generating a status summary in `conductor-last-status.txt` for the `/conduct status` display.

### 5.2 PostToolUse Hook Logic
The `post-state-write.sh` script is the primary enforcement mechanism. Crucially, it blocks the write with an **exit 1** status if any gate is violated, physically stopping the LLM from proceeding with invalid state transitions.
1.  **Validation:** Checks state against the JSON schema.
2.  **Phase Gate Enforcement:** In STANDARD/MAJOR tiers, blocks phase transitions if verification gates are not "pass."
3.  **Git Ratcheting:** Blocks phase advancement if uncommitted changes exist in the repository.
4.  **Fail-Open Behavior:** Architecturally, the hook is designed to "fail-open" on internal errors. This ensures the security/orchestration layer does not become a single point of failure for the developer's IDE in the event of a hook bug.

### 5.3 The Change Tracker
`change-tracker.sh` maintains an audit trail in `.conductor/change-log.jsonl`. It includes file paths, SHA256 hashes, and BRD-ref attribution. A strict redaction policy automatically strips secrets (e.g., `.env` files) matching CISO-001 patterns.

## 6. State Schema and Audit Infrastructure

### 6.1 The Product Schema
The `schemas/conductor-state.schema.json` is a 2,415-line Draft 2020-12 validator. It serves as the single source of truth for the system's operational state.

### 6.2 Core Schema Blocks
Key operational data blocks include:
*   **NHI Registry:** Non-Human Identity dispatch tracking and token consumption.
*   **Handoff History:** Deliverable verification and checkpoint IDs.
*   **Gemini Validations:** Verdicts and resolution status from independent AI verification.
*   **Verification Gates:** Status of 10 specific safety and quality gates.
*   **Cost Tracking:** Budget caps and cost forecasting with "exceeded" flags.
*   **Recovery State:** MTTR tracking, health snapshots, and recovery history.
*   **Outcome Metrics:** TTR (Time to Resolution), rework rates, and quality trends.
*   **Predictive Scaling:** Session cost forecasting and model-routing overrides.
*   **Circuit Breaker:** State and failure count thresholds to halt failing workflows.

### 6.3 Audit Sink (SIEM) Integration
The system emits events to external SIEM destinations (syslog, HTTP, etc.) using `audit_emitter.py`. All transmissions utilize HMAC integrity to prevent audit log tampering.

## 7. Command Interface and Operational Usage

### 7.1 The /conduct Command Surface
The `/conduct` command is the primary entry point for status checks and project initialization. Without arguments, it performs workflow detection and steering.

### 7.2 Hermes-Inspired Enhancements (E1–E6)
Six enhancements derived from agentic-runtime research:
1.  **E1: Skill Promotion:** `promote-skill` and `promote-skill-patch` allow manual operator APPROVE/REJECT gating for agent-suggested code.
2.  **E2: Skill Index:** `build-skill-index.sh` aggregates metadata into a searchable index with a 50KB cap.
3.  **E3: Programmatic Tool Calling:** `code-mode-dispatch.sh` enables "code-mode" dispatching through kernel-side scripts.
4.  **E4: Memory Note:** Manages a notes region in `MEMORY.md` with a **2200-char hard cap** and a **mkdir-atomic lock** to prevent concurrent write corruption.
5.  **E5: Standard Alignment:** Validates skills against the **agentskills.io** open specification.
6.  **E6: Change Tracker:** The append-only JSONL audit log described in the hooks section.

### 7.3 Deterministic Workflows
Opt-in, loop-shaped sub-phases executed as sandboxed scripts:
*   **hardening-loop.js:** A scan-fix-rescan cycle (up to 5 iterations) to resolve security findings.
*   **adversarial-review.js:** A parallel review debate between different AI models to ensure implementation quality.

### 7.4 Protocol Enforcement (Hookify)
Five optional `hookify` rules are available for hardening compliance:
*   `require-conductor-state`: Prevents system file edits without an active workflow.
*   `enforce-phase-sequence`: Blocks implementation until requirements are aligned.
*   `require-gemini-validation`: Mandates independent verification for all dispatches.
*   `verify-before-claiming-done`: Requires evidence of verification before completion.
*   `conductor-prompt-detection`: Flags prompts attempting to subvert the conductor protocol.