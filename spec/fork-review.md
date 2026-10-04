> **Historical (2026-09-28).** This review is the source of finding IDs F1–F21 and C1–C6. Its status column and line numbers are as of `c0a7e11` and aren't maintained. Current status is in the [finding index](forever-plan.md#finding-index-fork-review-2026-09-28) and the [issues](https://github.com/lxhwes/GuildCrafts-Forever/issues).

# GuildCrafts fork review — 2026-09-28

What a fork targeting WoW: Forever should fix and build. Based on three read-only
reviews (UI/UX, sync and data, code hygiene) of `feature/forever-support` at `c0a7e11`,
checked against the Forever API docs in a vendored Gethe/wow-ui-source checkout
(pin `bd2470a`, build 1.60.1.70009).

Status column:

- **verified** — re-read in the code (or docs) by the main session
- **reviewed** — a reviewer read the code; not re-checked
- **inferred** — reasoning only, or needs the client; see section 7

## Forever facts that shape the fork

- Retail Mainline API, Interface 16001. The client reads `_Camelot.toc`, ignores `_Forever.toc`,
  and prefers `_Camelot` over the unsuffixed TBC TOC (verified in game, 1.60.1, 2026-10-02).
- 12 professions: six crafting (Alchemy, Blacksmithing, Enchanting, Engineering,
  Leatherworking, Tailoring), three gathering (Herbalism, Mining, Skinning), and three
  secondary (Cooking, First Aid, Fishing). No Jewelcrafting or Inscription. Healing potions
  moved from Alchemy to First Aid. 600+ new recipes.
- `GetProfessions()` returns seven values: two primaries, then five secondaries
  (legacynext CLAUDE.md, citing `Blizzard_Professions/Camelot/Blizzard_ProfessionsFrame.lua:16`).
- SavedVariables were written but never loaded back on beta builds up to at least 69913.
  A player reported the 2026-09-24 build fixed it. Blizzard hasn't confirmed.
- `ReloadUI()` is protected (legacynext CLAUDE.md).
- Missing from the generated docs: `C_TradeSkillUI.GetAllRecipeIDs`, `IsTradeSkillReady`,
  `IsTradeSkillLinked`, `GetRecipeItemLink`, `GetRecipeNumReagents`. Scanning works in game,
  so the docs are incomplete for at least `GetAllRecipeIDs`.
- Present in the docs: `GetRecipeSchematic`, `GetRecipeOutputItemData`,
  `C_SpellBook.IsSpellKnown`, `C_ChatInfo.InChatMessagingLockdown`,
  `C_RestrictedActions.IsAddOnRestrictionActive`, `C_TradeSkillUI.IsGuildTradeSkillsEnabled`,
  `C_GuildInfo.QueryGuildMembersForRecipe`, event `GUILD_RECIPE_KNOWN_BY_MEMBERS`.
- Two competitors already ship Forever builds. Recipe Registry (`forever-v0.1.0`) has
  TSM/Auctionator pricing, all 12 professions and an options panel. Profession Master lists
  Forever and has shopping lists, missing-recipe views and a `!who` chat command.

## 1. Fix first: data safety and abuse

All small (S) unless noted.

| # | Finding | Evidence | Status |
|---|---|---|---|
| F1 | A client with empty SavedVariables wipes its own recipes on every peer. Login stamps empty professions as newest. The merge guard only fires when the incoming count is above zero. The own key is never merged back from peers. While the SV bug lasts, this happens on every login. | `Data.lua:734`, `:1772`, `:1710` | verified |
| F2 | `GetProfessions` is read as five slots; slots 3, 6 and 7 are ignored. A tracked profession in one of them is purged at login and a removal is broadcast to every peer. | `Data.lua:658`, `:702-744` | verified code; slot order inferred |
| F3 | First Aid isn't tracked and has no locale spell ID, so healing potions and bandages are invisible on Forever. | `Data.lua:98-113`, `:125-138` | verified |
| F4 | `!gc` echoes the sender's text into guild chat as the responder, and misses skip the cooldown. Any guildmate can make the DR post arbitrary text, repeatedly. | `Core.lua:430-433` | verified |
| F5 | The scan skips linked and NPC views but not the guild views. `IsTradeSkillLinked` exists: it is missing from the docs, but Blizzard's own code calls it. `IsTradeSkillGuild` and `IsTradeSkillGuildMember` are never checked, so opening a guildmate's recipes from the roster, or the guild's "All Recipes" list, files those recipes under your name and broadcasts them. The fix is to mirror Blizzard's local-crafting test. | `Data.lua:1481`; forever branch `Blizzard_ProfessionsTemplates/Blizzard_Professions.lua:377-383` | verified; exposure needs guild tradeskills enabled |
| F6 | Sync whispers strip the realm, so replies to connected-realm guildmates go to the wrong character. The 2.0.2 identity fix missed this line. | `Comms.lua:1376` | verified |
| F7 | RESUME duplicates transfers. Chunks are queued once a second regardless of how fast they drain. A 20–40 KB chunk takes 30–60 s at ChatThrottleLib's 800 B/s. The receiver sends RESUME after 4 s, and the sender re-queues every missing chunk, up to three times. | `Comms.lua:40-41`, `:68-70`, `:862-864`, `:988-993` | verified mechanism; chunk sizes measured on synthetic data |
| F8 | A DR that sees a higher term stops heartbeating but keeps `myRole = "DR"`. Heartbeats only restart on a role change, so a re-elected DR stays silent. | `Comms.lua:1460-1467`, `:315-320` | verified |
| F9 | The tooltip index debounce never debounces. `C_Timer.After` returns nothing, so every sync chunk schedules another full rebuild. | `Tooltip.lua:32`, `:46`; `UITimerDocumentation.lua:11-20` | verified |
| F10 | The tooltip hook writes the global `_`, a taint source on Mainline. | `Tooltip.lua:147` (luacheck W111) | verified |
| F11 | Scans have no debounce. Retries run every 1–2 s with no cap and no cancel on window close. The partial-scan guard counts unlearned recipes, so it never fires. | `Core.lua:51-52`; `Data.lua:1477`, `:1524`, `:1534`, `:1537` | reviewed |
| F12 | Forever recipes lose their category. The code reads `info.categoryName`, but the struct only has `categoryID`. | `Data.lua:1557`; `TradeSkillUITypesDocumentation.lua` (TradeSkillRecipeInfo) | verified |
| F13 | The election watchdog resets on every recompute, including each HELLO after a loading screen, so a DR that logged off can stay elected. Any node receiving a retry≥2 request evicts the DR and BDR guild-wide. | `Comms.lua:349-352`, `:432`, `:201`, `:625-626` | reviewed |
| F14 | `/gc reset` calls `ReloadUI()`, which is protected on Forever. | `Core.lua:504` | reviewed; protection per legacynext |
| F15 | Fuzzy search misses the documented example. `StripVowels` keeps `y`, so "agylity" becomes "gylty", not "glty". | `Data.lua:2238-2241` | verified |
| F16 | `IsSpellKnownCompat` tries the global `IsSpellKnown` first. Recipe Registry found that global returns false for every recipe ID on Forever, while `C_SpellBook.IsSpellKnown` is correct. Prefer the `C_SpellBook` call. | `Data.lua:61-66` (from the Forever port) | code verified; client behaviour from RR's in-game notes, 2026-09-18 |
| F17 | Identity split on Forever. `GetPlayerKey` builds `Name-Realm` from `UnitFullName`. RR recorded that function returning ("Kaedros Davian", "ClassicBetaPvE2") on 09-18, ("Kaedros", "Davian") on 09-25 and ("Kaedros") on 09-26. The roster and AceComm senders give "Kaedros Davian". On the last two shapes, a player's self-reported key (sent in HELLO and sync requests) differs from the key peers build from the roster, so peers see them offline and can prune them as an ex-member after 7 days. RR also suspects `GetRealmName()` follows the dynamic server instance, which would move the guild partition key. RR's fix: key by `UnitNameUnmodified("player")` joined with a space, and use roster names as-is. | `Data.lua:433-458`, `:473`, `:1868-1918`; `Comms.lua:190`, `:599` | code verified; client behaviour from RR's notes; the probe confirms |
| F18 | The bundled ChatThrottleLib is v31, and its `SendChatMessage` hook measures the text with `strlen(tostring(text))`. On Forever a player's chat line can be a secret value, so the hook errors and the client reports "execution tainted by" the addon on every chat line; RR hit this in game with the same v31. v32 returns early when `issecretvalue` is true. Update to v32 and delete the unused standalone v29 copy. This only bites when GuildCrafts' copy is the newest ChatThrottleLib loaded. | `Libs/AceComm-3.0/ChatThrottleLib.lua:281-289`; `Libs/embeds.xml:22`; RR `local-tests/specs/chat_throttle_spec.lua:1-14` | verified code; symptom from RR's in-game notes |
| F19 | An empty `GetProfessions()` read purges everything. The fallback it drops to (`IterSkillLines`, which needs `C_SkillLine` or `GetNumSkillLines`) doesn't exist on Forever, so every stored profession counts as dropped, gets purged, and has a removal broadcast guild-wide. Recipe Registry deletes nothing on an empty read. | `Data.lua:676-716`, `:69-89` | verified code |
| F20 | The whisper button can't reach two-word names. `UI:OpenWhisper` builds `"/w " .. name .. " Can you craft…"`, so for "Kaedros Davian" the target is probably "Kaedros" and "Davian" becomes the message. RR calls `ChatFrame_SendTell(target)` instead. | `MainFrame.lua:1986-1988` | verified code; chat parsing unverified |
| F21 | An empty profession name stops the scan silently. `professionName or parentProfessionName or name` accepts `""`, which is truthy in Lua, so the scan reports "not tracked" and never retries. RR falls back to `GetProfessionInfoByRecipeID` on the first recipe. | `Data.lua:1489-1500` | reviewer ran the code |

## 2. Core functionality

- **Smaller wire format.** Send recipe-ID sets instead of full recipe tables. For 120
  recipes this measured 591 B compressed against 3,554 B today. Rebuild RecipeDB locally from
  `GetRecipeSchematic`. Needs a `VERSION` / `DATA_FORMAT_VERSION` bump. (reviewed)
- **Byte-sized chunks** of about 2 KB instead of 5 members. Track progress through AceComm's
  `callbackFn`, scale timeouts to the bytes queued, and give each requester one queue slot.
  (reviewed)
- **Version-vector digest in HELLO and HEARTBEAT.** Send SYNC_REQUEST only on a mismatch.
  Today every loading screen sends the full vector: 1.7 KB at 200 members, 4.2 KB at 500.
  This revisits backlog #22 with new evidence. (reviewed, sizes measured)
- **Separate "content changed" from "member active".** `lastUpdate` does both, so every
  window open marks the whole entry as changed. Union-merge recipe sets with a per-profession
  drop timestamp, and tombstone inactive members instead of hard-deleting them. (reviewed)
- **`GetServerTime()` instead of `time()`** for last-write-wins, and clamp future timestamps.
  (reviewed)
- **Deltas carry a base version**, so a peer that missed an update pulls it instead of
  marking itself current. (reviewed)
- **Forever's restriction signals instead of `IsInInstance`.** Use
  `C_RestrictedActions.IsAddOnRestrictionActive(Enum.AddOnRestrictionType.Chat)`, the
  `ADDON_RESTRICTION_STATE_CHANGED` early warning, `InChatMessagingLockdown`, and the
  `SendAddonMessage` result codes. (docs verified; runtime inferred)
- **`NEW_RECIPE_LEARNED`** for one small message per learned recipe. (reviewed)
- **Cooldowns.** The modern scan path never reads them, and sync strips them. A guild
  cooldown board needs `C_Spell.GetSpellCooldown`, which is secret while cooldowns are
  restricted. (reviewed)
- **Blizzard's guild recipe API.** Forever's own UI ships the whole retail feature, behind
  `C_TradeSkillUI.IsGuildTradeSkillsEnabled()`:
  - The guild roster has a Professions view (`Blizzard_Communities/CommunitiesMemberList.lua:159-166`).
  - Clicking a member opens their recipes (`C_GuildInfo.QueryGuildMemberRecipes`, `:759`).
  - "All Recipes" opens the guild's combined list, and each recipe has "View Guild Crafters"
    (`Blizzard_Professions/Blizzard_ProfessionsCrafting.lua:826-830`, `:1109-1115`).

  The calls: `QueryGuildMembersForRecipe(skillLineID, recipeID)`, then the event
  `GUILD_RECIPE_KNOWN_BY_MEMBERS`, then `GetGuildRecipeInfoPostQuery()` and
  `GetGuildRecipeMember(i)` (returns displayName, fullName, classFileName, online) from
  `Blizzard_ProfessionsGuildMemberList.lua:36-84`.

  - Upside: covers offline members and members without the addon, with no SavedVariables and
    no addon traffic.
  - Limits: one recipe per query, asynchronous; needs the recipe spell ID and skill line ID;
    no reagents, cooldowns or specialisations; the results are global state shared with
    Blizzard's frame.
  - Whether it's switched on is a runtime flag (probe below). File paths are on the
    `Gethe/wow-ui-source` forever branch as fetched 2026-09-28, not the legacynext pin.

## 3. UI/UX

- **Search.** Match all words in any order, rank prefix hits first, and fall back to fuzzy
  matching. Today fuzzy matching only exists for `!gc`. Require 2 characters, cap the rows,
  accept shift-clicked item links, and share a recipe-keyed index with the tooltip. Today
  every keystroke walks every member×recipe with a `GetItemInfo` per row.
  (`MainFrame.lua:1456-1477`, `Data.lua:2319-2335`; reviewed)
- **Member page with profession tabs.** Member rows in search results are dead ends, a
  favorite member opens an arbitrary profession, and "All v" looks like a dropdown but only
  cycles. (`MainFrame.lua:1532-1538`, `:1661-1668`, `:395-412`; reviewed)
- **Cold start.** Show "Syncing 23/60". Separate "no data yet", "no match" and "hidden by
  filter". Don't show a red dot when you're simply the only addon user online. Give
  first-run guidance to open profession windows. (reviewed)
- **Rendering.** Rows are hidden, never reused, and the whole list rebuilds on every delta
  and on item-info bursts. Move to ScrollBox with a tree data provider and batch refreshes.
  (`MainFrame.lua:2297-2303`, `:2800-2939`; `Core.lua:62`, `:73-84`; reviewed)
- **Layout.** The content is fixed at 400 px and `OnResize` is empty. Names truncate, so
  similar enchants look identical. Save position, size and scale.
  (`MainFrame.lua:632`, `:256-258`; reviewed)
- **Tooltip.** One header line with counts, up to three online names, and Shift for the
  full list. Add an option to hide smelting. Today a tooltip can grow by 13 lines.
  (`Tooltip.lua:163-196`; reviewed)
- **Settings panel, Addon Compartment and `IconTexture`.** Settings for chat verbosity, a
  `!gc` responder opt-out, tooltip limits and scale. (reviewed)
- **Whisper.** Realm-aware, disabled when nobody is online, and offered through a context
  menu (whisper with the item link, invite, copy name). ESC should close the picker.
  (reviewed)
- **Accessibility.** Status is shown by colour alone in several places. Add text or a
  shape. (reviewed)
- **Mats on hand** via `C_Item.GetItemCount`. (inferred)
- **`/gc <query>` and a keybinding.** Today `/gc arcanite` prints help.
  (`Core.lua:511-512`; reviewed)

## 4. Code hygiene

- **Lint.** 81 warnings: 78 undefined globals, 1 global write, 1 unused argument and 1
  duplicate table key. It was 0 at the 1.0.4 cleanup; the Forever port added 15. No CI.
  (verified with luacheck 1.2.0 from `legacynext/tools`)
- **Tests.** Merge, tombstones, search and the serialization round-trip already run under
  plain Lua 5.1 with six stubs; the reviewer ran them in memory. A `.busted` harness plus
  legacynext's `spec_helper` would carry them. (reviewed)
- **Compat.lua.** 45 feature-detect branches are scattered across files, and the Forever
  port pasted the `GetItemInfo` shim into three of them. Going Forever-only would delete
  about 25 sites and roughly 600 lines. (reviewed)
- **One scan pipeline.** The three scanners have already diverged: the modern one stores a
  category only when there are reagents, and has no cooldowns and no backfill. Use one
  adapter per API feeding a single `ApplyScan`. (reviewed)
- **Event bus.** Replace modules reaching into each other with CallbackHandler messages,
  and drop the 31 `GuildCrafts.X and …` guards. (reviewed)
- **Packaging.** There's no `.pkgmeta`, no CI and no tags. The version lives in seven
  places, and the documented zip ships dotfiles. Use the BigWigs packager with
  `@project-version@`. legacynext has only dry-run a single unsuffixed 16001 TOC; the packager
  reads every TOC, so a multi-TOC package would also tag the Classic flavors. (reviewed)
- **Libraries.** AceGUI (7,109 lines) loads every login and is never used. The standalone
  ChatThrottleLib v29 is shadowed by AceComm's v31. LibDBIcon 43 predates the addon
  compartment. (reviewed)
- **Docs drift.** The RFCs describe hooks, guards, commands and a profile scope the code
  doesn't have. Mark them as upstream history. (reviewed)

## 5. Decisions for Alex

1. **Forever-only, or keep the Classic TOCs.** Forever-only deletes the legacy scan paths
   and frees the wire format. Keeping Classic means a wire bump splits the fork from
   upstream 2.0.x users on those clients.
2. **Private guild tool, or published addon.** Publishing means a rename and competing
   with Recipe Registry and Profession Master.
3. **Build on Blizzard's guild recipe API** if the probe shows it's live, or keep addon
   sync as the only source.

## 6. Suggested order

1. F1–F10 and F16–F21: small changes, most from one line to a few dozen. Identity (F17),
   ChatThrottleLib (F18) and the empty-read guards (F1, F19) come first. Section 9 lists the
   Recipe Registry code that covers most of them.
2. Lint to zero, CI, and a busted harness with characterization tests for merge, election
   and search.
3. Run the probe, then build `Compat.lua` with the Forever fixes and a Store seam for the SV
   bug.
4. Wire format v3: recipe-ID sets, byte chunks, digests. Blocked on decision 1.
5. The scan pipeline, then the ScrollBox UI, then search and the member page.
6. Settings panel, tooltip modes, cooldown board.

## 7. In-game checks

### Probe script

Paste into WoWLua and run. It parses under `luac -p` (Lua 5.1) both as written and with the
newlines stripped. Run it once, log out to character select and back in, and run it again;
the last lines check the SavedVariables bug.

```lua
local p=print;
p("== GuildCrafts Forever probe ==");
p("build", (GetBuildInfo()), select(4, GetBuildInfo()));
p("GC player key", GuildCrafts and GuildCrafts.Data and GuildCrafts.Data:GetPlayerKey());
p("UnitFullName", UnitFullName("player"));
if UnitNameUnmodified then p("UnitNameUnmodified", UnitNameUnmodified("player")); end;
p("realm", GetRealmName(), GetNormalizedRealmName and GetNormalizedRealmName());
p("roster #1", (GetGuildRosterInfo(1)), "guild club id", C_Club and C_Club.GetGuildClubId and C_Club.GetGuildClubId());
local t={GetProfessions()};
p("GetProfessions returns", select("#", GetProfessions()));
for i=1,7 do local x=t[i]; if x then local n,_,r,m,_,_,sl=GetProfessionInfo(x); p("slot", i, n, tostring(r).."/"..tostring(m), "skillLine", sl); else p("slot", i, "-"); end; end;
local T=C_TradeSkillUI;
for _,k in ipairs({"GetAllRecipeIDs","IsTradeSkillReady","IsTradeSkillLinked","IsTradeSkillGuild","IsTradeSkillGuildMember","GetRecipeItemLink","GetCategoryInfo","GetRecipeCooldown","GetProfessionSpells"}) do p("C_TradeSkillUI."..k, T[k]~=nil); end;
p("guild tradeskills enabled", T.IsGuildTradeSkillsEnabled and T.IsGuildTradeSkillsEnabled(), "PostQuery fn", GetGuildRecipeInfoPostQuery~=nil);
p("C_SkillLine", C_SkillLine~=nil, "GetNumSkillLines", GetNumSkillLines~=nil);
p("chat globals: OpenChat", ChatFrame_OpenChat~=nil, "InsertLink", ChatEdit_InsertLink~=nil, "SendChatMessage", SendChatMessage~=nil, "C_ChatInfo.SendChatMessage", C_ChatInfo.SendChatMessage~=nil);
p("chat lockdown", C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown(), "in instance", (IsInInstance()));
local R=C_RestrictedActions; p("chat restriction", R and R.IsAddOnRestrictionActive and Enum.AddOnRestrictionType and R.IsAddOnRestrictionActive(Enum.AddOnRestrictionType.Chat));
p("clock skew s", time()-GetServerTime(), "expansion", GetClassicExpansionLevel and GetClassicExpansionLevel());
p("connected realms", GetAutoCompleteRealms and #(GetAutoCompleteRealms() or {}), "guild members", GetNumGuildMembers());
p("knows 7183 (C_SpellBook, global)", C_SpellBook.IsSpellKnown(7183), IsSpellKnown and IsSpellKnown(7183));
p("regional unique names", RegionalUniqueNamesEnabled and RegionalUniqueNamesEnabled(), "crafting orders tab", C_CraftingOrders and C_CraftingOrders.ShouldShowCraftingOrderTab and C_CraftingOrders.ShouldShowCraftingOrderTab());
for _,id in ipairs({7183,3275}) do local s=T.GetRecipeSchematic and T.GetRecipeSchematic(id,false); p("schematic", id, "->", s and s.outputItemID); end;
local g=GuildCraftsDB and GuildCraftsDB.global;
p("SV probe from last run", g and g._probe);
if g then g._probe=GetServerTime(); end;
p("probe set. Log out to character select, back in, run again: nil above = SV bug still live");
```

Answers: F17 (does GuildCrafts' own key match the roster name?), F2 (slot order), F3
(First Aid's name and skill line), F5 (does `IsTradeSkillLinked` exist?), the undocumented recipe functions, the guild recipe API gate,
the chat shims, the restriction state, clock skew, connected realms, whether a recipe
resolves to its output item without its window open (needed for the recipe-ID wire format),
and the SV bug.

### Manual checks

- **Linked profession (F5).** Open a guildmate's profession link from chat and watch
  whether GuildCrafts prints "Scanned". Then run
  `/dump C_TradeSkillUI.GetBaseProfessionInfo()`.
- **Guild recipe API.** Run
  `/run local f=CreateFrame("Frame");f:RegisterEvent("GUILD_RECIPE_KNOWN_BY_MEMBERS");f:SetScript("OnEvent",function() print("GRK fired");end);C_GuildInfo.QueryGuildMembersForRecipe(171,7183);`
  and see whether "GRK fired" appears.
- **Scan event rate (F11).** Run
  `/run local n=0;local f=CreateFrame("Frame");f:RegisterEvent("TRADE_SKILL_LIST_UPDATE");f:RegisterEvent("NEW_RECIPE_LEARNED");f:SetScript("OnEvent",function(_,e,...) n=n+1;print(n,e,...);end);`,
  then open a profession window, craft five items and type in its search box.
- **Addon message throttle.** Run
  `/run local c={};for i=1,15 do local r=tostring(C_ChatInfo.SendAddonMessage("GCPROBE",("x"):rep(250),"WHISPER",UnitName("player")));c[r]=(c[r] or 0)+1;end;for k,v in pairs(c) do print(k,v);end;`
  Result code 3 means the message was throttled.
- **Cooldown secrecy.** On an alchemist, run `/dump C_Spell.GetSpellCooldown(17187)` once
  in a city and once in a dungeon.

## 8. Forever content

New recipes need no static data. The Forever scan reads recipes from the open profession
window (`GetAllRecipeIDs` → `GetRecipeInfo` → `GetRecipeSchematic`), so the 600+ new
recipes, their reagents and the campsite blueprints are stored the first time a crafter
opens their window. The work is in the hardcoded tables around them.

| # | Gap | Evidence | Change |
|---|---|---|---|
| C1 | First Aid and Fishing aren't tracked. Jewelcrafting and Inscription are removed only if `GetClassicExpansionLevel()` exists and returns 0; otherwise they show as empty rows. | `Data.lua:98-138`, `:2050-2071`; `MainFrame.lua:724-738` | Build the list from `C_TradeSkillUI.GetAllProfessionTradeSkillLines()` + `GetProfessionInfoBySkillLineID` (`TradeSkillUIDocumentation.lua:121`, `:488`). Key professions on skill line ID. |
| C2 | Every Forever profession has campsite crafts, gathering included. `IsGatheringProfession` hardcodes Herbalism and Skinning as having no recipes and hides their Recipes view. | `Data.lua:2175-2177`; `MainFrame.lua:846`, `:950`, `:2480`, `:2765` | Show the Recipes view whenever any member has recipes. |
| C3 | The specialisation table is TBC's: Potion/Elixir/Transmute Master, Mooncloth/Shadoweave/Spellfire, and descriptions that say "TBC". | `Data.lua:207-229` | Keep the vanilla specialisations if their spell IDs carry over; drop the rest. Probe `C_ProfSpecs.SkillLineHasSpecialization`, since Forever documents retail's spec-tree API. |
| C4 | The Forever scan reads no cooldowns, so new cooldown crafts and the old transmutes never show. | `Data.lua:1470-1605` | Read `C_Spell.GetSpellCooldown` per recipe during the scan, guarded by `issecretvalue`. No list is needed. |
| C5 | Every recipe is tagged ORIG on Forever, and the expansion buttons never build. | `Camelot.toc` loads no `Data/*.lua` | New content uses a separate ID range: the campsite Anvil is recipe spell 1263041 and "Blueprint: Anvil" is item 273086, while vanilla recipe spells sit under about 30,000. An ID threshold could tag "new in Forever" without a list. Confirm on more recipes first. |
| C6 | `source` is always empty, and there's no source-text API. Nothing documented maps a recipe item to the recipe it teaches. | `Data.lua:1564`; `TradeSkillUIDocumentation.lua` | Recipe sources and "known by" on dropped blueprints both need a static map. Build it after launch, since beta IDs churn. |

Optional: retail's `GetAllRecipeIDs` also returns unlearned recipes. If Forever does the
same, the fork can show which recipes nobody in the guild knows yet. To check, open a
profession window and run:

`/run local a=C_TradeSkillUI.GetAllRecipeIDs() or {};local n=0;for _,id in ipairs(a) do local i=C_TradeSkillUI.GetRecipeInfo(id);if i and i.learned then n=n+1;end;end;print("all",#a,"learned",n,"max id",#a>0 and math.max(unpack(a)) or 0);`

If "all" is greater than "learned", unlearned recipes are listed. The max ID also shows
whether new recipes sit above about 1,000,000 (C5).

## 9. Lessons from Recipe Registry

Compared against Recipe Registry's Forever addon (`RecipeRegistry_Forever/` on its `develop`
branch, `f7ffbb9`, MIT). The method was three read-only comparisons plus spot checks. RR's
docs are in Italian.

### Client facts RR verified in game (builds 69913–70009)

| Fact | RR's date | Affects |
|---|---|---|
| Classic tradeskill APIs are nil. `C_TradeSkillUI` has `GetAllRecipeIDs`, `GetRecipeInfo`, `GetRecipeItemLink`, `GetRecipeLink`, `GetBaseProfessionInfo`, `GetCategoryInfo` and `GetRecipeSchematic`, undocumented ones included | 09-18 | F5, F12 |
| `GetAllRecipeIDs` returns the whole catalog: 197 Alchemy rows at skill 1, 3 of them learned. With the window closed it returns a stale copy of the last profession opened | 09-18, 09-25 | F11 |
| `C_SpellBook.IsSpellKnown(recipeID)` is correct; the global `IsSpellKnown` returns false for recipe IDs | 09-18 | F16 |
| `GetBaseProfessionInfo` can be empty; `GetProfessionInfoByRecipeID` still answers | 09-18 | F21 |
| `TRADE_SKILL_SHOW` fires with an empty catalog; `TRADE_SKILL_DATA_SOURCE_CHANGED` fires with the full one | RR `Core/Core.lua:550-558` | F11 |
| Names are "First Surname". `UnitFullName` changed shape three times in a week, while `UnitNameUnmodified` returns both parts. Roster names and addon senders are bare "First Surname", whispers to the full name arrive, and a 120-member roster showed no realm suffix | 09-18 to 09-26 | F6, F17, F20 |
| ChatThrottleLib v31 taints every chat line | spec comment | F18 |
| SavedVariables are written but not reloaded (69913) | 09-18 | F1 |
| `GetRecipeSourceText` returns nothing for every recipe | generator comment | C6 |
| The `OnTooltipSetItem` script is gone, while `TooltipDataProcessor` and `GameTooltip:GetItem` work | 09-21 | tooltip |

Blizzard's own Forever code agrees on names: `NameUtil.GetUnmodifiedUnitFullName` joins
`UnitNameUnmodified`'s two parts with `Constants.CharacterNameSeparatorConsts.CHARACTERNAME_SURNAME_SEPARATOR`
(`Blizzard_FrameXMLUtil/Camelot/NameUtil.lua`, legacynext pin).

### Borrow now (small, no wire change)

1. **Identity.** Build the self key from `UnitNameUnmodified`, or from `NameUtil` where it
   exists. Use roster, sender and whisper names as-is, add RR's key validation (reject `:`,
   `|`, control characters and edge spaces), and migrate stored keys. (RR
   `Data/Data.lua:579-584`, `:862-876`, `:947-952`.) Fixes F6, F17 and F20.
2. **ChatThrottleLib v32**, plus RR's spec. Fixes F18.
3. **Data-safety rules** (RR `MergeEngine.lua:66-74`, `DataIndex.lua:456`,
   `DataScan.lua:213-220`, `:786-804`, `GuildLifecycleMaintenance.lua:65-84`). Fixes F1 and
   F19.
   - Union the recipes per profession.
   - Never let an empty profession win.
   - Merge additively into your own key when the local copy is empty.
   - Reject scans that shrink a profession.
   - Prune nothing on an empty read.
   - Abort pruning when the roster holds under 50% of known members.

   Keep GC's `remove_profession` with a per-profession drop time. Without it, the union
   inherits RR's bug where dropped professions come back.
4. **Scan gate** (RR `DataScan.lua:442-533`, `Core.lua:295-338`, `:546-559`). Fixes F5, F11
   and F21.
   - Require `IsTradeSkillReady`.
   - Reject Linked, Guild, GuildMember and NPC views. RR misses GuildMember.
   - Fall back to `GetProfessionInfoByRecipeID` for the profession.
   - Listen for SHOW plus DATA_SOURCE_CHANGED instead of LIST_UPDATE.
   - Retry at 0.3, 1, 2 and 5 s, with a token so newer events cancel older retries.
   - Guard on learned counts.
5. **All 12 professions**, with an allowlist. Rogue poisons (skill line 40) look like a
   profession in the data. (RR `Data.lua:110-163`.) Fixes F3 and part of C1.
6. **Categories** via `GetCategoryInfo(categoryID)`. Fixes F12.
7. **`NEW_RECIPE_LEARNED`**, with a required `C_SpellBook.IsSpellKnown` check. Queue every
   ID; RR keeps only the last.
8. **Vanilla-only specialisation IDs**: RR keeps 10 and drops the TBC ones. Covers C3.
9. **Short tooltip** (nine lines at most), with a chunked index and a dirty flag. Fixes F9
   and the tooltip clutter.
10. **Settings panel** registered through `Settings.RegisterCanvasLayoutCategory`. Use
    `OnRefresh`/`OnDefault`; RR sets `refresh`/`default`, which Forever never calls. Add
    LibDBIcon 56 with `showInCompartment`.
11. **Plain-Lua specs** with captured fixtures. RR's nine pass under PUC Lua 5.1. They end
    in `os.exit`, so busted reports a false pass.
12. **Version and channel from the TOC** (`C_AddOns.GetAddOnMetadata`), plus a dev comm
    prefix.
13. **An in-memory "why isn't it syncing" diagnostic**, about 100 lines.

### Borrow with the v3 wire format (needs a VERSION bump and a new comm prefix)

- **Fingerprint-first handshake on owner×profession blocks** (RR's djb2 hash,
  `DataIndex.lua:94-121`). It replaces the per-member version vector.
- **Keys-only block transfer.** On synthetic data RR measured 7.6 B per recipe against GC's
  43.7. One block per message with a per-block timeout, and no RESUME. Pipeline 2–3 blocks
  instead of RR's 2.5 s gap.
- **Requester-chosen seeds** instead of DR/BDR. Only worth it together with the two items
  above.

### UI ideas

- A recipe-keyed search index with debounce, a minimum length and chunked builds. Then add
  tokens, fuzzy matching and ranking; RR's search is still a literal substring match.
- A detail panel: online crafters with a one-click Ask (recipe link, BoP-aware) and a folded
  offline list.
- A "+ Materials" search scope.
- A guild members tab showing addon versions.
- Saved size, position and scale.
- Share materials (`/rr share …`).

### Don't copy

- the five-slot `GetProfessions` read
- the missing GuildMember check
- the last-ID-only debounce
- the 2.5 s idle per block
- ALERT-priority digests
- `panel.refresh`/`default`
- a union merge without retraction
- the scraped source rows

### Data provenance

RR's Forever dataset is 1.7 MB: 2,519 recipes from build 69913.

- **Safe:** the client-derived fields (IDs, reagents, categories) and RR's own vendor
  captures (about 800 rows).
- **Not reproducible:** the expansion flags and the recipe-item map come from a private
  datamining repo.
- **Unclear licence:** 1,211 source rows come from cMaNGOS-derived TBC data (GPL; not
  checked), and 396 from foreverchanges.pro, which reads from Wowhead (whose terms restrict
  reuse).

For C5, a spell ID ≥ 1,000,000 correctly tags 858 of 861 Forever-new recipes and misfires on
33 Season of Discovery leftovers. That only works if GC keeps the recipe spell ID at scan
time.

### Where GuildCrafts is ahead

- `!gc` for members without the addon
- the member drill-down; RR can't show what one member makes
- favourite members, and an editable whisper
- guild-wide retraction of a dropped profession
- DELTA_AD pushes changes within seconds; RR waits up to 300 s
- one 97 B heartbeat a minute, against a 329 B ALERT HELLO from every RR client
- sync code at a third of RR's size
- fits small screens
- a secret-value guard on chat, which RR lacks

### Strategy notes

- **Separate folder.** RR ships Forever as a separate addon folder, a full copy that is 89%
  duplicated, because "Forever is vanilla content behind a retail-shaped API". That argues
  for decision 1 going Forever-only, or a separate tree rather than multi-TOC.
- **Crafting orders.** RR's craft-orders and mail branch is TBC-only and unmerged. Forever
  ships Blizzard's crafting orders (`C_CraftingOrders`), and the probe checks the tab before
  anything similar gets built.

## Sources

- [warcraft.wiki.gg — TOC format](https://warcraft.wiki.gg/wiki/TOC_format)
- [Warcraft Tavern — WoW Forever Professions](https://www.warcrafttavern.com/forever/guides/professions/)
- [Zockify — WoW Forever Professions](https://www.zockify.com/forever/professions/)
- [Recipe Registry](https://www.curseforge.com/wow/addons/recipe-registry)
- [Profession Master](https://www.curseforge.com/wow/addons/profession-master)
- [ForeverSVFix](https://github.com/nobewayo/ForeverSVFix)
- [Recipe Registry (GitHub)](https://github.com/colettamattia91-cloud/Recipe-Registry), `develop` at `f7ffbb9`
- [Wowhead Forever — Anvil (spell 1263041)](https://www.wowhead.com/forever/spell=1263041/anvil)
- [ForeverDiff — Blueprint: Anvil (item 273086)](https://foreverdiff.com/items/blueprint-anvil-273086/)
- [Blizzard forums — SavedVariables never load (69913)](https://us.forums.blizzard.com/en/wow/t/savedvariables-never-load-in-the-beta-%E2%80%94-all-addon-settings-reset-on-login-69913/2354798)
