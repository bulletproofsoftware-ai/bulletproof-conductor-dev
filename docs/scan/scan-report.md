# Security Scan Report — bulletproof-conductor-dev

Independent security scan performed by [Code Hardener](https://bulletproofsoftware.ai/code/) using the **standard** profile (12 code-appropriate scanners). This report accompanies the signed attestation, SARIF, and rich portal PDF in this directory.

## Result

| Metric | Value |
|--------|-------|
| Scan ID | `b0348c67-3b81-4815-8ff3-ec7aea07ebe2` |
| Branch | `main` |
| Profile | `standard` |
| Score | **922 / 1000** (quality: excellent) |
| Files analyzed | 83 |
| Tools executed | 12 |
| **Critical** | **0** |
| **High** | **0** |
| Medium | 14 |
| Low | 4 |
| Info | 12 |
| Secrets (gitleaks) | **PASS** — 0 leaks |

**0 critical / 0 high findings.** No code changes were required to reach a clean critical/high posture. The repository is a Claude Code plugin — markdown agent definitions, bash hooks, dependency-free JavaScript workflow scripts, and standard-library-only Python helpers — with **no third-party runtime dependencies** (see [SBOM.md](../SBOM.md)), which keeps the supply-chain attack surface minimal.

## Scanners run (standard profile)

`trivy`, `gitleaks`, `opengrep`, `checkov`, `grype`, `syft`, `oxlint`, `ruff`, `bandit`, `dockle`, `hadolint`, plus SBOM license analysis. Secret scanning (gitleaks) and IaC scanning (checkov) both passed with zero findings; `grype` reported zero vulnerable components.

## Fixes applied

None required. There were **no critical or high findings** to remediate. The scan was run against the published tree as-is.

## What remains (low-risk, not remediated)

Per the org scan policy, medium/low findings that are advisory or cosmetic are documented honestly rather than force-fixed:

| Severity | Count | Rule | Assessment |
|----------|-------|------|------------|
| Medium | 12 | `github-actions-mutable-action-tag` (opengrep) | The CI workflow (`.github/workflows/validate.yml`) pins GitHub Actions to major-version tags (`actions/checkout@v4`, `actions/setup-python@v5`, `gitleaks/gitleaks-action@v2`) rather than commit SHAs. The workflow already declares `permissions: contents: read` and injects no `github.event.*` data into any `run:` block. Low practical risk for a validation-only workflow; SHA-pinning is a candidate hardening for a future release. |
| Medium | 1 | `dynamic-urllib-use-detected` (opengrep) | `hooks/scripts/lib/audit_emitter.py` builds an HTTP/syslog audit-sink URL from operator-supplied `conductor-state.json` config. The URL is operator-controlled configuration, not untrusted user input. |
| Medium | 1 | `OXLINT-UNKNOWN` | An unnecessary escape character in a JavaScript workflow script — a lint style nit with no security impact. |
| Low | 3 | `SBOM-LICENSE-UNKNOWN` | The SBOM tool could not resolve SPDX licenses for the three pinned GitHub Actions (`gitleaks/gitleaks-action@v2`, `actions/setup-python@v5`, `actions/checkout@v4`). These are CI-only, not shipped runtime dependencies. |
| Low | 1 | `LICENSE-Apache-2.0` | Informational — the scanner detected this repository's own Apache-2.0 `LICENSE` file. Expected and required artifact, not a violation. |

The 12 informational findings are non-actionable notices.

## Signed artifacts in this directory

- **[bulletproof-conductor-dev-scan-report.pdf](bulletproof-conductor-dev-scan-report.pdf)** — rich portal report (13 pages): attestation certificate + score gauge on page 1, full scanner breakdown and findings on the following pages.
- **[attestation.json](attestation.json)** — in-toto attestation, Ed25519-signed (`ed25519-local`), binds the scan to the subject digest.
- **[scan-report.sarif.json](scan-report.sarif.json)** — SARIF 2.1.0 output (6 runs), scanner paths normalized.
- **[scan-report-full.md](scan-report-full.md)** — full machine-generated findings report.

---

Apache-2.0 © 2026 bulletproofsoftware-ai. See [LICENSE](../../LICENSE) and [NOTICE](../../NOTICE).
