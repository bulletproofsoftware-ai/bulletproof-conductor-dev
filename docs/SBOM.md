# Software Bill of Materials (SBOM)

## Summary

`bulletproof-conductor-dev` is a **Claude Code plugin**, not a compiled or packaged application. It ships:

- **18 agent definitions** (`agents/*.md`) — Markdown with YAML frontmatter
- **1 slash command** (`commands/conduct.md`)
- **Bash hooks** (`hooks/scripts/*.sh`) plus shared libraries
- **Standard-library-only Python helpers** (`hooks/scripts/lib/*.py`, `scripts/lib/*.py`, `templates/conductor-prefill.py`)
- **Dependency-free JavaScript workflow scripts** (`workflows/*.js`, run via the Claude Code `Workflow` tool)
- **JSON schemas** (`schemas/*.json`) and YAML/JSON reference data

There is **no `package.json`, `requirements.txt`, or `pyproject.toml`** in this repository, and therefore **no third-party runtime dependency tree** to enumerate. This is by design: the plugin runs inside the Claude Code host and relies only on the host runtime, POSIX shell utilities, and the Python standard library.

## Runtime dependencies

**None.** Zero third-party npm or PyPI packages are installed or vendored.

### Python (standard library only)

Every Python helper imports only from the CPython standard library:

| Module | Used by | Purpose |
|--------|---------|---------|
| `json`, `os`, `sys`, `re` | all helpers | parsing, IO, path handling |
| `hashlib`, `hmac` | `audit_emitter.py` | audit-event integrity / signing |
| `socket` | `audit_emitter.py` | syslog transport |
| `logging`, `logging.handlers` | `audit_emitter.py` | syslog handler |
| `urllib.request`, `urllib.error` | `audit_emitter.py` | HTTP audit-sink transport |
| `datetime` | `audit_emitter.py` | timestamps |

No external Python package is required at runtime.

### JavaScript

`workflows/hardening-loop.js` and `workflows/adversarial-review.js` are executed by the Claude Code `Workflow` tool and use no `require`/`import` of third-party modules.

### Shell

Hooks use POSIX shell plus commonly available utilities (`jq`, `grep`, `sed`, `sha256sum`/`shasum`). These are host-provided, not vendored.

## CI-only dependencies (not shipped)

The GitHub Actions validation workflow (`.github/workflows/validate.yml`) pulls the following at CI time only. They are **not** part of the plugin's runtime footprint:

| Component | Version | License | Purpose |
|-----------|---------|---------|---------|
| `actions/checkout` | v4 | MIT | check out the repo |
| `actions/setup-python` | v5 | MIT | provision Python 3.12 |
| `gitleaks/gitleaks-action` | v2 | MIT | secret scanning |
| `jsonschema`, `check-jsonschema` | latest (pip) | MIT | schema validation |
| `yamllint` | latest (pip) | GPL-3.0 | YAML linting |
| `pyyaml` | latest (pip) | MIT | frontmatter parsing |
| `shellcheck` | ubuntu-provided | GPL-3.0 | shell linting |

## Base images

**None.** This repository ships no `Dockerfile` and no container image. It is installed by symlinking (or marketplace-installing) the plugin directory into the Claude Code plugins path.

## Verification

The absence of a dependency manifest was confirmed against the tracked file list. The independent Code Hardener scan (see [scan/scan-report.md](scan/scan-report.md)) ran `grype` and `syft` and reported **zero vulnerable components**; the only SBOM findings were unresolved-license notices for the three CI-only GitHub Actions, which are not runtime dependencies.

---

Apache-2.0 © 2026 bulletproofsoftware-ai. See [LICENSE](../LICENSE) and [NOTICE](../NOTICE).
