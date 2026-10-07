#!/usr/bin/env bash
# Regressions for tools/check-plan-index.sh against fixture issues, PRs and a small plan,
# so no network is needed. Each case changes one thing in a clean fixture.
# Run from the repository root: bash tools/test-check-plan-index.sh
set -u

script="$(cd "$(dirname "$0")/.." && pwd)/tools/check-plan-index.sh"
dir=$(mktemp -d "${TMPDIR:-/tmp}/gc-plan-index-test.XXXXXX") || exit 1
[[ -n $dir && -d $dir ]] || { echo "no scratch directory"; exit 1; }
trap 'rm -rf "$dir"' EXIT

main_sha=1111111aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa

# issue <number> <title> <state> <milestone> [body]
issue() {
    jq -n --argjson n "$1" --arg t "$2" --arg s "$3" --arg m "$4" --arg b "${5:-}" '{
        number: $n, title: $t, state: $s, stateReason: (if $s == "CLOSED" then "COMPLETED" else null end),
        body: $b, milestone: {title: $m}, labels: {nodes: []}, subIssuesSummary: {total: 0, completed: 0},
        comments: {totalCount: 0, nodes: []}, timelineItems: {nodes: []}}'
}

clean() {
    {
        issue 1 "H1: CI" CLOSED "Phase 1 Hardening" "- [x] Lint passes (#10)" |
            jq '.comments = {totalCount: 1, nodes: [{body: "Closed by #10."}]}'
        issue 2 "H2: Sync" OPEN "Phase 3 Guild testing" $'- [x] F8 fixed (#10)\n- [ ] F7'
        issue 3 "F7: RESUME" OPEN "Phase 3 Guild testing"
    } | jq -s . >"$dir/issues.json"
    jq -n '[{number: 10, body: "", mergeCommit: {oid: "x"}, comments: {nodes: []}}]' >"$dir/prs.json"
    echo "$main_sha" >"$dir/main-shas.txt"
    cat >"$dir/plan.md" <<'EOF'
## Phase 1 — Hardening

Done: H1 [#1]

- [x] CI green (#10)

## Phase 3 — Guild testing

| ID | Issue | Scope |
|---|---|---|
| H2 | [#2] | Sync |
| F7 | [#3] | RESUME |

## Decisions log

| 2026-10-04 | H2 ([#2]) decided |
EOF
}

passed=0 failed=0
# expect <want exit> <needle, or "" for none> <name>
expect() {
    local want=$1 needle=$2 name=$3 out code
    out=$(bash "$script" --data "$dir" --plan "$dir/plan.md" 2>&1)
    code=$?
    if [[ $code -eq $want && ( -z $needle || $out == *"$needle"* ) ]]; then
        echo "PASS $name"
        passed=$((passed + 1))
    else
        echo "FAIL $name: exit $code, output: $out"
        failed=$((failed + 1))
    fi
}
edit_issues() { jq "$1" "$dir/issues.json" >"$dir/t" && mv "$dir/t" "$dir/issues.json"; }
edit_prs() { jq "$1" "$dir/prs.json" >"$dir/t" && mv "$dir/t" "$dir/prs.json"; }

clean; expect 0 "0 drift" "a clean fixture passes"

clean; edit_issues '(.[] | select(.number == 3) | .title) = "F8: wrong"'
expect 1 'F7 links #3, titled "F8: wrong"' "a title that doesn't start with the row ID"

clean; edit_issues '(.[] | select(.number == 3) | .milestone.title) = "Phase 2 Tester build"'
expect 1 'is under "Phase 3"' "a milestone that doesn't match the section"

clean; edit_issues '(.[] | select(.number == 1) | .state) = "OPEN"'
expect 1 "listed as done but is open" "a Done row that is still open"

clean; edit_issues '. + [{number: 4, title: "F9: new", state: "OPEN", body: "", milestone: null, labels: {nodes: []}, subIssuesSummary: {total: 0, completed: 0}, comments: {totalCount: 0, nodes: []}, timelineItems: {nodes: []}}]'
expect 1 '#4 "F9: new" is open but not in the plan' "an open plan-ID issue missing from the plan"

clean; edit_issues '(.[] | select(.number == 2) | .body) = "- [x] F8 fixed"'
expect 1 "#2: ticked without evidence" "a tick with no evidence"

clean; edit_issues '(.[] | select(.number == 2) | .body) = "- [x] F8 fixed (#3)"'
expect 1 "#2: ticked without evidence" "a tick citing only an issue"

clean; edit_issues '(.[] | select(.number == 2) | .body) = "- [x] F8 fixed in `1111111`"'
expect 0 "0 drift" "a tick citing a commit on main"

clean; edit_issues '(.[] | select(.number == 2) | .body) = "- [x] F8 fixed in `2222222`"'
expect 1 "ticked without evidence" "a tick citing a commit not on main"

clean; edit_issues '(.[] | select(.number == 2) | .body) = "- [x] Probe run, `migration-forever.md 2026-10-05`"'
expect 0 "0 drift" "a tick citing a migration-forever entry"

clean; sed -i.bak 's/- \[x\] CI green (#10)/- [x] CI green/' "$dir/plan.md"
expect 1 "plan gate (Phase 1 — Hardening): ticked without evidence" "a plan gate with no evidence"

clean; edit_issues '(.[] | select(.number == 1) | .comments) = {totalCount: 0, nodes: []}'
expect 1 "#1: closed with no linked PR and no evidence comment" "a hand close with no evidence"

clean; edit_issues '(.[] | select(.number == 1) | .comments) = {totalCount: 0, nodes: []} | (.[] | select(.number == 1) | .stateReason) = "NOT_PLANNED"'
expect 1 "closed as not planned with no reason" "a not-planned close with no reason"

clean; edit_issues '(.[] | select(.number == 1) | .timelineItems) = {nodes: [{closer: {__typename: "Commit", oid: "abc", associatedPullRequests: {nodes: [{number: 10, body: "### Tracking\nFinishes: #3\nProgress: #1"}]}}}]}'
expect 1 "#1: closed by PR #10, whose Tracking block does not list it under Finishes" "the #15 case: closed by a commit from a PR that doesn't finish it"

clean; edit_issues '(.[] | select(.number == 1) | .timelineItems) = {nodes: [{closer: {__typename: "Commit", oid: "abc", associatedPullRequests: {nodes: [{number: 10, body: "### Tracking\nFinishes: #1"}]}}}]}'
expect 0 "0 drift" "a close from a PR that finishes it"

clean; edit_prs '(.[0].body) = "### Tracking\nFinishes: #3"'
expect 1 "PR #10: Tracking block not applied" "a merged Tracking block not applied yet"

clean; edit_prs '(.[0].body) = "### Tracking\nFinishes: #3" | (.[0].comments.nodes) = [{body: "Tracking applied: #3 closed"}]'
expect 0 "0 drift" "an applied Tracking block"

clean; edit_prs '(.[0].body) = "### Tracking\nFinishes:\nProgress:"'
expect 0 "0 drift" "an empty Tracking block needs nothing"

clean; edit_issues '(.[] | select(.number == 2) | .subIssuesSummary) = {total: 2, completed: 2}'
expect 1 "#2: all 2 sub-issues are closed" "an umbrella whose sub-issues are all closed"

clean; printf '\n[#1]: https://example.com/pull/1\n' >>"$dir/plan.md"
expect 1 "H1 cites PR #1, which is not merged" "a plan link to an unmerged PR"

clean; edit_issues '(.[] | select(.number == 2) | .body) = "- [x] F8 fixed"'
out=$(bash "$script" --summary --data "$dir" --plan "$dir/plan.md"); code=$?
if [[ $code -eq 0 && $out == "Tracking: 1 drift item(s)"* ]]; then
    echo "PASS --summary reports drift and still exits 0"; passed=$((passed + 1))
else
    echo "FAIL --summary: exit $code, output: $out"; failed=$((failed + 1))
fi

echo "$passed passed, $failed failed"
[[ $failed -eq 0 ]]
