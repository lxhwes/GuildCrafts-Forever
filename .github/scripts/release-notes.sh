#!/usr/bin/env bash
# Writes one CHANGELOG.md section to the file .pkgmeta names as manual-changelog (H20, #80),
# so CurseForge and the GitHub release get this version's notes, not the whole history.
# Runs in the checked-out repository. Environment:
#   REF        the ref being packaged: inputs.ref || github.ref
#   CHANGELOG  source file (default CHANGELOG.md)
#   OUT        notes file (default .release-notes.md; the packager never copies dotfiles)
#
# A tag build takes the section headed "## <tag without v>", alone or followed by a space
# (for example "## 2.1.0-forever-beta.1 — 2026-10-20"), and fails if there is none.
# Any other build (branch, SHA, blank) takes the topmost "## " section.
set -euo pipefail

changelog=${CHANGELOG:-CHANGELOG.md}
out=${OUT:-.release-notes.md}
ref=${REF:-}

fail() { echo "::error::release-notes: $*"; exit 1; }

rm -f "$out"
[[ -f $changelog ]] || fail "$changelog not found"

is_branch() {
    git show-ref --verify --quiet "refs/heads/$1" \
        || git show-ref --verify --quiet "refs/remotes/origin/$1"
}

# Match actions/checkout: refs/tags/ is a tag, refs/heads/ a branch, and a bare name is a
# branch if one exists, else a tag if one exists. Anything else is a SHA.
tag=
case $ref in
    refs/tags/*) tag=${ref#refs/tags/} ;;
    refs/*|"") ;;
    *) if ! is_branch "$ref" && git show-ref --verify --quiet "refs/tags/$ref"; then tag=$ref; fi ;;
esac
version=${tag#v}

# Headings and body lines share the file's indent (two spaces in CHANGELOG.md); strip it.
notes=$(awk -v want="$version" '
    /^ *## / {
        if (found) exit
        title = $0
        sub(/^ *## /, "", title)
        if (want == "" || title == want || index(title, want " ") == 1) {
            found = 1
            match($0, /^ */)
            pad = substr($0, 1, RLENGTH)
        }
    }
    found {
        line = $0
        if (substr(line, 1, length(pad)) == pad) line = substr(line, length(pad) + 1)
        lines[++n] = line
        if (line ~ /[^ ]/) last = n
    }
    END {
        if (!found) exit 3
        for (i = 1; i <= last; i++) print lines[i]
    }
' "$changelog") || {
    if [[ -n $tag ]]; then
        fail "$changelog has no '## $version' heading for tag $tag. Rename '## Unreleased' to '## $version — YYYY-MM-DD' before tagging."
    fi
    fail "$changelog has no '## ' heading"
}

printf '%s\n' "$notes" > "$out"
echo "release-notes: wrote '$(head -n1 "$out")' ($(wc -l < "$out" | tr -d ' ') lines) to $out for ${tag:-${ref:-the checked-out commit}}"
