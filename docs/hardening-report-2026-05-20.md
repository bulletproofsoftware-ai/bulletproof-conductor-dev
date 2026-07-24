# Security Scan Report: conductor-dev

**Scan ID:** `92860554-fd58-40ca-ac30-6f2dd034b26a`
**Date:** 2026-05-20T18:20:20.843Z
**Score:** 1000/1000 (excellent)
**Branch:** main | **Commit:** `N/A`
**Profile:** standard

## Summary

| Severity | Count |
|----------|-------|
| Critical | 0 |
| High | 0 |
| Medium | 0 |
| Low | 0 |
| Info | 0 |
| **Total (open)** | **0** |

> **Note:** The counts above reflect _open_ findings only.
> 8 additional finding(s) excluded — 1 false positive, 7 ignored — see "Suppressed & Dismissed Findings" below.
> 2 scanner(s) were skipped — see "Skipped Scanners" below.

## Scanners Executed

| Scanner | Status | Findings | Duration | Notes |
|---------|--------|----------|----------|-------|
| trivy | pass | 2 | 2.4s |  |
| gitleaks | pass | 0 | 0.4s |  |
| opengrep | pass | 1 | 6.6s |  |
| checkov | pass | 0 | 2.2s |  |
| grype | pass | 0 | 1.3s |  |
| syft | pass | 3 | 1.3s |  |
| package-validator | skipped | 0 | 0.0s |  |
| oxlint | skipped | 0 | 0.0s | _skipped: no_matching_files_ |
| ruff | pass | 0 | 0.0s |  |
| actionlint | pass | 0 | 0.0s |  |
| jscpd | pass | 2 | 1.8s |  |
| typos | fail | 0 | 0.0s | _error: Cannot read properties of undefined (reading 'length')_ |
| _file_inventory | pass | 0 | 0.0s |  |

## Skipped Scanners (2)

Scanners that did not run on this scan, with the reason why and how to enable them.

| Scanner | Reason | How to enable |
|---------|--------|---------------|
| `oxlint` | no_matching_files | No .js/.ts files found — Oxlint requires a JavaScript/TypeScript project |
| `package-validator` | unknown | _(no hint)_ |

## Suppressed & Dismissed Findings (8)

Findings that exist in this scan but are not counted as open. Each disposition is documented here for audit and compliance evidence.

### False Positives (1)

#### [MEDIUM] dynamic-urllib-use-detected

- **Scanner:** `opengrep` (rule `python.lang.security.audit.dynamic-urllib-use-detected.dynamic-urllib-use-detected`)
- **Location:** `/scan-target/hooks/scripts/lib/audit_emitter.py:376`
- **CWE:** CWE-939: Improper Authorization in Handler for Custom URL Scheme
- **OWASP:** A
- **Disposition:** False Positive
- **Reason:** Scheme allowlist + noqa S310 defense in commit 2ef0a81
- **Comment:** audit_emitter.emit_http() allowlists http(s) schemes BEFORE urlopen; file:// and others rejected with ValueError. Dynamic value is operator-configured audit_sink.syslog_target, not user input. Opengrep pattern match cannot detect surrounding validation.
- **Dismissed by:** Test User on 2026-05-20T18:22:24.029Z
- **Source:** Manually dismissed

---

### Ignored (7)

#### [LOW] License Compliance: MIT in 

- **Scanner:** `trivy` (rule `LICENSE-MIT`)
- **Location:** `LICENSE`
- **OWASP:** A06:2021-Vulnerable and Outdated Components
- **Disposition:** Ignored
- **Reason:** False flag on repo LICENSE file itself
- **Comment:** Repo declares its own MIT license in LICENSE file. Expected and required artifact, not a compliance violation.
- **Dismissed by:** Test User on 2026-05-20T18:22:24.067Z
- **Source:** Manually dismissed

---

#### [LOW] Unknown License: gitleaks/gitleaks-action@v2

- **Scanner:** `syft` (rule `SBOM-LICENSE-UNKNOWN`)
- **Location:** `/.github/workflows/validate.yml`
- **OWASP:** A08:2021-Software and Data Integrity Failures
- **Disposition:** Ignored
- **Reason:** External GitHub Action license metadata — out of scope
- **Comment:** syft cannot resolve licenses for github.com/<owner>/<repo>@<sha> action refs. These are third-party actions whose licenses live in their upstream repos, not in conductor-dev.
- **Dismissed by:** Test User on 2026-05-20T18:22:24.056Z
- **Source:** Manually dismissed

---

#### [LOW] Unknown License: actions/setup-python@v5

- **Scanner:** `syft` (rule `SBOM-LICENSE-UNKNOWN`)
- **Location:** `/.github/workflows/validate.yml`
- **OWASP:** A08:2021-Software and Data Integrity Failures
- **Disposition:** Ignored
- **Reason:** External GitHub Action license metadata — out of scope
- **Comment:** syft cannot resolve licenses for github.com/<owner>/<repo>@<sha> action refs. These are third-party actions whose licenses live in their upstream repos, not in conductor-dev.
- **Dismissed by:** Test User on 2026-05-20T18:22:24.056Z
- **Source:** Manually dismissed

---

#### [LOW] Unknown License: actions/checkout@v4

- **Scanner:** `syft` (rule `SBOM-LICENSE-UNKNOWN`)
- **Location:** `/.github/workflows/validate.yml`
- **OWASP:** A08:2021-Software and Data Integrity Failures
- **Disposition:** Ignored
- **Reason:** External GitHub Action license metadata — out of scope
- **Comment:** syft cannot resolve licenses for github.com/<owner>/<repo>@<sha> action refs. These are third-party actions whose licenses live in their upstream repos, not in conductor-dev.
- **Dismissed by:** Test User on 2026-05-20T18:22:24.056Z
- **Source:** Manually dismissed

---

#### [INFO] License Compliance: Copyright in 

- **Scanner:** `trivy` (rule `LICENSE-Copyright`)
- **Location:** `agents/conductor-doc-gen.md`
- **OWASP:** A06:2021-Vulnerable and Outdated Components
- **Disposition:** Ignored
- **Reason:** Copyright string in agent prose, not license declaration
- **Comment:** trivy flagged the word "Copyright" appearing in agents/conductor-doc-gen.md docstring. This is documentation prose about copyright handling (the agent generates compliance docs), not a license declaration.
- **Dismissed by:** Test User on 2026-05-20T18:22:24.086Z
- **Source:** Manually dismissed

---

#### [INFO] Code duplication: 12 lines between TODO/hermes-e2-progressive-disclosure.md and commands/conduct.md

- **Scanner:** `jscpd` (rule `JSCPD-DUPLICATE`)
- **Location:** `TODO/hermes-e2-progressive-disclosure.md:143`
- **Disposition:** Ignored
- **Reason:** Intentional template/spec overlap in markdown
- **Comment:** Code duplication detected by jscpd between markdown files is INTENTIONAL — the TODO specs quote canonical command behavior verbatim per the spec/command contract.
- **Dismissed by:** Test User on 2026-05-20T18:22:24.077Z
- **Source:** Manually dismissed

---

#### [INFO] Code duplication: 12 lines between docs/COMPLIANCE-OVERVIEW.md and templates/COMPLIANCE-OVERVIEW.md

- **Scanner:** `jscpd` (rule `JSCPD-DUPLICATE`)
- **Location:** `docs/COMPLIANCE-OVERVIEW.md:741`
- **Disposition:** Ignored
- **Reason:** Intentional template/spec overlap in markdown
- **Comment:** Code duplication detected by jscpd between markdown files is INTENTIONAL — the TODO specs quote canonical command behavior verbatim per the spec/command contract.
- **Dismissed by:** Test User on 2026-05-20T18:22:24.077Z
- **Source:** Manually dismissed

---

## Recommendations

1. No findings detected -- maintain current security practices and scan regularly

---
*Generated by Code Hardener v0.1.0 | 2026-05-20T18:22:51.865Z*