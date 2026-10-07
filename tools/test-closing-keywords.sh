#!/usr/bin/env bash
# Regressions for .github/scripts/closing-keywords.sh, the CI guard against issues closed
# by a keyword in a PR title, body or commit message (#15).
# Run from the repository root: bash tools/test-closing-keywords.sh
set -u

script="$(cd "$(dirname "$0")/.." && pwd)/.github/scripts/closing-keywords.sh"
passed=0 failed=0

# expect <want exit: 0|1> <name> <text>
expect() {
    local want=$1 name=$2 text=$3 out code
    out=$(printf '%s\n' "$text" | bash "$script" 2>&1)
    code=$?
    if [[ $code -eq $want ]]; then
        echo "PASS $name"
        passed=$((passed + 1))
    else
        echo "FAIL $name: exit $code, output: $out"
        failed=$((failed + 1))
    fi
}

expect 1 "the #15 squash body is caught" "- Decide to fix #15's returning DR with #44's DR-elect pull"
expect 1 "a colon after the keyword is caught" "Fixes: #12"
expect 1 "upper case is caught" "CLOSES #3"
expect 1 "a cross-repo reference is caught" "resolved lxhwes/GuildCrafts-Forever#4"
expect 1 "an issue URL is caught" "closed https://github.com/lxhwes/GuildCrafts-Forever/issues/9"
expect 1 "a keyword at the start of a line is caught" "fix #1"
expect 0 "Refs and Part of pass" "Refs #15. Part of #44."
expect 0 "a Tracking block passes" $'### Tracking\nFinishes: #112\nProgress: #44 F30'
expect 0 "a word ending in fix passes" "prefix #15 and suffix #16"
expect 0 "fixed in a PR passes" "F29 fixed in #95"
expect 0 "a keyword without an issue passes" "Fix the scan gate"
expect 0 "empty input passes" ""

echo "$passed passed, $failed failed"
[[ $failed -eq 0 ]]
