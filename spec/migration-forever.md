# GuildCrafts — WoW Forever Migration Guide

> Target: WoW Forever (Interface `16001`, client `1.60.1`, Mainline API)
> Current: Forever loads through `GuildCrafts_Camelot.toc` on `feature/forever-support`
> API source of truth: Gethe/wow-ui-source branch `forever`, read at legacynext's pin
> `9a789c0` (`1.60.1.70170`). Citations below are against that pin unless marked "in game".

Forever runs the retail (Mainline) API under a Classic-shaped interface number. The Forever
port (`c0a7e11`) already covers the scan and lookup fallbacks (`C_Item`, `C_SpellBook`,
`C_TradeSkillUI.GetRecipeSchematic`). This guide covers what stood between that port and a
clean load: which TOC the client reads, profession pruning, and the expansion filter with no
recipe data loaded. Only the Forever flavor is maintained here; the other five TOCs and
`Data/Data_*.lua` stay as upstream shipped them.

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
| Version bump | None | `@project-version@`, packager-filled; `DISPLAY_VERSION` reads it |

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

**Packaging caveat (out of scope here):** the BigWigs packager reads every TOC in the folder,
so a multi-TOC package would also tag the Classic flavors. A Forever-only package is needed
before any CurseForge upload.

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

### What was expected

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

**None.** The check reads a value the client reports; it isn't keyed on the interface number.

### Risk and gate

Forever is Classic+. Blizzard could raise the reported expansion level while still shipping no
Jewelcrafting or Inscription. The `< 1` and `< 2` checks would then stop pruning, and both
would come back as tracked professions that don't exist.

- **Impact.** Cosmetic. The left panel draws a row for every tracked profession
  (`MainFrame.lua:755-790`), so two empty `Jewelcrafting (0)` and `Inscription (0)` rows would
  appear. No stored data changes, because no character can learn either profession.
- **Detection.** Immediate. The rows show on the first `/gc` after the client change.
- **Why not gate it now.** A Forever-specific gate needs one of two things. One is a hardcoded
  skill-line ID, which the project rules forbid. The other is the list from
  `C_TradeSkillUI.GetAllProfessionTradeSkillLines()` (`TradeSkillUIDocumentation.lua:121`),
  which is unverified on Forever. If that list holds only the professions the client
  actually has, pruning can be built from it with no IDs and no expansion-level check.
- **`PSL` result (in game, 2026-10-02).** The list holds Alchemy, Blacksmithing, Enchanting,
  Engineering, Herbalism, Leatherworking, Mining, Skinning and Tailoring, plus
  `Test Profession [DNT]`. Each appears twice: as a parent line (171, 164, 333, 202, 182, 165,
  186, 393, 197) and as a child line (2937–2948) whose `parentProfessionName` is the same name.
  **Jewelcrafting and Inscription are absent**, so the list can gate them. Cooking, First Aid
  and Fishing are also absent: secondary skills aren't in this list, so a gate may only use it
  for primary professions.
- **Gate (implemented).** `Data:ApplyClientProfessionGate`, run from `Data:OnEnable`, drops
  Jewelcrafting and Inscription when the client's skill-line list is non-empty and names
  neither. It only narrows the expansion-level result. If the list is missing or empty, the
  expansion-level check stands.

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
out of scope (spec/fork-review.md C5).

---

## Task 4 — SyncPausePolicy: Forever addon restrictions

Forever blocks addon messages during some activities. Approved 2026-10-02 and implemented in
`Modules/SyncPausePolicy.lua`. `RA` and `RS` confirmed the API in game; whether the event
fires at a boss pull waits on `RE` (`docs/ingame-commands.md`).

### Documented signals (source only, never run in game)

| Signal | Citation |
|---|---|
| `C_RestrictedActions.IsAddOnRestrictionActive(type)` returns bool; always false while `ADDON_RESTRICTION_STATE_CHANGED` is being dispatched | `RestrictedActionsDocumentation.lua:55-67` |
| `ADDON_RESTRICTION_STATE_CHANGED (type, state)`; fires before a restriction activates and after it deactivates | `RestrictedActionsDocumentation.lua:96-107` |
| `Enum.AddOnRestrictionType`: Combat 0, Encounter 1, ChallengeMode 2, PvPMatch 3, Map 4, Chat 5 | `RestrictedActionsConstantsDocumentation.lua:19-31` |
| `Enum.AddOnRestrictionState`: Inactive 0, Activating 1, Active 2 | `RestrictedActionsConstantsDocumentation.lua:6-15` |
| `C_ChatInfo.InChatMessagingLockdown()` | `ChatInfoDocumentation.lua:293` |
| `SendAddonMessage` result 11 = `AddOnMessageLockdown` | `ChatConstantsDocumentation.lua:162` |

### Shape

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
restriction, and a grace period after a restriction lifts.

---

## What does NOT need to change

- **Other flavors' TOCs and `Data/Data_*.lua`** — untouched by design
- **Comms protocol, `VERSION`, `DATA_FORMAT_VERSION`** — Forever guilds only sync with Forever clients
- **Recipe key system** — positive itemID / negative spellID
- **Profession pruning** — Task 2
- **Expansion filter** — Task 3

---

## Forever-specific edge cases (known, not in this guide's scope)

These come from `spec/fork-review.md` and legacynext's in-game notes. They affect behaviour
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
  - `GetRealmName()` is `Classic Beta PvP`; `GetNormalizedRealmName()` is `ClassicBetaPVP`.
    GuildCrafts' own normalisation gives `ClassicBetaPvP`, so the two differ in case. Forever
    has no realms; it is split only by ruleset (PvP or PvE), so `GetRealmName()` names the
    ruleset.
  - **Fixed:** `Modules/ForeverIdentity.lua`, loaded only from the Camelot TOC, keys members by
    GUID. Senders and roster rows resolve to GUIDs through the roster, and names are read back
    for display and whispers. Classic flavors keep `Name-Realm`, using the defaults in
    `Data:GetMemberName`, `Data:GetWhisperTarget` and `Data:RosterMemberKey`.
  - Still unverified: the sender name for a guildmate on another server (GUID prefix 4613 vs
    4619), and whether an addon whisper to `First Surname` reaches them. The two-client
    checklist covers both.
- **ChatThrottleLib v31 taint (F18).** Its `SendChatMessage` hook calls `strlen` on secret
  chat values. v32 has the `issecretvalue` guard.
- **Empty profession read purges data (F19), fallback confirmed absent in game 2026-10-02.**
  `DetectProfessions` runs 5s after login or `/reload`, not at logout. `SKL` printed
  `false false false true`: `C_SkillLine`, global `GetNumSkillLines` and global
  `GetSkillLineInfo` don't exist; only `C_SkillInfo` does. So when `GetProfessions()` comes back
  empty, the fallback (`Data.lua:69-89`) reads zero lines. Every stored profession is then
  purged and its removal broadcast. legacynext saw professions read empty at `PLAYER_LOGOUT`
  (`CLAUDE.md:254-257`). **Fixed:** detection never removes a profession that holds recipes;
  `/gc drop <profession>` is the only path, removals carry `x = 1` and must be newer, and
  `MergeIncoming` keeps professions an incoming entry lost without a drop marker
  (`Data:CarryOverProfessions`).
  `PROF` on the same day: slot 1 Alchemy, slot 2 Herbalism, slot 5 Cooking, slots 3, 4, 6 and 7
  empty. That matches the positions GuildCrafts reads.
- **`/gc reset` calls `ReloadUI()` (F14).** Reported as protected on Forever; unverified.

---

## Recommended test checklist

All on a Forever character, with the full TOC set installed:

1. AddOns list shows GuildCrafts, not flagged out of date
2. `/run` TOC probe prints `16001 true … true true`
3. No Lua errors at login (BugSack, or the default error frame)
4. `/gc` opens the main window
5. No expansion filter buttons; the search box reaches the scope dropdown
6. The profession list has no Jewelcrafting or Inscription
7. While in a guild, open and close a profession window, then `/gc dump`: it prints your key
   and a non-zero recipe count for that profession (scan verified 2026-10-02: Alchemy 5 of 197)
8. In `/gc`, that profession → your name lists the same recipes (passed 2026-10-02)
9. `/gc comms` first line reads `--- Comms Status (GuildCrafts dev) ---` from an unpackaged
   copy, or the packaged version from a CurseForge build

### Two-client checklist

The solo list above never runs the DR/BDR election or the sync protocol. This section needs
you (A) and one guildmate (B), both on this branch's build, both in the same guild.

GuildCrafts prefixes its chat lines with `GuildCrafts:`; `[debug]` lines only print after
`/gc debug`. Debug mode resets at every login and `/reload`, so turn it on again each time.
Commands marked by tag (`RA`, `SP`, `RE`) are in `docs/ingame-commands.md`.

**Who should be DR.** Election picks the lowest member key by plain byte order
(`Comms.lua:291-301`). Get each key from the first line of `/gc dump` (`Local player: …`) and
work out the expected DR before you start. Call the lower key LOW and the other HIGH.

#### Setup

| Step | Who | Do | Expect |
|---|---|---|---|
| S1 | both | `/gc dump` | `Local player: <key>`. Note both keys; decide LOW and HIGH |
| S2 | both | `/gc comms` | First line `--- Comms Status (GuildCrafts dev) ---` |
| S3 | both | `RA` | `RA true true true true false`. If not, skip section R |

#### E — Election

| Step | Who | Do | Expect |
|---|---|---|---|
| E1 | A only | Log in alone. Wait 30s. `/gc comms` | `My role: DR`, `DR: <A>`, `BDR: none`, `Total addon users: 1` |
| E2 | A | `/gc debug` | `Debug mode: ON` |
| E3 | B | Log in. Wait 30s | On A: `[debug] HELLO from <B> v2`, then `[debug] Sent HELLO reply to <B>` |
| E4 | both | `/gc comms` | Both print the same `DR: <LOW>` and `BDR: <HIGH>`. LOW shows `My role: DR`, HIGH `My role: BDR`. `Total addon users: 2`, both keys listed |
| E5 | LOW | Wait for HIGH's sync (about 15s after E3) | With debug on, LOW prints `[debug] Handling SYNC_REQUEST from <HIGH> (role: DR )`, then either `Sync with <HIGH> — already converged.` or `Sending SYNC_PULL to <HIGH> …` |

**Fail:** both clients say `My role: DR` (split election), either shows `Total addon users: 1`
after 60s, or the two disagree on `DR:`.

#### D — One client drops

| Step | Who | Do | Expect |
|---|---|---|---|
| D1 | HIGH | Log out | — |
| D2 | LOW | Wait 60s. `/gc comms` | Still `Total addon users: 2` and `BDR: <HIGH>`. **This is the code's behaviour, not a pass.** Only the DR is ever evicted (`Comms.lua:443-466`), and roster-based eviction was removed (`Comms.lua:470-476`). Record it as a finding |
| D3 | HIGH | Log back in. Wait 30s. Both `/gc comms` | Back to the E4 state |
| D4 | HIGH | `/gc debug` | `Debug mode: ON` |
| D5 | LOW | Log out | — |
| D6 | HIGH | Wait up to 4 minutes; the watchdog checks every 60s, and the timeout is 180s | `[debug] DR heartbeat timeout — removing <LOW>`, `[debug] You are now the Designated Router (DR).`, `[debug] DR term advanced to <n>`, and `Role changed: BDR → DR` |
| D7 | HIGH | `/gc comms` | `My role: DR`, `DR: <HIGH>`, `BDR: none` |
| D8 | LOW | Log back in. Wait 60s. Both `/gc comms` | Both agree on `DR: <LOW>` and `BDR: <HIGH>`. HIGH printed `Role changed: DR → BDR` if its debug was still on |

**Fail:** D6 never fires within 4 minutes, or D8 leaves both as DR, or they disagree after 2
minutes. For D8, note whether HIGH printed `Dropping stale HEARTBEAT`: LOW comes back with a
lower term than the one HIGH adopted at D6.

#### P — Delta propagation

A delta only goes out when a scan finds new recipes. Use a profession window that has never
been opened on that character, or learn one new recipe from a trainer first.

| Step | Who | Do | Expect |
|---|---|---|---|
| P1 | both | `/gc debug` | `Debug mode: ON` |
| P2 | A | Open the profession window | A: `Scanned <Prof>: <N> new recipe(s) found.`, `[debug] Broadcast DELTA_UPDATE (add) for <A> <Prof>` |
| P3 | B | Watch chat | `[debug] DELTA_UPDATE (add) from <A sender> for <A>`, plus one `[debug] Delta merged: <A> <Prof> <recipeKey>` per recipe |
| P4 | B | `/gc`, then `<Prof>`, then A's name | The same N recipes |
| P5–P7 | swap A and B | Repeat P2–P4 the other way | Same, mirrored |

**Fail:** P3 prints nothing, or P4 shows a different count. Record the sender name exactly as
P3 prints it; it shows whether AceComm's sender matches the key from S1 (F17).

#### R — Pause under a restriction

Needs `RA` to pass. Entering an instance already pauses sync on its own, so R isolates the
restriction by watching the debug lines and `SP`.

| Step | Who | Do | Expect |
|---|---|---|---|
| R1 | A | `RE`, then `/gc debug` | `RE armed`, `Debug mode: ON` |
| R2 | A | Enter a dungeon. Wait 15s, then `SP` | `[debug] SyncPausePolicy: inside instance — sync paused`; `SP true false true false` (the 12s zone-transition flag has cleared) |
| R3 | A | Pull the first boss. During the fight run `SP` | Ignore `RE` lines with type 0 (Combat). Expect `RE <time> 1 1` or `RE <time> 1 2`, `[debug] SyncPausePolicy: restriction Encounter active — sync paused`, and `SP true true true false 1` (combat is set too) |
| R4 | A | Kill or wipe. Wait 10s, then `SP` | `RE <time> 1 0`, `[debug] SyncPausePolicy: restriction Encounter lifted`, and `SP true false true false` with nothing after (combat's 6s grace has run out) |
| R5 | A | Still inside, open a profession with a new recipe (see P) | `Scanned … new`, then `[debug] BroadcastNewRecipes suppressed (SyncPausePolicy) for <Prof>` |
| R6 | B | Watch chat | Nothing from A |
| R7 | A | Leave the instance. Wait 20s | `[debug] SyncPausePolicy: instance grace expired — sync resumed` |
| R8 | B | `/gc dump`, then `/reload`, wait 30s, `/gc dump` | The first dump is missing A's new recipes. The second has them. Suppressed deltas are dropped, not queued (`Comms.lua:1062-1066`), so B only catches up at its next login sync |
| R9 | A | Optional: pull a boss again and `/reload` mid-fight. `SP` | Ends with `1`, from the state read at `OnEnable` |

**Fail:** R3 shows no `RE` line, which means the event never fired on Forever. R3's debug line
missing while `RE` fires means GuildCrafts didn't register it. B receives A's delta at R6.

---

## Open questions — verify on live Forever

1. **Client build** of the 2026-10-02 runs. `GetBuildInfo()` printed only the `1.60.1` version
   string; the build number (second return) wasn't captured.
2. **`C_RestrictedActions` at runtime.** Does it exist, and does
   `ADDON_RESTRICTION_STATE_CHANGED` fire on entering a boss encounter? Task 4 depends on it.
   Probes: `RA`, `RS`, `RE`. **Partly answered 2026-10-02:** `RA true true true true false`, so
   the API and both enums exist and chat isn't locked down. `RS` listed all six types with the
   documented values (Combat 0, Encounter 1, ChallengeMode 2, PvPMatch 3, Map 4, Chat 5), each in
   state 0 (Inactive) in the open world. Whether the event fires at a boss pull (`RE`) is still
   open: it needs a dungeon run.
3. **Solo checklist items 3–8** passed in game on 2026-10-02. Item 9 and the two-client
   checklist are not yet run.
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
   first dump, or the scan exited silently.
