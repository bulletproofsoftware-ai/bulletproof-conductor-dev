# Security Scan Report: bulletproof-conductor-dev

**Scan ID:** `b0348c67-3b81-4815-8ff3-ec7aea07ebe2`
**Date:** 2026-07-24T20:58:55.898Z
**Score:** 1000/1000 (excellent)
**Branch:** main | **Commit:** `N/A`
**Profile:** standard

## Summary

| Severity | Count |
|----------|-------|
| Critical | 0 |
| High | 0 |
| Medium | 14 |
| Low | 4 |
| Info | 12 |
| **Total (open)** | **30** |

> **Note:** The counts above reflect _open_ findings only.
> 1 scanner(s) were skipped — see "Skipped Scanners" below.

## Scanners Executed

| Scanner | Status | Findings | Duration | Notes |
|---------|--------|----------|----------|-------|
| trivy | pass | 2 | 2.7s |  |
| gitleaks | pass | 0 | 0.4s |  |
| opengrep | pass | 13 | 6.2s |  |
| checkov | pass | 0 | 3.3s |  |
| grype | pass | 0 | 3.1s |  |
| syft | pass | 3 | 1.5s |  |
| package-validator | skipped | 0 | 0.0s |  |
| oxlint | pass | 2 | 0.0s |  |
| ruff | pass | 0 | 0.0s |  |
| actionlint | pass | 0 | 0.0s |  |
| jscpd | pass | 0 | 0.0s |  |
| typos | pass | 11 | 0.0s |  |
| _file_inventory | pass | 0 | 0.0s |  |

## Medium Findings (14)

### [MEDIUM] Unnecessary escape character '"'

- **File:** `workflows/adversarial-review.js`
- **Scanner:** oxlint
- **Rule:** `OXLINT-UNKNOWN`

**What's wrong:** Unnecessary escape character '"'

**How to fix:** Review this finding and apply the appropriate fix based on the description: Unnecessary escape character '"'

**Action:** Plan to fix this issue in your next sprint or release.

---

### [MEDIUM] Detected a dynamic value being used with urllib. urllib supports 'file://' schemes, so a dynamic value controlled by a malicious actor may allow them to read arbitrary files. Audit uses of urllib calls to ensure user data cannot control the URLs, or consider using the 'requests' library instead.

- **File:** `hooks/scripts/lib/audit_emitter.py:376`
- **Scanner:** opengrep
- **Rule:** `python.lang.security.audit.dynamic-urllib-use-detected.dynamic-urllib-use-detected`
- **CWE:** [CWE-939: Improper Authorization in Handler for Custom URL Scheme](https://cwe.mitre.org/data/definitions/939.html)
- **OWASP:** A

**What's wrong:** Detected a dynamic value being used with urllib. urllib supports 'file://' schemes, so a dynamic value controlled by a malicious actor may allow them to read arbitrary files. Audit uses of urllib calls to ensure user data cannot control the URLs, or consider using the 'requests' library instead.

**Code:**
```python
requires login
```

**How to fix:** Review this finding and apply the appropriate fix based on the description: Detected a dynamic value being used with urllib. urllib supports 'file://' schemes, so a dynamic value controlled by a malicious actor may allow them to read arbitrary files. Audit uses of urllib call

**Action:** Plan to fix this issue in your next sprint or release.

---

### [MEDIUM] GitHub Actions step uses a mutable tag or branch reference. Tags and branch names can be silently repointed by the action owner, enabling supply-chain attacks — as seen in the trivy-action and kics-github-action compromises. Pin the reference to a full 40-character commit SHA instead, e.g. \`uses: actions/checkout@8ade135a41bc03ea155e62e844d188df1ea18608\`.

- **File:** `.github/workflows/validate.yml:187`
- **Scanner:** opengrep
- **Rule:** `yaml.github-actions.security.github-actions-mutable-action-tag.github-actions-mutable-action-tag`
- **CWE:** [CWE-1357: Reliance on Insufficiently Trustworthy Component](https://cwe.mitre.org/data/definitions/1357.html)
- **OWASP:** A08:2021 - Software and Data Integrity Failures

**What's wrong:** GitHub Actions step uses a mutable tag or branch reference. Tags and branch names can be silently repointed by the action owner, enabling supply-chain attacks — as seen in the trivy-action and kics-github-action compromises. Pin the reference to a full 40-character commit SHA instead, e.g. `uses: actions/checkout@8ade135a41bc03ea155e62e844d188df1ea18608`.

**Code:**
```yaml
requires login
```

**How to fix:** Review this finding and apply the appropriate fix based on the description: GitHub Actions step uses a mutable tag or branch reference. Tags and branch names can be silently repointed by the action owner, enabling supply-chain attacks — as seen in the trivy-action and kics-gi

**Action:** Plan to fix this issue in your next sprint or release.

---

### [MEDIUM] GitHub Actions step uses a mutable tag or branch reference. Tags and branch names can be silently repointed by the action owner, enabling supply-chain attacks — as seen in the trivy-action and kics-github-action compromises. Pin the reference to a full 40-character commit SHA instead, e.g. \`uses: actions/checkout@8ade135a41bc03ea155e62e844d188df1ea18608\`.

- **File:** `.github/workflows/validate.yml:178`
- **Scanner:** opengrep
- **Rule:** `yaml.github-actions.security.github-actions-mutable-action-tag.github-actions-mutable-action-tag`
- **CWE:** [CWE-1357: Reliance on Insufficiently Trustworthy Component](https://cwe.mitre.org/data/definitions/1357.html)
- **OWASP:** A08:2021 - Software and Data Integrity Failures

**What's wrong:** GitHub Actions step uses a mutable tag or branch reference. Tags and branch names can be silently repointed by the action owner, enabling supply-chain attacks — as seen in the trivy-action and kics-github-action compromises. Pin the reference to a full 40-character commit SHA instead, e.g. `uses: actions/checkout@8ade135a41bc03ea155e62e844d188df1ea18608`.

**Code:**
```yaml
requires login
```

**How to fix:** Review this finding and apply the appropriate fix based on the description: GitHub Actions step uses a mutable tag or branch reference. Tags and branch names can be silently repointed by the action owner, enabling supply-chain attacks — as seen in the trivy-action and kics-gi

**Action:** Plan to fix this issue in your next sprint or release.

---

### [MEDIUM] GitHub Actions step uses a mutable tag or branch reference. Tags and branch names can be silently repointed by the action owner, enabling supply-chain attacks — as seen in the trivy-action and kics-github-action compromises. Pin the reference to a full 40-character commit SHA instead, e.g. \`uses: actions/checkout@8ade135a41bc03ea155e62e844d188df1ea18608\`.

- **File:** `.github/workflows/validate.yml:175`
- **Scanner:** opengrep
- **Rule:** `yaml.github-actions.security.github-actions-mutable-action-tag.github-actions-mutable-action-tag`
- **CWE:** [CWE-1357: Reliance on Insufficiently Trustworthy Component](https://cwe.mitre.org/data/definitions/1357.html)
- **OWASP:** A08:2021 - Software and Data Integrity Failures

**What's wrong:** GitHub Actions step uses a mutable tag or branch reference. Tags and branch names can be silently repointed by the action owner, enabling supply-chain attacks — as seen in the trivy-action and kics-github-action compromises. Pin the reference to a full 40-character commit SHA instead, e.g. `uses: actions/checkout@8ade135a41bc03ea155e62e844d188df1ea18608`.

**Code:**
```yaml
requires login
```

**How to fix:** Review this finding and apply the appropriate fix based on the description: GitHub Actions step uses a mutable tag or branch reference. Tags and branch names can be silently repointed by the action owner, enabling supply-chain attacks — as seen in the trivy-action and kics-gi

**Action:** Plan to fix this issue in your next sprint or release.

---

### [MEDIUM] GitHub Actions step uses a mutable tag or branch reference. Tags and branch names can be silently repointed by the action owner, enabling supply-chain attacks — as seen in the trivy-action and kics-github-action compromises. Pin the reference to a full 40-character commit SHA instead, e.g. \`uses: actions/checkout@8ade135a41bc03ea155e62e844d188df1ea18608\`.

- **File:** `.github/workflows/validate.yml:153`
- **Scanner:** opengrep
- **Rule:** `yaml.github-actions.security.github-actions-mutable-action-tag.github-actions-mutable-action-tag`
- **CWE:** [CWE-1357: Reliance on Insufficiently Trustworthy Component](https://cwe.mitre.org/data/definitions/1357.html)
- **OWASP:** A08:2021 - Software and Data Integrity Failures

**What's wrong:** GitHub Actions step uses a mutable tag or branch reference. Tags and branch names can be silently repointed by the action owner, enabling supply-chain attacks — as seen in the trivy-action and kics-github-action compromises. Pin the reference to a full 40-character commit SHA instead, e.g. `uses: actions/checkout@8ade135a41bc03ea155e62e844d188df1ea18608`.

**Code:**
```yaml
requires login
```

**How to fix:** Review this finding and apply the appropriate fix based on the description: GitHub Actions step uses a mutable tag or branch reference. Tags and branch names can be silently repointed by the action owner, enabling supply-chain attacks — as seen in the trivy-action and kics-gi

**Action:** Plan to fix this issue in your next sprint or release.

---

### [MEDIUM] GitHub Actions step uses a mutable tag or branch reference. Tags and branch names can be silently repointed by the action owner, enabling supply-chain attacks — as seen in the trivy-action and kics-github-action compromises. Pin the reference to a full 40-character commit SHA instead, e.g. \`uses: actions/checkout@8ade135a41bc03ea155e62e844d188df1ea18608\`.

- **File:** `.github/workflows/validate.yml:112`
- **Scanner:** opengrep
- **Rule:** `yaml.github-actions.security.github-actions-mutable-action-tag.github-actions-mutable-action-tag`
- **CWE:** [CWE-1357: Reliance on Insufficiently Trustworthy Component](https://cwe.mitre.org/data/definitions/1357.html)
- **OWASP:** A08:2021 - Software and Data Integrity Failures

**What's wrong:** GitHub Actions step uses a mutable tag or branch reference. Tags and branch names can be silently repointed by the action owner, enabling supply-chain attacks — as seen in the trivy-action and kics-github-action compromises. Pin the reference to a full 40-character commit SHA instead, e.g. `uses: actions/checkout@8ade135a41bc03ea155e62e844d188df1ea18608`.

**Code:**
```yaml
requires login
```

**How to fix:** Review this finding and apply the appropriate fix based on the description: GitHub Actions step uses a mutable tag or branch reference. Tags and branch names can be silently repointed by the action owner, enabling supply-chain attacks — as seen in the trivy-action and kics-gi

**Action:** Plan to fix this issue in your next sprint or release.

---

### [MEDIUM] GitHub Actions step uses a mutable tag or branch reference. Tags and branch names can be silently repointed by the action owner, enabling supply-chain attacks — as seen in the trivy-action and kics-github-action compromises. Pin the reference to a full 40-character commit SHA instead, e.g. \`uses: actions/checkout@8ade135a41bc03ea155e62e844d188df1ea18608\`.

- **File:** `.github/workflows/validate.yml:111`
- **Scanner:** opengrep
- **Rule:** `yaml.github-actions.security.github-actions-mutable-action-tag.github-actions-mutable-action-tag`
- **CWE:** [CWE-1357: Reliance on Insufficiently Trustworthy Component](https://cwe.mitre.org/data/definitions/1357.html)
- **OWASP:** A08:2021 - Software and Data Integrity Failures

**What's wrong:** GitHub Actions step uses a mutable tag or branch reference. Tags and branch names can be silently repointed by the action owner, enabling supply-chain attacks — as seen in the trivy-action and kics-github-action compromises. Pin the reference to a full 40-character commit SHA instead, e.g. `uses: actions/checkout@8ade135a41bc03ea155e62e844d188df1ea18608`.

**Code:**
```yaml
requires login
```

**How to fix:** Review this finding and apply the appropriate fix based on the description: GitHub Actions step uses a mutable tag or branch reference. Tags and branch names can be silently repointed by the action owner, enabling supply-chain attacks — as seen in the trivy-action and kics-gi

**Action:** Plan to fix this issue in your next sprint or release.

---

### [MEDIUM] GitHub Actions step uses a mutable tag or branch reference. Tags and branch names can be silently repointed by the action owner, enabling supply-chain attacks — as seen in the trivy-action and kics-github-action compromises. Pin the reference to a full 40-character commit SHA instead, e.g. \`uses: actions/checkout@8ade135a41bc03ea155e62e844d188df1ea18608\`.

- **File:** `.github/workflows/validate.yml:89`
- **Scanner:** opengrep
- **Rule:** `yaml.github-actions.security.github-actions-mutable-action-tag.github-actions-mutable-action-tag`
- **CWE:** [CWE-1357: Reliance on Insufficiently Trustworthy Component](https://cwe.mitre.org/data/definitions/1357.html)
- **OWASP:** A08:2021 - Software and Data Integrity Failures

**What's wrong:** GitHub Actions step uses a mutable tag or branch reference. Tags and branch names can be silently repointed by the action owner, enabling supply-chain attacks — as seen in the trivy-action and kics-github-action compromises. Pin the reference to a full 40-character commit SHA instead, e.g. `uses: actions/checkout@8ade135a41bc03ea155e62e844d188df1ea18608`.

**Code:**
```yaml
requires login
```

**How to fix:** Review this finding and apply the appropriate fix based on the description: GitHub Actions step uses a mutable tag or branch reference. Tags and branch names can be silently repointed by the action owner, enabling supply-chain attacks — as seen in the trivy-action and kics-gi

**Action:** Plan to fix this issue in your next sprint or release.

---

### [MEDIUM] GitHub Actions step uses a mutable tag or branch reference. Tags and branch names can be silently repointed by the action owner, enabling supply-chain attacks — as seen in the trivy-action and kics-github-action compromises. Pin the reference to a full 40-character commit SHA instead, e.g. \`uses: actions/checkout@8ade135a41bc03ea155e62e844d188df1ea18608\`.

- **File:** `.github/workflows/validate.yml:71`
- **Scanner:** opengrep
- **Rule:** `yaml.github-actions.security.github-actions-mutable-action-tag.github-actions-mutable-action-tag`
- **CWE:** [CWE-1357: Reliance on Insufficiently Trustworthy Component](https://cwe.mitre.org/data/definitions/1357.html)
- **OWASP:** A08:2021 - Software and Data Integrity Failures

**What's wrong:** GitHub Actions step uses a mutable tag or branch reference. Tags and branch names can be silently repointed by the action owner, enabling supply-chain attacks — as seen in the trivy-action and kics-github-action compromises. Pin the reference to a full 40-character commit SHA instead, e.g. `uses: actions/checkout@8ade135a41bc03ea155e62e844d188df1ea18608`.

**Code:**
```yaml
requires login
```

**How to fix:** Review this finding and apply the appropriate fix based on the description: GitHub Actions step uses a mutable tag or branch reference. Tags and branch names can be silently repointed by the action owner, enabling supply-chain attacks — as seen in the trivy-action and kics-gi

**Action:** Plan to fix this issue in your next sprint or release.

---

### [MEDIUM] GitHub Actions step uses a mutable tag or branch reference. Tags and branch names can be silently repointed by the action owner, enabling supply-chain attacks — as seen in the trivy-action and kics-github-action compromises. Pin the reference to a full 40-character commit SHA instead, e.g. \`uses: actions/checkout@8ade135a41bc03ea155e62e844d188df1ea18608\`.

- **File:** `.github/workflows/validate.yml:70`
- **Scanner:** opengrep
- **Rule:** `yaml.github-actions.security.github-actions-mutable-action-tag.github-actions-mutable-action-tag`
- **CWE:** [CWE-1357: Reliance on Insufficiently Trustworthy Component](https://cwe.mitre.org/data/definitions/1357.html)
- **OWASP:** A08:2021 - Software and Data Integrity Failures

**What's wrong:** GitHub Actions step uses a mutable tag or branch reference. Tags and branch names can be silently repointed by the action owner, enabling supply-chain attacks — as seen in the trivy-action and kics-github-action compromises. Pin the reference to a full 40-character commit SHA instead, e.g. `uses: actions/checkout@8ade135a41bc03ea155e62e844d188df1ea18608`.

**Code:**
```yaml
requires login
```

**How to fix:** Review this finding and apply the appropriate fix based on the description: GitHub Actions step uses a mutable tag or branch reference. Tags and branch names can be silently repointed by the action owner, enabling supply-chain attacks — as seen in the trivy-action and kics-gi

**Action:** Plan to fix this issue in your next sprint or release.

---

### [MEDIUM] GitHub Actions step uses a mutable tag or branch reference. Tags and branch names can be silently repointed by the action owner, enabling supply-chain attacks — as seen in the trivy-action and kics-github-action compromises. Pin the reference to a full 40-character commit SHA instead, e.g. \`uses: actions/checkout@8ade135a41bc03ea155e62e844d188df1ea18608\`.

- **File:** `.github/workflows/validate.yml:39`
- **Scanner:** opengrep
- **Rule:** `yaml.github-actions.security.github-actions-mutable-action-tag.github-actions-mutable-action-tag`
- **CWE:** [CWE-1357: Reliance on Insufficiently Trustworthy Component](https://cwe.mitre.org/data/definitions/1357.html)
- **OWASP:** A08:2021 - Software and Data Integrity Failures

**What's wrong:** GitHub Actions step uses a mutable tag or branch reference. Tags and branch names can be silently repointed by the action owner, enabling supply-chain attacks — as seen in the trivy-action and kics-github-action compromises. Pin the reference to a full 40-character commit SHA instead, e.g. `uses: actions/checkout@8ade135a41bc03ea155e62e844d188df1ea18608`.

**Code:**
```yaml
requires login
```

**How to fix:** Review this finding and apply the appropriate fix based on the description: GitHub Actions step uses a mutable tag or branch reference. Tags and branch names can be silently repointed by the action owner, enabling supply-chain attacks — as seen in the trivy-action and kics-gi

**Action:** Plan to fix this issue in your next sprint or release.

---

### [MEDIUM] GitHub Actions step uses a mutable tag or branch reference. Tags and branch names can be silently repointed by the action owner, enabling supply-chain attacks — as seen in the trivy-action and kics-github-action compromises. Pin the reference to a full 40-character commit SHA instead, e.g. \`uses: actions/checkout@8ade135a41bc03ea155e62e844d188df1ea18608\`.

- **File:** `.github/workflows/validate.yml:38`
- **Scanner:** opengrep
- **Rule:** `yaml.github-actions.security.github-actions-mutable-action-tag.github-actions-mutable-action-tag`
- **CWE:** [CWE-1357: Reliance on Insufficiently Trustworthy Component](https://cwe.mitre.org/data/definitions/1357.html)
- **OWASP:** A08:2021 - Software and Data Integrity Failures

**What's wrong:** GitHub Actions step uses a mutable tag or branch reference. Tags and branch names can be silently repointed by the action owner, enabling supply-chain attacks — as seen in the trivy-action and kics-github-action compromises. Pin the reference to a full 40-character commit SHA instead, e.g. `uses: actions/checkout@8ade135a41bc03ea155e62e844d188df1ea18608`.

**Code:**
```yaml
requires login
```

**How to fix:** Review this finding and apply the appropriate fix based on the description: GitHub Actions step uses a mutable tag or branch reference. Tags and branch names can be silently repointed by the action owner, enabling supply-chain attacks — as seen in the trivy-action and kics-gi

**Action:** Plan to fix this issue in your next sprint or release.

---

### [MEDIUM] GitHub Actions step uses a mutable tag or branch reference. Tags and branch names can be silently repointed by the action owner, enabling supply-chain attacks — as seen in the trivy-action and kics-github-action compromises. Pin the reference to a full 40-character commit SHA instead, e.g. \`uses: actions/checkout@8ade135a41bc03ea155e62e844d188df1ea18608\`.

- **File:** `.github/workflows/validate.yml:20`
- **Scanner:** opengrep
- **Rule:** `yaml.github-actions.security.github-actions-mutable-action-tag.github-actions-mutable-action-tag`
- **CWE:** [CWE-1357: Reliance on Insufficiently Trustworthy Component](https://cwe.mitre.org/data/definitions/1357.html)
- **OWASP:** A08:2021 - Software and Data Integrity Failures

**What's wrong:** GitHub Actions step uses a mutable tag or branch reference. Tags and branch names can be silently repointed by the action owner, enabling supply-chain attacks — as seen in the trivy-action and kics-github-action compromises. Pin the reference to a full 40-character commit SHA instead, e.g. `uses: actions/checkout@8ade135a41bc03ea155e62e844d188df1ea18608`.

**Code:**
```yaml
requires login
```

**How to fix:** Review this finding and apply the appropriate fix based on the description: GitHub Actions step uses a mutable tag or branch reference. Tags and branch names can be silently repointed by the action owner, enabling supply-chain attacks — as seen in the trivy-action and kics-gi

**Action:** Plan to fix this issue in your next sprint or release.

---

## Low Findings (4)

- **SBOM-LICENSE-UNKNOWN**: Unknown License: gitleaks/gitleaks-action@v2 (`/.github/workflows/validate.yml`)
- **SBOM-LICENSE-UNKNOWN**: Unknown License: actions/setup-python@v5 (`/.github/workflows/validate.yml`)
- **SBOM-LICENSE-UNKNOWN**: Unknown License: actions/checkout@v4 (`/.github/workflows/validate.yml`)
- **LICENSE-Apache-2.0**: License Compliance: Apache-2.0 in  (`LICENSE`)

## Skipped Scanners (1)

Scanners that did not run on this scan, with the reason why and how to enable them.

| Scanner | Reason | How to enable |
|---------|--------|---------------|
| `package-validator` | unknown | _(no hint)_ |

## Recommendations

1. Update 1 vulnerable dependency/dependencies -- run `npm audit fix` or equivalent

---
*Generated by Code Hardener v0.1.0 | 2026-07-24T21:01:14.006Z*