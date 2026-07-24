"""REQ-CDV-006 — kernel workflow-state schema accepts the live v1.0
conductor-state.json shape.

This test exercises the schema-level backward-compatibility surface that the
kernel v0.1.0 promises to conductor-dev v1.1.0: the legacy v1.0/1.0.0 in-flight
conductor-state.json file (as used by /conduct in pre-kernel-split deployments)
loads against the kernel's workflow-state.schema.json without modification.

In-scope fixtures (must VALIDATE):
  - conductor-dev/conductor-state.json (live v1.0 — the file /conduct mutates
    on every run)

Out-of-scope fixtures (allowed to fail — documented archival snapshots):
  - conductor-state.json.bak-prd12-17 — pre-refactor snapshot with fields
    (workflow_type, tier_score, tier_signals, adversarialReview) that were
    shed during the PRD-12-to-17 schema-cleanup migrations. This backup is
    retained for forensic history, not as a compat target. Migrating it
    requires moving the four extra fields into domain_extensions{} per the
    kernel's domain-isolation model.

Run as a script:
    python3 tests/test_req_cdv_006_backward_compat.py

Exit codes:
    0 — all in-scope fixtures validate
    1 — at least one in-scope fixture fails validation
    2 — schema or fixture file missing
"""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import List, Tuple

try:
    import jsonschema
except ImportError:
    print("ERROR: jsonschema not installed. pip install jsonschema", file=sys.stderr)
    sys.exit(2)


REPO_ROOT = Path(__file__).resolve().parent.parent
KERNEL_SCHEMA = (
    REPO_ROOT.parent / "conductor-kernel" / "schemas" / "workflow-state.schema.json"
)

# (label, path, in_scope_for_req_cdv_006)
FIXTURES: List[Tuple[str, Path, bool]] = [
    (
        "conductor-dev/conductor-state.json (live v1.0)",
        REPO_ROOT / "conductor-state.json",
        True,
    ),
    (
        "conductor-dev/conductor-state.json.bak-prd12-17 (archival snapshot)",
        REPO_ROOT / "conductor-state.json.bak-prd12-17",
        False,
    ),
]


def main() -> int:
    if not KERNEL_SCHEMA.exists():
        print(f"FAIL (2): kernel schema not found at {KERNEL_SCHEMA}", file=sys.stderr)
        return 2

    with KERNEL_SCHEMA.open() as f:
        schema = json.load(f)

    validator = jsonschema.Draft202012Validator(
        schema, format_checker=jsonschema.FormatChecker()
    )

    print("REQ-CDV-006 backward-compat — kernel schema validates legacy state")
    print(f"Schema: {KERNEL_SCHEMA}")
    print()

    in_scope_failures = 0
    for label, path, in_scope in FIXTURES:
        scope_tag = "[in-scope]" if in_scope else "[archival, out-of-scope]"
        print(f"--- {label} {scope_tag}")
        if not path.exists():
            if in_scope:
                print(f"    FAIL: fixture missing at {path}")
                in_scope_failures += 1
            else:
                print("    SKIP: fixture missing (not in-scope)")
            print()
            continue

        with path.open() as f:
            doc = json.load(f)
        sv = doc.get("schema_version", "<absent>")
        errors = sorted(validator.iter_errors(doc), key=lambda e: list(e.path))

        if not errors:
            print(f"    PASS  (schema_version={sv})")
        else:
            label_pf = "FAIL" if in_scope else "EXPECTED-FAIL"
            print(f"    {label_pf}  (schema_version={sv}, {len(errors)} errors)")
            for e in errors[:5]:
                loc = "/".join(map(str, e.path)) or "<root>"
                print(f"      - {loc}: {e.message[:150]}")
            if in_scope:
                in_scope_failures += 1
        print()

    if in_scope_failures == 0:
        print("OVERALL: PASS — all in-scope REQ-CDV-006 fixtures validate.")
        return 0
    else:
        print(f"OVERALL: FAIL — {in_scope_failures} in-scope fixture(s) failed.")
        return 1


if __name__ == "__main__":
    sys.exit(main())
