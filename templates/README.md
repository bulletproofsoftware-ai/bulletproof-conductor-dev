# Templates

Project-included templates that satisfy auditor first-pass review and operator scaffolding needs.

## Contents

| File | Purpose |
|------|---------|
| `COMPLIANCE-OVERVIEW.md` | 27-section auditor-grade compliance summary template covering SOC 2, ISO 27001, ISO 42001, NIST SSDF, NIST 800-53, NIST AI RMF, NIST CSF 2.0, COBIT 2019, OWASP Top 10 2025, CIS Controls v8, PCI-DSS, HIPAA, GDPR, CCPA/CPRA, EU AI Act, SLSA 1-4, EO 14028, FedRAMP |
| `scaffold-compliance.sh` | One-shot scaffolder: copies the template into a target project, replaces obvious placeholders with detected values, prints the manual-fill checklist |

## How to use the compliance template

### Option 1: Manual

```bash
cp /path/to/conductor-plugin/templates/COMPLIANCE-OVERVIEW.md \
   /path/to/your-project/docs/COMPLIANCE-OVERVIEW.md
```

Then walk top-to-bottom, replacing every `{{ FIELDNAME }}` with the project's actual value. Sections are marked **must-be-completed** vs **N/A-permitted**.

Estimated effort: 20–40 hours for a new project; 4–8 hours per quarterly review for a stable one.

### Option 2: Scaffolded

```bash
/path/to/conductor-plugin/templates/scaffold-compliance.sh /path/to/your-project
```

The script:
- Copies `COMPLIANCE-OVERVIEW.md` to `docs/COMPLIANCE-OVERVIEW.md` in the target project
- Pre-fills `{{ PROJECT_NAME }}` from the directory name (or `package.json`/`pyproject.toml` if present)
- Pre-fills `{{ YYYY-MM-DD }}` with today's date
- Pre-fills `{{ SEMVER }}` from `git describe` if available
- Adds a `compliance-evidence/` directory for evidence artifacts
- Prints a checklist of fields the operator must still fill

The scaffolder does NOT touch any field requiring human judgment (owners, frameworks-in-scope, risk acceptance).

## When to update the template itself

- After a material framework revision (e.g., new ISO 27001 release, new SOC 2 TSC)
- After a new compliance regime is adopted at the org level (e.g., adding ISO 42001 for AI workloads)
- After a major audit reveals a structural gap

## Audit-trail considerations

The template is designed to coexist with conductor-plugin's own audit mechanisms:
- `conductor-state.json` (workflow state, NHI registry, gate verdicts, Gemini validations)
- `BRD-tracker.json` (requirement → spec → implementation → test → complete traceability)
- External `audit_sink` syslog destination

These are **primary evidence**; the COMPLIANCE-OVERVIEW.md is a **summary** that points to them.
