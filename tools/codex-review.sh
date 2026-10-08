#!/usr/bin/env bash
# Codex review of the current branch: the task, the commits and the diff go in one prompt,
# and the structured verdict comes back as JSON. The codex-review skill says when to run it
# and what to do with the result.
#
# Usage: tools/codex-review.sh (--issue N | --task-file FILE | --task TEXT) [--base REF]
#                              [--focus TEXT] [--prior FILE] [--model M] [--effort E]
#                              [--allow-extra-run] [--dry-run]
#
# Runs are saved to .codex-review/<branch>/run-N.{json,prompt.md,log}. Run 2 needs --prior,
# the responses to run 1. Run 3 needs --allow-extra-run.
#
# Exit: 0 nothing blocking; 2 a critical or high finding, new or from an earlier run and not
# resolved; 1 refused or failed.
set -u

here=$(cd "$(dirname "$0")" && pwd)
schema=$here/codex-review.schema.json
codex=${CODEX_BIN:-codex}

base=origin/main issue='' task_file='' task='' focus='' prior='' model=gpt-6.1-sol effort=medium
allow_extra=0 dry_run=0
max_inline_diff=150000

die() { echo "codex-review: $*" >&2; exit 1; }

while [[ $# -gt 0 ]]; do
    case $1 in
        --base) base=${2:?}; shift ;;
        --issue) issue=${2:?}; shift ;;
        --task-file) task_file=${2:?}; shift ;;
        --task) task=${2:?}; shift ;;
        --focus) focus=${2:?}; shift ;;
        --prior) prior=${2:?}; shift ;;
        --model) model=${2:?}; shift ;;
        --effort) effort=${2:?}; shift ;;
        --allow-extra-run) allow_extra=1 ;;
        --dry-run) dry_run=1 ;;
        *) die "unknown argument: $1" ;;
    esac
    shift
done

top=$(git rev-parse --show-toplevel 2>/dev/null) || die "not in a git repository"
cd "$top" || exit 1
git rev-parse --verify -q "$base^{commit}" >/dev/null || die "unknown base: $base"
sources=0
for src in "$issue" "$task_file" "$task"; do [[ -n $src ]] && sources=$((sources + 1)); done
[[ $sources -gt 0 ]] || die "needs the original task: --issue N, --task-file FILE or --task TEXT"
[[ $sources -eq 1 ]] || die "pass only one of --issue, --task-file and --task"
[[ -z $task_file || -f $task_file ]] || die "no such task file: $task_file"
[[ -z $prior || -f $prior ]] || die "no such prior file: $prior"

# Codex reads the files on disk, so they have to match the diff it's given. Untracked files
# count too: Codex would review one the PR doesn't ship. Ignored files (.codex-review/) don't.
[[ -z $(git status --porcelain) ]] \
    || die "uncommitted changes or untracked files; commit or remove them so the diff matches the files"
range=$base...HEAD
[[ -n $(git diff --name-only "$range") ]] || die "no changes against base $base"

branch=$(git symbolic-ref -q --short HEAD || echo "detached-$(git rev-parse --short HEAD)")
run_dir=.codex-review/${branch//\//-}
runs=0
for f in "$run_dir"/run-*.json; do [[ -e $f ]] && runs=$((runs + 1)); done
n=$((runs + 1))

if [[ $dry_run -eq 0 ]]; then
    [[ $n -lt 2 || -n $prior ]] \
        || die "run $n needs --prior: a file answering each run $runs finding with its fix commit or rebuttal"
    [[ $n -lt 3 || $allow_extra -eq 1 ]] \
        || die "run $n refused: two runs is the cap. Take the open findings to Alex; pass --allow-extra-run only when Alex asks for another run"
fi
command -v jq >/dev/null || die "jq is required"

# Every finding from earlier runs, latest wording first. Run N must account for each one.
earlier='[]'
if [[ $runs -gt 0 ]]; then
    earlier=$(jq -s '[.[].findings[]] | reverse | unique_by(.title)' "$run_dir"/run-*.json) \
        || die "can't read the earlier runs in $run_dir"
fi

if [[ -n $issue ]]; then
    task=$(gh issue view "$issue" --json number,title,body \
        --jq '"#\(.number) \(.title)\n\n\(.body)"') || die "gh issue view $issue failed"
elif [[ -n $task_file ]]; then
    task=$(cat "$task_file")
fi

changed=$(git diff --name-only "$range")
diff_bytes=$(git diff "$range" | wc -c | tr -d ' ')

prompt() {
    cat <<EOF
You are reviewing a change to GuildCrafts before its pull request opens. Apply AGENTS.md:
its red flags and its severity scale decide what you report and how you grade it.

This is run $n. You are read-only. Report findings; don't edit files.

## Task

The change is meant to do this. Judge the diff against it: flag anything the task asks for
that the diff misses, and anything the diff does that the task doesn't call for.

$task

## Commits

$(git log --format='%h %s' "$base..HEAD")

## Changed files

$(git diff --stat "$range")

EOF
    if grep -qE '^GuildCrafts/Modules/(Comms|SyncPausePolicy|ForeverIdentity|Data)\.lua$' <<<"$changed"; then
        cat <<'EOF'
## Multi-client cases

This change touches sync, election, identity or merge and prune code. Read the matching RFC
in `RFC/` and check it against the source. Then trace the cases the stub suites can't reach:
several clients at once, DR loss mid-transfer, a stale term arriving after a newer one, a
reconnect after a drop, and a peer on an older protocol version.

EOF
    fi
    if [[ -n $focus ]]; then
        printf '## Focus\n\n%s\n\n' "$focus"
    fi
    if [[ $runs -gt 0 ]]; then
        cat <<EOF
## Previous review

Earlier runs reported these findings:

$(jq -r '.[] | "- [\(.severity)] \(.title) (\(.file):\(.line_start)-\(.line_end)): \(.body)"' <<<"$earlier")

Add one entry to \`prior\` for each of them, with \`title\` copied exactly as written above.
Set \`status\` to \`resolved\` if the fix holds, \`rebuttal-accepted\` if the author's evidence
holds, or \`still-open\` if neither does, and give the reason in \`note\`. Report a new finding
only if it is critical or high, or a fix introduced it.

The author's responses, each a fix commit or a rebuttal with evidence:

$(if [[ -n $prior ]]; then cat "$prior"; else echo "(none given)"; fi)

EOF
    fi
    echo "## Diff"
    echo
    if [[ $diff_bytes -le $max_inline_diff ]]; then
        echo '```diff'
        git diff "$range"
        echo '```'
    else
        echo "The diff is $diff_bytes bytes, too large to include. Read it with"
        echo "\`git diff $range -- <path>\`, one changed file at a time."
    fi
    cat <<'EOF'

## Output

Return JSON matching the schema. `verdict` is `approve` only when no finding is critical or
high and no critical or high earlier finding is still open. Ground every finding in a file and
line range from the current tree. Leave `prior` empty when there is no previous review.
EOF
}

if [[ $dry_run -eq 1 ]]; then
    prompt
    exit 0
fi

mkdir -p "$run_dir" || exit 1
prompt_file=$run_dir/run-$n.prompt.md
log=$run_dir/run-$n.log
pending=$run_dir/run-$n.json.partial
out=$run_dir/run-$n.json
prompt >"$prompt_file"
rm -f "$pending"

echo "codex-review: run $n, $model at $effort effort, log in $log" >&2
"$codex" exec -s read-only --ephemeral -C "$top" -m "$model" \
    -c "model_reasoning_effort=$effort" --output-schema "$schema" -o "$pending" \
    - <"$prompt_file" >"$log" 2>&1
status=$?
[[ $status -eq 0 ]] || die "codex exited $status; see $log"
jq -e '.verdict and (.findings | type == "array") and (.prior | type == "array")' \
    "$pending" >/dev/null 2>&1 || die "run $n output isn't the expected JSON; see $pending"
mv "$pending" "$out"

echo "codex-review: run $n -> $out"
# A critical or high finding blocks while it's new, still open, or missing from prior.
report=$(jq -r --argjson earlier "$earlier" '
    def blocks: .severity == "critical" or .severity == "high";
    # a title listed more than once counts as still-open if any entry says so
    ([.prior | group_by(.title)[] | {key: .[0].title,
        value: (if any(.status == "still-open") then "still-open" else .[0].status end)}]
      | from_entries) as $status
    | [$earlier[] | select(blocks) | .title as $t | ($status[$t] // "missing")
        | select(. == "still-open" or . == "missing") | {title: $t, status: .}] as $open
    | (([.findings[] | select(blocks)] | length) + ($open | length)) as $blocking
    | "verdict: \(.verdict). \(.summary)",
      (.findings[] | "[\(.severity)] \(.file):\(.line_start)-\(.line_end) \(.title)"),
      (.prior[] | "\(.status): \(.title)"),
      ($open[] | select(.status == "missing") | "no prior entry: \(.title)"),
      "blocking: \($blocking)"' "$out") || die "couldn't read $out"
echo "$report"
blocking=${report##*blocking: }
[[ $blocking =~ ^[0-9]+$ ]] || die "couldn't count blocking findings in $out"
[[ $blocking -eq 0 ]] || exit 2
