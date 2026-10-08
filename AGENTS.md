<!-- Shared by every coding agent. Claude Code imports it from CLAUDE.md, so edit it under ~/.claude/rules/instruction-files.md. Claude-only workflow stays in CLAUDE.md. -->
# GuildCrafts: notes for coding agents

## What this project is

The WoW Forever fork of GuildCrafts (`lxhwes/GuildCrafts-Forever`, from `dkruenbo/GuildCrafts`,
MIT). Lua, AceAddon-3.0. It tracks guild members' profession recipes and syncs them between
addon users through a DR/BDR election over the GUILD addon message channel.

WoW Forever is a beta Mainline client, 1.60.1. It loads `GuildCrafts/GuildCrafts_Camelot.toc`
(the client reads `_Camelot`, not `_Forever`; verified in game 2026-10-02).

Only Forever is maintained and published here. That was the condition of the upstream
author's permission (`docs/ORIGIN.md`).

## Rules

- Never edit the five Classic TOCs (`GuildCrafts.toc`, `_Vanilla`, `_Wrath`, `_Cata`, `_Mists`)
  or `GuildCrafts/Data/Data_*.lua`. They are inherited and stay untouched.
- No file published from this fork may be tagged for another flavor.
- Gethe/wow-ui-source branch `forever`, at the pin in `.claude/forever-tools/pin`, is the API
  source of truth. It wins over docs and training data, and Retail or Classic behaviour is never
  evidence. It's a shared checkout at `~/code/wow-ui-source-forever/wow-ui-source`, with
  `PINS.md` beside it. Anything the pin doesn't cover, guild roster behaviour included, needs an
  in-game probe.
- Feature-detect APIs. Never branch on interface number. Never hardcode IDs.
- SavedVariables booleans may not round-trip on Forever; store 1/0 until proven otherwise.
- Players are keyed by GUID on Forever (`Modules/ForeverIdentity.lua`, Camelot TOC only).
  Names are "First Surname" with no realm.
- When a PR changes a function, rewrite that function's upstream-history comments ("Patch 3",
  "1.1.7+") to say what the code does. Fork plan IDs (H22, F8) are fine. No comment-only PRs
  during the beta (F46, [#37](https://github.com/lxhwes/GuildCrafts-Forever/issues/37)).

## Docs map

| Doc | What it's for |
|---|---|
| `spec/forever-plan.md` | Phases to the Nov 4 launch, their gates, the plan-ID → issue index, decisions. Work items are GitHub Issues; check both before proposing work |
| `spec/migration-forever.md` | Dated decisions and in-game evidence |
| `docs/releasing.md` | The release runbook |
| `docs/testing.md` | Regression commands, solo and two-client procedures |
| `docs/ingame-commands.md` | Copyable `/run` probes, mirrored to the gist |
| `docs/beta-builds.md` | What each re-pin of the shared Forever checkout meant for GuildCrafts, newest first |
| `docs/user-guide.md` | Player-facing usage and limitations |
| `docs/ORIGIN.md` | Provenance and the author's permission, quoted verbatim |
| `spec/fork-review.md` | The 2026-09-28 review that defines F1–F21 and C1–C6; historical, status lives in the issues |
| `spec/curseforge-audit.md` | The 2026-10-03 audit of upstream player reports that defines F22–F40; evidence at `60c6b32` |
| `spec/later/` | Implementation specs for Later items N1–N8, the N4 ADR and threat model, and their research |
| `RFC/`, other `spec/*.md`, `ROADMAP.md` | Upstream history, bannered as such |

In markdown table cells, escape `|` as `\|`, even inside backticks.

## Build and release

`.github/workflows/release.yml` is the only release path. Never upload a hand-made zip:
`zip -r GuildCrafts/` ships all six TOCs. A pushed `v*` tag publishes to CurseForge. Procedure
and safeguards: `docs/releasing.md`.

- `GuildCrafts_Camelot.toc` `## Version:` is `@project-version@`, filled in by the packager.
  Never bump a TOC version by hand.
- `GuildCrafts.DISPLAY_VERSION` is read from the loaded TOC at load. It reads `dev` when
  unpackaged. `/gc comms` prints it on its first line.

## Git workflow

- Branches: `feature/<description>`, `fix/<description>`, `docs/<description>`
- PRs are squash-merged into `main`, branch deleted after merge. The squash message is the PR
  title and body; merge commits are off
- Force-push to feature branches is fine (they're never shared before PR). After a rebase, use
  `git push --force-with-lease`
- Status lives only in the GitHub issues; `spec/forever-plan.md` keeps phases, gates, the ID
  index and decisions. Every PR fills in the template's `### Tracking` block
- Never write a closing keyword (close, fix, resolve and their forms) next to an issue number in
  a PR title, body or commit message. CI rejects it; issues close through the Tracking block

## CHANGELOG

- New entries go under `## Unreleased` until a release
- Date format: `YYYY-MM-DD`
- Sections: `### New features`, `### Improvements`, `### Fixes`
- Keep upstream's 2-space indentation

## Testing

`bash tools/run-tests.sh` runs luacheck and every `tools/test-*` suite under PUC Lua 5.1, the
same checks as `.github/workflows/ci.yml`. The suites stub WoW APIs. They never run the game
client or the addon message transport; in-game procedures are in `docs/testing.md`.

- Declare any new WoW global in `GuildCrafts/.luacheckrc` `read_globals`.
- Modules capture WoW globals as locals at load (`local GetNumSkillLines = GetNumSkillLines`).
  To test a client that lacks an API, nil the global and `dofile` a fresh copy of the module
  (see the Forever empty-read case in `tools/test-profession-sync.lua`).

## Reviewing

- Weigh multi-client cases the suites can't reach: several clients, DR loss mid-transfer, stale
  terms, reconnects.
- Out of scope: the five Classic TOCs, `GuildCrafts/Data/Data_*.lua` and `GuildCrafts/Libs/`.
- Ground every finding in file:line. Report material findings only: no style, naming or cleanup
  notes.

### Red flags

Each of these has shipped as a bug here or breaks a project rule. The IDs point at
`spec/fork-review.md`.

- Branching on the interface or build number instead of feature-detecting the API.
- A hardcoded spell, recipe, item or skill-line ID.
- A boolean written to SavedVariables. Forever may not round-trip them; store 1/0.
- A player keyed by name or `Name-Realm` where the Camelot TOC keys by GUID
  (`Modules/ForeverIdentity.lua`). Names are "First Surname" with no realm.
- An addon-message send that doesn't go through `SyncPausePolicy`, other than the
  `CRITICAL_SIGNALS` it deliberately bypasses (`Comms.lua`).
- A wire-format change without a bump to `GuildCrafts.VERSION` or `DATA_FORMAT_VERSION`, or a
  bump without a wire change.
- Data purged, or a removal broadcast, because a read came back empty or partial (F1, F2, F19).
- Recipes from someone else's view (linked, guild or guildmate) filed under the player (F5).
- Taint: writing a global such as `_`, or calling a protected function such as `ReloadUI` (F10,
  F14).
- Code that keeps the return value of `C_Timer.After`, which returns nothing (F9).
- `""` accepted as a name or key. It's truthy in Lua (F21).
- String operations on chat text that can be a secret value (F18).
- Guild chat that echoes text another player sent (F4).
- An edit to a Classic TOC, a `Data_*.lua` file, or a TOC's `## Version:` line.
- A new WoW global missing from `GuildCrafts/.luacheckrc`.
- A behaviour change with no regression test in `tools/`.

### Severity

Critical and high block the pull request.

- critical: data loss or corruption that reaches other clients, a Lua error or taint on a
  path every player hits, or a release that publishes the wrong files.
- high: wrong behaviour on a common path, sync or election that stalls or splits, or any red
  flag above.
- medium: wrong behaviour on an edge case, or a changed branch with no test.
- low: anything else worth a line.
