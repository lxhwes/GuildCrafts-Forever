# N1: `/gc export` copy frame — implementation spec

Issue [#51](https://github.com/lxhwes/GuildCrafts-Forever/issues/51). Written 2026-10-04 against
`main` at `4c9492b`; line numbers are at that commit. Status: ready to build once the Oct 28
freeze has passed and the launch build is out.

## Start here (for a new session)

1. Read `CLAUDE.md`, this file, and the privacy rules in `spec/later-backlog.md`.
2. Read `GuildCrafts/Modules/Report.lua` (the copy box this reuses) and `tools/test-report.lua`
   (the test pattern).
3. Run the EB probe below, and the TIME probe in `docs/ingame-commands.md`, if their results
   aren't in `spec/migration-forever.md` yet.
4. Work TDD: `test(export):` commit first, then `feat(export):`.

## Decisions

| Date | Decision | Why |
|---|---|---|
| 2026-10-04 | JSON uses a recipe dictionary plus per-member key lists, not one object per member-recipe | 100-member fixture: 2.0 MB row-per-recipe vs 246 KB compact (`spec/later/research/export-size.lua`). N3 and N5 reuse this shape |
| 2026-10-04 | Reuse Report's raw `EditBox` copy frame, not AceGUI | Report's frame is verified on Forever (H5, PR #50). AceGUI is embedded but nothing uses it, and it is untested on 1.60.1 |
| 2026-10-04 | "Hide in my view" (N2a) doesn't filter exports; only the opt-out marker (N2b) does | Alex, 2026-10-04: hiding is personal, export answers for the guild |
| 2026-10-04 | Output is deterministic: members, professions and recipe keys sorted | N5's dry run must match the upload byte for byte, and N8's feed diffs snapshots |

## Code facts

- Guild partition: `Data:GetGuildDB()` (`Modules/Data.lua:501`) returns `db.global[guildKey]`.
  Member entries are tables with `professions`; tombstones have no `professions`, so every
  reader that checks `entry.professions` already skips them (`Data.lua:2406`, `:2569`, `:2631`,
  `Tooltip.lua:73`). N2's opt-out marker is tombstone-shaped and is skipped the same way.
- Stored per-profession fields: `skillLevel`, `maxSkillLevel`, `specialisation`, `lastUpdate`,
  `recipes[recipeKey] = { name, source }`, and a local-only `cooldowns` (`Data.lua:1014-1037`)
  that exports leave out. `StripSyncFields` (`Data.lua:1753-1770`) shows the synced subset.
  Categories and reagents live in the shared RecipeDB: `Data:GetRecipeCategory(key)` (`:354`).
- Recipe keys: positive item ID or negative spell ID (`Data.lua:321`).
- Display names: `Data:GetMemberName(guid)` (`ForeverIdentity.lua:115`) returns the GUID itself
  when the roster can't resolve it. H3 ([#6]) will persist names; until then offline members may
  be unresolved.
- Localized recipe names: `Data:GetLocalizedRecipeName(key, fallback)` (`Data.lua:189`).
- Timestamps are `time()` today. H2 ([#5]) moves sync revisions to `GetServerTime()`, which is
  documented at the pin (`SystemTimeDocumentation.lua`, `GetServerTime`).
- Slash commands: `GuildCrafts:SlashHandler` (`Core.lua:482`) lowercases its whole input
  (`:483`). The help line is `Core.lua:534`.
- Copy frame: `EnsureFrame` and `Report:Show` (`Report.lua:226-278`). `Show` doubles every `|`
  so color codes copy as typed (`:275`).
- Camelot-only modules (Report, ForeverIdentity) are listed only in `GuildCrafts_Camelot.toc`,
  and `Core.lua` guards on `self.Report`. Export follows the same pattern, because the five
  Classic TOCs are never edited.

## Design

### Module

`GuildCrafts/Modules/Export.lua`, Camelot TOC only, listed after `Modules\Report.lua`.

```lua
Export:Collect()          -- → model table (below); pure, no frames, testable
Export:ToJSON(model)      -- → string
Export:ToCSV(model, profFilter) -- → string
Export:Show(format, profFilter) -- builds, then opens the copy box
```

`Collect` walks `GetGuildDB()` and skips:
- entries without a `professions` table (tombstones and N2 opt-out markers);
- the local player's own entry when N2's own opt-out flag is set;
- professions with no recipes (gathering professions still appear in JSON with `recipes: []`,
  but produce no CSV rows).

### Copy box

Refactor `Report.lua`'s `EnsureFrame` into `Report:ShowCopyBox(title, text, escapePipes)` and
have `Report:Show` call it. Export calls `Report:ShowCopyBox("GuildCrafts export (JSON) -
Ctrl-A, Ctrl-C to copy", text, false)`. JSON escapes `|` as `\u007c`, so the box never sees a
raw pipe. CSV replaces any `|` with `/`; names can't contain pipes, so only a malformed recipe
name could hit this.

### Commands

```
/gc export json            whole guild partition
/gc export csv             whole guild partition
/gc export csv <profession>  one profession (case-insensitive, canonical name via Data:GetCanonicalProfName)
```

Parse from the raw input, before `SlashHandler`'s `:lower()`, or match case-insensitively.
Add both to the help line and to `docs/user-guide.md` "Slash commands".

If the built string is larger than the EB probe's comfortable size, print one chat line with
the size and suggest `/gc export csv <profession>` instead of opening the box.

### JSON schema 1

```json
{
  "schema": 1,
  "kind": "guildcrafts-export",
  "addon": "2.2.0-forever",
  "locale": "enUS",
  "generatedAt": 1790000000,
  "guild": { "name": "Grim", "key": "Grim-Classic Beta PvP" },
  "recipes": {
    "-2330": { "name": "Minor Healing Potion", "category": "Potions" },
    "2459":  { "name": "Swiftness Potion", "category": "Potions" }
  },
  "members": [
    {
      "guid": "Player-4619-012F81BC",
      "name": "Geo Prizm",
      "lastUpdate": 1789990000,
      "professions": [
        { "name": "Alchemy", "skill": 210, "maxSkill": 225,
          "specialisation": "Elixir Master", "lastScanned": 1789990000,
          "recipes": [-2330, 2459] }
      ]
    }
  ]
}
```

- `generatedAt`: `GetServerTime()` when present, else `time()`. Both are Unix seconds.
- `name`: `null` when `GetMemberName` returns the GUID (unresolved). Never write a GUID into
  `name`.
- Optional fields (`specialisation`, `category`, `maxSkill`) are omitted, never `null`, except
  `name`.
- No booleans anywhere (N3 stores this as a Lua table in SavedVariables).
- `recipes` object keys are the recipe key as a decimal string. Member `recipes` arrays hold
  numbers, sorted ascending.
- `members` sorted by `name` (unresolved last, then by GUID). `professions` sorted by name.
- String escaping: `\"`, `\\`, `\n`, `\r`, `\t`, other bytes below 0x20 as `\u00XX`, and `|` as
  `\u007c`. Pass other bytes through; WoW strings are UTF-8.

### CSV

Header: `Member,Profession,Skill,Specialisation,Recipe,RecipeKey,Category,LastScanned`. One row
per member-profession-recipe, ordered like the JSON.
- RFC 4180 quoting: quote a field containing `,` `"` CR or LF, and double inner quotes. Two-word
  names ("Geo Prizm") need no quoting.
- `Member`: the display name, or `(unresolved)` when it isn't known. No GUIDs in CSV.
- `LastScanned`: `YYYY-MM-DD` of the profession's `lastUpdate`, UTC via `date("!%Y-%m-%d")` if
  the TIME probe shows `!` works, else local `date("%Y-%m-%d")`.
- Line ending `\n`.

### Performance

The 100-member fixture builds in about 20 ms in desktop Lua 5.1. That's a one-off hitch on a
typed command, so no coroutine unless the in-game timing (`debugprofilestop`) exceeds 100 ms.
The EditBox `SetText` cost is the unknown; the EB probe measures it.

### `docs/export-format.md`

Write the schema above, plus this compatibility rule:
- Adding an optional field doesn't change `schema`.
- Removing or renaming a field, or changing a type or meaning, increments `schema`.
- Consumers ignore unknown fields and reject a `schema` they don't know.

## Tests: `tools/test-export.lua`

Copy the stubbing pattern from `tools/test-report.lua`. Cases:
1. CSV escaping: a recipe name with a comma, one with a double quote, one with a newline;
   two-word member names stay unquoted.
2. Empty guild partition: JSON has `"members":[]` and `"recipes":{}`; CSV is the header only.
3. Not in a guild: `/gc export` prints a message and opens nothing.
4. Tombstones and opt-out markers (`{ _tombstone = true, _optout = 1, lastUpdate = n }`) are
   absent from both formats. Write this case now; it passes before N2 exists because neither
   has `professions`.
5. Own opt-out flag set (stub N2's accessor): own entry absent.
6. Unresolved name: JSON `"name":null` with the GUID; CSV `(unresolved)`.
7. Deterministic: two `Collect` runs over the same data, built in different insertion orders,
   give identical strings.
8. JSON is valid: decode it with a small decoder in the test, or pipe it to
   `python3 -m json.tool` (the CI runner and Alex's Mac both have Python 3).
9. `|` in a recipe name becomes `\u007c` in JSON and `/` in CSV.
10. Profession filter: `csv alchemy` returns only Alchemy rows.

Add the suite to `.github/workflows/ci.yml` and to the list in `CLAUDE.md` "Verification" and
`docs/testing.md`.

## In-game checks

Add EB to `docs/ingame-commands.md`; it parse-checks with `luac -p` and is 255 characters or
fewer.

EB, anywhere. Prints input length, stored length and milliseconds for a 1 MB `SetText`:
```
/run local f=CreateFrame("EditBox");f:SetMultiLine(true);f:SetMaxLetters(0);if f.SetMaxBytes then f:SetMaxBytes(0);end;local s=("abcdefghi\n"):rep(1e5);local t=debugprofilestop();f:SetText(s);print("EB",#s,#f:GetText(),floor(debugprofilestop()-t));
```
Then, with N1 built: `/gc export json` in the real guild, Ctrl-A, Ctrl-C, paste into a text
editor, and confirm the byte count matches and the JSON validates.

Whether `date` takes the `!` UTC prefix, and the client/server clock skew, are answered by the
TIME probe already in `docs/ingame-commands.md` (H2). Its last field is server time formatted
with `date("!...")`, and its third is server minus client in seconds. One TIME run answers both
H2 and N1, so N1 adds no probe of its own.

## Done when (from the issue)

- [ ] `/gc export csv` and `/gc export json` open the frame; `/gc help` lists them.
- [ ] Schema written down in `docs/export-format.md`, with a version number and a compatibility
      rule.
- [ ] `tools/test-export.lua` covers CSV escaping, an empty guild, and opt-out exclusion; added
      to CI.
- [ ] luacheck 0 warnings; user guide updated.

Also: CHANGELOG entry under `## Unreleased` → `### New features`; EB and TIME results recorded in
`spec/migration-forever.md`.

[#5]: https://github.com/lxhwes/GuildCrafts-Forever/issues/5
[#6]: https://github.com/lxhwes/GuildCrafts-Forever/issues/6
