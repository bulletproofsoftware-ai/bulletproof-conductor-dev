# Contributing to conductor-dev

Thanks for your interest. This document covers what you need to work on the
plugin and what a change has to satisfy before it can be merged.

## Getting set up

```bash
git clone https://github.com/bulletproofsoftware-ai/bulletproof-conductor-dev.git
cd bulletproof-conductor-dev
bash tests/validate-plugin.sh
```

`validate-plugin.sh` is the same suite CI runs. It should pass on a clean clone
before you change anything — if it doesn't, that's a bug worth reporting on its
own. Checks whose tooling is missing report SKIP rather than failing, so
install `jq`, `python3` (with `jsonschema` and `pyyaml`), `shellcheck`, and
`gitleaks` for full coverage.

`conductor-dev` depends on
[`conductor-kernel`](https://github.com/bulletproofsoftware-ai/bulletproof-conductor-kernel)
at runtime. You do not need it installed to run the validation suite, but you
do need it to exercise `/conduct` end to end.

### Cross-plugin tests

`tests/test_req_cdv_006_backward_compat.py` checks that the kernel's
`workflow-state.schema.json` still accepts this plugin's legacy state shape.
It needs the kernel present and **exits 77 (SKIP) when it is not** — a
single-repository checkout cannot verify a two-plugin contract.

That skip is a real coverage gap, not a pass. If you change
`schemas/conductor-state.schema.json` or the shape of `conductor-state.json`,
run it against a real kernel before opening a PR:

```bash
export CONDUCTOR_KERNEL_ROOT=/path/to/conductor-kernel
python3 tests/test_req_cdv_006_backward_compat.py   # expect exit 0
```

## Repository layout

| Path | What lives there |
|------|------------------|
| `commands/` | The `/conduct` slash command |
| `agents/` | Dev-domain agent definitions |
| `hooks/scripts/` | Hook implementations (shell) |
| `workflows/` | Deterministic Workflow-tool scripts |
| `schemas/` | JSON Schemas, including `conductor-state.schema.json` |
| `templates/` | Scaffolding templates and generators |
| `tests/` | Validation and regression suites |
| `docs/` | Operator-facing documentation |

Agents and skills that belong to the **kernel** are not in this repository.
If a change touches shared orchestration behaviour, it probably belongs in
`conductor-kernel` instead.

## The canonical-prose rule

The orchestration section of `commands/conduct.md` between
`<!-- BEGIN_CANONICAL -->` and `<!-- END_CANONICAL -->` is duplicated verbatim
from the kernel's `lib/dispatcher-core.md`. **Do not edit it here.** Change the
kernel first, then re-sync this copy and update the `sync_hash` in the block
header. The kernel's `scripts/ci-dispatcher-diff.sh` is what detects drift.

Domain-specific prose — argument routing, the Code Hardener phase, adversarial
review — lives outside that block and is edited here.

## What a change must satisfy

1. `bash tests/validate-plugin.sh` passes.
2. Shell changes pass `shellcheck -x -S error -e SC1091` (what CI gates on).
3. No secrets. `gitleaks detect --source .` stays clean.
4. **No environment coupling.** Nothing may assume a specific machine: no
   absolute home paths, no personal hostnames or SSH aliases, no assumption
   that sibling repositories sit at a particular location, no ports that
   reflect one operator's port map. Anything installation-specific goes
   through an environment variable with a sane documented default. This is the
   most common reason a change is sent back.
5. **Optional dependencies stay optional.** Gemini CLI and Code Hardener are
   not bundled. If you add an integration, it degrades honestly when the
   service is absent, and the degradation is recorded rather than silently
   treated as success.
6. Docs match behaviour. If you change what a flag or variable does, update the
   documentation in the same commit.
7. No placeholders or stubbed implementations.

## Commit style

Conventional-commit prefixes (`feat:`, `fix:`, `docs:`, `chore:`, `test:`),
a concise subject line, and a body explaining *why* when it isn't obvious.
Stage files by name — never `git add .`.

## Reporting bugs

Open an issue with the command you ran, what you expected, what happened, and
the output of `bash tests/validate-plugin.sh`. If it involves a workflow, the
relevant `conductor-state.json` excerpt helps — redact anything sensitive
first.

For security issues, follow [SECURITY.md](SECURITY.md) and do **not** open a
public issue.

## License

By contributing you agree that your contributions are licensed under
Apache-2.0, matching [LICENSE](LICENSE).
