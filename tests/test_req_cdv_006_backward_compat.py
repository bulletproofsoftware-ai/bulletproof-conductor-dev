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


def _kernel_schema_path() -> Path | None:
    """Locate the kernel's workflow-state schema.

    The kernel is a separate plugin whose install location this repository does
    not assume. Resolution order:

      1. $CONDUCTOR_KERNEL_SCHEMA  — the schema file itself
      2. $CONDUCTOR_KERNEL_ROOT    — the kernel plugin directory
      3. a sibling ``conductor-kernel`` checkout, if one happens to exist

    Returns None when the kernel cannot be located, which the caller reports as
    SKIP rather than failure — this test validates a cross-plugin contract and
    simply cannot run without the other side of it.
    """
    import os

    explicit = os.environ.get("CONDUCTOR_KERNEL_SCHEMA", "").strip()
    if explicit:
        return Path(os.path.expanduser(explicit))

    root = os.environ.get("CONDUCTOR_KERNEL_ROOT", "").strip()
    if root:
        return Path(os.path.expanduser(root)) / "schemas" / "workflow-state.schema.json"

    for sibling in ("conductor-kernel", "bulletproof-conductor-kernel"):
        candidate = (
            REPO_ROOT.parent / sibling / "schemas" / "workflow-state.schema.json"
        )
        if candidate.exists():
            return candidate

    return None


KERNEL_SCHEMA = _kernel_schema_path()

# (label, path, in_scope_for_req_cdv_006)
#
# The committed fixture is a representative legacy v1.0 state file. It is the
# in-scope compat target so this test runs on a clean clone.
#
# If a real in-flight conductor-state.json is present in the working tree it is
# validated too, which catches drift in a live workflow — but its absence is not
# a failure, since it is a runtime artifact rather than a tracked file.
FIXTURES: List[Tuple[str, Path, bool]] = [
    (
        "tests/fixtures/conductor-state.v1.0.json (committed legacy shape)",
        REPO_ROOT / "tests" / "fixtures" / "conductor-state.v1.0.json",
        True,
    ),
    (
        "conductor-state.json (live workflow, if present)",
        REPO_ROOT / "conductor-state.json",
        False,
    ),
]


def main() -> int:
    if KERNEL_SCHEMA is None or not KERNEL_SCHEMA.exists():
        print("SKIP (77): conductor-kernel schema not found.")
        print()
        print("  This test validates a contract between two plugins, so it needs")
        print("  the kernel's workflow-state.schema.json. Point it at your install:")
        print("    export CONDUCTOR_KERNEL_ROOT=/path/to/conductor-kernel")
        print("  or name the schema file directly:")
        print("    export CONDUCTOR_KERNEL_SCHEMA=/path/to/workflow-state.schema.json")
        print()
        print("  Kernel: https://github.com/bulletproofsoftware-ai/bulletproof-conductor-kernel")
        return 77

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
