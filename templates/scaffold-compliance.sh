#!/usr/bin/env bash
# scaffold-compliance.sh — copy COMPLIANCE-OVERVIEW.md into a project with auto-detected fields pre-filled
#
# Usage: ./scaffold-compliance.sh <target-project-dir>
#
# What it does (read-only on conductor-plugin; writes only inside target project):
#   1. Copies templates/COMPLIANCE-OVERVIEW.md to <target>/docs/COMPLIANCE-OVERVIEW.md
#   2. Pre-fills auto-detectable fields (project name, date, semver if git tagged)
#   3. Creates <target>/compliance-evidence/ directory for artifact storage
#   4. Prints the manual-fill checklist
#
# What it does NOT do:
#   - Fill any field requiring human judgment (owners, frameworks-in-scope, risk acceptance)
#   - Overwrite an existing COMPLIANCE-OVERVIEW.md (refuses + tells the user)

set -euo pipefail

# Parse args: --conductor pre-fills from conductor-state.json + BRD-tracker.json
CONDUCTOR_MODE=0
TARGET=""
RUN_SYNC_HOOK=1
for arg in "$@"; do
    case "$arg" in
        --conductor) CONDUCTOR_MODE=1 ;;
        --no-sync) RUN_SYNC_HOOK=0 ;;
        --help|-h)
            cat <<USAGE
Usage: $0 [--conductor] [--no-sync] <target-project-dir>

Options:
  --conductor          Pre-fill from conductor-state.json + BRD-tracker.json
                       (adds Appendix A with audit-trail snapshot)
  --no-sync            Do not run \$CONDUCTOR_DOC_SYNC_HOOK after generation
  --help, -h           This message

Without --conductor, only basic auto-detected fields (name, date, semver) are filled.
USAGE
            exit 0
            ;;
        --*) echo "unknown flag: $arg" >&2; exit 2 ;;
        *) TARGET="$arg" ;;
    esac
done

if [ -z "$TARGET" ]; then
    echo "usage: $0 [--conductor] [--no-sync] <target-project-dir>" >&2
    exit 2
fi

if [ ! -d "$TARGET" ]; then
    echo "error: $TARGET is not a directory" >&2
    exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE="$SCRIPT_DIR/COMPLIANCE-OVERVIEW.md"

if [ ! -f "$TEMPLATE" ]; then
    echo "error: template not found at $TEMPLATE" >&2
    exit 2
fi

DEST_DIR="$TARGET/docs"
DEST="$DEST_DIR/COMPLIANCE-OVERVIEW.md"
mkdir -p "$DEST_DIR"

if [ -f "$DEST" ]; then
    echo "error: $DEST already exists — refusing to overwrite" >&2
    echo "       (move or back up the existing file if you want to start fresh)" >&2
    exit 3
fi

# Auto-detect fields
PROJECT_NAME="$(basename "$(cd "$TARGET" && pwd)")"
TODAY="$(date -u +%Y-%m-%d)"
SHORT_CODE="$(echo "$PROJECT_NAME" | tr '[:lower:]' '[:upper:]' | tr -cd 'A-Z0-9' | head -c 6)"
[ -z "$SHORT_CODE" ] && SHORT_CODE="PROJ"
DATE_COMPACT="$(date -u +%Y%m%d)"

# Try to detect semver
SEMVER="0.0.0"
if [ -f "$TARGET/package.json" ]; then
    DETECTED_VER="$(grep -oE '"version":\s*"[^"]+"' "$TARGET/package.json" | head -1 | sed 's/.*"\([^"]*\)"$/\1/')"
    [ -n "$DETECTED_VER" ] && SEMVER="$DETECTED_VER"
elif [ -f "$TARGET/pyproject.toml" ]; then
    DETECTED_VER="$(grep -E '^version' "$TARGET/pyproject.toml" | head -1 | sed -E 's/version\s*=\s*"([^"]+)"/\1/' | tr -d '"')"
    [ -n "$DETECTED_VER" ] && SEMVER="$DETECTED_VER"
elif command -v git >/dev/null 2>&1; then
    DETECTED_VER="$(cd "$TARGET" && git describe --tags --abbrev=0 2>/dev/null || echo "")"
    [ -n "$DETECTED_VER" ] && SEMVER="${DETECTED_VER#v}"
fi

# Copy template and replace auto-fillable placeholders
if [ "$CONDUCTOR_MODE" -eq 1 ] && [ -f "$TARGET/conductor-state.json" ]; then
    PREFILL="$SCRIPT_DIR/conductor-prefill.py"
    if [ ! -f "$PREFILL" ]; then
        echo "error: --conductor mode requires conductor-prefill.py at $PREFILL" >&2
        exit 2
    fi
    python3 "$PREFILL" "$TARGET" > "$DEST"
    echo "  generated with conductor pre-fill (Appendix A added)"
else
    sed \
        -e "s|{{ PROJECT_NAME }}|${PROJECT_NAME}|g" \
        -e "s|{{ PROJECT_SHORT_CODE }}|${SHORT_CODE}|g" \
        -e "s|{{ SEMVER }}|${SEMVER}|g" \
        -e "s|{{ YYYY-MM-DD }}|${TODAY}|g" \
        -e "s|{{ YYYYMMDD }}|${DATE_COMPACT}|g" \
        "$TEMPLATE" > "$DEST"
    echo "  generated with basic auto-fill (re-run with --conductor for full pre-fill)"
fi

# Create evidence directory
EVIDENCE_DIR="$TARGET/compliance-evidence"
mkdir -p "$EVIDENCE_DIR"
cat > "$EVIDENCE_DIR/README.md" <<'EVIDENCE_README'
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
EVIDENCE_README

echo ""
echo "OK — scaffold complete."
echo ""
echo "Created:"
echo "  $DEST"
echo "  $EVIDENCE_DIR/ (with README)"
echo ""
echo "Auto-filled values:"
echo "  PROJECT_NAME       = $PROJECT_NAME"
echo "  PROJECT_SHORT_CODE = $SHORT_CODE"
echo "  SEMVER             = $SEMVER"
echo "  Document date      = $TODAY"
echo ""
echo "Manual-fill checklist (high priority):"
echo "  □ §1  Executive Summary — must be substantive"
echo "  □ §2  Scope — in/out of scope, environments, data categories"
echo "  □ §3  Compliance frameworks — mark Required/Voluntary/N/A for each"
echo "  □ §4  Roles + named individuals (RACI)"
echo "  □ §5  Architecture diagram + component inventory"
echo "  □ §6  Data classification + inventory + RoPA"
echo "  □ §7  IAM details + identity lifecycle SLAs"
echo "  □ §8  Cryptographic Bill of Materials + KMS + PQC plan"
echo "  □ §13 RTO/RPO + last DR test date"
echo "  □ §14 IR plan reference + severity classifications"
echo "  □ §15 Vendor inventory + DPAs/BAAs"
echo "  □ §17 AI risk classification (if AI in scope)"
echo "  □ §18 Latest pentest date + attestation letter"
echo "  □ §20 Top 5 residual risks + named acceptance"
echo "  □ §23 Framework-specific control matrices"
echo "  □ §24 Evidence package index"
echo "  □ §25 Approval signatures"
echo ""
echo "Estimated effort: 20-40 hours for first issue; 4-8 hours per quarterly review."

# Optional post-generation sync. Set CONDUCTOR_DOC_SYNC_HOOK to an executable
# that receives the generated document path; leave it unset to skip. Operators
# wire this to whatever their docs live in (a vault, a wiki, a bucket).
if [ "$RUN_SYNC_HOOK" -eq 1 ] && [ -n "${CONDUCTOR_DOC_SYNC_HOOK:-}" ]; then
    if [ -x "$CONDUCTOR_DOC_SYNC_HOOK" ]; then
        echo ""
        echo "=== Running doc-sync hook ==="
        "$CONDUCTOR_DOC_SYNC_HOOK" "$DEST" "$PROJECT_NAME" 2>&1 | tail -5 || \
            echo "(doc-sync hook failed; the document was still generated)"
    else
        echo ""
        echo "(doc-sync hook set but not executable: $CONDUCTOR_DOC_SYNC_HOOK — skipping)"
    fi
fi
