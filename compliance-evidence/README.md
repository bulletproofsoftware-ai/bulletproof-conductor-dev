# Compliance Evidence

This directory holds primary evidence artifacts referenced by `docs/COMPLIANCE-OVERVIEW.md`.

## Structure (suggested)

```
compliance-evidence/
├── README.md                     # this file
├── architecture/                 # diagrams, ADRs, threat models
├── policies/                     # security, privacy, acceptable use
├── pentest/                      # external pentest reports + attestation letters
├── sbom/                         # SBOMs per release
├── attestations/                 # SLSA provenance, cosign signatures
├── access-reviews/               # quarterly access review records
├── dr-tests/                     # disaster recovery test reports
├── training/                     # training completion records (anonymized)
├── vendor/                       # vendor SOC 2 reports, DPAs, BAAs
├── audit-logs/                   # log samples + integrity verification
└── conductor/                    # snapshots of conductor-state.json + BRD-tracker.json at major checkpoints
```

## Retention

Items in this directory should follow the retention policy declared in `docs/COMPLIANCE-OVERVIEW.md` §6 + §9. Most artifacts retained ≥7 years for SOC 2 / financial workloads.

## Sensitivity

This directory may contain sensitive material. Apply repo-level access controls or move to a dedicated secure share. Do NOT commit anything containing PII, credentials, or customer data.
