<!-- Before editing, read ~/.claude/rules/instruction-files.md. Shared project rules live in AGENTS.md; this file holds what only Claude Code uses. -->
# GuildCrafts: Claude Code notes

@AGENTS.md

## Agent conventions

Test command: `bash tools/run-tests.sh`
High-risk paths: `GuildCrafts/Modules/Comms.lua`, `GuildCrafts/Modules/SyncPausePolicy.lua`, `GuildCrafts/Modules/ForeverIdentity.lua`, `GuildCrafts/Modules/Data.lua`

<!-- The commit guard runs the Test command before every commit. .claude/rules/sync.md loads for the High-risk paths; keep its globs and this line in step. -->

## Tracking

The `track` skill keeps the issues and `spec/forever-plan.md` in step, and the session-start
`Tracking:` line reports drift. A nightly `.github/workflows/plan-index.yml` run fails on drift too.

## Codex review

Every code PR gets `tools/codex-review.sh` after the Test command passes and before the PR
opens; the `codex-review` skill has the procedure. Doc-only PRs skip it. `/review-loop`'s
Codex stage reviews uncommitted changes and doesn't count as one of the two runs.

After 2–3 failed attempts at the same failure, ask the `codex:codex-rescue` agent for an
independent diagnosis before taking it to Alex. Say "read-only, diagnosis only" in the
prompt, because the agent adds `--write` by default.

## Forever tooling

The `forever-tools` plugin's skills read `.claude/forever-tools/config.env`. The shared checkout
serves LegacyNext too, so its re-pins show up here as `PIN_MOVED` at session start; catch up
with `beta-build-bump` in reconcile mode.

## In-game commands

Claude can't run the game, and the Forever beta runs on Alex's other PC. Probes go in
`docs/ingame-commands.md`, which a secret gist mirrors; `.claude/rules/ingame-commands.md` has
the rules and loads when that file is opened. Alex pastes results back into chat. Record them
in `spec/migration-forever.md` and never assume a result.
