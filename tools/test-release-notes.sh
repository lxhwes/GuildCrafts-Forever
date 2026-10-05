#!/usr/bin/env bash
# Release-notes extraction regressions (.github/scripts/release-notes.sh, H20 #80) against a scratch repo.
# Run from the repository root: bash tools/test-release-notes.sh (test-release-preflight.sh calls it).
set -u

script="$(cd "$(dirname "$0")/.." && pwd)/.github/scripts/release-notes.sh"
# Every git call below targets $repo. If it were empty, git -C "" would act on this
# repository, so stop unless it is a fresh scratch directory.
repo=$(mktemp -d "${TMPDIR:-/tmp}/gc-notes.XXXXXX") || exit 1
[[ -n $repo && -d $repo && -z $(ls -A "$repo") ]] || { echo "no scratch directory"; exit 1; }
trap 'rm -rf "$repo"' EXIT

# Same shape as CHANGELOG.md: every line indented by two spaces.
cat > "$repo/CHANGELOG.md" <<'EOF'
  # Changelog

  Preface that must never ship.

  ## Unreleased

  ### Fixes

  - **Top fix** — only in Unreleased.

  ## 2.1.0-forever-beta.1 — 2026-10-20

  ### New features

  - **Beta feature** — only in beta.1.

  ### Fixes

  - **Beta fix** — also beta.1.


  ## 2.0.2 — 2026-09-08

  - **Upstream** — Classic history.
EOF

git -C "$repo" init -q -b main
git -C "$repo" add CHANGELOG.md
git -C "$repo" -c user.name=t -c user.email=t@t commit -q -m one
git -C "$repo" tag v2.1.0-forever-beta.1
git -C "$repo" tag v2.1.0-forever-beta
git -C "$repo" tag v3.0.0
sha=$(git -C "$repo" rev-parse HEAD)

top='## Unreleased

### Fixes

- **Top fix** — only in Unreleased.'

beta1='## 2.1.0-forever-beta.1 — 2026-10-20

### New features

- **Beta feature** — only in beta.1.

### Fixes

- **Beta fix** — also beta.1.'

passed=0 failed=0
pass() { echo "PASS $1"; passed=$((passed + 1)); }
fail() { echo "FAIL $1: $2"; failed=$((failed + 1)); }

# expect_notes <name> <REF> <want notes>
expect_notes() {
    local name=$1 ref=$2 want=$3 out code got
    rm -f "$repo/.release-notes.md"
    out=$(cd "$repo" && env -i PATH="$PATH" HOME="$HOME" REF="$ref" bash "$script" 2>&1)
    code=$?
    if [[ $code -ne 0 ]]; then fail "$name" "exit $code, output: $out"; return; fi
    got=$(cat "$repo/.release-notes.md" 2>/dev/null)
    if [[ $got == "$want" ]]; then pass "$name"; else fail "$name" "notes were:
$got"; fi
}

# expect_refusal <name> <REF> <needle in output>
expect_refusal() {
    local name=$1 ref=$2 needle=$3 out code
    rm -f "$repo/.release-notes.md"
    out=$(cd "$repo" && env -i PATH="$PATH" HOME="$HOME" REF="$ref" bash "$script" 2>&1)
    code=$?
    if [[ $code -eq 1 && $out == *"$needle"* && ! -e $repo/.release-notes.md ]]; then
        pass "$name"
    else
        fail "$name" "exit $code, notes file $([[ -e $repo/.release-notes.md ]] && echo written || echo absent), output: $out"
    fi
}

expect_notes "a tag push takes the tag's section, de-indented" refs/tags/v2.1.0-forever-beta.1 "$beta1"
expect_notes "a dispatch on a bare tag name takes the tag's section" v2.1.0-forever-beta.1 "$beta1"
expect_notes "a branch takes the top section" refs/heads/main "$top"
expect_notes "a bare branch name takes the top section" main "$top"
expect_notes "a SHA takes the top section" "$sha" "$top"
expect_notes "a blank ref takes the top section" "" "$top"
expect_refusal "a tag with no section fails" refs/tags/v3.0.0 "no '## 3.0.0' heading"
expect_refusal "a tag that only prefixes a heading fails" v2.1.0-forever-beta "no '## 2.1.0-forever-beta' heading"

# Nothing outside the chosen section leaks in.
for ref in refs/tags/v2.1.0-forever-beta.1 main; do
    rm -f "$repo/.release-notes.md"
    (cd "$repo" && env -i PATH="$PATH" HOME="$HOME" REF="$ref" bash "$script" >/dev/null 2>&1)
    leaks=$(grep -E 'Preface|Upstream|2\.0\.2|# Changelog' "$repo/.release-notes.md" 2>/dev/null)
    if [[ -f $repo/.release-notes.md && -z $leaks ]]; then
        pass "nothing below the next heading or above the section leaks in ($ref)"
    else
        fail "nothing leaks in ($ref)" "${leaks:-no notes file}"
    fi
done

# A tag that shares a branch name is checked out as the branch, so it takes the top section.
git -C "$repo" branch v3.0.0
expect_notes "a name that is both a branch and a tag is treated as the branch" v3.0.0 "$top"

if [[ $failed -ne 0 ]]; then
    echo "$failed release notes regression(s) failed"
    exit 1
fi
echo "$passed release notes regressions passed"
