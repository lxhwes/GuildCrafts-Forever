# GuildCrafts Forever — "Later" backlog

Written 2026-10-03 against `main` at `3c646a5`. These are feature ideas parked until after
launch. Nothing here is committed work, and nothing here may start before the Oct 28 feature
freeze has passed and the launch build is out. It defines plan IDs **N1–N9** (things that leave
the game: export, companion, web, Discord) and **G1–G7** (in-game features). Neither prefix
means anything else in `spec/`.

---

## Instructions for Claude Code (done)

**Done 2026-10-03. Don't run these steps again.** Issues [#51]–[#66] exist on the Later
milestone, the four labels were added, and the plan was updated in
[PR #70](https://github.com/lxhwes/GuildCrafts-Forever/pull/70). The W prefix became N, because
`docs/testing.md` already uses W1 and W2 as checklist steps. The steps below are kept as a record.

Read `CLAUDE.md` first; its rules win over anything here. Then:

1. **Look at the existing format.** Open two existing issues (for example #34 and #44) and copy
   their structure: title `<ID>: <title>`, the plan-link header, a **Findings** section and a
   **Done when** checklist. Use the Why / How / Depends on / Done when content below for each
   item. Cite this file (`spec/later-backlog.md`) the same way issues cite
   `spec/fork-review.md` and `spec/curseforge-audit.md`.
2. **Milestone and labels.** Create a milestone named **Later**, separate from Post-launch
   (Post-launch holds committed work; Later holds ideas). List the existing labels, then
   propose only the missing ones from this set: `feature`, `external`, `security`, `research`.
   Reuse `needs-ingame` and `documentation` where noted. Ask Alex before creating labels or the
   milestone.
3. **Dry run first.** Print every issue title, its labels and the first lines of its body, and
   wait for Alex to approve before creating anything on GitHub.
4. **Create the issues** in ID order (N1…N9, then G1…G7) so the numbers come out grouped.
5. **Update `spec/forever-plan.md`:**
   - Add a `## Later (ideas, not committed)` section after "Post-launch (parked)", with one
     table for N and one for G, columns `ID | Issue | Item | Depends on`, linking issues as
     `[#N]`.
   - Add the `[#N]: https://github.com/lxhwes/GuildCrafts-Forever/issues/N` reference lines at
     the bottom, in number order.
   - Add a decisions-log row: `2026-10-03 | Later backlog N1–N9, G1–G7 added from
     spec/later-backlog.md; N4 design gates all external services`.
   - In the "Finding index (CurseForge comment audit)" area, don't touch existing rows. Audit row
     X3 is now tracked as N2; mention that in N2's issue, not in the audit file.
6. **Don't commit or push.** Leave the plan edit and this file uncommitted and tell Alex which
   files changed. Escape `|` as `\|` in any table cell.

---

## Privacy and guild segregation (applies to every N item)

The requirement: each guild's data is visible only to that guild, and nothing leaves the game
without consent. These are the rules every N issue inherits. N4 turns them into a threat model
and an architecture decision record before anything is built.

### What the code already does, and where it leaks

- `GuildCraftsDB` keeps one partition per guild, keyed `"GuildName-Realm"`
  (`Data:GetGuildKey`, `Modules/Data.lua`). One SavedVariables file therefore holds the data of
  **every guild any character on that account has been in**. Uploading the raw file would leak
  other guilds' data. This is the main segregation risk, and it sits on the player's own disk.
- `GuildName-Realm` isn't a safe identity for a guild. On Forever one guild can span several
  servers, and a guild name isn't unique across regions. The backend must not use it as a
  tenant ID.
- Members are keyed by GUID. Names come from the roster and aren't persisted yet (H3, [#6]).
- The addon is open source and can't hold a secret. Nothing the game produces can prove to a
  server that an upload is genuine, or that the uploader is in the guild.

### Rules

1. **Segregate at the source.** The addon writes an export only for a partition the player has
   explicitly enabled (N3). The companion reads only that block, for the one guild it's bound
   to. It never uploads the raw file, other partitions, the WTF account folder name or any file
   paths.
2. **Tenant = a guild's Discord server.** Discord is the trust anchor, because the game can't
   be one. A tenant is created by a Discord server admin and bound to that server's ID. There's
   no public directory, no tenant search and no guessable URLs, and pages are `noindex`.
3. **Viewers sign in with Discord OAuth.** Access requires membership of the bound Discord
   server, optionally with a configured role. Check it at login and again periodically, and
   keep sessions short-lived.
4. **Uploaders use tenant-scoped, write-only tokens.** One token per uploader, shown once,
   stored hashed, revocable and rotatable. A token can only replace its own tenant's snapshot.
5. **Hard tenant isolation in the backend.** Every query goes through one tenant-scoped access
   layer. Automated tests must prove that cross-tenant reads and writes fail. N4 decides
   between a `tenant_id` on every row and one database per tenant. Return 404, not 403, for
   other tenants' resources, so they can't be enumerated.
6. **Uploads are untrusted input.** Validate against the versioned export schema, cap the size,
   rate-limit per token, and escape everything in HTML (XSS) and Discord (send no mentions:
   empty `allowed_mentions`).
7. **Consent.** Officers enable the integration per guild. Each character can opt out (N2), and
   every export path honors the opt-out. `docs/user-guide.md` says exactly what leaves the game
   and where it goes.
8. **Data minimization and retention.** Store names, professions, skill levels, recipes and
   timestamps only. Purge snapshots older than a retention window. Deleting a tenant purges
   everything, including logs that carry member names.
9. **Stay inside Blizzard's addon rules.** The addon stays free and unobfuscated, and sends
   nothing out of the game itself. The companion only reads files the game has already written
   and never automates the client.
10. **Say the trust limit plainly.** A tenant admin who issues an upload token is vouching for
    that uploader. A malicious uploader could submit made-up data for their own tenant. They
    can't reach any other tenant.

---

## N — Out of game

### N1 [#51]: `/gc export` copy frame

- **Why:** The cheapest way to get data out of the game, and the format everything else reads.
  Upstream candidate #7 (`ROADMAP.md`, "Export to CSV / Text").
- **How:** A read-only `MultiLineEditBox` in an AceGUI frame, selected all on open. Two formats:
  CSV (`Member, Profession, Skill, Specialisation, Recipe, RecipeKey, Category, LastScanned`)
  and JSON with a top-level `schema` version. Current guild partition only. Names resolved
  from the live roster at export time; GUIDs in JSON only. Members who opted out (N2) are
  left out. Build strings with `table.concat`, and yield in a coroutine if a large-guild
  fixture drops frames.
- **Depends on:** N2 for the opt-out filter (N1 can ship first and add the filter when N2
  lands).
- **Done when:**
  - [ ] `/gc export csv` and `/gc export json` open the frame; `/gc help` lists them.
  - [ ] Schema written down in `docs/export-format.md`, with a version number and a
        compatibility rule.
  - [ ] `tools/test-export.lua` covers CSV escaping (commas, quotes, two-word names), an empty
        guild, and opt-out exclusion; added to CI.
  - [ ] luacheck 0 warnings; user guide updated.
- **Labels:** `feature`, `external`, `documentation`

### N2 [#52]: Per-character opt-out (audit X3)

- **Why:** A privacy prerequisite for anything that leaves the game, and a player request
  (`spec/curseforge-audit.md` X3). Untracked until now.
- **How:** Two parts, as X3 describes. (a) **Hide in my view:** a local filter, account-wide,
  stored 1/0. (b) **Stop publishing me:** a lasting opt-out marker on the member entry that
  merge, F1's carry-over (`Data.lua`) and prune all respect, so peers don't restore or revive
  the entry. Touches the protocol: read `RFC/rfc-0002-sync-protocol.md` and
  `RFC/rfc-0003-data-model.md` first. Decide whether this joins protocol v4 ([#34]). Each
  character opts out separately, because Forever doesn't expose which characters share an
  account.
- **Depends on:** [#34] if bundled with v4.
- **Done when:**
  - [ ] `/gc optout` and `/gc optin` (names to confirm), with a confirmation line in chat.
  - [ ] An opted-out member disappears from every peer's view, tooltip and `!gc` reply after
        sync, and stays gone across reloads, prune and carry-over.
  - [ ] Regression test for merge, carry-over and prune with the marker; two-client checklist
        step added to `docs/testing.md`.
- **Labels:** `feature`, `security`, `needs-ingame`

### N3 [#53]: Companion export block in SavedVariables

- **Why:** Gives the companion (N5) a stable, versioned contract, so it never parses internal
  tables, and enforces segregation at the source.
- **How:** `/gc companion on` enables the current guild's partition (stored 1/0). On
  `PLAYER_LOGOUT`, the addon writes `GuildCraftsDB._export[<guildKey>]`, using N1's JSON schema
  as a Lua table: `schema`, `generatedAt` (server time, per H2 [#5]), member names and GUIDs,
  professions, recipes. It writes nothing for partitions that aren't enabled, and clears the
  block on `/gc companion off`. Include `C_Club.GetGuildClubId()` if it exists on Forever, as a
  hint only. Measure the SavedVariables size growth on a 100-member fixture.
- **Depends on:** N1 (schema), N2 (opt-out), H3 [#6] (persisted names).
- **Done when:**
  - [ ] The block exists only for enabled partitions; disabling removes it at next logout.
  - [ ] Test proves a two-guild SavedVariables yields an export for the enabled guild only.
  - [ ] Size impact recorded in the issue.
  - [ ] `C_Club` availability probed in game and recorded in `spec/migration-forever.md`.
- **Labels:** `feature`, `external`, `security`, `needs-ingame`

### N4 [#54]: Design: companion, web and Discord bot (ADR + threat model)

- **Why:** It gates N5–N8. The privacy rules above have to become concrete decisions before
  any code or hosting exists.
- **How:** Write an ADR covering:
  - where the code lives (a separate repo is likely: the release workflow zips `GuildCrafts/`,
    and services don't belong in it);
  - the stack: Cloudflare Workers with D1, KV and R2, or an alternative;
  - the companion's language and how it's distributed (signed binaries, auto-update or not);
  - the tenancy model (rules 2–5) and isolation choice;
  - Discord app scopes and how the role check works;
  - retention numbers, cost ceiling and abuse handling.

  Add a STRIDE-style threat model, with the forged-upload and other-guild-partition cases
  stated explicitly.
- **Depends on:** N1's schema draft.
- **Done when:**
  - [ ] ADR merged, in this repo or the new one, with every privacy rule mapped to a mechanism.
  - [ ] Threat model lists each threat, its mitigation and its accepted residual risk.
  - [ ] Decision on whether N5–N8 move to the new repo's tracker.
- **Labels:** `external`, `security`, `documentation`

### N5 [#55]: Companion uploader

- **Why:** Gets the guild's recipe book to the web without anyone copying and pasting.
- **How:** Watches the SavedVariables file for changes (it's written on logout or reload),
  parses only `_export[<bound guildKey>]` with a safe Lua-table parser (never `load`/`eval`),
  and uploads with the tenant token. A first-run wizard binds one guild and pastes the token.
  A `--dry-run` shows exactly what would be sent. The token is kept in the OS keychain.
- **Depends on:** N3, N4, N6.
- **Done when:**
  - [ ] Never reads or sends other partitions, the account folder name or paths (test with a
        multi-guild fixture).
  - [ ] Parser fuzz-tested against malformed files.
  - [ ] The dry run matches the real upload byte for byte.
- **Labels:** `feature`, `external`, `security`

### N6 [#56]: Web backend: tenancy, auth and isolation

- **Why:** The privacy rules live or die here.
- **How:** Implements rules 2–8: tenant creation by a Discord server admin, Discord OAuth,
  membership and role checks, hashed upload tokens, the tenant-scoped access layer, schema
  validation, rate limits, an audit log, retention purge and tenant deletion.
- **Depends on:** N4.
- **Done when:**
  - [ ] The test suite proves cross-tenant reads and writes fail, for every endpoint.
  - [ ] Tokens are revocable, and a revoked token fails within one request.
  - [ ] Tenant deletion leaves nothing behind (checked by a query).
  - [ ] Someone other than the author reviews it against the threat model.
- **Labels:** `feature`, `external`, `security`

### N7 [#57]: Web recipe book

- **Why:** "Who can craft X" when nobody is logged in.
- **How:** Search by recipe, member or profession, with a crafter list, skill and
  specialisation. A clear "data as of <last upload>" stamp, and stale markers that match the
  addon's 30-day rule. Phone-friendly.
- **Depends on:** N6.
- **Done when:**
  - [ ] Signed-in members of the bound Discord server can search; anyone else gets nothing.
  - [ ] Opted-out members never appear.
  - [ ] Output escaping is tested with hostile names.
- **Labels:** `feature`, `external`

### N8 [#58]: Discord bot

- **Why:** `!gc` outside the game, in the place the guild already talks.
- **How:** Slash commands `/craft <recipe>` and `/crafter <member>`, with an option for
  ephemeral replies. It answers only in the bound Discord server and reads only that tenant.
  It sends no mentions. An optional "new recipes learned" feed goes to a channel an officer
  picks, built from the difference between snapshots.
- **Depends on:** N6.
- **Done when:**
  - [ ] Installed in a second, unbound server, the bot refuses every command.
  - [ ] The feed is off by default and respects opt-out.
  - [ ] Rate-limited per user.
- **Labels:** `feature`, `external`

### N9 [#59]: Spike: does Blizzard's web API cover Forever?

- **Why:** Retail's profile API has a character-professions endpoint. If it covers Forever
  characters, the web book could include guildmates who don't run the addon, and it could
  verify guild membership through Battle.net, a stronger trust anchor than Discord. Unverified.
- **How:** Check the official API docs and namespaces, and try one Forever character and
  guild. Read only; no build.
- **Done when:**
  - [ ] A yes or no recorded in `spec/migration-forever.md`, with the evidence.
  - [ ] If yes, a note in N4's ADR on using it for membership checks and coverage.
- **Labels:** `research`, `external`

---

## G — In game

### G1 [#60]: Recipe-scroll tooltip alert

- **Why:** The most useful moment to know is when you're holding, looting or browsing a
  recipe: "Nobody in the guild knows this. 2 members have Tailoring 300+."
- **How:** Extend `Modules/Tooltip.lua`'s item post-call. It needs the spell or item a recipe
  item teaches. Probe the tooltip data or item APIs on Forever first; fall back to C5's
  generated data ([#31]). No hard-coded ID tables. Debounce with the same index as the crafter
  lines (after H16 [#19]).
- **Depends on:** a probe (`needs-ingame`); [#31] if no API exists; [#19].
- **Done when:**
  - [ ] Probe added to `docs/ingame-commands.md` and its result recorded.
  - [ ] The tooltip shows "known by" or "nobody knows", plus eligible members, for recipe items.
  - [ ] There's a toggle in the bottom bar, stored 1/0.
  - [ ] No extra rebuild per hover.
- **Labels:** `feature`, `needs-ingame`

### G2 [#61]: Coverage view: single-crafter and missing recipes

- **Why:** Officers want to know where the guild depends on one person, and what nobody can
  make.
- **How:** A view or filter listing recipes with exactly one crafter, built from data the addon
  already has. "Nobody knows" needs the full recipe list from [#31].
- **Depends on:** [#31] for the second half only.
- **Done when:**
  - [ ] The single-crafter list ships without [#31].
  - [ ] Opted-out members (N2) don't count.
  - [ ] Test on a fixture.
- **Labels:** `feature`

### G3 [#62]: Reagent check in recipe detail

- **Why:** "Can I bring the mats?" without leaving the window.
- **How:** Reagents already store `itemID` when the link resolved (`Data.lua`, reagent scan).
  Show `have/need` using `C_Item.GetItemCount` or `GetItemCount`, feature-detected, with the
  bank included where the API allows. Refresh on `BAG_UPDATE_DELAYED`, throttled.
- **Depends on:** nothing.
- **Done when:**
  - [ ] Counts show for reagents that have an item ID; the rest show need only.
  - [ ] No refresh storm while looting.
  - [ ] Two-word item names are unaffected.
- **Labels:** `feature`, `needs-ingame`

### G4 [#63]: Favorite crafter online alert

- **Why:** You starred someone because you need them; tell me when they log on.
- **How:** Compare `Data._onlineCache` before and after roster rebuilds, and print one chat line
  (no sound by default) for favorited members coming online. Toggle stored 1/0. Silent during
  combat and instances, and a per-member cooldown so relogs don't spam. Coordinate with F33's
  roster-pass work ([#44]).
- **Depends on:** [#44] (F33).
- **Done when:**
  - [ ] One alert per real login.
  - [ ] Nothing during the first roster load after your own login.
  - [ ] It respects the toggle.
- **Labels:** `feature`, `needs-ingame`

### G5 [#64]: "Recently learned" feed

- **Why:** Shows the guild's crafting growing, and helps people spot new crafters.
- **How:** Keep it local: record `firstSeen` (server time) the first time this client sees a
  recipe on a member. That needs no protocol change. A panel lists the last N days. Don't count
  first-sync arrivals as "learned": suppress them during a member's initial sync.
- **Depends on:** H2 [#5] (server time).
- **Done when:**
  - [ ] A fresh install doesn't flood the feed.
  - [ ] Entries survive a reload.
  - [ ] Pruned or opted-out members drop out.
- **Labels:** `feature`

### G6 [#65]: Raid consumables view (for Dec 9)

- **Why:** Raid prep is when "who makes flasks" actually matters.
- **How:** A preset filter across Alchemy, Cooking and similar professions, grouped by category,
  showing cooldown state. Categories depend on F12's fix (H15 [#18]); cooldowns on C4 [#30].
  Build the presets from category names, not item IDs.
- **Depends on:** [#18], [#30].
- **Done when:**
  - [ ] The view lists consumable crafters with cooldowns.
  - [ ] It works in other client locales (category-driven).
  - [ ] It ships before or near raid opening.
- **Labels:** `feature`

### G7 [#66]: Public API for other addons

- **Why:** Auction house, collection and tooltip addons could show guild crafters for very
  little work on our side.
- **How:** `GuildCrafts.API`, with read-only, documented functions such as
  `GetCrafters(itemOrRecipeKey)`, `IsKnownInGuild(key)` and `GetMemberProfessions(name)`. Plus
  CallbackHandler events (already embedded): `GuildCrafts_DataChanged` and
  `GuildCrafts_MemberUpdated`. Return copies, never internal tables. Version it separately from
  the wire protocol.
- **Depends on:** N2 (the API must hide opted-out members).
- **Done when:**
  - [ ] `docs/api.md` written.
  - [ ] `tools/test-api.lua` proves returned tables can't mutate the database.
  - [ ] An API version constant exists.
- **Labels:** `feature`, `documentation`

---

## Suggested order, once launch is stable

1. N2, then N1. Both are small, useful on their own, and everything external needs them.
2. N9 (an hour of research) and N4 (the design), before writing any service code.
3. G3, G4 and G7: quick in-game wins.
4. N3, N6, N5, N7, N8: the external stack, in dependency order.
5. G1, G2, G5 and G6 as their dependencies land ([#31], [#30], [#18], [#5]).

[#5]: https://github.com/lxhwes/GuildCrafts-Forever/issues/5
[#6]: https://github.com/lxhwes/GuildCrafts-Forever/issues/6
[#18]: https://github.com/lxhwes/GuildCrafts-Forever/issues/18
[#19]: https://github.com/lxhwes/GuildCrafts-Forever/issues/19
[#30]: https://github.com/lxhwes/GuildCrafts-Forever/issues/30
[#31]: https://github.com/lxhwes/GuildCrafts-Forever/issues/31
[#34]: https://github.com/lxhwes/GuildCrafts-Forever/issues/34
[#44]: https://github.com/lxhwes/GuildCrafts-Forever/issues/44
[#51]: https://github.com/lxhwes/GuildCrafts-Forever/issues/51
[#52]: https://github.com/lxhwes/GuildCrafts-Forever/issues/52
[#53]: https://github.com/lxhwes/GuildCrafts-Forever/issues/53
[#54]: https://github.com/lxhwes/GuildCrafts-Forever/issues/54
[#55]: https://github.com/lxhwes/GuildCrafts-Forever/issues/55
[#56]: https://github.com/lxhwes/GuildCrafts-Forever/issues/56
[#57]: https://github.com/lxhwes/GuildCrafts-Forever/issues/57
[#58]: https://github.com/lxhwes/GuildCrafts-Forever/issues/58
[#59]: https://github.com/lxhwes/GuildCrafts-Forever/issues/59
[#60]: https://github.com/lxhwes/GuildCrafts-Forever/issues/60
[#61]: https://github.com/lxhwes/GuildCrafts-Forever/issues/61
[#62]: https://github.com/lxhwes/GuildCrafts-Forever/issues/62
[#63]: https://github.com/lxhwes/GuildCrafts-Forever/issues/63
[#64]: https://github.com/lxhwes/GuildCrafts-Forever/issues/64
[#65]: https://github.com/lxhwes/GuildCrafts-Forever/issues/65
[#66]: https://github.com/lxhwes/GuildCrafts-Forever/issues/66
