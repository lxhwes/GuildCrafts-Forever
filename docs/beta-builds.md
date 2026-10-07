# Forever beta build log

What each re-pin of the shared Forever checkout (`~/code/wow-ui-source-forever`) meant for
GuildCrafts. Newest first. Written by the `beta-build-bump` skill, including when legacynext
moved the pin and this repo reconciled afterwards. "Touches us" means a symbol in
`.claude/forever-tools/watchlist.txt` or a `C_*` call under `GuildCrafts/`. A build that moved
nothing gets an entry too: a gap here should mean "nobody checked", not "nothing happened".

## 1.60.1.70245 — 2026-10-06

Pin: `e3ecc27` → `15666a6`

**Does not touch us**
- Only `version.txt` changed. No file in the sparse set moved, and the Camelot TOC's
  `## Interface: 16001` still matches.

## 1.60.1.70205 — 2026-10-04

Pin: `9a789c0` → `e3ecc27`

**Does not touch us**
- `ChatFrameEditBoxBaseMixin:ExtractTellTarget` second-word pattern `%w+` → `%S+`
  (`Blizzard_ChatFrameBase/Shared/ChatFrameEditBox.lua:85`). The `[W]` button sets the tell
  target directly and skips this parser. Only the `/w name text` fallback in
  `UI:OpenWhisper` goes through it, and the new pattern also matches a second name word with
  non-alphanumeric bytes. One-line edit, so the `:73-120` citation in `UI/MainFrame.lua` holds.
- `Blizzard_SharedTalentUI/Blizzard_TalentDisplay.lua`: `GenerateClosure` →
  `GenerateFlatClosure`, twice

## 1.60.1.70170 — 2026-10-04

Pin: `9a789c0`, unchanged. The checkout moved from legacynext's `vendor/` to the shared location
and was widened to the professions, chat and guild directories. Every pin-relative citation in
`spec/` was written against this pin. Some were made with `git show` into directories that are
checked out now. GuildCrafts is reconciled at `9a789c0`.
