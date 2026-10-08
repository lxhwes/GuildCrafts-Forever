#!/usr/bin/env bash
# Fails when text on stdin holds a GitHub closing keyword next to an issue reference
# ("fix #15", "Closes: owner/repo#3", "resolved https://github.com/o/r/issues/4").
# Issues close only through a PR's Tracking block (AGENTS.md, Git workflow). #15 closed by
# accident from a squash commit body that said "fix #15's".
# Usage: printf '%s\n' "$TITLE" "$BODY" | bash .github/scripts/closing-keywords.sh
set -u

ref='([[:alnum:]_.-]+/[[:alnum:]_.-]+)?#[0-9]+|https://github\.com/[^[:space:]]+/issues/[0-9]+'
pattern="(^|[^[:alnum:]_])(close[sd]?|fix(e[sd])?|resolve[sd]?):?[[:space:]]+($ref)"

hits=$(grep -Eio "$pattern" | sed -E 's/^[^[:alpha:]]//')
if [[ -n $hits ]]; then
    echo "Closing keywords found. Use the Tracking block (Finishes:/Progress:) instead:"
    printf '  %s\n' "$hits"
    exit 1
fi
echo "closing-keywords: none"
