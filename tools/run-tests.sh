#!/usr/bin/env bash
# Lint and every tools/test-* suite: the checks ci.yml runs, and CLAUDE.md's Test command.
# Uses lua5.1 and luacheck from PATH, else LegacyNext's PUC Lua 5.1 toolchain.
set -uo pipefail
cd "$(dirname "$0")/.."

bin=${LUA51_BIN:-$HOME/code/legacynext/tools/lua51/bin}
lua=$(command -v lua5.1 || echo "$bin/lua")
luacheck=$(command -v luacheck || echo "$bin/luacheck")

failed=()
run() { echo "== $*"; "$@" || failed+=("$*"); }
lint() { (cd GuildCrafts && "$luacheck" . --no-color); }

run lint
for t in tools/test-*.lua; do run "$lua" "$t"; done
for t in tools/test-*.sh; do run bash "$t"; done

if ((${#failed[@]})); then
    printf 'FAILED: %s\n' "${failed[@]}"
    exit 1
fi
echo "run-tests: all passed"
