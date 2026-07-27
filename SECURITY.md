# Security Policy

## Supported Versions

This plugin follows semantic versioning. Security fixes are backported as follows:

| Version | Status               | Receives security fixes |
|---------|----------------------|-------------------------|
| 1.x     | **Active**           | Yes                     |
| < 1.0   | End of life          | No                      |

The current version is recorded in `.claude-plugin/plugin.json`.

## Reporting a Vulnerability

**Do not open a public GitHub issue for security vulnerabilities.**

Email **marc@bulletproofsoftware.ai** with:

1. A description of the vulnerability
2. The affected component (agent, hook, schema, skill)
3. Reproduction steps
4. Impact assessment (who is affected, what is exposed)
5. Any proposed mitigation

We commit to:

- **Acknowledgement** within 2 business days
- **Initial triage** within 5 business days, including a severity rating (CVSS 4.0)
- **Status updates** at least every 7 days until resolution
- **Patch release** for CRITICAL/HIGH within 14 days, MEDIUM within 30 days

Please give us a reasonable disclosure window before publishing details. We will credit reporters in the CHANGELOG unless they request anonymity.

## Scope

In scope:

- Hook scripts in `hooks/scripts/` — command injection, path traversal, race conditions, privilege escalation
- Agent prompts in `agents/` — prompt-injection-induced misuse, governance bypass, tool privilege escalation
- Skill reference data in `skills/` — data-integrity, exfiltration, classification leakage
- Schema in `schemas/` — validation bypass that allows malformed state to persist
- The `/conduct` slash command — argument injection, unauthorized state modification
- Plugin manifest (`plugin.json`, `marketplace.json`) — installation/distribution attack vectors

Out of scope:

- Vulnerabilities in Claude Code itself (report to Anthropic)
- Vulnerabilities in third-party tools the plugin invokes (Gemini CLI, gitleaks, syft, cosign, etc.)
- Social engineering of plugin users
- DoS via resource exhaustion of LLM provider (the conductor's `cost_tracking` is the mitigation)

## Trust Model

This plugin is designed to operate inside Claude Code as a privileged workflow orchestrator. It assumes:

- **The operator is trusted.** The plugin does not defend against a malicious operator who can already invoke arbitrary Bash and edit any file.
- **Agent dispatches are authenticated by Claude Code's `Task` tool.** The plugin trusts that subagent_type maps to the named agent file.
- **External binaries on the operator's PATH are trusted.** The plugin invokes `gemini`, `git`, `jq`, `python3`, `gitleaks`, `syft`, `cosign`. Compromised versions of these can subvert the plugin.
- **The filesystem is the source of truth.** State files (`conductor-state.json`, `BRD-tracker.json`) are read/written without locking; concurrent writers can corrupt state. Single-operator use is assumed.

The plugin **does** defend against:

- Untrusted agent outputs (Gemini independent validation)
- Phase-gate bypass attempts (programmatic PostToolUse enforcement)
- Workflow tampering (JSON schema validation on every state write)
- Self-erasure of audit trail (external `audit_sink` to syslog if configured)
- Excessive cost (denial-of-wallet protection via `cost_tracking` budget caps)
- Prohibited behaviors (kill-switch via PostToolUse hook + `intent.prohibited_behaviors[]`)

## Security Properties of the Plugin Itself

The plugin code (hooks, agents, skills) has these security properties:

| Property | Mechanism | Verification |
|----------|-----------|--------------|
| No command injection in hooks | All shell expansions through `jq -r` and quoted variables | Tested with malicious `file_path` payloads; shellcheck CI gate |
| No hardcoded secrets | Repository scanned with gitleaks at commit and CI | `gitleaks detect --source .` returns 0 findings |
| Hook scripts not world-writable | `chmod 700` on every script in `hooks/scripts/` | `ls -la hooks/scripts/*.sh` |
| State file integrity | Schema validation post-Write/Edit; phase transitions reject corrupt state | `tests/validate-plugin.sh` |
| Cache file safety | Per-project cache dir, symlinks rejected, fail-secure | `hooks/scripts/post-state-write.sh` |

CI runs the validation script on every PR (`.github/workflows/validate.yml`).

## Compliance Frameworks

This plugin is designed to support workflows operating under:

- NIST SSDF (SP 800-218 v1.1)
- OWASP Top 10 2025 (Web, API, LLM)
- SOC 2 Type II
- ISO/IEC 27001:2022
- GDPR, HIPAA, PCI-DSS (when configured via `project_characteristics.compliance_requirements`)
- SLSA Levels 1–4 (via `conductor-supply-chain-security` agent)
- ISO/IEC 42001 (AI management — via governance integration)

The plugin's `conductor-ciso` agent maps controls to these frameworks at the BRD-extraction phase. See `agents/conductor-ciso.md` for the control catalog.

## Known Limitations

- **Single-operator state file.** Concurrent writers can corrupt `conductor-state.json`. Use git ratcheting + checkpoints to recover.
- **Hookify rules are advisory unless paired with PreToolUse implementation.** An operator's `.claude/hookify.*.local.md` rules are enforced by the hookify plugin; they are not part of conductor's own governance.
- **Gemini validation degrades open.** If `gemini` CLI is unavailable, validation is skipped with a warning. This is intentional (preserve workflow availability) but reduces accountability.

## Audit Trail

Every workflow action is recorded in:

1. `conductor-state.json` — `agent_instances[]`, `handoff_history[]`, `gemini_validations[]`, `completed_tasks[]`, `recovery.recovery_history[]`
2. Optional external syslog via `audit_sink.syslog_target`
3. Git history of state file writes

For compliance audits, the relevant evidence is the git log of `conductor-state.json` plus the contents of `audit_sink.syslog_target`.
