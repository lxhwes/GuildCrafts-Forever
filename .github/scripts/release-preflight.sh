#!/usr/bin/env bash
# Refuses a publishing release run before anything is packaged, uploaded or released (H18, #21).
# Runs in the checked-out repository. Environment:
#   PUBLISH         "true" when this run would publish
#   EVENT_NAME      github.event_name
#   GITHUB_REF      the pushed ref, for push events
#   INPUT_REF       the workflow_dispatch "ref" input
#   HAS_CF_API_KEY  "true" when the CF_API_KEY secret is set (never the value itself)
set -euo pipefail

fail() { echo "::error::release-preflight: $*"; exit 1; }

if [[ ${PUBLISH:-false} != true ]]; then
    echo "release-preflight: not publishing"
    exit 0
fi

# Without the token the packager skips CurseForge but still creates the GitHub release.
[[ ${HAS_CF_API_KEY:-false} == true ]] || fail "CF_API_KEY is not set; refusing to publish"

if [[ ${EVENT_NAME:-} == push ]]; then
    ref=${GITHUB_REF:-}
else
    ref=${INPUT_REF:-}
fi
tag=${ref#refs/tags/}

[[ -n $tag ]] || fail "publishing needs a tag as ref"
[[ $tag == v* ]] || fail "'$tag' is not a v* tag"
git show-ref --verify --quiet "refs/tags/$tag" || fail "'$tag' is not a tag"
if git show-ref --verify --quiet "refs/heads/$tag" \
        || git show-ref --verify --quiet "refs/remotes/origin/$tag"; then
    fail "'$tag' is also a branch name"
fi
[[ $(git rev-parse "refs/tags/$tag^{commit}") == $(git rev-parse HEAD) ]] \
    || fail "HEAD is not '$tag'"

# The packager takes its version and release type from a tag on HEAD; with two it picks one.
count=$(git tag --points-at HEAD | wc -l | tr -d ' ')
[[ $count -eq 1 ]] || fail "HEAD carries $count tags ($(git tag --points-at HEAD | tr '\n' ' '))"

echo "release-preflight: publishing $tag"
