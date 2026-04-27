#!/usr/bin/env python3

# Copyright (c) 2026 Adam Brauns (@AdamBrauns)

"""UserPromptSubmit hook: block prompts with @.env-style file mentions.

Claude Code resolves @path mentions client-side before any tool call, so
PreToolUse hooks can't catch them. This hook inspects the raw prompt.
"""

import json
import re
import sys

AT_ENV_RE = re.compile(
    r"@\S*(?<!\w)\.env(?:rc)?(?:\.|[*?]|(?!\w))",
    re.IGNORECASE,
)


def main() -> None:
    prompt = json.load(sys.stdin).get("prompt", "")
    if AT_ENV_RE.search(prompt):
        print("@-mentions of .env / .envrc files are blocked.", file=sys.stderr)
        sys.exit(2)


if __name__ == "__main__":
    main()
