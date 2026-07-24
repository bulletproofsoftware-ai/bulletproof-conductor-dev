# Installation — bulletproof-conductor-dev

## Prerequisites

- **[Claude Code](https://claude.com/claude-code)** — this is a Claude Code plugin.
- **[`conductor-kernel`](https://github.com/bulletproofsoftware-ai/bulletproof-conductor-kernel) `>= 0.1.0`** — the required orchestration engine. conductor-dev will not function without it; it references kernel agents and skills as `conductor-kernel:<name>`.
- **POSIX shell + `jq`** — the hooks are bash and use `jq`. Present on macOS and Linux by default (install `jq` if missing).
- **Python 3** — for the schema-validation and helper scripts (standard library only; no `pip install` required to run the plugin).

There is **no `npm install` / `pip install` step** for the plugin itself — it ships no third-party runtime dependencies (see [SBOM.md](SBOM.md)).

## Local development install

Install the kernel first, then this plugin, by symlinking each into the Claude Code local-plugins path:

```bash
# 1. conductor-kernel (required dependency)
git clone https://github.com/bulletproofsoftware-ai/bulletproof-conductor-kernel.git conductor-kernel
ln -s "$(pwd)/conductor-kernel" ~/.claude/plugins/local/conductor-kernel

# 2. conductor-dev
git clone https://github.com/bulletproofsoftware-ai/bulletproof-conductor-dev.git conductor-dev
ln -s "$(pwd)/conductor-dev" ~/.claude/plugins/local/conductor-dev
```

Then enable **both** plugins in Claude Code through your plugin marketplace settings.

## Marketplace install (when published)

```bash
claude plugin install conductor-kernel
claude plugin install conductor-dev
```

## Verify the install

Run the bundled local CI mirror from the repo root:

```bash
bash tests/validate-plugin.sh
```

It checks:

- `shellcheck` on every hook script
- JSON Schema Draft 2020-12 validity of `schemas/conductor-state.schema.json`
- Agent frontmatter completeness (`name` + `description` + `model`) and filename/name match
- Agent registry consistency (every implemented registry agent has a file)
- Hook runtime smoke tests (including an injection attempt)
- Secrets scan (`gitleaks`)
- Plugin manifest sanity

The same checks run in CI via `.github/workflows/validate.yml`.

Then, inside a Claude Code session, confirm the command resolves:

```
/conduct status
```

With no active workflow this reports "no workflow active" — confirming the plugin is loaded.

## First run

```
/conduct new Build a task management API with user authentication
```

The Conductor classifies the request into a tier and begins the tier-appropriate pipeline, creating `conductor-state.json` in your current working directory. See [HOW-TO-USE.md](HOW-TO-USE.md) for the full command surface.

## Uninstall

Remove the symlinks (local install) or `claude plugin remove conductor-dev` (marketplace). Delete any per-project `conductor-state.json` and `BRD-tracker.json` if you no longer need the audit trail.

---

Apache-2.0 © 2026 bulletproofsoftware-ai. See [LICENSE](../LICENSE) and [NOTICE](../NOTICE).
