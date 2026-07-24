#!/usr/bin/env python3
"""
sanitize.py — Deterministic text sanitization for SBR ingestion.

Reads raw text from stdin and writes sanitized text to stdout. If the text
contains a disqualifying classification marker (T2-Confidential or
T3-Restricted), writes the sentinel `__SKIP__` to stdout and exits 0 — the
caller (bash) checks for that sentinel and skips the item.

Extracted from scripts/ingest-sbr.sh because the original `python3 - <<'PY'`
heredoc pattern fed the heredoc into python's stdin (since `-` means "read
program from stdin"), leaving sys.stdin.read() empty. Standalone file fixes
that: `python3 sanitize.py` reads its program from the file and inherits the
caller's stdin.

Idempotent and side-effect-free. Exit 0 on success. Exit 1 on internal error.
"""

import re
import sys


def sanitize(text: str) -> str:
    # Hard skip: restricted classifications.
    for marker in ("T2-Confidential", "T3-Restricted"):
        if marker in text:
            return "__SKIP__"

    # Email addresses -> [REDACTED].
    text = re.sub(
        r"[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}",
        "[REDACTED]",
        text,
    )

    # Absolute home/system paths -> tilde-relative or [PATH].
    text = re.sub(r"/Users/[A-Za-z0-9_\-.]+", "~", text)
    text = re.sub(r"/home/[A-Za-z0-9_\-.]+", "~", text)
    text = re.sub(r"/root\b", "~", text)

    # AWS-style access keys (AKIA + 16 alnum) -> [REDACTED_KEY].
    text = re.sub(r"\bAKIA[0-9A-Z]{16}\b", "[REDACTED_KEY]", text)

    # Generic API-key-ish patterns: long base64/hex blocks (100+ chars, no whitespace).
    text = re.sub(
        r"(?<![A-Za-z0-9+/=])[A-Za-z0-9+/=]{100,}(?![A-Za-z0-9+/=])",
        "[REDACTED_BLOB]",
        text,
    )

    # .env-file-style assignments where the variable name signals a secret.
    text = re.sub(
        r"((?:SECRET|TOKEN|KEY|PASSWORD|PASSWD|PWD)[A-Z0-9_]*\s*=\s*)\S+",
        r"\1[REDACTED]",
        text,
        flags=re.IGNORECASE,
    )

    # Bearer tokens.
    text = re.sub(
        r"(Bearer\s+)[A-Za-z0-9._\-]+",
        r"\1[REDACTED]",
        text,
        flags=re.IGNORECASE,
    )

    return text


def main() -> int:
    try:
        raw = sys.stdin.read()
    except Exception as exc:
        print(f"sanitize.py: failed to read stdin: {exc}", file=sys.stderr)
        return 1

    cleaned = sanitize(raw)
    sys.stdout.write(cleaned)
    return 0


if __name__ == "__main__":
    sys.exit(main())
