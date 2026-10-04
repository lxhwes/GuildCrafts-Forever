# N3: Companion export block in SavedVariables — implementation spec

Issue [#53](https://github.com/lxhwes/GuildCrafts-Forever/issues/53). Written 2026-10-04 against
`main` at `4c9492b`. Status: ready to build after N1 ([#51]), N2 ([#52]) and H3 ([#6]).

## Start here (for a new session)

1. Read `CLAUDE.md`, `spec/later/N1-export.md` (the model and schema this reuses),
   `spec/later/N2-optout.md`, and the ADR `spec/later/N4-adr-external-services.md`.
2. Confirm the CLUB probe result is in `spec/migration-forever.md`; run it if not.
3. TDD: `test(companion):` first.

## Why a block at all

The companion (N5) must never parse internal tables. `GuildCraftsDB` holds every guild any
character on the account has been in (`Data:GetGuildDB`, `Modules/Data.lua:490-522`), so
uploading or even parsing it risks leaking other guilds. The addon writes one versioned block
per guild the player enabled, and the companion reads only that.

## Decisions

| Date | Decision | Why |
|---|---|---|
| 2026-10-04 | A separate SavedVariable, `GuildCraftsExport`, declared only in `GuildCrafts_Camelot.toc` | Alex. The companion parses only the `GuildCraftsExport = {...}` statement and skips `GuildCraftsDB` without building it. Same file on disk (`WTF/Account/<ACCOUNT>/SavedVariables/GuildCrafts.lua`) |
| 2026-10-04 | The block is N1's JSON model (schema 1) as a Lua table | One schema for copy-paste, companion and backend |
| 2026-10-04 | The enable flag is `GuildCraftsDB.global._companion[guildKey] = 1` | Account-wide, per partition, internal. Not in `GuildCraftsExport`, so the companion sees data only |

## Shape

```lua
GuildCraftsExport = {
    format = 1,                 -- the container's version; N1's schema number is inside each block
    guilds = {
        ["Grim-Classic Beta PvP"] = {
            schema = 1, kind = "guildcrafts-export", addon = "2.2.0-forever", locale = "enUS",
            generatedAt = 1790000000,
            guild = { name = "Grim", key = "Grim-Classic Beta PvP", clubId = "123456" },
            recipes = { [-2330] = { name = "Minor Healing Potion", category = "Potions" } },
            members = { { guid = "Player-4619-012F81BC", name = "Geo Prizm", lastUpdate = 1789990000,
                          professions = { { name = "Alchemy", skill = 210, maxSkill = 225,
                                            lastScanned = 1789990000, recipes = { -2330 } } } } },
        },
    },
}
```

- No booleans (SavedVariables rule). Missing `name` means unresolved, the same as JSON `null`.
- `guild.clubId` only when `C_Club.GetGuildClubId` exists, returns non-nil, and
  `issecretvalue` is false. It's documented at the pin (`ClubDocumentation.lua`,
  `GetGuildClubId`, `RequiresClubsInitialized = true`), so it can be nil early in a session.
  It's a hint for the backend's guild pin (ADR AD7), never an identity.
- `recipes` keys are numbers in Lua; N5 converts them to decimal strings for JSON.

## Behaviour

- `/gc companion on`: set the flag for the current guild key and print what will happen:
  `Companion export on for <guild>. At each logout or /reload, GuildCrafts writes this guild's
  recipe data to its SavedVariables file for the GuildCrafts companion app to upload. The addon
  itself sends nothing outside the game.`
- `/gc companion off`: clear the flag and set `GuildCraftsExport.guilds[guildKey] = nil` at once.
- `/gc companion` (status): on or off for this guild, the last `generatedAt`, member count.
- On `PLAYER_LOGOUT` (it also fires on `/reload`):
  1. Drop every `GuildCraftsExport.guilds[key]` whose flag isn't set.
  2. If the current guild's flag is set, rebuild its block with `Export:Collect()`.
  3. Leave other enabled guilds' blocks alone. They hold data from the last logout of a
     character in that guild.
- `Collect()` already leaves out opted-out members and the owner when opted out (N1, N2). The
  "hide in my view" list doesn't apply.
- Build cost: one `Collect()` per logout, about 20 ms for 100 members in desktop Lua 5.1.

## Size

`spec/later/research/export-size.lua` estimates the block at about 360 KB for 100 members (2
professions of 120 recipes plus Cooking each), against roughly 2 MB for the member data already
in `GuildCraftsDB`. Measure it for real in the test with a writer that formats like the client
(tabs, `["key"] = value,`, `-- [n]` index comments) and record the number in the issue.

## Tests: `tools/test-companion-export.lua`

1. Two partitions, X enabled and Y not. Logout while in X: only X in `GuildCraftsExport.guilds`.
2. Then log in to a character in Y and log out: X still present, Y absent.
3. `/gc companion off` in X: block gone immediately, and still gone after the next logout.
4. Turning the flag off by any other path (flag cleared, block present): gone at next logout.
5. Opted-out member markers and the opted-out owner are absent.
6. The block contains no booleans (walk the table).
7. `clubId` is omitted when `C_Club` is nil, when it returns nil, and when `issecretvalue` says
   the value is secret.
8. Size print for the 100-member fixture (informational, not asserted).

Add to CI, `CLAUDE.md` "Verification" and `docs/testing.md`.

## In-game

- CLUB probe, in a guild. Prints the club ID, its name and type, and the guild name:
  ```
  /run local id=C_Club and C_Club.GetGuildClubId and C_Club.GetGuildClubId();local i=id and C_Club.GetClubInfo and C_Club.GetClubInfo(id);print("CLUB",id,i and i.name,i and i.clubType,GetGuildInfo("player"));
  ```
- With the feature built: `/gc companion on`, `/reload`, then open
  `WTF/Account/<ACCOUNT>/SavedVariables/GuildCrafts.lua` and confirm `GuildCraftsExport` holds
  one guild. Note the file size before and after.
- If the TOC `## SavedVariables:` line change doesn't take effect after `/reload`, a full client
  restart is needed (the client reads TOC metadata at startup). Record which.

## Docs

`docs/user-guide.md`: what the block holds, that it sits in plain text in the WTF folder like
the rest of GuildCrafts' data, and how to turn it off. CHANGELOG `### New features`.

## Done when (from the issue)

- [ ] The block exists only for enabled partitions; disabling removes it at next logout.
- [ ] Test proves a two-guild SavedVariables yields an export for the enabled guild only.
- [ ] Size impact recorded in the issue.
- [ ] `C_Club` availability probed in game and recorded in `spec/migration-forever.md`.

[#6]: https://github.com/lxhwes/GuildCrafts-Forever/issues/6
[#51]: https://github.com/lxhwes/GuildCrafts-Forever/issues/51
[#52]: https://github.com/lxhwes/GuildCrafts-Forever/issues/52
