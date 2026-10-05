#!/usr/bin/env bash
# tools/codex-review.sh regressions against a scratch repo, with a stub in place of codex.
# Run from the repository root: bash tools/test-codex-review.sh
set -u

script="$(cd "$(dirname "$0")" && pwd)/codex-review.sh"
# Every git call below targets $repo. If it were empty, git -C "" would act on this
# repository, so stop unless it is a fresh scratch directory.
scratch=$(mktemp -d "${TMPDIR:-/tmp}/gc-codex-review.XXXXXX") || exit 1
[[ -n $scratch && -d $scratch && -z $(ls -A "$scratch") ]] || { echo "no scratch directory"; exit 1; }
trap 'rm -rf "$scratch"' EXIT
repo=$scratch/repo
mkdir -p "$repo"

gitc() { git -C "$repo" -c user.name=t -c user.email=t@t "$@"; }

gitc init -q -b main
mkdir -p "$repo/GuildCrafts/Modules"
echo 'local a = 1' >"$repo/GuildCrafts/Modules/MinimapButton.lua"
gitc add -A && gitc commit -q -m base
gitc branch base
gitc checkout -q -b feature/x

# The stub records its arguments and stdin, then writes $STUB_RESPONSE where -o points.
cat >"$scratch/codex" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" >"$STUB_DIR/args"
cat >"$STUB_DIR/stdin"
out=
while [[ $# -gt 0 ]]; do
    if [[ $1 == -o ]]; then out=$2; shift; fi
    shift
done
[[ -n $out ]] && cat "$STUB_DIR/response" >"$out"
exit "${STUB_EXIT:-0}"
EOF
chmod +x "$scratch/codex"
export CODEX_BIN=$scratch/codex STUB_DIR=$scratch

respond() { printf '%s\n' "$1" >"$scratch/response"; }
finding() { printf '{"severity":"%s","title":"%s","body":"b","file":"GuildCrafts/Modules/Data.lua","line_start":3,"line_end":4,"confidence":0.8,"recommendation":"r"}' "$1" "$2"; }
prior() { printf '{"title":"%s","status":"%s","note":"n"}' "$1" "$2"; }
# result <findings, comma-separated> <prior entries, comma-separated>
result() { printf '{"verdict":"needs-attention","summary":"s","findings":[%s],"prior":[%s]}' "$1" "${2:-}"; }
clean='{"verdict":"approve","summary":"ok","findings":[],"prior":[]}'
high=$(result "$(finding high "Purges on empty read")")
medium=$(result "$(finding medium "Edge")")
run1=$(result "$(finding high "Purges on empty read"),$(finding medium "Edge")")

passed=0 failed=0
out='' code=''

run() { out=$(cd "$repo" && bash "$script" --base base "$@" 2>&1); code=$?; }

# check <name> <want exit> <needle in output> [<needle that must be absent>]
check() {
    local name=$1 want=$2 needle=$3 absent=${4:-}
    if [[ $code -eq $want && $out == *"$needle"* && ( -z $absent || $out != *"$absent"* ) ]]; then
        echo "PASS $name"
        passed=$((passed + 1))
    else
        echo "FAIL $name: exit $code, output: $out"
        failed=$((failed + 1))
    fi
}

# check_absent <name> <path that must not exist>
check_absent() {
    if [[ ! -e $2 ]]; then
        echo "PASS $1"
        passed=$((passed + 1))
    else
        echo "FAIL $1: $2 exists"
        failed=$((failed + 1))
    fi
}

# check_file <name> <file> <needle>
check_file() {
    local name=$1 file=$2 needle=$3
    if [[ -f $file && $(cat "$file") == *"$needle"* ]]; then
        echo "PASS $name"
        passed=$((passed + 1))
    else
        echo "FAIL $name: $file lacks $needle"
        failed=$((failed + 1))
    fi
}

run_dir=$repo/.codex-review/feature-x
task="Fix the minimap tooltip."

# seed_run1: a saved run 1 with one high and one medium finding, and no run 2.
seed_run1() { rm -rf "$repo/.codex-review"; mkdir -p "$run_dir"; printf '%s\n' "$run1" >"$run_dir/run-1.json"; }

run --dry-run --task "$task"
check "an empty diff refuses to review" 1 "no changes against base"

echo 'local b = 2' >>"$repo/GuildCrafts/Modules/MinimapButton.lua"
run --dry-run --task "$task"
check "uncommitted changes refuse to review" 1 "uncommitted changes"

gitc commit -q -am "feat(ui): second local"
run --dry-run
check "a missing task refuses to review" 1 "needs the original task"

run --dry-run --task "$task"
check "an inline task reaches the prompt" 0 "$task"
check "the prompt carries the diff" 0 "+local b = 2"
check "the prompt carries the commits" 0 "feat(ui): second local"
check "a non-sync change gets no multi-client section" 0 "## Changed files" "## Multi-client cases"

echo 'Fix the tooltip from a file.' >"$scratch/task.md"
run --dry-run --task-file "$scratch/task.md"
check "a task file reaches the prompt" 0 "Fix the tooltip from a file."

run --dry-run --task "$task" --task-file "$scratch/task.md"
check "two task sources refuse" 1 "only one of"

run --dry-run --task "$task" --focus "Look at the tooltip anchor."
check "focus text reaches the prompt" 0 "Look at the tooltip anchor."

echo 'local term = 1' >"$repo/GuildCrafts/Modules/Comms.lua"
gitc add -A && gitc commit -q -m "fix(sync): term"
run --dry-run --task "$task"
check "a Comms.lua change adds the multi-client section" 0 "## Multi-client cases"

check_absent "a dry run writes nothing" "$repo/.codex-review"

respond "$high"
run --task "$task"
check "a high finding is blocking" 2 "blocking: 1"
check "the summary names the finding" 2 "[high] GuildCrafts/Modules/Data.lua:3-4 Purges on empty read"
check_file "run 1 is saved" "$run_dir/run-1.json" '"severity":"high"'
check_file "the prompt is saved beside it" "$run_dir/run-1.prompt.md" "$task"
check_file "codex runs read-only" "$scratch/args" $'-s\nread-only'
check_file "codex gets the output schema" "$scratch/args" "codex-review.schema.json"
check_file "codex gets the default model" "$scratch/args" $'-m\ngpt-6.1-sol'
check_file "codex gets the effort for this run only" "$scratch/args" "model_reasoning_effort=medium"
check_file "codex reads the prompt on stdin" "$scratch/stdin" "$task"

rm -rf "$repo/.codex-review"
respond "$medium"
run --task "$task"
check "a medium finding is not blocking" 0 "blocking: 0"

seed_run1
run --task "$task"
check "run 2 without --prior refuses" 1 "--prior"
check_absent "a refused run writes nothing" "$run_dir/run-2.json"

echo 'Purges on empty read: fixed in abc123.' >"$scratch/prior.md"
respond "$(result "" "$(prior "Purges on empty read" resolved),$(prior Edge still-open)")"
run --task "$task" --prior "$scratch/prior.md"
check "a still-open medium from run 1 doesn't block" 0 "blocking: 0"
check "the still-open medium is still shown" 0 "still-open: Edge"
check_file "the responses reach the prompt" "$scratch/stdin" "fixed in abc123"
check_file "run 1's findings reach the prompt" "$scratch/stdin" "[medium] Edge"
check_file "the prompt says which run it is" "$scratch/stdin" "This is run 2"

seed_run1
respond "$(result "" "$(prior "Purges on empty read" still-open)")"
run --task "$task" --prior "$scratch/prior.md"
check "a still-open high from run 1 blocks" 2 "still-open: Purges on empty read"

seed_run1
respond "$(result "" "$(prior Edge rebuttal-accepted)")"
run --task "$task" --prior "$scratch/prior.md"
check "a run 1 high missing from prior blocks" 2 "no prior entry: Purges on empty read"

seed_run1
respond "$(result "$(finding critical "Fix broke the merge")" "$(prior "Purges on empty read" resolved)")"
run --task "$task" --prior "$scratch/prior.md"
check "a new critical in run 2 blocks" 2 "blocking: 1"

respond "$clean"
run --task "$task" --prior "$scratch/prior.md"
check "run 3 refuses" 1 "two runs"
respond "$(result "" "$(prior "Purges on empty read" resolved),$(prior "Fix broke the merge" resolved)")"
run --task "$task" --prior "$scratch/prior.md" --allow-extra-run
check "run 3 goes ahead when allowed" 0 "blocking: 0"

rm -rf "$repo/.codex-review"
respond "$clean"
out=$(cd "$repo" && STUB_EXIT=1 bash "$script" --base base --task "$task" 2>&1); code=$?
check "a codex failure exits 1" 1 "codex exited 1"
check_absent "a failed run is not counted" "$run_dir/run-1.json"

run --task "$task" --model gpt-reserve --effort low
check_file "--model overrides the default" "$scratch/args" $'-m\ngpt-reserve'
check_file "--effort overrides the default" "$scratch/args" "model_reasoning_effort=low"

if [[ $failed -ne 0 ]]; then
    echo "$failed codex review regression(s) failed"
    exit 1
fi
echo "$passed codex review regressions passed"
