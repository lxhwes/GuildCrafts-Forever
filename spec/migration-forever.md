# GuildCrafts — WoW Forever migration record

> Target: WoW Forever (Interface `16001`, client `1.60.1`, Mainline API)
> Current: Forever loads through `GuildCrafts_Camelot.toc`. `feature/forever-support` was merged
> to `main` by PR #1 (merge commit `8f0dc69`, 2026-10-02 23:06 -04:00)
> API source of truth: Gethe/wow-ui-source branch `forever`, read at legacynext's pin
> `9a789c0` (`1.60.1.70170`). Citations below are against that pin unless marked "in game".

Forever runs the retail (Mainline) API under a Classic-shaped interface number. The Forever
port (`c0a7e11`) already covers the scan and lookup fallbacks (`C_Item`, `C_SpellBook`,
`C_TradeSkillUI.GetRecipeSchematic`). This record covers what stood between that port and a
clean load: which TOC the client reads, profession pruning, and the expansion filter with no
recipe data loaded. Only the Forever flavor is maintained here; the other five TOCs and
`Data/Data_*.lua` stay as upstream shipped them.

This file is the dated record of decisions and evidence. Planned work and open questions are
in `spec/forever-plan.md`. Test procedures are in `docs/testing.md`, and the release procedure
is in `docs/releasing.md`.

Rules that apply to every task: feature-detect APIs, never branch on interface number, never
hardcode IDs, and store `1`/`0` rather than booleans in SavedVariables until a boolean
round-trip is proven on Forever.

---

## Summary of changes

| Area | Type | Status |
|------|------|--------|
| TOC suffix — ship `_Camelot`, drop `_Forever` | Mechanical | Done (`0e373e7`), verified in game |
| Profession pruning (`GetClassicExpansionLevel`) | Gate added on client skill lines | Expansion level verified in game; gate inputs verified (`PSL`) |
| Expansion filter / recipe tagging with no `Data_*.lua` | None needed | Verified in game: no buttons, no Lua errors |
| SyncPausePolicy — Forever addon restrictions | Extend existing module | Implemented; API verified in game, encounter event not yet |
| Display version | None | `@project-version@`, packager-filled; `DISPLAY_VERSION` reads it |
| Profession drop/relearn sync (PR #1 review) | Retain drop history; live drop validation; per-profession revisions | Implemented; 28 Lua 5.1 regression checks pass; in-game verification pending |
| Forever-only packaging | Release workflow (`8b88277`) | Implemented; GitHub dry run passed 2026-10-03 (run `37093088953`); no CurseForge upload yet |

---

## Multi-TOC strategy

Forever is one more TOC in the existing multi-TOC folder. It lists the shared files and **no
`Data\Data_*.lua`**, the same as `GuildCrafts_Vanilla.toc`.

```
GuildCrafts/
  GuildCrafts.toc              # TBC Anniversary (Interface: 20506) — upstream, untouched
  GuildCrafts_Vanilla.toc      # Classic Era (11507) — upstream, untouched
  GuildCrafts_Wrath.toc        # WotLK Classic (30403) — upstream, untouched
  GuildCrafts_Cata.toc         # Cata Classic (40402) — upstream, untouched
  GuildCrafts_Mists.toc        # MoP Classic (50504) — upstream, untouched
  GuildCrafts_Camelot.toc      # WoW Forever (16001) — maintained here
```

Blizzard's own forever-branch TOCs gate files with `AllowLoadGameType`, and Forever's game
type is `camelot` (for example `Blizzard_AchievementUI.toc:8`,
`[Game]\Blizzard_AchievementUI.lua [AllowLoadGameType camelot]`). No vendored TOC uses a
`_Forever` or `_Camelot` filename suffix, so the suffix had to be settled in game.

**Packaging:** the BigWigs packager reads every TOC in the folder, so a multi-TOC package would
also tag the Classic flavors. The Forever-only release workflow (`8b88277`) solves this; see
"Packaging" below and `docs/releasing.md`.

---

## Task 1 — Ship Forever through `GuildCrafts_Camelot.toc`

**Done in `0e373e7`.** In-game results on 1.60.1, 2026-10-02, one folder layout per full
client restart:

| TOCs in the folder | Addon list | Probe |
|---|---|---|
| `_Forever` only | Not listed | — |
| `GuildCrafts.toc` + `_Forever` | Listed, out of date | `GC true 2.0.2 nil false false`: TBC TOC chosen, not loaded |
| `_Camelot` only | Listed, not out of date, enabled | `TOC 16001 true 2 true true` |
| All five upstream TOCs + `_Camelot` | Listed | `TOC 16001 true 2 true true` |

So the client reads `_Camelot`, ignores `_Forever`, and prefers `_Camelot` over the
unsuffixed TBC TOC.

The `TOC` probe prints `C_AddOns.GetAddOnInterfaceVersion`, the `loadable` and `reason`
returns of `C_AddOns.GetAddOnInfo`, `C_AddOns.GetAddOnEnableState` and
`C_AddOns.IsAddOnLoaded` (`AddOnsDocumentation.lua:98-200`, `:322`).

`GuildCrafts_Camelot.toc` now has:

```
## Interface: 16001
## Author: GuildCrafts Team
## Version: @project-version@
## X-Curse-Project-ID: 1469206
```

It is not part of the hand-bumped version checklist in `CLAUDE.md`.

---

## Task 2 — Profession pruning

### Earlier hypothesis (disproved in game)

`Data.lua:2054` reads:

```lua
local _expansionLevel = GetClassicExpansionLevel and GetClassicExpansionLevel() or 99
```

The concern was that `GetClassicExpansionLevel` doesn't exist on a Mainline client, so the
`or 99` fallback would skip pruning and Forever characters would get Jewelcrafting and
Inscription.

### What the client does

The function is documented on Forever (`ExpansionInfoDocumentation.lua:40-47`, no arguments,
non-nilable number). In game on 1.60.1 (2026-10-02):

```
EXP 0 0 0 0 1.60.1 16001
```

`GetClassicExpansionLevel()`, `GetExpansionLevel()`, `GetServerExpansionLevel()` and
`LE_EXPANSION_LEVEL_CURRENT` all read `0`. The `< 1` branch drops Jewelcrafting and the `< 2`
branch drops Inscription (`Data.lua:2055-2071`). What's left is the vanilla tracked set:
Alchemy, Blacksmithing, Enchanting, Engineering, Leatherworking, Tailoring, Mining, Herbalism,
Skinning and Cooking.

### Change

**None** to the expansion-level check. It reads a value the client reports; it isn't keyed on
the interface number. A skill-line gate was added later (`c16b09f`); see "Risk and gate".

### Risk and gate

Forever is Classic+. Blizzard could raise the reported expansion level while still shipping no
Jewelcrafting or Inscription. The `< 1` and `< 2` checks would then stop pruning, and both
would come back as tracked professions that don't exist.

- **Impact.** Cosmetic. The left panel draws a row for every tracked profession
  (`MainFrame.lua:755-790`), so two empty `Jewelcrafting (0)` and `Inscription (0)` rows would
  appear. No stored data changes, because no character can learn either profession.
- **Detection.** Immediate. The rows show on the first `/gc` after the client change.
- **Earlier reasoning, before the `PSL` result.** A Forever-specific gate needs one of two
  things. One is a hardcoded skill-line ID, which the project rules forbid. The other is the
  list from `C_TradeSkillUI.GetAllProfessionTradeSkillLines()`
  (`TradeSkillUIDocumentation.lua:121`), which was unverified on Forever at the time. If that
  list holds only the professions the client actually has, pruning can be built from it with no
  IDs and no expansion-level check.
- **`PSL` result (in game, 2026-10-02).** The list holds Alchemy, Blacksmithing, Enchanting,
  Engineering, Herbalism, Leatherworking, Mining, Skinning and Tailoring, plus
  `Test Profession [DNT]`. Each appears twice: as a parent line (171, 164, 333, 202, 182, 165,
  186, 393, 197) and as a child line (2937–2948) whose `parentProfessionName` is the same name.
  **Jewelcrafting and Inscription are absent**, so the list can gate them. Cooking, First Aid
  and Fishing are also absent: secondary skills aren't in this list, so a gate may only use it
  for primary professions.
- **Gate (implemented in `c16b09f`).** `Data:ApplyClientProfessionGate`, run from
  `Data:OnEnable`, drops Jewelcrafting and Inscription when the client's skill-line list is
  non-empty and names neither. It only narrows the expansion-level result. If the list is
  missing or empty, the expansion-level check stands.

---

## Task 3 — Expansion filter and recipe tagging with no `Data_*.lua`

The Camelot TOC loads no recipe data, so `GuildCrafts.TBC_ITEM_IDS`, `WOTLK_ITEM_IDS`,
`CATA_ITEM_IDS` and `MOP_ITEM_IDS` are all nil. Classic Era has run this path since
multi-TOC support landed: `GuildCrafts_Vanilla.toc` loads no data files either.

| Step | Code | Behaviour with no data |
|---|---|---|
| Tagging | `Data:GetExpansionTag`, `Data.lua:240-250` | Every recipe returns `"ORIG"` |
| Default filter | `DB_DEFAULTS.profile.expansionFilter`, `Data.lua:274-282` | `{ ORIG = true }` |
| Backfill | `Data:OnInitialize`, `Data.lua:296-302` | Nothing added; every guard is nil |
| Buttons | `MainFrame.lua:437-497` | None built. The Vanilla button sits inside the TBC branch |
| Search box anchor | `MainFrame.lua:506-510` | Anchors to the scope button |
| Button visuals | `UI:_UpdateExpansionFilterVisuals`, `MainFrame.lua:2642-2645` | Returns early (no Vanilla button) |
| Filtering | `MainFrame.lua:1064-1067`, `:1247-1249`, `:2789-2791` | `expansionFilter.ORIG` is true, so every recipe shows |

On SavedVariables: AceDB strips values equal to their defaults when it saves, and with no
buttons there is no way to toggle a tag, so `expansionFilter` never gets written. This path
doesn't depend on booleans round-tripping.

### Change

**None.** Every recipe is filed under "Vanilla" internally, but no button or label shows the
tag, so users can't see it. Telling new Forever recipes apart is recipe-data work, which is
out of scope (C5 in `spec/forever-plan.md`).

---

## Task 4 — SyncPausePolicy: Forever addon restrictions

Forever blocks addon messages during some activities. Approved 2026-10-02 and implemented in
`Modules/SyncPausePolicy.lua` (`71526af`). `RA` and `RS` confirmed the API in game. Whether the
event fires at a boss pull is still open: Q2 in `spec/forever-plan.md`, answered by the `RE`
probe in `docs/ingame-commands.md`, which `docs/testing.md` section R runs.

### Documented signals (source only, never run in game)

| Signal | Citation |
|---|---|
| `C_RestrictedActions.IsAddOnRestrictionActive(type)` returns bool; always false while `ADDON_RESTRICTION_STATE_CHANGED` is being dispatched | `RestrictedActionsDocumentation.lua:55-67` |
| `ADDON_RESTRICTION_STATE_CHANGED (type, state)`; fires before a restriction activates and after it deactivates | `RestrictedActionsDocumentation.lua:96-107` |
| `Enum.AddOnRestrictionType`: Combat 0, Encounter 1, ChallengeMode 2, PvPMatch 3, Map 4, Chat 5 | `RestrictedActionsConstantsDocumentation.lua:19-31` |
| `Enum.AddOnRestrictionState`: Inactive 0, Activating 1, Active 2 | `RestrictedActionsConstantsDocumentation.lua:6-15` |
| `C_ChatInfo.InChatMessagingLockdown()` | `ChatInfoDocumentation.lua:293` |
| `SendAddonMessage` result 11 = `AddOnMessageLockdown` | `ChatConstantsDocumentation.lua:162` |

### Shape (as approved and implemented in `71526af`)

Extend `Modules/SyncPausePolicy.lua`; don't add a second gate.

- In `OnEnable`, if `C_RestrictedActions` and `Enum.AddOnRestrictionType` exist, register
  `ADDON_RESTRICTION_STATE_CHANGED`. Wrap the registration in `pcall`, because AceEvent
  throws on an unknown event name.
- Keep an in-memory set of restriction types whose state is Activating or Active. Clear a
  type when its state is Inactive.
- `ShouldPause()` also returns true while Encounter, ChallengeMode, PvPMatch, Map or Chat is
  set. Combat stays on the existing `InCombatLockdown` path.
- Read every type's current state once at `OnEnable`, to catch a `/reload` inside a
  restriction.
- Nothing is persisted, so the 1/0 SavedVariables rule doesn't apply.

On Classic clients `C_RestrictedActions` is nil, so those flavors are unaffected.

Not included, pending a decision: holding `HELLO`/`HEARTBEAT`/`GC_ACK` during a Chat
restriction, keeping the DR watchdog fresh under Map or Chat, keeping `!gc` silent under a
restriction, and a grace period after a restriction lifts. These wait on the `RE` result (H8 in
`spec/forever-plan.md`).

---

## What does NOT need to change

- **Other flavors' TOCs and `Data/Data_*.lua`** — untouched by design
- **Transport and election** — profession-reset fixes below extend the existing payloads; `VERSION` and `DATA_FORMAT_VERSION` are now 3
- **Recipe key system** — positive itemID / negative spellID
- **Profession pruning** — Task 2
- **Expansion filter** — Task 3

---

## Forever-specific edge cases (known, not in this record's scope)

These come from the 2026-09-28 fork review and legacynext's in-game notes. Finding IDs (F#, C#)
are indexed, with current status, in `spec/forever-plan.md`. They affect behaviour
after load, not whether the addon loads.

- **Identity (F17), verified in game 2026-10-02.**
  - `UnitFullName`, `UnitName` and `UnitNameUnmodified` all return `Geo`, `Prizm`: first name,
    then surname. `GetPlayerKey` (`Data.lua:436-440`) builds `Geo-Prizm`.
  - The guild roster names the same player `Geo Prizm`, with a space and no realm.
    `CHAT_MSG_ADDON` reports the sender as `Geo Prizm` too.
  - `NormalizeMemberKey("Geo Prizm")` appends the local realm and gives
    `Geo Prizm-ClassicBetaPvP`, which never equals a self-reported key. `PruneRoster`
    (`Data.lua:1868-1935`) will mark every member absent and tombstone them after 7 days.
  - `GetGuildRosterInfo` returns the GUID as its 17th value (`Player-4619-012F81BC`), which
    matches `UnitGUID("player")`.
  - The guild spans servers: one member's GUID starts `Player-4613-`, the rest `Player-4619-`.
  - `GetRealmName()` is `Classic Beta PvP`; `GetNormalizedRealmName()` is `ClassicBetaPvP`,
    the same as GuildCrafts' own normalisation. The 10-02 record had `ClassicBetaPVP`; Alex read
    `ClassicBetaPvP` off the screen on 2026-10-04. Forever
    has no realms; it is split only by ruleset (PvP or PvE), so `GetRealmName()` names the
    ruleset.
  - **Fixed:** `Modules/ForeverIdentity.lua`, loaded only from the Camelot TOC, keys members by
    GUID. Senders and roster rows resolve to GUIDs through the roster, and names are read back
    for display and whispers. Classic flavors keep `Name-Realm`, using the defaults in
    `Data:GetMemberName`, `Data:GetWhisperTarget` and `Data:RosterMemberKey`.
  - Still unverified: the sender name for a guildmate on another server (GUID prefix 4613 vs
    4619), and whether an addon whisper to `First Surname` reaches them. Tracked as Q5 in
    `spec/forever-plan.md`; `docs/testing.md` section W tests it.
- **ChatThrottleLib v31 taint (F18). Fixed:** the bundled copy is v32 from Ace3
  `Release-r1403` (sha256 `3491b6c9…6dde8`). Its hooks return early when text or destination is a
  secret value (`ChatThrottleLib.lua:282`, `:292`). It's otherwise identical to v31, and
  AceComm-3.0 (MINOR 14) is unaffected. The unused standalone v29 copy is removed. Whether this
  clears the taint in game is unverified (Q6 in `spec/forever-plan.md`).
- **Empty profession read purges data (F19), fallback confirmed absent in game 2026-10-02.**
  `DetectProfessions` runs 5s after login or `/reload`, not at logout. `SKL` printed
  `false false false true`: `C_SkillLine`, global `GetNumSkillLines` and global
  `GetSkillLineInfo` don't exist; only `C_SkillInfo` does. So when `GetProfessions()` comes back
  empty, the fallback (`Data.lua:69-89`) reads zero lines. Every stored profession is then
  purged and its removal broadcast. legacynext saw professions read empty at `PLAYER_LOGOUT`
  (`CLAUDE.md:254-257`). **Fixed:** detection never removes a profession that holds recipes;
  `/gc drop <profession>` is the only path, removals carry `x = 1` and must not predate
  that profession's stored revision, and
  `MergeIncoming` keeps professions an incoming entry lost without a drop marker
  (`Data:CarryOverProfessions`).
  `PROF` on the same day: slot 1 Alchemy, slot 2 Herbalism, slot 5 Cooking, slots 3, 4, 6 and 7
  empty. That matches the positions GuildCrafts reads.
  **PR #1 follow-up (implemented, 2026-10-02):** `dropped[profName]` retains the last explicit
  drop revision after relearning. Full snapshots and recipe deltas carry that history.
  A later drop starts a new recipe generation, so carry-over and the partial-scan guard
  cannot preserve pre-drop recipes. Within the same generation those protections still
  apply. `/gc drop` performs a live profession read and preserves recipes if the API errors
  or returns an unnamed occupied slot. A successful empty read is accepted for this
  explicit command, allowing removal after the last profession is unlearned.
  **H9 (PR #43, issue closed 2026-10-04) reverses that for Forever:** on a client with no
  skill-line source, an empty `GetProfessions()` read now counts as unreadable, so `/gc drop`
  refuses and asks the player to try again. Clients with skill lines still accept it.
  Professions have their own `lastUpdate`; unrelated updates cannot block a removal.
  Local mutations advance `lastUpdate` to `max(time(), previous + 1)`; no-change scans
  cannot move it backwards. Equal-version sync exchanges entries with drop history and
  pulls the requesting owner's entry, then reconciles previously unseen drop markers.
  Protocol and data-format versions are 3.
  **Local verification:** `tools/test-profession-sync.lua` passed all 28 checks on Lua
  5.1.5; `luac -p` passed for Core, Data, Comms and the regression script. In-game results
  for these fixes have not been supplied.
- **`/gc reset` calls `ReloadUI()` (F14).** Reported as protected on Forever. Disproved in game
  on 2026-10-04: `RLX` reloaded the UI from insecure code (see "Probe run, 2026-10-04"). What
  `/gc reset` clears is still open in H7.
- **Favorites stored booleans. Fixed in H13 (PR #67, issue closed 2026-10-04).**
  `Modules/Favorites.lua` wrote `favoriteRecipes[key] = true` and `favoriteMembers[key] = true`
  to `GuildCraftsCharDB`. It now stores `1`, under the 1/0 rule, and rewrites saved `true`
  entries as `1` at login. `tools/test-favorites.lua` covers it.

---

## Probe run, 2026-10-04

Alex ran the probe set from `docs/ingame-commands.md` on build `1.60.1.70205` and posted the
output as gist comment 6406829 (2026-10-05 02:22 UTC, 22:22 local on 10-04). Raw lines are quoted
as posted. The `GTS` function names came back with spaces in them, so at least part of the paste
was retyped. Citations are against pin `e3ecc27` (`1.60.1.70205`).

Unchanged from 2026-10-02: `GC true @project-version@ 1469206 true true`,
`TOC 16001 true 2 true true`, `EXP 0 0 0 0 1.60.1 16001`, `SKL false false false true`,
`SND Geo Prizm`, `RA true true true true false`, `RS` (all six types in state 0), the `PSL`
list (no Jewelcrafting or Inscription; `Test Profession [DNT]` on 2933 and 2934), and
`SP false false false false`.

| Probe | Result | What it settles |
|---|---|---|
| `TS` | `TS Alchemy nil 197 7` | 7 of 197 Alchemy recipes learned, up from 5 |
| `PROF` | 1 Alchemy (5), 2 Herbalism (6), 3 First Aid (4), 4 Fishing (8), 5 Cooking (7), 6–7 nil | First Aid and Fishing, learned since 10-02, fill slots 3 and 4 as Forever's ProfessionsBook expects. A test character for H17 now exists |
| `CAT` | `CAT true true 2 2424`; `2424 table Alchemy nil`; `2592 table SEASON OF DISCOVERY nil` | `GetCategoryInfo` and `GetCategories` exist. Alchemy has two top-level categories, neither with a parent. Which category a recipe resolves to is the `CATR` probe |
| `ME` | `Geo Prizm Geo Prizm Geo Prizm Player-4619-012F81BC Classic Beta PvP ClassicBetaPvP` | Same as 10-02, except `GetNormalizedRealmName()` reads `ClassicBetaPvP`, checked on screen. The 10-02 record had `ClassicBetaPVP`. Either that was a transcription slip or the client changed; nothing recorded can tell which |
| `GR` | `GR true 74 Grim`; 8 online, on server prefixes 4613 and 4619 | Same shape as 10-02 |
| `GRO` | `GRO 74 8 66 66`, with Show Offline Members checked and unchecked | The roster API lists all 74 members either way, and all 66 offline rows have a name and a GUID. H3's premise and F35 don't reproduce on this build |
| `TIME` | `TIME 1791166608 1791166605 3 2026-10-05 02:16:48` | `GetServerTime()` exists, sits 3 s from the local clock, and its UTC date matches the time of the run. Usable for H2 |
| `BLD` | `BLD 1.60.1 70205 Oct 2 2026 16001` | The client is on 70205, the build the shared checkout was re-pinned to (#83). The localized version and build info returns weren't in the paste |
| `GTS` | All five functions return `false` on Alex's own profession. The client doesn't offer a guildmate's profession from the roster | `IsGuildTradeSkillsEnabled` is false. `IsTradeSkillLinked`, `IsTradeSkillGuild` and `IsTradeSkillGuildMember` exist, though the API docs don't list them; Blizzard calls all three (`Blizzard_ProfessionsTemplates/Blizzard_Professions.lua:378`). The linked-view skip in the scan is live. A guild view can't be opened on this build, so F5 can't happen here yet |
| `CHL` | `CHL true true true true` | `ChatFrameUtil.InsertLink` and `OpenChat` exist, which PR #79 uses. Clicking shift-click and `[W]` is still unchecked |
| `CHT` | `CHT true true false true true true` | Both `SendChatMessage` and `C_ChatInfo.SendChatMessage` exist, and they're different functions. The global is a wrapper in `Blizzard_DeprecatedChatInfo/Deprecated_ChatInfo.lua:8-10`, defined only when the `loadDeprecationFallbacks` CVar is on (`:4`). The `ChatEdit_InsertLink`, `ChatFrame_OpenChat` and `ChatFrame_SendTell` globals come from the same gated file (`Deprecated_ChatFrame.lua:4`, `:43`, `:74`, `:84`). The TOC notes say they "will be removed at the next expansion". `!gc` and `[G]` call the global, so they depend on that CVar |
| `TELL` | `TELL Geo true`; no header reported | Not a two-word test. The probe used only `UnitName`'s first return, so it opened a whisper to `Geo`. Fixed in `docs/ingame-commands.md`; re-run pending |
| `RL` | `RL true true true nil` | `ReloadUI` and `C_UI.Reload` exist. `issecurevariable("ReloadUI")` returned `true`, `nil`: secure, and no addon has tainted it |
| `RLX` | "it reloaded" | `ReloadUI()` called from insecure code reloads the UI. It isn't protected on 70205, so F14's premise is wrong |

Not run: `RE`, which needs a dungeon (Q2).

---

## Test results

The solo and two-client procedures moved to `docs/testing.md` on 2026-10-03. The results below
stay here.

### Solo checklist

Run on a Forever character with the full TOC set installed from a source checkout.

- Items 3–8 passed on 2026-10-02. Item 7's scan: Alchemy 5 of 197. Item 8 passed the same day.
- Item 9 passed on 2026-10-03: `/gc comms` read `Comms Status (GuildCrafts dev)`, the expected
  value for an unpackaged copy.
- Items 1 and 2 are the TOC experiments in Task 1.

**Smoke test on merged `main` (`8f0dc69`), 2026-10-03, full TOC set, after a full relog:**
- No Lua errors at login.
- `/gc comms`: `Comms Status (GuildCrafts dev)`, `My role: DR`, `DR: Player-4619-012F81BC`,
  `BDR: none`, `[1] Geo Prizm Player-4619-012F81BC (v3, …)`, `Total addon users: 1`.
- `/gc dump`: `Local player: Player-4619-012F81BC`, guild key `Grim-Classic Beta PvP`, Cooking 12,
  Herbalism 13, Alchemy 11, `Total: 1 members, 36 recipes`. Profession windows were opened
  first, so the counts are fresh scans. No `Geo-Prizm` entry was left beside the GUID key.
- `SP false false false false`.
- Herbalism holds 13 recipes, so Forever gathering professions do have recipes. The Recipes
  view still hides them for Herbalism and Skinning (`IsGatheringProfession`).

### Two-client checklist

Not run yet. It's the Phase 2 exit gate in `spec/forever-plan.md`.

---

## Packaging — Forever only

`.github/workflows/release.yml` runs BigWigsMods/packager pinned at `e50a250f` (v2.6.1). It's
the only way a GuildCrafts file reaches CurseForge project 1469206.

### Why `.pkgmeta` alone isn't enough

`release.sh` finds every `GuildCrafts{,_Vanilla,_TBC,_Wrath,_Cata,_Mists,_Camelot}.toc`
(`release.sh:1389-1423`) and adds a game version for each (`:1343-1355`). That happens
before `ignore:` is applied, which only runs while copying files (`:1852-1862`, `:2042`). In a
local dry run on 2026-10-02, ignoring the five TOCs produced a zip holding only
`GuildCrafts_Camelot.toc` that was still tagged `5.5.4, 4.4.2, 3.4.3, 2.5.6, 1.60.1, 1.15.7`.

### Mechanism

`docs/releasing.md` describes the strip, `-d -g forever` stage, gate and publish steps as
they stand. The results below are the dated checks of that mechanism.

Checked locally on 2026-10-02 against `a1c0554`:
- Strip plus `-d -g forever` gave `Game version: 1.60.1`, `Build type: non-retail
  version-forever`, and `GuildCrafts-a1c0554-forever.zip`. The gate printed `OK`.
- The zip's TOC had `## Version: a1c0554` and `## X-Curse-Project-ID: 1469206`.
- Without the strip, `-g forever` exited 1: `GuildCrafts.toc does not have an interface version
  that is compatible with the game version "forever"`.

On GitHub on 2026-10-03, `workflow_dispatch` with `publish=false` (run `37093088953`, `main` at
`8f0dc69`):
- Strip, package and gate all passed, and publish was skipped. The gate printed
  `forever-gate: OK (Game version: 1.60.1; GuildCrafts-8f0dc69-forever.zip; CTL v32)`.
- The downloaded artifact held one TOC outside `Libs/`, `GuildCrafts/GuildCrafts_Camelot.toc`
  (Interface 16001, `## Version: 8f0dc69`, project 1469206), and no `Data/`, docs, `CLAUDE.md`
  or dotfiles. `README.md` opens with [@dkruenbo](https://github.com/dkruenbo)'s credit, and `LICENSE` has both copyright lines.
- The packager writes CRLF line endings. With `\r` stripped, the zipped ChatThrottleLib hashes
  to the vetted v32 `3491b6c9…6dde8`.
- No real CurseForge upload has been made yet.

### Release procedure

The draft-upload plan that was here moved to `docs/releasing.md` on 2026-10-03. Its alpha-tag
example is replaced there by the beta tag planned in `spec/forever-plan.md`.

---

## Battle.net web API (N9, 2026-10-03)

**No Forever coverage.** Checked on 2026-10-03 against Blizzard's developer docs and forums. This
was web research, not an in-game test.
- The Classic namespaces are `*-classic1x-*` (Era), `*-classic-*` (Mists Progression) and
  `*-classicann-*` (Anniversary). There's no Forever or Camelot namespace
  ([namespaces](https://community.developer.battle.net/documentation/world-of-warcraft-classic/guides/namespaces)).
- The Classic Profile APIs have Guild Roster but no Character Professions endpoint.
- The forum thread "When will we gain API access to Forever APIs?" (2026-09-18) has no Blizzard
  reply ([thread](https://us.forums.blizzard.com/en/blizzard/t/when-will-we-gain-api-access-to-forever-apis/59595)).

Even if access opens, professions would need a new Classic endpoint. Forever has no realms,
either, so realm-keyed paths may not map. The addon-plus-companion design (N4 ADR) doesn't
depend on this API. Full notes are in `spec/later/research/2026-10-03-companion-n9.md`. #59 was
closed as not planned on 2026-10-04.

---

## Question log

Answers and partial answers from the in-game runs. Open questions are tracked in the "Open
questions" table of `spec/forever-plan.md`; each entry below names its Q number there.

1. **Client build** of the 2026-10-02 runs. `GetBuildInfo()` printed only the `1.60.1` version
   string; the build number (second return) wasn't captured. Open as Q1. `/gc report` landed
   in H5 (PR #50) and prints every `GetBuildInfo()` return on its `Client:` line. Q1 closes
   once that line from the Forever client is recorded here. Unverified: on 2026-10-03
   wago.tools listed build 1.60.1.70205 under `wow_classic_beta`
   (`spec/later/research/2026-10-03-companion-n9.md`), newer than the `70170` pin. The
   `Client:` line will show whether the client has patched past the pin.
   **2026-10-04:** `BLD` printed `1.60.1 70205 Oct 2 2026 16001`, so the client is on 70205,
   the same build as pin `e3ecc27`. That build is dated Oct 2, so it may or may not be the one
   the 10-02 runs used. Nothing recorded on 10-02 or 10-03 can tell 70170 from 70205. The
   `/gc report` `Session start` line records the build from now on.
2. **`C_RestrictedActions` at runtime.** Does it exist, and does
   `ADDON_RESTRICTION_STATE_CHANGED` fire on entering a boss encounter? Task 4 depends on it.
   Probes: `RA`, `RS`, `RE`. **Partly answered 2026-10-02:** `RA true true true true false`, so
   the API and both enums exist and chat isn't locked down. `RS` listed all six types with the
   documented values (Combat 0, Encounter 1, ChallengeMode 2, PvPMatch 3, Map 4, Chat 5), each in
   state 0 (Inactive) in the open world. Whether the event fires at a boss pull (`RE`) is still
   open: it needs a dungeon run. Open as Q2 (H8).
3. **Solo checklist.** Items 3–8 passed in game on 2026-10-02. Item 9 passed on 2026-10-03
   (see "Test results"). Q3 is closed. The two-client checklist hasn't been run.
4. **First `/gc dump` showed 0 recipes.** On 2026-10-02 it listed Cooking, Alchemy and
   Herbalism with 0 recipes each, and printed the key `Geo-Prizm` (F17 confirmed on that build).
   A re-run with `/gc debug` on the same day scanned correctly. Opening Alchemy printed
   `Scanned Alchemy: 5 new recipe(s) found.` and broadcast `DELTA_UPDATE` and `DELTA_AD`; the
   second event (`TRADE_SKILL_LIST_UPDATE` or `TRADE_SKILL_SHOW`) found no new recipes. The
   probe read `TS Alchemy nil 197 5`: `professionName` "Alchemy", no `parentProfessionName`,
   197 recipe IDs, 5 learned. A `/gc dump` after a full relog the same day still showed
   `Alchemy: 5 recipes` under the same guild key, `Grim-Classic Beta PvP`. So SavedVariables
   survived the relog and the partition key didn't move between those sessions. That rules
   out a partition change for this pair of sessions. Either no window was opened before the
   first dump, or the scan exited silently. Open as Q4. H5 and H6 have landed (PRs #50, #76),
   so every scan early-exit now leaves a reason in `/gc report`. Q4 closes after the
   reproduction in #26 is recorded.
