# Forever beta build log

What each re-pin of the shared Forever checkout (`~/code/wow-ui-source-forever`) meant for
GuildCrafts. Newest first. Written by the `beta-build-bump` skill, including when legacynext
moved the pin and this repo reconciled afterwards. "Touches us" means a symbol in
`.claude/forever-tools/watchlist.txt` or a `C_*` call under `GuildCrafts/`. A build that moved
nothing gets an entry too: a gap here should mean "nobody checked", not "nothing happened".

## 1.60.1.70170 — 2026-10-04

Pin: `9a789c0`, unchanged. The checkout moved from legacynext's `vendor/` to the shared location
and was widened to the professions, chat and guild directories. Every pin-relative citation in
`spec/` was written against this pin. Some were made with `git show` into directories that are
checked out now. GuildCrafts is reconciled at `9a789c0`.
