# Audit Remediation — Patch Application Guide

These patches address findings from the 2026-04-17 compliance audit (see `docs/audit-remediation/AUDIT-REPORT.md`). Each patch is in a separate file. Apply in order.

The reason these are emitted as patches rather than direct edits: this repo's hookify governance rules (`require-conductor-state`, `enforce-phase-sequence`) intentionally block writes to `agents/`, `skills/`, `hooks/`, `schemas/` to prevent unauthorized modifications by AI agents. **The audit-remediation work writes to those paths**, so the operator must apply these patches manually after review.

## Order of application

| # | Patch | Severity | What it changes |
|---|-------|----------|-----------------|
| 01 | `01-create-secrets-lifecycle-agent.patch` | CRITICAL | Adds `agents/conductor-secrets-lifecycle.md` (resolves missing-agent reference in routing matrix) |
| 02 | `02-create-supply-chain-security-agent.patch` | CRITICAL | Adds `agents/conductor-supply-chain-security.md` |
| 03 | `03-create-retrospective-agent.patch` | CRITICAL | Adds `agents/conductor-retrospective.md` |
| 04 | `04-fix-hook-tmp-race.patch` | HIGH | `hooks/scripts/post-state-write.sh` — replaces `/tmp` cache with per-project `.conductor-cache/` (eliminates symlink race) |
| 05 | `05-update-process-knowledge-skill.patch` | CRITICAL | `skills/process-knowledge/SKILL.md` — clarifies YAML-direct interface as v1, MCP tools as v2 roadmap, aligns with PRD naming |
| 06 | `06-update-agent-registry-implemented.patch` | HIGH | `skills/agent-interop/references/agent-registry.yaml` — moves the 3 newly-implemented agents from PLANNED to implemented |

## Recommended workflow

```bash
cd /path/to/conductor-plugin

# 1. Review every patch before applying
for p in docs/audit-remediation/patches/*.patch; do
    echo "=== $p ==="
    cat "$p"
    read -p "Apply? [y/N] " confirm
    if [ "$confirm" = "y" ]; then
        git apply --check "$p" && git apply "$p"
    fi
done

# 2. Verify nothing broke
./tests/validate-plugin.sh

# 3. If validation passes, commit
git add agents/conductor-secrets-lifecycle.md \
        agents/conductor-supply-chain-security.md \
        agents/conductor-retrospective.md \
        hooks/scripts/post-state-write.sh \
        skills/process-knowledge/SKILL.md \
        skills/agent-interop/references/agent-registry.yaml

git commit -m "fix: apply audit remediation patches (3 missing agents, hook race fix, skill alignment)

Resolves CRITICAL findings C1, C3 and HIGH finding H4 from the
2026-04-17 compliance audit. See docs/audit-remediation/AUDIT-REPORT.md."
```

## What was already applied directly

The following were applied without patches because they write to non-blocked paths:

- `README.md` — H1 (rewrote with current counts and full PRD coverage)
- `SECURITY.md` — H2 (vulnerability disclosure policy)
- `CHANGELOG.md` — H2 (change history)
- `.gitignore` — housekeeping (added `conductor-last-status.txt`, `.conductor-cache/`)
- `.claude-plugin/plugin.json` — M1 (restored explicit `hooks`/`commands`/`agents`/`skills` declarations)
- `tests/validate-plugin.sh` — H5 (local CI mirror, full validation suite)
- `docs/audit-remediation/AUDIT-REPORT.md` — the audit report itself
- `docs/audit-remediation/proposed-ci/validate.yml` — C2 (CI workflow draft, blocked from `.github/workflows/` by security_reminder_hook — see C2 instructions below)

## C2: CI/CD workflow installation

The CI workflow file (`docs/audit-remediation/proposed-ci/validate.yml`) was blocked from being written directly to `.github/workflows/validate.yml` by the operator's `security_reminder_hook`. The hook is correct to be cautious about workflow files; please review the workflow content for safety, then move it into place:

```bash
# After reviewing docs/audit-remediation/proposed-ci/validate.yml for safety
mkdir -p .github/workflows
mv docs/audit-remediation/proposed-ci/validate.yml .github/workflows/validate.yml
git add .github/workflows/validate.yml
git commit -m "ci: add validation workflow (shellcheck + schema + yamllint + consistency)"
```

The workflow does NOT use any unsafe patterns (no direct interpolation of `github.event.*` into `run:` blocks). It only checks out the repo and runs validation tools.

## Verification checklist (run before committing)

- [ ] `./tests/validate-plugin.sh` exits 0 with no failures
- [ ] `agents/` count is 34: `ls agents/*.md | wc -l` returns 34
- [ ] Registry has zero PLANNED entries for newly-implemented agents
- [ ] `git diff hooks/scripts/post-state-write.sh` shows the cache-dir change
- [ ] `grep "PLANNED — not yet" skills/process-knowledge/SKILL.md` returns 0 matches
- [ ] CI workflow runs successfully on the next push (after C2 install)

## Rollback

If anything breaks, the patches can be reversed:

```bash
git apply -R docs/audit-remediation/patches/*.patch
```
