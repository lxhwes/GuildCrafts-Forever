#!/usr/bin/env bash
# Release preflight regressions (.github/scripts/release-preflight.sh, H18 #21) against a scratch repo.
# Run from the repository root: bash tools/test-release-preflight.sh
set -u

script="$(cd "$(dirname "$0")/.." && pwd)/.github/scripts/release-preflight.sh"
# Every git call below targets $repo. If it were empty, git -C "" would act on this
# repository, so stop unless it is a fresh scratch directory.
repo=$(mktemp -d "${TMPDIR:-/tmp}/gc-preflight.XXXXXX") || exit 1
[[ -n $repo && -d $repo && -z $(ls -A "$repo") ]] || { echo "no scratch directory"; exit 1; }
trap 'rm -rf "$repo"' EXIT

git -C "$repo" init -q -b main
git -C "$repo" -c user.name=t -c user.email=t@t commit -q --allow-empty -m one
git -C "$repo" tag v1.0.0
git -C "$repo" tag beta1
git -C "$repo" -c user.name=t -c user.email=t@t commit -q --allow-empty -m two
git -C "$repo" tag v2.0.0
git -C "$repo" branch v9

passed=0 failed=0

# expect <want exit: 0|1> <needle in output> <name> <checkout> [VAR=value ...]
expect() {
    local want=$1 needle=$2 name=$3 checkout=$4
    shift 4
    git -C "$repo" checkout -q --detach "$checkout"
    local out code
    out=$(cd "$repo" && env -i PATH="$PATH" HOME="$HOME" "$@" bash "$script" 2>&1)
    code=$?
    if [[ $code -eq $want && $out == *"$needle"* ]]; then
        echo "PASS $name"
        passed=$((passed + 1))
    else
        echo "FAIL $name: exit $code, output: $out"
        failed=$((failed + 1))
    fi
}

expect 0 "not publishing" "a dry run passes without a tag or token" main \
    PUBLISH=false EVENT_NAME=workflow_dispatch INPUT_REF=main
expect 1 "CF_API_KEY" "a missing token fails before anything else" v2.0.0 \
    PUBLISH=true EVENT_NAME=push GITHUB_REF=refs/tags/v2.0.0 HAS_CF_API_KEY=false
expect 1 "needs a tag" "a dispatch with no ref refuses to publish" main \
    PUBLISH=true EVENT_NAME=workflow_dispatch INPUT_REF= HAS_CF_API_KEY=true
expect 1 "not a v* tag" "a dispatch on a non-v* tag refuses to publish" beta1 \
    PUBLISH=true EVENT_NAME=workflow_dispatch INPUT_REF=beta1 HAS_CF_API_KEY=true
expect 1 "not a v* tag" "a dispatch on a branch refuses to publish" main \
    PUBLISH=true EVENT_NAME=workflow_dispatch INPUT_REF=main HAS_CF_API_KEY=true
expect 1 "is not a tag" "a v-named branch refuses to publish" v9 \
    PUBLISH=true EVENT_NAME=workflow_dispatch INPUT_REF=v9 HAS_CF_API_KEY=true
expect 1 "HEAD is not" "a tag that isn't the checked-out commit refuses to publish" main~1 \
    PUBLISH=true EVENT_NAME=workflow_dispatch INPUT_REF=v2.0.0 HAS_CF_API_KEY=true
expect 1 "2 tags" "a commit carrying two tags refuses to publish" v1.0.0 \
    PUBLISH=true EVENT_NAME=workflow_dispatch INPUT_REF=v1.0.0 HAS_CF_API_KEY=true
expect 0 "publishing v2.0.0" "a v* tag push with a token publishes" v2.0.0 \
    PUBLISH=true EVENT_NAME=push GITHUB_REF=refs/tags/v2.0.0 HAS_CF_API_KEY=true
expect 0 "publishing v2.0.0" "a dispatch on a full tag ref publishes" v2.0.0 \
    PUBLISH=true EVENT_NAME=workflow_dispatch INPUT_REF=refs/tags/v2.0.0 HAS_CF_API_KEY=true

git -C "$repo" tag v9
expect 1 "also a branch" "a tag that shares a branch name refuses to publish" refs/tags/v9 \
    PUBLISH=true EVENT_NAME=workflow_dispatch INPUT_REF=v9 HAS_CF_API_KEY=true

if [[ $failed -ne 0 ]]; then
    echo "$failed release preflight regression(s) failed"
    exit 1
fi
echo "$passed release preflight regressions passed"
