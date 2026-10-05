# GuildCrafts: notes for Codex

Read `CLAUDE.md` first. It holds this project's rules, docs map, architecture notes and test
commands, and it is kept current. This file only adds what a reviewer needs. CLAUDE.md's
sections on the gist and on Codex review describe Claude's workflow, not yours.

When reviewing:
- WoW API source of truth: Gethe/wow-ui-source branch `forever` at pin 9a789c0, a shared
  checkout at `~/code/wow-ui-source-forever/wow-ui-source` (`PINS.md` beside it). Forever is a beta Mainline 1.60.1 client.
  Don't cite Retail or Classic API behaviour as fact. If the pin doesn't cover it, say it needs
  an in-game probe.
- The `tools/` suites stub WoW and never run the client or the addon message transport. Weigh
  multi-client cases they can't reach: several clients, DR loss mid-transfer, stale terms,
  reconnects.
- Out of scope: the five Classic TOCs, `GuildCrafts/Data/Data_*.lua` and `GuildCrafts/Libs/`.
  They're inherited and never edited.
- Ground every finding in file:line.
- Report material findings only. No style, naming or cleanup notes.

## Red flags

Each of these has shipped as a bug here or breaks a project rule. The IDs point at
`spec/fork-review.md`.

- Branching on the interface or build number instead of feature-detecting the API.
- A hardcoded spell, recipe, item or skill-line ID.
- A boolean written to SavedVariables. Forever may not round-trip them; store 1/0.
- A player keyed by name or `Name-Realm` where the Camelot TOC keys by GUID
  (`Modules/ForeverIdentity.lua`). Names are "First Surname" with no realm.
- An addon-message send that doesn't go through `SyncPausePolicy`.
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

## Severity

Critical and high block the pull request.

- critical: data loss or corruption that reaches other clients, a Lua error or taint on a
  path every player hits, or a release that publishes the wrong files.
- high: wrong behaviour on a common path, sync or election that stalls or splits, or any red
  flag above.
- medium: wrong behaviour on an edge case, or a changed branch with no test.
- low: anything else worth a line.
