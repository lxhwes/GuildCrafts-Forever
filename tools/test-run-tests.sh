#!/usr/bin/env bash
# Regressions for tools/run-tests.sh, the Test command the commit guard and workflows run.
# Each case copies the runner into a scratch tree with stub suites and a stub toolchain, so
# this never runs the real suites and the real runner never recurses into itself.
# Run from the repository root: bash tools/test-run-tests.sh
set -u

runner="$(cd "$(dirname "$0")" && pwd)/run-tests.sh"
passed=0 failed=0
scratch=$(mktemp -d "${TMPDIR:-/tmp}/gc-run-tests.XXXXXX") || exit 1
trap 'rm -rf "$scratch"' EXIT

# A tree with the runner, a stub toolchain (bin/) and the named stub suites. A suite whose
# name contains "fail" exits 1; LINT_FAIL=1 makes the stub luacheck fail.
make_tree() {
    local tree=$1; shift
    mkdir -p "$tree/tools" "$tree/GuildCrafts" "$tree/bin"
    cp "$runner" "$tree/tools/run-tests.sh"
    printf '#!/bin/sh\necho "ran $1"\ncase "$1" in *fail*) exit 1 ;; esac\n' >"$tree/bin/lua5.1"
    printf '#!/bin/sh\n[ "${LINT_FAIL:-0}" = 1 ] && exit 1\necho "Total: 0 warnings"\n' >"$tree/bin/luacheck"
    chmod +x "$tree/bin/lua5.1" "$tree/bin/luacheck"
    local s
    for s in "$@"; do
        case $s in
            *.lua) echo '-- stub' >"$tree/tools/$s" ;;
            *.sh) printf 'echo "ran %s"\ncase %s in *fail*) exit 1 ;; esac\n' "$s" "$s" >"$tree/tools/$s" ;;
        esac
    done
}

# expect <name> <want exit: 0|nonzero> <grep that must match|-> <grep that must not match|-> <tree> [env...]
expect() {
    local name=$1 want=$2 must=$3 mustnot=$4 tree=$5; shift 5
    local out code ok=1
    out=$(cd / && env "$@" bash "$tree/tools/run-tests.sh" </dev/null 2>&1)
    code=$?
    if [[ $want == 0 ]]; then [[ $code -eq 0 ]] || ok=0; else [[ $code -ne 0 ]] || ok=0; fi
    [[ $must == - ]] || grep -qE -- "$must" <<<"$out" || ok=0
    [[ $mustnot == - ]] || ! grep -qE -- "$mustnot" <<<"$out" || ok=0
    if [[ $ok -eq 1 ]]; then
        echo "PASS $name"
        passed=$((passed + 1))
    else
        echo "FAIL $name: exit $code, output:"
        sed 's/^/    /' <<<"$out"
        failed=$((failed + 1))
    fi
}

t=$scratch/pass; make_tree "$t" test-a.lua test-b.sh
expect "all suites pass" 0 "run-tests: all passed" "FAILED" "$t" PATH="$t/bin:$PATH"
expect "every suite and the lint run" 0 "ran tools/test-a.lua" - "$t" PATH="$t/bin:$PATH"

t=$scratch/lua; make_tree "$t" test-a.lua test-fail.lua test-b.sh
expect "a failing Lua suite fails the run" nonzero "FAILED: .*test-fail.lua" "all passed" "$t" PATH="$t/bin:$PATH"

t=$scratch/sh; make_tree "$t" test-a.lua test-fail.sh
expect "a failing shell suite fails the run" nonzero "FAILED: bash tools/test-fail.sh" "all passed" "$t" PATH="$t/bin:$PATH"

t=$scratch/lint; make_tree "$t" test-a.lua
expect "a lint failure fails the run" nonzero "FAILED: lint" "all passed" "$t" PATH="$t/bin:$PATH" LINT_FAIL=1

t=$scratch/both; make_tree "$t" test-fail.lua test-z.sh test-fail2.sh
expect "suites after a failure still run" nonzero "ran test-z.sh" "all passed" "$t" PATH="$t/bin:$PATH"
expect "every failure is listed" nonzero "FAILED: bash tools/test-fail2.sh" "all passed" "$t" PATH="$t/bin:$PATH"

# No lua5.1 or luacheck on PATH, and the fallback toolchain directory doesn't exist.
t=$scratch/none; make_tree "$t" test-a.lua test-b.sh
mkdir -p "$t/minbin"
ln -s "$(command -v bash)" "$t/minbin/bash"
ln -s "$(command -v dirname)" "$t/minbin/dirname"
expect "a missing toolchain fails the run" nonzero "FAILED" "all passed" "$t" PATH="$t/minbin" LUA51_BIN="$t/no-such-dir"

echo "$passed passed, $failed failed"
[[ $failed -eq 0 ]]
