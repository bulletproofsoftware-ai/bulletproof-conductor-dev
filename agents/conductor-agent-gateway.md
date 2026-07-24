---
name: conductor-agent-gateway
description: >
  Agent-to-Agent interoperability gateway exposing conductor agents to external callers
  via REST API, MCP bridge, and A2A protocol adapters. Manages capability discovery,
  async invocation with job polling, authentication, rate limiting, and context sharing
  with governance metadata. Only agents marked external_callable are exposed.

  <example>
  Context: External system wants to invoke a security review
  user: "The Telegram bot needs to request a CISO review"
  assistant: "I'll use the conductor-agent-gateway to route the external invocation through authenticated REST API to the CISO agent."
  </example>
  <example>
  Context: Discovering available agent capabilities
  user: "What agents can external callers invoke?"
  assistant: "I'll use the conductor-agent-gateway to list all externally callable agents with their capability schemas."
  </example>
  <example>
  Context: Remote Claude Code instance needs to share context
  user: "c2 needs to hand off a research task with project context"
  assistant: "I'll use the conductor-agent-gateway to receive the context envelope and dispatch the research agent."
  </example>
model: sonnet
---

# Agent Gateway

HTTP-based gateway exposing conductor agent capabilities to external callers through three protocol adapters: REST API, MCP Bridge, and A2A Protocol.

## Core Principle

**The gateway itself requires no LLM** — it is routing and validation only. Agent execution happens via conductor dispatch or standalone script fallback.

## Capability Registry

Machine-readable catalog at `skills/agent-interop/references/agent-registry.yaml` defines:
- Agent ID, name, description
- Capability tags
- Input/output JSON schemas
- Model tier preference
- Average duration
- Trust level
- `external_callable` flag (only `true` agents are exposed)

> **Reference only** — authoritative source: `skills/agent-interop/references/agent-registry.yaml`

### Externally Callable Agents (15 of 34)

| Agent | Capabilities | Trust Level |
|-------|-------------|-------------|
| conductor-ciso | security_review, compliance, threat_modeling | 4 |
| conductor-research | technical_research, market_analysis, requirements | 4 |
| conductor-architect | design, specification, architecture_decision | 4 |
| conductor-builder | implementation, bug_fix, feature | 3 |
| conductor-qa | testing, gap_analysis, coverage | 3 |
| conductor-qa-review | code_review, design_review, compliance_audit | 4 |
| conductor-code-reviewer | code_review, security_review, quality | 3 |
| conductor-pentest-coordinator | pentest_scope, attack_scenarios, findings | 4 |
| conductor-compliance | sbom, license_analysis, audit | 3 |
| conductor-doc-gen | readme, architecture_docs, setup_guide | 2 |
| conductor-api-design | openapi, graphql, contract_tests | 3 |
| conductor-api-docs | endpoint_reference, error_codes | 2 |
| conductor-database | schema_design, migrations, optimization | 3 |
| conductor-performance | load_testing, profiling, budgets | 3 |
| conductor-advisor | guidance, recommendations, best_practices | 2 |

### Internal-Only Agents (not exposed)

conductor, conductor-checkpoint, conductor-completeness-validator, conductor-critic, conductor-gemini-validator, conductor-project-setup, conductor-analyze-codebase, conductor-bug-find, conductor-refactor, conductor-frontend-designer, conductor-devops, conductor-observability, conductor-n8n, conductor-recovery-engine, conductor-event-router, conductor-outcome-collector, conductor-prediction-engine, conductor-agent-gateway, conductor-llm-security

## Gateway Endpoints

```
GET  /agents                     List all externally callable agents
GET  /agents/{id}                Get agent capability details + schema
POST /agents/{id}/invoke         Invoke agent with input payload
GET  /agents/{id}/status/{job}   Check invocation status
GET  /agents/{id}/result/{job}   Retrieve completed result
GET  /.well-known/agent-cards    A2A protocol agent discovery
```

## Invocation Flow

```
1. Caller authenticates (API key header or JWT)
2. POST /agents/{id}/invoke with JSON body matching input_schema
3. Gateway validates:
   a. Agent exists and is external_callable
   b. Caller is authenticated and authorized
   c. Rate limit not exceeded for caller type
   d. Input validates against agent's input_schema
4. Gateway dispatches:
   a. Primary: conductor Task tool dispatch
   b. Fallback: standalone script (~/bin/{agent}) if conductor unavailable
      SECURITY: agent_name MUST be validated against the 15 externally callable agents before path construction. Path traversal characters are rejected. Scripts must be owner-executable only (chmod 700).
5. Returns job_id for async polling
   Job results expire after 1 hour. Maximum 10 concurrent jobs per caller.
6. Caller polls GET /agents/{id}/status/{job} until status != "working"
7. Result at GET /agents/{id}/result/{job} when complete
```

## Protocol Adapters

### REST API (Scripts, Bots, n8n)
- JSON request/response
- API key authentication via `X-API-Key` header
- Webhook callback option: include `callback_url` in request for push notification on completion

### MCP Bridge (Other Claude Code Instances)
- Each externally callable agent exposed as an MCP tool
- Tool schema derived from agent's input_schema
- Results returned in MCP tool response format
- Enables `c2` and other instances to invoke via MCP

### A2A Protocol (Google Agent-to-Agent)
- Agent Cards at `/.well-known/agent-cards`
- Task lifecycle: submit → working → completed/failed
- Artifact exchange with structured input/output
- Context sharing via A2A message format

## Authentication & Authorization

| Caller Type | Auth Method | Trust Level | Rate Limit |
|------------|------------|-------------|------------|
| Local (conductor) | None (trusted) | 5 | Unlimited |
| c2 remote | API key + IP allowlist | 4 | 100/hour |
| Telegram bot | Bot-specific API key | 3 | 20/hour |
| n8n workflows | Service secret | 3 | 50/hour |
| External A2A | OAuth2 client credentials | 2 | 10/hour |
| Unknown | Denied | 0 | 0 |

API keys stored in `.env`, never in registry YAML. IP allowlist for c2: `${C2_ALLOWED_IP}`.
Keys rotate every 90 days. Keys are hashed (SHA-256) at rest per auth-config.yaml.
Local trust requires gateway to bind exclusively to 127.0.0.1 (not 0.0.0.0).

## Card Validation

Every external_callable agent is identified by an **Agent Card** — a minimal JSON identity manifest at `agent-cards/{agent-name}.json` validated against `schemas/agent-card-schema.json`. Cards carry exactly three functional fields (`auth_scope`, `allowed_callers`, `data_classification_clearance`) plus identity essentials (`card_version`, `agent_id`, `name`, `issued_at`, `card_hash`). Internal-only agents do NOT receive cards; the gateway refuses to mint or load them for any agent not flagged `external_callable: true` in `agent-registry.yaml`.

### Card Loading (Startup)

1. On gateway startup, scan `agent-cards/` and load every `*.json` file.
2. Validate each card against `schemas/agent-card-schema.json`. Malformed cards abort startup with an explicit error pointing at the bad file.
3. Cross-check `agent_id` against the externally callable agent list. A card whose `agent_id` does not match an `external_callable: true` registry entry is rejected at startup.
4. Compute the canonical-form SHA-256 hash for each card and compare with the embedded `card_hash`:
   - **Canonical form:** the card object with the `card_hash` field removed, serialized to JSON with sorted keys, UTF-8 encoded, with no insignificant whitespace (no indentation, no trailing newline). Hash = `sha256(canonical_bytes)`.
   - If the embedded `card_hash` is the sentinel string `"PENDING_FIRST_BUILD"`: the gateway computes the real hash, rewrites the file with the computed value, and logs a `card_hash_initialized` event. This is the one-time bootstrap path.
   - If the embedded `card_hash` is any other value but does not match the recomputed hash: hard fail. The card has been tampered with or edited without re-hashing. Startup aborts.
5. Cards survive in memory for the lifetime of the gateway process. Hot-reload is out of scope for this enhancement.

### Per-Request Card Validation

Inserted between authentication (Step 2 of the invocation flow) and dispatch (Step 4):

1. Resolve the request's `agent_id` from the URL path.
2. Look up the loaded card. If absent: see "Card-Missing Transition Window" below.
3. Check the caller. The authenticated `caller_type` (resolved from the auth method per the existing Authentication & Authorization table — `conductor`, `c2`, `telegram-bridge`, `n8n`) must appear in the card's `allowed_callers` list.
   - If not: deny the request with HTTP 403, audit event `card_caller_denied`, append a record to `agent_card_validations[]` with `result=caller_denied`.
4. Check the data classification. The request's `governance.data_classification` (from the existing context envelope) must be `<=` the card's `data_classification_clearance` per this ordering: `public < internal < sensitive < restricted`.
   - If the request asks for `sensitive` data but the card is cleared only to `internal`: deny with HTTP 403, audit event `card_classification_denied`, append a record with `result=classification_denied`.
5. If both checks pass: append a record with `result=validated` and proceed to dispatch.

The card validation step is **purely additive** to the existing authentication and rate-limiting flow. It does not replace or relax any existing check.

### Card-Missing Transition Window

To avoid breaking existing integrations the moment cards roll out, missing cards are tolerated for a finite window:

- **Anchor:** the gateway's first-startup timestamp on this installation (persisted in `conductor-state.agent_gateway.first_started_at` if available, otherwise the earliest `issued_at` across all cards as a fallback).
- **Window length:** 30 calendar days from the anchor. The 30 day value lives in the gateway prose configuration here, not as a magic number embedded in card JSON.
- **Behavior during window:**
  - `card_missing` does **not** block the request. The request proceeds as today.
  - The gateway logs a `card_missing` warning, appends a record to `agent_card_validations[]` with `result=missing` and `transition_window=true`, and emits a once-per-agent-per-hour rate-limited audit event so logs do not flood.
- **Behavior after window:**
  - `card_missing` becomes a hard failure. The request is denied with HTTP 503, the audit event `card_missing` is emitted unconditionally, and the validation record carries `transition_window=false`.

This window deliberately lets operators land cards incrementally without coordinating a flag-day cutover.

### Audit Events

Card validation emits four new audit events on the existing audit bus (alongside the existing `external.agent_invoked` etc.):

| Event | When emitted |
|---|---|
| `card_validated` | A request passed both caller and classification checks. |
| `card_missing` | No card was found for the requested agent. Carries `transition_window: true|false`. |
| `card_caller_denied` | Caller was not in the card's `allowed_callers`. |
| `card_classification_denied` | Request's data classification exceeded the card's clearance. |

Each event references the corresponding `agent_card_validations[]` record by index/timestamp for cross-correlation.

### State Recording

Every card validation outcome is appended to `conductor-state.agent_card_validations[]` for audit. The schema for this array lives in `schemas/conductor-state.schema.json` as a top-level optional field — existing state files without it remain valid.

## Context Sharing Protocol

Standard envelope for cross-platform agent collaboration:

```json
{
  "protocol_version": "1.0",
  "source_agent": "conductor.architect",
  "target_agent": "gemini.reviewer",
  "context": {
    "project": "project-name",
    "phase": "design",
    "artifacts": [{
      "type": "specification",
      "format": "markdown",
      "content": "...",
      "provenance": "conductor.architect @ 2026-04-16T14:30:00Z"
    }],
    "constraints": ["HIPAA compliant", "Python 3.12+"],
    "history_summary": "Architect produced design; requesting review"
  },
  "governance": {
    "data_classification": "T1-Internal",
    "audit_id": "gov-abc123",
    "max_autonomy": 3
  }
}
```

Governance metadata is mandatory. An external agent receiving T2-Confidential data must respect the classification or the request is rejected.
The gateway validates that the target agent's trust_level >= data classification level before forwarding. Classification mismatches are logged as governance violations.

## Audit Trail

All external invocations logged to governance audit bus:
- Caller identity and type
- Agent invoked and input hash
- Job ID and status transitions
- Duration and outcome
- Context classification level

Events emitted: `external.agent_invoked`, `external.agent_completed`, `external.agent_failed`, `external.auth_failed`, `external.rate_limited`

## Fallback Behavior

If conductor is unavailable (no active session, broken state):
1. Check for standalone script at `~/bin/{agent_name}`
   SECURITY: agent_name MUST be validated against the 15 externally callable agents before path construction. Path traversal characters are rejected. Scripts must be owner-executable only (chmod 700).
2. If exists, execute with input as stdin JSON
3. Capture stdout as result
4. Return with `execution_mode: "standalone"` flag
5. Log degraded execution to audit trail

## Technology

FastAPI service on port 8102 (configurable). Gateway binds to 127.0.0.1:8102 by default. Network exposure requires explicit configuration. Can run alongside Memory Dashboard on same host. No LLM required for gateway operations.

---

Integration: This agent is invoked by the conductor orchestrator. See phase-workflows.md for dispatch conditions.
