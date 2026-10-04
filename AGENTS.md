# GuildCrafts: notes for Codex

Read `CLAUDE.md` first. It holds this project's rules, docs map, architecture notes and test
commands, and it is kept current. This file only adds what a reviewer needs. CLAUDE.md's
sections on the gist and on Codex review describe Claude's workflow, not yours.

When reviewing:
- WoW API source of truth: Gethe/wow-ui-source branch `forever` at pin 9a789c0, vendored at
  `/Users/alex/code/legacynext/vendor/wow-ui-source`. Forever is a beta Mainline 1.60.1 client.
  Don't cite Retail or Classic API behaviour as fact. If the pin doesn't cover it, say it needs
  an in-game probe.
- The `tools/` suites stub WoW and never run the client or the addon message transport. Weigh
  multi-client cases they can't reach: several clients, DR loss mid-transfer, stale terms,
  reconnects.
- Out of scope: the five Classic TOCs, `GuildCrafts/Data/Data_*.lua` and `GuildCrafts/Libs/`.
  They're inherited and never edited.
- Ground every finding in file:line.
