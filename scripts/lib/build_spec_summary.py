#!/usr/bin/env python3
"""
build_spec_summary.py — Heuristic spec_summary builder for SBR payloads.

Reads sanitized prompt text from stdin and writes a short (<=500-char) summary
to stdout. Summary = first H1 heading + first paragraph immediately following
the heading. Falls back to first two non-empty lines when no H1 is present.

Extracted from scripts/ingest-sbr.sh because the original `python3 - <<'PY'`
heredoc pattern fed the heredoc into python's stdin, so sys.stdin.read()
returned an empty string. Standalone file restores stdin pass-through.

Idempotent and side-effect-free. Exit 0.
"""

import sys


def build_summary(text: str) -> str:
    text = text.strip()
    if not text:
        return ""

    lines = text.splitlines()
    heading = None
    para_lines: list[str] = []
    in_para = False

    for line in lines:
        stripped = line.strip()
        if heading is None and stripped.startswith("# "):
            heading = stripped[2:].strip()
            continue
        if heading is not None and not in_para:
            if stripped:
                in_para = True
                para_lines.append(stripped)
            continue
        if in_para:
            if not stripped:
                break
            para_lines.append(stripped)

    if heading is None:
        # No H1 — fall back to first non-empty line + next non-empty.
        nonempty = [ln.strip() for ln in lines if ln.strip()]
        heading = nonempty[0] if nonempty else ""
        para_lines = nonempty[1:3]

    summary = (heading + ". " + " ".join(para_lines)).strip()
    # Cap at 500 chars per schema.
    if len(summary) > 500:
        summary = summary[:497].rstrip() + "..."
    return summary


def main() -> int:
    try:
        raw = sys.stdin.read()
    except Exception as exc:
        print(
            f"build_spec_summary.py: failed to read stdin: {exc}",
            file=sys.stderr,
        )
        return 1

    sys.stdout.write(build_summary(raw))
    return 0


if __name__ == "__main__":
    sys.exit(main())
