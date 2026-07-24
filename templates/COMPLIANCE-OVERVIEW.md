# Compliance Overview Summary

> **TEMPLATE INSTRUCTIONS** — replace every `{{ FIELDNAME }}` with the project's actual value. Where evidence is referenced, supply a path or URL. Sections marked **N/A-permitted** may be marked Not Applicable with one-line justification. Sections marked **must-be-completed** require a substantive answer for any auditor first pass to succeed. Last template revision: 2026-04-17.

---

## 0. Document Control

| Field | Value |
|-------|-------|
| Document Title | Compliance Overview Summary — {{ PROJECT_NAME }} |
| Document ID | COS-{{ PROJECT_SHORT_CODE }}-{{ YYYYMMDD }} |
| Project Name | {{ PROJECT_NAME }} |
| Project Version | {{ SEMVER }} |
| Document Version | 1.0 |
| Date Issued | {{ YYYY-MM-DD }} |
| Document Owner | {{ NAME, ROLE }} |
| Document Classification | {{ Public / Internal / Confidential / Restricted }} |
| Review Cadence | Quarterly minimum, or upon material change |
| Next Scheduled Review | {{ YYYY-MM-DD }} |
| Status | {{ Draft / Under Review / Approved / Superseded }} |

**Distribution List:** {{ comma-separated list of named recipients }}

---

## 1. Executive Summary (must-be-completed)

A two-to-three paragraph plain-English description of:
- What the system does and who uses it
- Why it requires compliance scrutiny (regulated data, regulated industry, public trust, etc.)
- The headline assertion: which frameworks the project claims compliance with, and the date of last independent assessment

Example: *"{{ PROJECT_NAME }} is a {{ DESCRIPTION }} serving {{ USER_POPULATION }}. It processes {{ DATA_CATEGORIES }} for {{ PURPOSES }}, requiring conformance with {{ FRAMEWORK_LIST }}. As of {{ DATE }}, all {{ NUMBER }} applicable controls are implemented and evidenced in this document and the linked artifacts."*

---

## 2. Scope (must-be-completed)

### 2.1 In Scope

| Item | Description |
|------|-------------|
| Applications / Services | {{ list of services included }} |
| Environments | {{ Production / Staging / Development — which are in scope }} |
| Data categories | {{ PII / PHI / PCI / Financial / Internal / Public }} |
| Geographic scope | {{ jurisdictions, data residency }} |
| Time period covered | {{ from YYYY-MM-DD to YYYY-MM-DD }} |
| Infrastructure layers | {{ application / platform / infrastructure }} |
| Personnel in scope | {{ roles with access to in-scope systems }} |

### 2.2 Out of Scope (with justification)

| Item | Reason for exclusion |
|------|----------------------|
| {{ component }} | {{ justification, e.g., "isolated dev environment, no production data" }} |

### 2.3 System Boundaries

A description of trust boundaries between in-scope and out-of-scope systems. Reference the architecture diagram (Section 5).

---

## 3. Applicable Compliance Frameworks (must-be-completed)

Mark each framework as `Required`, `Voluntary adoption`, `Reference only`, or `Not applicable` with one-line justification. For Required and Voluntary, link to the control mapping in Section 23.

| Framework | Status | Driver | Last Assessment | Mapping Reference |
|-----------|--------|--------|------------------|-------------------|
| **SOC 2 Type II** (Trust Services Criteria 2017, 2022 revisions) | {{ Required / Voluntary / N/A }} | {{ customer requirement / sales / contract }} | {{ YYYY-MM-DD or N/A }} | §23.1 |
| **ISO/IEC 27001:2022** (Annex A controls) | {{ ... }} | {{ ... }} | {{ ... }} | §23.2 |
| **ISO/IEC 42001:2023** (AI Management System) | {{ ... }} | {{ ... }} | {{ ... }} | §23.3 |
| **NIST SSDF SP 800-218 v1.1** (Secure Software Development Framework) | {{ ... }} | {{ EO 14028 / federal customer }} | {{ ... }} | §23.4 |
| **NIST SP 800-53 Rev 5** (control catalog) | {{ ... }} | {{ federal contract / FedRAMP }} | {{ ... }} | §23.5 |
| **NIST AI RMF 1.0** | {{ ... }} | {{ AI system in scope }} | {{ ... }} | §23.6 |
| **NIST Cybersecurity Framework 2.0** | {{ ... }} | {{ baseline alignment }} | {{ ... }} | §23.7 |
| **COBIT 2019** (governance + management objectives) | {{ ... }} | {{ board-level IT governance }} | {{ ... }} | §23.8 |
| **OWASP Top 10 2025** (Web, API, LLM) | {{ Required }} | {{ web/API/AI surface }} | {{ ... }} | §23.9 |
| **CIS Controls v8** | {{ ... }} | {{ baseline hardening }} | {{ ... }} | §23.10 |
| **CIS Benchmarks** (OS, Container, Kubernetes) | {{ ... }} | {{ infrastructure hardening }} | {{ ... }} | §23.11 |
| **PCI-DSS v4.0** | {{ Required if PAN data, else N/A }} | {{ card data processing }} | {{ ... }} | §23.12 |
| **HIPAA Security Rule** | {{ Required if PHI, else N/A }} | {{ healthcare PHI }} | {{ ... }} | §23.13 |
| **GDPR** (EU 2016/679) | {{ Required if EU subjects, else N/A }} | {{ EU data subjects }} | {{ ... }} | §23.14 |
| **CCPA / CPRA** | {{ ... }} | {{ California consumers }} | {{ ... }} | §23.15 |
| **EU AI Act** (2024/1689) | {{ Required if AI system in EU scope }} | {{ AI risk classification }} | {{ ... }} | §23.16 |
| **SLSA Levels 1-4** (supply chain integrity) | {{ Target level: __ }} | {{ release artifact integrity }} | {{ ... }} | §23.17 |
| **Executive Order 14028** | {{ Required if federal customer }} | {{ federal software supplier }} | {{ ... }} | §23.18 |
| **FedRAMP** | {{ Required if federal cloud }} | {{ federal cloud workload }} | {{ Moderate / High }} | §23.19 |
| Industry-specific (DOI insurance, FINRA, etc.) | {{ ... }} | {{ ... }} | {{ ... }} | §23.20 |

---

## 4. Roles, Responsibilities, and Accountability (must-be-completed)

RACI for compliance-relevant functions. Cite named individuals (not role titles alone) for at least the first column.

| Function | Responsible | Accountable | Consulted | Informed |
|----------|-------------|-------------|-----------|----------|
| Compliance officer | {{ NAME }} | {{ NAME }} | Legal, Engineering | Board |
| Information security (CISO) | {{ NAME }} | {{ NAME }} | Engineering, Legal | Board |
| Data protection officer (DPO) | {{ NAME, if GDPR }} | {{ NAME }} | Privacy, Legal | Board |
| Privacy program owner | {{ NAME }} | {{ NAME }} | Legal | Customer Success |
| Engineering lead | {{ NAME }} | {{ NAME }} | Security, Compliance | PM |
| Product owner | {{ NAME }} | {{ NAME }} | Engineering, Compliance | Sales |
| Incident commander (on-call) | {{ NAME and rotation }} | CISO | Engineering, Legal | Comms |
| AI risk owner (if AI in scope) | {{ NAME }} | {{ NAME }} | Privacy, Security | Board |

**Approving authority for risk acceptance:** {{ NAME, ROLE — typically CISO or CIO }}

---

## 5. System Architecture (must-be-completed)

### 5.1 High-Level Architecture

Insert or link an architecture diagram showing:
- All in-scope components and their interactions
- Trust boundaries (where data crosses zones)
- Authentication checkpoints
- Data stores (with classification labels)
- Third-party services and the data they receive

> Diagram path: `{{ docs/ARCHITECTURE.md }}` or `{{ asset URL }}`

### 5.2 Component Inventory

| Component | Type | Owner | Classification | Trust Zone |
|-----------|------|-------|----------------|------------|
| {{ Web frontend }} | {{ React SPA }} | {{ team }} | {{ Public }} | {{ DMZ }} |
| {{ API gateway }} | {{ Kong / nginx }} | {{ team }} | {{ Internal }} | {{ Application }} |
| {{ Application service }} | {{ Node/Python }} | {{ team }} | {{ Confidential }} | {{ Application }} |
| {{ Primary database }} | {{ PostgreSQL 16 }} | {{ team }} | {{ Restricted }} | {{ Data }} |
| {{ Cache }} | {{ Redis }} | {{ team }} | {{ Confidential }} | {{ Data }} |
| {{ Object storage }} | {{ S3 / GCS }} | {{ team }} | {{ varies }} | {{ Data }} |
| {{ Vector store (if AI) }} | {{ Qdrant }} | {{ team }} | {{ Internal }} | {{ Data }} |

### 5.3 Third-Party Services

Listed in §17 with details. Diagram should annotate which third parties receive what data.

### 5.4 Data Flows

Brief narrative of the principal data flows. Reference any DFD documents in linked evidence. Identify each flow's: source → destination, classification, encryption in transit, authentication mechanism.

---

## 6. Data Classification & Inventory (must-be-completed)

### 6.1 Data Classification Scheme

| Class | Examples | Encryption at Rest | Encryption in Transit | Retention |
|-------|----------|---------------------|------------------------|-----------|
| Restricted | {{ PHI, PAN, government IDs }} | AES-256-GCM | TLS 1.3 | {{ regulatory minimum, e.g., 7 yrs }} |
| Confidential | {{ PII, financial, contracts }} | AES-256-GCM | TLS 1.3 | {{ business need }} |
| Internal | {{ employee data, internal docs }} | AES-256 | TLS 1.2+ | {{ business need }} |
| Public | {{ marketing, published API specs }} | optional | TLS 1.2+ | indefinite |

### 6.2 Data Inventory (Records of Processing if GDPR)

| Data Type | Class | Storage Location | Lawful Basis (GDPR) | Retention | Access Roles |
|-----------|-------|------------------|---------------------|-----------|--------------|
| {{ User account email + password hash }} | Confidential | {{ users.db.PostgreSQL }} | {{ contract }} | {{ account life + 30d }} | {{ engineering, support }} |
| {{ Payment tokens }} | Restricted | {{ Stripe — never stored }} | {{ contract }} | {{ never (vault-only) }} | {{ none directly }} |

### 6.3 Cross-border Data Transfers

| From | To | Mechanism | Safeguard | Documented in |
|------|-----|-----------|-----------|---------------|
| {{ EU }} | {{ US }} | {{ DPA + SCCs }} | {{ EU Standard Contractual Clauses 2021 }} | {{ doc reference }} |

### 6.4 Data Subject Rights (GDPR / CCPA)

| Right | Process | Owner | SLA |
|-------|---------|-------|-----|
| Access | {{ /api/v1/dsar/access }} | DPO | 30 days |
| Erasure | {{ /api/v1/dsar/delete + Qdrant cascade }} | DPO | 30 days |
| Portability | {{ JSON export }} | DPO | 30 days |
| Objection | {{ ... }} | DPO | 30 days |
| Opt-out (sale/share, CCPA) | {{ ... }} | Privacy | Promptly |

---

## 7. Identity & Access Management (must-be-completed)

### 7.1 Authentication

| Surface | Method | MFA Required | Session Lifetime | Notes |
|---------|--------|--------------|-------------------|-------|
| End-user UI | {{ OAuth 2.0 + PKCE / SAML }} | {{ Yes / Conditional / No }} | {{ 30 min idle, 12 h max }} | {{ ... }} |
| Internal admin UI | {{ SSO (Okta) }} | Yes (TOTP / WebAuthn) | {{ 8 h max, no idle keep-alive }} | {{ ... }} |
| API (machine) | {{ mTLS / OAuth client_credentials }} | N/A | {{ 1 h tokens }} | {{ rotation policy }} |
| Privileged ops (break-glass) | {{ MFA + dual approval }} | Yes (hardware key) | One-time | Audit-logged |

### 7.2 Authorization Model

- **Model in use:** {{ RBAC / ABAC / hybrid }}
- **Policy location:** {{ source-controlled at }} `{{ path }}`
- **Default posture:** Deny by default
- **Privilege review cadence:** {{ Quarterly / Semi-annual }}
- **Last privilege review:** {{ YYYY-MM-DD }}

### 7.3 Identity Lifecycle

| Event | Process | Maximum Time | Owner |
|-------|---------|--------------|-------|
| Onboarding (provision) | {{ ... }} | {{ Day 1 }} | {{ HR + IT }} |
| Role change | {{ ... }} | {{ Same day }} | {{ Manager }} |
| Termination (revocation) | {{ ... }} | {{ Within 4 hours of HR notice }} | {{ IT + HR }} |
| Service account creation | {{ approval + ticket }} | — | {{ Security }} |
| Periodic review | {{ ... }} | {{ Quarterly }} | {{ Compliance }} |

### 7.4 Non-Human Identities (NHI)

For agent/service identities:
- Inventory location: {{ conductor-state.json `agent_instances[]` }} or {{ external NHI registry }}
- Lifecycle: {{ session-scoped / long-lived }}
- Rotation cadence: {{ ... }}
- Audit trail: every spawn/terminate logged with parent NHI lineage

---

## 8. Cryptography & Key Management (must-be-completed)

### 8.1 Cryptographic Bill of Materials (C-BOM)

| Algorithm | Use | Key Size | Rotation | Quantum-Vulnerable | Migration Plan |
|-----------|-----|----------|----------|--------------------|----------------|
| {{ AES-256-GCM }} | Data at rest | 256-bit | {{ 1 year envelope }} | No | N/A |
| {{ TLS 1.3 (ChaCha20-Poly1305 / AES-256-GCM) }} | Data in transit | — | Cert-driven | No (symmetric) | N/A |
| {{ Argon2id }} | Password hashing | 64MB / 3 iter | N/A | No | N/A |
| {{ RSA-2048 }} | {{ legacy JWT signing }} | 2048-bit | {{ 1 year }} | **Yes** | {{ migrate to ML-DSA by YYYY-MM-DD }} |
| {{ Ed25519 }} | {{ commit signing, agent attestation }} | 256-bit | {{ 90 days }} | **Yes** | {{ track NIST PQC adoption }} |
| {{ ECDH P-256 }} | {{ key agreement }} | — | Per-session | **Yes** | {{ migrate to ML-KEM by YYYY-MM-DD }} |
| {{ SHA-256 }} | Integrity / fingerprinting | — | N/A | No | N/A |

### 8.2 Key Management

- **KMS in use:** {{ AWS KMS / GCP KMS / Azure Key Vault / HashiCorp Vault }}
- **Key custody:** {{ separation-of-duties model }}
- **HSM-backed:** {{ Yes / No — per key class }}
- **Key escrow / recovery:** {{ procedure reference }}
- **Cryptoperiod policy:** {{ document reference }}

### 8.3 Post-Quantum Cryptography Readiness

- **Assessment date:** {{ YYYY-MM-DD }}
- **Status:** {{ Not assessed / Not ready / Partial / Ready }}
- **Inventory of quantum-vulnerable algorithms:** see §8.1 (RSA, ECDSA, ECDH, classical DH, DSA)
- **NIST PQC migration plan:** {{ link to roadmap }} — target completion {{ YYYY-MM-DD }}
- **Approved replacements:** ML-KEM (key encapsulation), ML-DSA / SLH-DSA (signatures), per FIPS 203/204/205

### 8.4 Secrets Management

- **Vault in use:** {{ HashiCorp Vault / AWS Secrets Manager / GCP Secret Manager / Azure Key Vault }}
- **Forbidden patterns:** no secrets in code, config files, env files committed to source, logs, error responses, or tickets
- **Detection:** gitleaks + detect-secrets at pre-commit and CI; CI failure on detection
- **Rotation policy reference:** {{ docs/SECRETS-ROTATION-POLICY.md }}
- **Last leak incident:** {{ none / YYYY-MM-DD }}

---

## 9. Logging, Monitoring & Audit Trail (must-be-completed)

### 9.1 Logged Event Categories

| Category | Source | Retention | Destination | Tamper-Evident |
|----------|--------|-----------|-------------|-----------------|
| Authentication (success / failure) | App + IdP | {{ 1 year hot, 7 years cold }} | {{ SIEM }} | {{ append-only / WORM bucket }} |
| Authorization decisions (allow / deny) | App | {{ 1 year }} | SIEM | append-only |
| Privileged operations | App + KMS | {{ 7 years }} | SIEM + WORM | Yes |
| Data access (sensitive read/write) | App | {{ 2 years }} | SIEM | append-only |
| Configuration changes | IaC + secrets | {{ 7 years }} | Git + SIEM | git history |
| Network ingress/egress | Firewall / proxy | {{ 90 days hot }} | SIEM | append-only |
| Application errors / exceptions | App | {{ 90 days }} | {{ Sentry / Datadog }} | n/a |
| Agent dispatches (NHI lifecycle) | conductor-state.json | {{ permanent in git }} | git + audit_sink | git history + signed |
| Gemini validation verdicts | conductor-state.json | {{ permanent in git }} | git + audit_sink | git history + signed |
| Phase gate decisions | conductor-state.json | {{ permanent in git }} | git + audit_sink | git history + signed |

### 9.2 Audit Trail Mechanisms (conductor-managed projects)

- **State file:** `conductor-state.json` validated against schema on every write (PostToolUse hook)
- **NHI registry:** every agent spawn/terminate recorded with parent lineage
- **Handoff history:** source/target/expected/received deliverables/checkpoint IDs
- **Audit sink:** external syslog destination preserves logs outside agent write scope (`audit_sink.syslog_target`)
- **Git ratcheting:** every state transition is a recoverable commit
- **Immutability:** audit_sink target is {{ Wazuh / Splunk / etc. }} — append-only, signed transport

### 9.3 Monitoring & Alerting

- **SIEM:** {{ name + version }}
- **Alerting destinations:** {{ PagerDuty / Slack / email }}
- **Rules / detections:** {{ link to detection-as-code repo }}
- **Mean time to detection (MTTD):** {{ measured value }} ({{ target }})
- **Mean time to acknowledge (MTTA):** {{ value }} ({{ target }})
- **Mean time to remediate (MTTR):** {{ value }} ({{ target }})

### 9.4 Log Integrity

- {{ Cryptographic chaining (Merkle tree, hash chain) / WORM storage / signed batches }}
- Chain-of-custody process: {{ description }}
- Integrity verification cadence: {{ daily automated }}

---

## 10. Secure Software Development Lifecycle (must-be-completed)

### 10.1 NIST SSDF SP 800-218 Practice Mapping

| Practice | Implementation | Evidence |
|----------|----------------|----------|
| **PO.1** Define security requirements | {{ BRD security section + threat model in BRD-tracker.json }} | {{ doc path }} |
| **PO.2** Assign roles & responsibilities | §4 of this document | this doc |
| **PO.3** Implement supporting toolchain | {{ SAST/DAST/SCA tools listed in §11 }} | {{ tooling inventory }} |
| **PO.4** Train developers | §20 | training records |
| **PO.5** Define security policies | {{ link to policy repo }} | {{ ... }} |
| **PS.1** Protect source code | Branch protection, signed commits, {{ codeowners }} | {{ git config }} |
| **PS.2** Sign artifacts | Cosign + Sigstore — see §12 | {{ signing config }} |
| **PS.3** Secure build environments | {{ ephemeral CI runners, SLSA L{{ N }} }} | {{ pipeline config }} |
| **PS.4** Verify integrity | SLSA provenance verification — see §12 | {{ verify-release.sh }} |
| **PS.5** Archive releases | {{ tagged + signed in artifact registry, retention {{ N }} years }} | {{ registry policy }} |
| **PW.1** Design for security | Threat model required pre-architecture | {{ STRIDE artifact }} |
| **PW.2** Review design | CISO gate before implementation | conductor-state.json `verification_status.post_ciso` |
| **PW.3** Verify third-party components | SCA + SBOM at every build | {{ sbom path }} |
| **PW.4** Reuse secure code | {{ shared libraries from approved registry }} | {{ ... }} |
| **PW.5** Secure coding practices | Code review + linters enforced | {{ CI config }} |
| **PW.6** Secure build | Reproducible builds {{ Yes / target Yes by YYYY-MM-DD }} | {{ ... }} |
| **PW.7** Code review for security | Mandatory peer review + automated SAST | {{ PR policy }} |
| **PW.8** Test for vulnerabilities | DAST + SAST + SCA — see §11 | {{ test reports }} |
| **PW.9** Secure default config | Default-deny posture; hardening baselines | {{ baseline doc }} |
| **RV.1** Identify vulnerabilities continuously | Continuous SCA + scheduled pentest — see §19 | {{ ... }} |
| **RV.2** Assess and prioritize | CVSS-based + business context | {{ vuln management policy }} |
| **RV.3** Remediate within SLA | §11 | {{ remediation tracker }} |
| **RV.4** Root cause analysis | Post-incident reviews — see §15 | {{ post-mortem template }} |

### 10.2 Change Management

| Control | Implementation |
|---------|----------------|
| Source of truth | git (signed commits required) |
| Branch protection | main branch protected; {{ N }} approvals required; CI must pass |
| Code review | Mandatory peer review + CISO gate for security-sensitive changes |
| CI gates | shellcheck, schema validation, SAST (Semgrep), SCA (Trivy), secrets (gitleaks), tests, license scan |
| Deployment approval | {{ named approvers per environment }} |
| Production deployments | {{ release window / blue-green / canary }} |
| Emergency change process | {{ doc reference }} |
| Change history | Git log + deployment platform audit log |

### 10.3 Conductor Workflow Mandate (if applicable)

For projects governed by the conductor plugin, every change traverses:
- Tier classification → BRD extraction → architecture spec → spec alignment check → builder readback → CISO review → QA review → adversarial review → completeness validation
- Each agent dispatch is independently validated by Gemini CLI
- Phase transitions are programmatically enforced by `hooks/scripts/post-state-write.sh` (cannot be bypassed by LLM)

---

## 11. Vulnerability & Threat Management (must-be-completed)

### 11.1 Tooling Inventory

| Category | Tool | Frequency | Failure Mode |
|----------|------|-----------|--------------|
| SAST | {{ Semgrep / SonarQube / CodeQL }} | Every PR + nightly | Block on HIGH/CRITICAL |
| SCA | {{ Trivy / Snyk / Dependabot }} | Every PR + nightly | Block on HIGH/CRITICAL |
| Secrets detection | gitleaks + detect-secrets | Pre-commit + CI | Block any finding |
| Container scan | Trivy | Every image build | Block on HIGH/CRITICAL |
| IaC scan | Checkov | Every PR | Block on HIGH/CRITICAL |
| DAST | {{ OWASP ZAP / Burp }} | Pre-release + monthly | {{ Block / advisory }} |
| API security | {{ ZAP API scan / Bright }} | Pre-release | {{ ... }} |
| LLM-specific | {{ custom prompt-injection detector / OWASP LLM testing }} | Pre-release | Advisory + manual review |
| Penetration test | External vendor — see §19 | {{ Annually + after major changes }} | All HIGH/CRITICAL must be remediated or accepted |

### 11.2 Remediation SLA

| Severity | Discovery → Patch SLA | Notes |
|----------|------------------------|-------|
| Critical | {{ 24 hours }} | Includes CVSS 9.0+ and known exploited (CISA KEV) |
| High | {{ 7 days }} | CVSS 7.0–8.9 |
| Medium | {{ 30 days }} | CVSS 4.0–6.9 |
| Low | {{ 90 days }} | CVSS 0.1–3.9 |

### 11.3 Threat Model

- **Methodology:** {{ STRIDE / LINDDUN / PASTA }}
- **Last full review:** {{ YYYY-MM-DD }}
- **Next scheduled review:** {{ YYYY-MM-DD }} (annually + on major architecture change)
- **Document reference:** {{ docs/THREAT-MODEL.md }}
- **Top residual risks:** see §21

### 11.4 Vulnerability Disclosure

- **Public policy:** {{ link to SECURITY.md }}
- **Reporting channel:** {{ security@example.com / hackerone / etc. }}
- **Acknowledgement SLA:** 2 business days
- **Triage SLA:** 5 business days
- **Disclosure window:** Coordinated, default 90 days

---

## 12. Supply Chain Security (must-be-completed)

### 12.1 SLSA Compliance

- **Target SLSA Level:** {{ 1 / 2 / 3 / 4 }}
- **Build platform:** {{ GitHub Actions / GitLab CI / Jenkins }}
- **Provenance generator:** {{ slsa-github-generator / in-toto / custom }}
- **Provenance location:** `{{ attestations/ }}` per release
- **Verification recipe:** `{{ docs/verify-release.sh }}` (operator can verify with no insider knowledge)

### 12.2 Software Bill of Materials (SBOM)

- **Format:** {{ CycloneDX 1.5 / SPDX 2.3 }}
- **Generator:** {{ Syft / cdxgen / npm sbom }}
- **CISA 2025 minimum elements:** all 9 fields populated (component name, version, supplier, unique identifier, component hash, license, tool name, generation context, dependency relationships)
- **Distribution:** {{ published with each release / available on request }}
- **Refresh cadence:** every release, plus monthly continuous scan

### 12.3 Artifact Signing

- **Signing tool:** {{ cosign keyless via Sigstore + Fulcio }}
- **Signing identity:** {{ workflow OIDC token tied to release tag }}
- **Transparency log:** Rekor (public)
- **Verification:** `cosign verify-blob --certificate-identity-regexp=...`
- **Storage:** signatures published alongside artifacts (`.sig` + `.cert`)

### 12.4 Dependency Hygiene

- **Lock files committed:** {{ package-lock.json / Pipfile.lock / Cargo.lock / go.sum / pnpm-lock.yaml }}
- **Reproducible installs:** {{ pip --require-hashes / npm ci / etc. }}
- **Signature verification:** {{ npm audit signatures / go mod verify }}
- **Approved registries only:** {{ list }}
- **Typosquat / dependency-confusion checks:** {{ tool / cadence }}
- **Stale-dependency policy:** Updates prioritized by severity; major releases evaluated within {{ 30 days }}

### 12.5 Commit Signing

- **Required on:** {{ main branch / all branches }}
- **Mechanism:** {{ Sigstore gitsign / GPG / SSH }}
- **Enforcement:** CI rejects unsigned commits on protected branches
- **Identity verification:** signers tied to organization SSO

---

## 13. Business Continuity & Disaster Recovery (must-be-completed)

### 13.1 Recovery Objectives

| Service | RTO (Recovery Time Objective) | RPO (Recovery Point Objective) |
|---------|-------------------------------|--------------------------------|
| {{ Web application }} | {{ 4 hours }} | {{ 15 minutes }} |
| {{ Primary database }} | {{ 1 hour }} | {{ 5 minutes }} |
| {{ Object storage }} | {{ 8 hours }} | {{ 1 hour }} |
| {{ Audit logs }} | {{ 24 hours }} | {{ 0 (no loss tolerated) }} |

### 13.2 Backup Strategy

| Data category | Frequency | Retention | Storage Location | Encryption | Last DR Test |
|---------------|-----------|-----------|-------------------|------------|---------------|
| Database | {{ continuous WAL + nightly }} | {{ 35 days hot, 1 year cold }} | {{ cross-region S3 }} | AES-256 | {{ YYYY-MM-DD }} |
| Object storage | {{ versioning + lifecycle }} | {{ per data class }} | {{ cross-region }} | AES-256 | {{ ... }} |
| Configuration | Git (continuous) | Indefinite | GitHub + mirror | — | {{ ... }} |
| Audit logs | {{ stream }} | {{ regulatory minimum }} | {{ WORM bucket }} | AES-256 | {{ ... }} |

### 13.3 DR Test Cadence

- **Tabletop exercise:** {{ Quarterly }}
- **Partial recovery test:** {{ Semi-annual }}
- **Full failover drill:** {{ Annual }}
- **Last full drill:** {{ YYYY-MM-DD }}
- **Post-drill report:** {{ doc reference }}

---

## 14. Incident Response (must-be-completed)

### 14.1 IR Plan Reference

- **Plan document:** {{ docs/INCIDENT-RESPONSE-PLAN.md }}
- **Plan owner:** {{ NAME, ROLE }}
- **Last review:** {{ YYYY-MM-DD }}
- **Last tabletop:** {{ YYYY-MM-DD }}

### 14.2 Severity Classification

| Severity | Description | Response Time | Notification |
|----------|-------------|---------------|--------------|
| SEV1 | Production outage / data breach / safety risk | {{ 15 min }} | {{ Page on-call + leadership }} |
| SEV2 | Significant degradation / suspected breach | {{ 1 hour }} | {{ Page on-call }} |
| SEV3 | Limited impact / contained issue | {{ 4 hours }} | {{ Slack channel }} |
| SEV4 | Minor / cosmetic | {{ 1 business day }} | {{ Ticket queue }} |

### 14.3 Notification Obligations

| Trigger | Recipient | Statutory SLA | Internal SLA |
|---------|-----------|----------------|---------------|
| GDPR personal data breach | Supervisory authority | 72 hours | {{ 24 hours }} |
| GDPR personal data breach (high risk) | Affected data subjects | "Without undue delay" | {{ 48 hours }} |
| HIPAA breach (>500) | HHS + media | 60 days | {{ 30 days }} |
| HIPAA breach (<500) | HHS | Annual log | {{ within 30 days of discovery }} |
| State breach laws (US) | State AG / residents | Varies (1-90 days) | {{ tracker }} |
| Customer contractual | Customer | Per contract | Per contract |
| SOC 2 reportable event | External auditor | At assessment | Real-time log |

### 14.4 Forensic Readiness

- **Log preservation:** automatic on incident declaration
- **Forensic toolkit:** {{ ... }}
- **Outside counsel on retainer:** {{ Yes — name }} for material incidents
- **Cyber insurance:** {{ carrier, policy number, limit }}

---

## 15. Third-Party Risk Management (must-be-completed)

### 15.1 Vendor Inventory (in scope)

| Vendor | Service | Data Shared | Contract | DPA | BAA | SOC 2 Date | Review Due |
|--------|---------|-------------|----------|-----|-----|------------|-------------|
| {{ AWS }} | {{ Hosting }} | All in-scope | {{ MSA + AWS Customer Agreement }} | Yes | Yes (if HIPAA) | {{ Q4 2026 }} | {{ Annual }} |
| {{ Stripe }} | {{ Payments }} | {{ Token only }} | {{ MSA }} | N/A | N/A | {{ Public }} | {{ Annual }} |
| {{ Anthropic }} | {{ LLM API }} | {{ Prompt content }} | {{ Enterprise agreement }} | {{ DPA in place }} | N/A | {{ ... }} | {{ Annual }} |
| {{ ... }} | {{ ... }} | {{ ... }} | {{ ... }} | {{ ... }} | {{ ... }} | {{ ... }} | {{ ... }} |

### 15.2 Vendor Onboarding Checklist

- [ ] Security questionnaire completed (CAIQ or equivalent)
- [ ] SOC 2 Type II report obtained (or equivalent)
- [ ] DPA signed (if processing personal data)
- [ ] BAA signed (if processing PHI)
- [ ] Data flow documented
- [ ] Recovery procedures verified
- [ ] Approval recorded by: {{ NAME }}

### 15.3 Subprocessor Notice

- **Public list:** {{ URL — required by GDPR Art. 28 }}
- **Customer notification mechanism:** {{ email / portal — for new subprocessors }}
- **Notice period:** {{ 30 days advance notice }}

---

## 16. Privacy Program (must-be-completed if any personal data)

### 16.1 Privacy Notice & Consent

- **Public privacy policy:** {{ URL }}
- **Cookie / tracking policy:** {{ URL }}
- **Consent mechanism:** {{ banner / CMP — name }}
- **Consent records retention:** {{ duration }}
- **Withdrawal mechanism:** {{ URL / process }}

### 16.2 GDPR Compliance Specifics

- **Lawful basis for each processing:** documented in §6.2
- **Data Protection Impact Assessment (DPIA) completed:** {{ Yes / No / Not required }} — last review {{ YYYY-MM-DD }}
- **Records of Processing Activities (RoPA):** {{ document reference }} — Article 30 compliance
- **Data Protection Officer (DPO):** {{ NAME, contact, registered with: {{ authority }} }}
- **EU representative:** {{ NAME (if non-EU controller) }}

### 16.3 Children's Data (COPPA)

- **In scope?** {{ Yes / No }}
- **Age gating:** {{ description if Yes }}
- **Verifiable parental consent mechanism:** {{ ... }}

### 16.4 De-identification & Minimization

- Data collection limited to lawful purpose
- Anonymization / pseudonymization techniques: {{ list }}
- Re-identification risk assessment: {{ doc reference }}

---

## 17. AI/ML Specific Controls (must-be-completed if AI/ML in scope)

### 17.1 AI Risk Classification

- **EU AI Act risk tier:** {{ Minimal / Limited / High-Risk / Prohibited / GPAI }}
- **NIST AI RMF profile:** {{ document reference }}
- **ISO 42001 AIMS coverage:** {{ document reference }}

### 17.2 Model Inventory

| Model | Provider | Version | Use Case | Data Sent | Logging | Approved By |
|-------|----------|---------|----------|-----------|---------|-------------|
| {{ claude-opus-4 }} | Anthropic | {{ 4.7 }} | {{ orchestration }} | {{ prompts only, no PII flagged }} | {{ via audit_sink }} | {{ CISO + AI risk owner }} |
| {{ ... }} | {{ ... }} | {{ ... }} | {{ ... }} | {{ ... }} | {{ ... }} | {{ ... }} |

### 17.3 OWASP LLM Top 10 (2025) Mitigations

| Risk | Mitigation in this system | Evidence |
|------|---------------------------|----------|
| LLM01 Prompt injection | {{ system/user separation, input sanitization, output filtering }} | {{ ... }} |
| LLM02 Insecure output handling | {{ output encoded, executed output sandboxed, no raw eval }} | {{ ... }} |
| LLM03 Training data poisoning | N/A (use upstream models only) | — |
| LLM04 Model DoS | {{ rate limiting, input length caps, cost ceilings }} | {{ ... }} |
| LLM05 Supply chain | {{ provider attestation, no fine-tuned weights in repo }} | {{ ... }} |
| LLM06 Sensitive info disclosure | {{ output redaction, DLP }} | {{ ... }} |
| LLM07 Insecure plugin design | {{ tool least-privilege, NHI tracking }} | {{ ... }} |
| LLM08 Excessive agency | {{ human-in-loop for elevated actions, kill switch on prohibited behaviors }} | {{ ... }} |
| LLM09 Overreliance | {{ Gemini independent validation, critic gates }} | {{ ... }} |
| LLM10 Model theft | N/A (no proprietary model weights) | — |

### 17.4 AI Governance Controls

- **Identity manifests:** YAML manifests with SHA-256 integrity verification
- **Trust levels:** 1-5 scale with parent-ceiling enforcement
- **Constitutional contracts:** monotonically decreasing privileges in delegation
- **Drift detection:** observer-side runtime monitoring
- **Audit bus:** immutable, append-only event log
- **Human gates:** required for {{ high-tier elevated operations }}

### 17.5 AI Decision Auditability

- Every AI-influenced decision is recorded with: model used, prompt (or hash), output, validation verdict, human review (if any)
- Storage: {{ conductor-state.json / external audit DB }}
- Retention: {{ regulatory minimum }}
- Reproducibility: {{ deterministic sampling / temperature 0 for production / replay capability }}

---

## 18. Penetration Testing & Independent Validation

### 18.1 Latest External Penetration Test

- **Vendor:** {{ NAME }}
- **Date:** {{ YYYY-MM-DD }}
- **Scope:** {{ ... }}
- **Findings summary:** {{ Critical: N, High: N, Medium: N, Low: N, Info: N }}
- **Remediation status:** {{ All Critical/High closed / In progress }}
- **Attestation letter:** {{ doc path }}
- **Next test scheduled:** {{ YYYY-MM-DD }}

### 18.2 Bug Bounty Program

- **Status:** {{ Public / Private / None }}
- **Platform:** {{ HackerOne / Bugcrowd / private }}
- **Scope:** {{ ... }}

### 18.3 Independent Code Review

- **Multi-model adversarial review:** Claude + Gemini consensus, debated through {{ N }} rounds
- **Last review:** {{ YYYY-MM-DD }}
- **Outstanding disputed findings:** {{ N }} — see {{ doc reference }}

---

## 19. Training & Awareness (must-be-completed)

### 19.1 Required Training

| Audience | Curriculum | Frequency | Last Cycle Completion |
|----------|------------|-----------|------------------------|
| All employees | Security awareness | Annual + on hire | {{ N% on time }} |
| All employees | Privacy / GDPR / CCPA | Annual + on hire | {{ N% }} |
| Engineers | Secure coding (OWASP, language-specific) | Annual | {{ N% }} |
| Engineers | Threat modeling | Once + refresher every 2 yrs | {{ N% }} |
| Operators | Incident response | Annual + tabletop participation | {{ N% }} |
| AI / ML practitioners | LLM security, AI governance | Annual | {{ N% }} |
| Data handlers | Data classification, handling | Annual | {{ N% }} |

### 19.2 Phishing Simulation

- **Cadence:** {{ Quarterly }}
- **Failure rate:** {{ N% }} ({{ trend vs prior period }})
- **Remediation:** failed users complete additional training

---

## 20. Risk Assessment & Acceptance (must-be-completed)

### 20.1 Risk Register Summary

| Risk ID | Description | Likelihood | Impact | Inherent Risk | Mitigation | Residual Risk | Owner | Acceptance |
|---------|-------------|------------|--------|---------------|------------|----------------|-------|------------|
| {{ R-001 }} | {{ ... }} | {{ Low/Med/High }} | {{ Low/Med/High }} | {{ score }} | {{ ... }} | {{ score }} | {{ NAME }} | {{ NAME, date }} |

Full register: {{ docs/RISK-REGISTER.md }}

### 20.2 Top Residual Risks

List the top 5 risks after mitigation, with explicit acceptance by named risk owner. Auditors look for honest disclosure here, not zero risks.

### 20.3 Risk Acceptance Authority

| Residual Risk Level | Approval Authority |
|---------------------|--------------------|
| Low | Engineering lead |
| Medium | Department head + CISO |
| High | CISO + executive sponsor |
| Critical | CEO + Board notification |

---

## 21. Conductor / Workflow-Generated Evidence (if applicable)

For projects orchestrated by the conductor plugin, the following artifacts constitute primary audit evidence and are version-controlled with the project:

| Artifact | Path | Content |
|----------|------|---------|
| Workflow state | `conductor-state.json` | Tier classification, NHI registry, gate verdicts, Gemini validations, recovery history, cost tracking |
| Requirements traceability | `BRD-tracker.json` | Every requirement from extraction → spec → implementation → test → complete |
| Architecture decisions | `docs/architecture/` | Specifications and ADRs |
| Adversarial review | `docs/adversarial-review-{date}.md` | Multi-model consensus review with debate transcripts |
| Hardening report | `docs/hardening-report-{date}.md` | Code Hardener final score 1000 + zero open findings |
| Completeness validation | `completeness-report-{timestamp}.json` | Final gate verifying every artifact is present and functional |
| Workflow retrospective | `docs/retrospective-{date}.md` | Lessons learned, process improvement candidates |

These are not summary reports — they are the primary records generated during the work. They survive any later document tampering because they are git-history-protected and (when configured) emitted to an external syslog audit_sink.

---

## 22. Continuous Compliance Monitoring

### 22.1 Continuous Controls

| Control | Mechanism | Frequency | Alert Destination |
|---------|-----------|-----------|--------------------|
| Configuration drift | {{ AWS Config / OPA }} | Continuous | {{ SIEM }} |
| Vulnerability scan | {{ Trivy / Snyk }} | Daily | {{ Engineering channel }} |
| Secret scan | gitleaks | Pre-commit + CI + nightly | {{ Security channel }} |
| Identity drift | {{ ... }} | Daily | {{ ... }} |
| Encryption posture | {{ KMS audit }} | Weekly | {{ ... }} |
| Backup integrity | {{ restore test }} | Monthly | {{ ... }} |
| Log integrity | {{ hash chain verification }} | Daily | {{ ... }} |

### 22.2 Compliance Dashboards

- {{ Drata / Vanta / Tugboat / Custom }} — link
- Real-time control status: {{ URL }}
- Evidence collection: {{ automated where possible }}

---

## 23. Control Mapping Matrices

For each Required framework in §3, supply or link a control matrix mapping the framework's controls to this project's implementations.

### 23.1 SOC 2 Trust Services Criteria

| TSC | Criterion | Implementation | Evidence |
|-----|-----------|----------------|----------|
| CC1 | Control Environment | {{ §4 + policies }} | {{ ... }} |
| CC2 | Communication & Information | {{ §9 logging }} | {{ ... }} |
| CC3 | Risk Assessment | §20 | {{ ... }} |
| CC4 | Monitoring | §22 | {{ ... }} |
| CC5 | Control Activities | All sections | this doc |
| CC6 | Logical & Physical Access | §7 | {{ ... }} |
| CC7 | System Operations | §13, §14, §22 | {{ ... }} |
| CC8 | Change Management | §10.2 | {{ ... }} |
| CC9 | Risk Mitigation | §11, §15 | {{ ... }} |
| A1 | Availability | §13 | {{ ... }} |
| C1 | Confidentiality | §6, §8 | {{ ... }} |
| PI1 | Processing Integrity | §10, §22 | {{ ... }} |
| P1-P8 | Privacy | §16 | {{ ... }} |

### 23.2 ISO/IEC 27001:2022 Annex A (93 controls)

Provide complete mapping. Section references:
- A.5 Organizational controls (37) → §4, §15, §17, §20
- A.6 People controls (8) → §7.3, §19
- A.7 Physical controls (14) → {{ separate physical security doc }}
- A.8 Technological controls (34) → §6, §7, §8, §9, §10, §11, §12, §13, §14, §22

Full matrix: {{ docs/iso-27001-control-matrix.xlsx }}

### 23.3 ISO/IEC 42001:2023 (AI Management System)

Required if AI in scope. Maps to §17 + AI risk owner from §4. Full matrix: {{ docs/iso-42001-control-matrix.md }}

### 23.4 NIST SSDF SP 800-218

Mapped in §10.1.

### 23.5 NIST SP 800-53 Rev 5

For federal workloads. Provide control catalog mapping at the chosen baseline (Low/Moderate/High). Reference: {{ docs/nist-800-53-control-matrix.md }}

### 23.6 NIST AI RMF 1.0

Govern / Map / Measure / Manage functions. Reference: {{ docs/nist-ai-rmf-profile.md }}

### 23.7 NIST Cybersecurity Framework 2.0

| Function | Coverage |
|----------|----------|
| Govern (GV) | §3, §4, §20 |
| Identify (ID) | §5, §6, §15, §20 |
| Protect (PR) | §7, §8, §10, §16 |
| Detect (DE) | §9, §11, §22 |
| Respond (RS) | §14 |
| Recover (RC) | §13 |

### 23.8 COBIT 2019 (Governance and Management Objectives)

| Objective | Domain | Coverage in this Document |
|-----------|--------|---------------------------|
| **EDM01** Ensured Governance Framework Setting and Maintenance | EDM | §1, §3, §4, §20 |
| **EDM02** Ensured Benefits Delivery | EDM | §1 (executive summary), §22 (continuous controls) |
| **EDM03** Ensured Risk Optimization | EDM | §11, §15, §20 |
| **EDM04** Ensured Resource Optimization | EDM | §13, §22 |
| **EDM05** Ensured Stakeholder Engagement | EDM | §4, §15 (vendors) |
| **APO01** Managed I&T Management Framework | APO | §3, §10 |
| **APO02** Managed Strategy | APO | §1 + linked strategy doc |
| **APO03** Managed Enterprise Architecture | APO | §5 |
| **APO04** Managed Innovation | APO | §17 (AI / ML governance) |
| **APO05** Managed Portfolio | APO | {{ portfolio document }} |
| **APO06** Managed Budget and Costs | APO | {{ budget tracker / cost_tracking }} |
| **APO07** Managed Human Resources | APO | §4, §19 |
| **APO08** Managed Relationships | APO | §15 (vendors) |
| **APO09** Managed Service Agreements | APO | §15 (contracts), §17 (AI provider terms) |
| **APO10** Managed Vendors | APO | §15 |
| **APO11** Managed Quality | APO | §10, §11, §18 |
| **APO12** Managed Risk | APO | §11, §15, §20 |
| **APO13** Managed Security | APO | §7, §8, §9, §11, §12 |
| **APO14** Managed Data | APO | §6, §16 |
| **BAI01** Managed Programs | BAI | {{ program management doc }} |
| **BAI02** Managed Requirements Definition | BAI | §10 (BRD process) |
| **BAI03** Managed Solutions Identification and Build | BAI | §10 (SSDLC) |
| **BAI04** Managed Availability and Capacity | BAI | §13 |
| **BAI05** Managed Organizational Change | BAI | §19 (training), §10.2 (change mgmt) |
| **BAI06** Managed IT Changes | BAI | §10.2 |
| **BAI07** Managed IT Change Acceptance and Transitioning | BAI | §10.2 (deployment approval) |
| **BAI08** Managed Knowledge | BAI | §21 (conductor evidence + retrospectives) |
| **BAI09** Managed Assets | BAI | §5.2, §15.1 |
| **BAI10** Managed Configuration | BAI | §10 (IaC, config-as-code) |
| **BAI11** Managed Projects | BAI | {{ project mgmt artifacts }} |
| **DSS01** Managed Operations | DSS | §13, §22 |
| **DSS02** Managed Service Requests and Incidents | DSS | §14 |
| **DSS03** Managed Problems | DSS | §14, §11.4 |
| **DSS04** Managed Continuity | DSS | §13 |
| **DSS05** Managed Security Services | DSS | §7, §11, §12, §22 |
| **DSS06** Managed Business Process Controls | DSS | §10, §22 |
| **MEA01** Managed Performance and Conformance Monitoring | MEA | §22 (continuous compliance) |
| **MEA02** Managed System of Internal Control | MEA | §10.2, §20, §22 |
| **MEA03** Managed Compliance with External Requirements | MEA | §3, §16, this whole doc |
| **MEA04** Managed Assurance | MEA | §18, §22 |

### 23.9 OWASP Top 10 2025

Web/API/LLM versions mapped to §11.1 (tools), §17.3 (LLM), and source code review evidence.

### 23.10 CIS Controls v8

| IG (Implementation Group) | Coverage |
|----------------------------|----------|
| IG1 (Essential cyber hygiene) | Baseline implemented |
| IG2 (mid-size enterprise) | {{ targeted / partial }} |
| IG3 (mature enterprise) | {{ as required by other frameworks }} |

### 23.11–23.20

Additional matrices per framework declared Required in §3. One linked file per framework.

---

## 24. Evidence Package Index

Auditor walks this index to find primary evidence. Each entry is a path or URL plus a one-line description.

| # | Evidence | Location | Last Updated |
|---|----------|----------|---------------|
| E-001 | Architecture diagram | {{ docs/ARCHITECTURE.md }} | {{ YYYY-MM-DD }} |
| E-002 | Threat model | {{ docs/THREAT-MODEL.md }} | {{ ... }} |
| E-003 | Risk register | {{ docs/RISK-REGISTER.md }} | {{ ... }} |
| E-004 | Privacy policy | {{ URL }} | {{ ... }} |
| E-005 | Security policy | {{ docs/SECURITY-POLICY.md }} | {{ ... }} |
| E-006 | Acceptable use policy | {{ ... }} | {{ ... }} |
| E-007 | Incident response plan | {{ docs/INCIDENT-RESPONSE-PLAN.md }} | {{ ... }} |
| E-008 | Business continuity plan | {{ docs/BCP.md }} | {{ ... }} |
| E-009 | Vendor inventory + DPAs | {{ docs/vendors/ }} | {{ ... }} |
| E-010 | Latest pentest report + attestation | {{ secure share / docs/pentest/{{date}}.pdf }} | {{ ... }} |
| E-011 | SBOM (latest release) | {{ artifacts/sbom-{{ver}}.cdx.json }} | {{ release date }} |
| E-012 | SLSA provenance (latest release) | {{ attestations/{{artifact}}.intoto.jsonl }} | {{ release date }} |
| E-013 | Cosign signatures | {{ alongside artifacts }} | {{ ... }} |
| E-014 | Training completion records | {{ LMS export }} | {{ ... }} |
| E-015 | Phishing simulation results | {{ ... }} | {{ ... }} |
| E-016 | Backup test attestation | {{ docs/dr-test-{{date}}.md }} | {{ ... }} |
| E-017 | Access review records (last cycle) | {{ ... }} | {{ ... }} |
| E-018 | Conductor workflow state | `conductor-state.json` | continuous |
| E-019 | BRD-tracker (requirements traceability) | `BRD-tracker.json` | continuous |
| E-020 | Adversarial review record | {{ docs/adversarial-review-{{date}}.md }} | per release |
| E-021 | Completeness validation report | {{ completeness-report-{{ts}}.json }} | per release |
| E-022 | Audit log samples | {{ secure share }} | continuous |
| E-023 | RoPA (GDPR Art. 30) | {{ docs/ropa.md }} | quarterly |
| E-024 | DPIA (if conducted) | {{ docs/dpia-{{date}}.md }} | as needed |
| E-025 | Secrets rotation policy + log | {{ docs/SECRETS-ROTATION-POLICY.md + rotation-log.csv }} | continuous |

---

## 25. Approvals (must-be-completed)

This document is **not effective** until all required signatures are obtained. Re-approval required after material changes (architecture, scope, framework, or annually at minimum).

| Role | Name | Signature | Date | Notes |
|------|------|-----------|------|-------|
| CISO / Head of Security | {{ NAME }} | {{ }} | {{ YYYY-MM-DD }} | |
| Compliance Officer | {{ NAME }} | {{ }} | {{ ... }} | |
| Data Protection Officer (if GDPR) | {{ NAME }} | {{ }} | {{ ... }} | |
| Engineering Lead | {{ NAME }} | {{ }} | {{ ... }} | |
| Product Owner | {{ NAME }} | {{ }} | {{ ... }} | |
| Legal | {{ NAME }} | {{ }} | {{ ... }} | |
| AI Risk Owner (if AI in scope) | {{ NAME }} | {{ }} | {{ ... }} | |
| Executive Sponsor | {{ NAME }} | {{ }} | {{ ... }} | |

---

## 26. Revision History

| Version | Date | Author | Change Summary | Approved By |
|---------|------|--------|------------------|-------------|
| 1.0 | {{ YYYY-MM-DD }} | {{ NAME }} | Initial issue | per §25 |
| {{ ... }} | {{ ... }} | {{ ... }} | {{ ... }} | {{ ... }} |

---

## 27. Glossary

| Term | Definition |
|------|------------|
| BRD | Business Requirements Document |
| C-BOM | Cryptographic Bill of Materials |
| CISO | Chief Information Security Officer |
| CMP | Consent Management Platform |
| DLP | Data Loss Prevention |
| DPA | Data Processing Agreement |
| DPIA | Data Protection Impact Assessment |
| DPO | Data Protection Officer |
| DR | Disaster Recovery |
| HSM | Hardware Security Module |
| IdP | Identity Provider |
| IR | Incident Response |
| KMS | Key Management Service / System |
| KEV | Known Exploited Vulnerabilities (CISA) |
| MFA | Multi-Factor Authentication |
| MTTA | Mean Time To Acknowledge |
| MTTD | Mean Time To Detect |
| MTTR | Mean Time To Remediate (or Recover) |
| NHI | Non-Human Identity |
| OPA | Open Policy Agent |
| PAN | Primary Account Number (PCI) |
| PHI | Protected Health Information |
| PII | Personally Identifiable Information |
| PQC | Post-Quantum Cryptography |
| RoPA | Records of Processing Activities (GDPR Art. 30) |
| RPO | Recovery Point Objective |
| RTO | Recovery Time Objective |
| SBOM | Software Bill of Materials |
| SCA | Software Composition Analysis |
| SAST | Static Application Security Testing |
| DAST | Dynamic Application Security Testing |
| SCC | Standard Contractual Clauses (EU) |
| SLSA | Supply-chain Levels for Software Artifacts |
| SSDF | Secure Software Development Framework (NIST) |
| SSDLC | Secure Software Development Life Cycle |
| TSC | Trust Services Criteria (SOC 2) |
| WORM | Write Once Read Many |

---

**END OF DOCUMENT** — Total length: 27 sections. Estimated completion effort: 20-40 hours for a new project; 4-8 hours per quarterly review for a stable project.
