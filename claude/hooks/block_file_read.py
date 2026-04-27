#!/usr/bin/env python3

# Copyright (c) 2026 Adam Brauns (@AdamBrauns)

"""PreToolUse hook: block access to .env / .envrc files."""

import json
import re
import sys

ENV_RE = re.compile(r"(?<!\w)\.env(?:rc)?(?:\.|[*?]|(?!\w))", re.IGNORECASE)
FIELDS = ("file_path", "path", "command", "glob")


def main() -> None:
    ti = json.load(sys.stdin).get("tool_input") or {}
    blob = " ".join(str(ti.get(k, "")) for k in FIELDS)
    if ENV_RE.search(blob):
        print("Access to .env / .envrc files is blocked.", file=sys.stderr)
        sys.exit(2)


if __name__ == "__main__":
    main()
