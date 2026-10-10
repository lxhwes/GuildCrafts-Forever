# Forever beta build log

What each re-pin of the shared Forever checkout (`~/code/wow-ui-source-forever`) meant for
GuildCrafts. Newest first. Written by the `beta-build-bump` skill, including when legacynext
moved the pin and this repo reconciled afterwards. "Touches us" means a symbol in
`.claude/forever-tools/watchlist.txt` or a `C_*` call under `GuildCrafts/`. A build that moved
nothing gets an entry too: a gap here should mean "nobody checked", not "nothing happened".

## 1.60.1.70334 — 2026-10-09

Pin: `15666a6` → `2ced784`

**Does not touch us**
- `SetFrameStrata` now takes secret arguments when untainted, and `GetFrameStrata` returns a
  secret under the new `Enum.SecretAspect.FrameStrata`
  (`SimpleFrameAPIDocumentation.lua:435-437`, `:1293-1297`). GuildCrafts passes literal strata
  strings (`UI/MainFrame.lua:123`, `:2103`, `:2149`; `Modules/Report.lua:248`) and never reads
  strata back. `SetFrameStrata` added to the watchlist.
- `Enum.ChatChannelType` gained `DiscordParty` 5, `DiscordGuild` 6 and `DiscordSolo` 7. That
  moved `RegisterAddonMessagePrefixResult` and `SendAddonMessageResult` down three lines in
  `ChatConstantsDocumentation.lua` (now `:133-143` and `:147-166`). Their values are unchanged.
  The docs citing the old lines pin them to an earlier commit, so they stay as written.
- `ProfessionsMixin` keeps the frame open on `TRADE_SKILL_CLOSE` while the book page shows, and
  closes the trade skill on abandon. Blizzard call sites only. The scan hooks
  `TRADE_SKILL_SHOW` and `TRADE_SKILL_LIST_UPDATE`, whose handling did not change.
- `Blizzard_ProfessionsCrafting.lua` lost 10 gamepad lines, so the View Guild Crafters code
  cited in `spec/fork-review.md` is now at `:816-820` and `:1099-1105`. The claim holds.
- `Blizzard_ProfessionsTemplates/Camelot/Blizzard_ProfessionsTemplates.lua` deleted. Nothing
  here cites it.
- The rest of the 55 sparse-set files (208 repo-wide) is VoiceChat typing (`number` →
  `VoiceChatID`), Discord voice, gamepad, settings and achievement UI. The Camelot TOC's
  `## Interface: 16001` still matches.

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
