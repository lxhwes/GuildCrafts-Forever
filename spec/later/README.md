# Later backlog N1–N8: implementation specs

Written 2026-10-04 against `main` at `4c9492b`. These turn issues #51–#58 into specs a new
session can start from. The ideas, the privacy rules and the original done-when lists are in
`spec/later-backlog.md`; the issues stay the trackers. Nothing here starts before the Oct 28
feature freeze has passed and the launch build is out.

## Order

```
N2 opt-out ──┬─► N1 export ──► N3 companion block ──► N5 companion
             │        └──────► N4 ADR ──► N6 backend ──┬─► N5 companion
             └───────────────────────────────────────────┤─► N7 web book
                                                         └─► N8 Discord bot
```

1. **N2** first: the protocol change, and every export path filters on it. N1 can be built in
   parallel; its opt-out test passes before N2 exists.
2. **N1**, then **N3** (after H3 [#6] persists names).
3. **N4** accepted, then the new repository is created (AD1).
4. **N6**, then **N5**, **N7** and **N8**, which can go in parallel.

| ID | Spec | Repo | Feasible? | Blocked on |
|---|---|---|---|---|
| N1 | [N1-export.md](N1-export.md) | addon | Yes. Size measured; EB probe pending | EB and DT probes |
| N2 | [N2-optout.md](N2-optout.md) | addon | Yes, with an accepted residual for version-3 clients | — |
| N3 | [N3-companion-export.md](N3-companion-export.md) | addon | Yes. `C_Club.GetGuildClubId` documented at the pin | N1, N2, H3 [#6]; CLUB probe |
| N4 | [N4-adr-external-services.md](N4-adr-external-services.md) | addon (ADR) | Proposed | Alex's review |
| N5 | [N5-companion.md](N5-companion.md) | new | Yes. Launch folder name unverified | N3, N4, N6 |
| N6 | [N6-backend.md](N6-backend.md) | new | Yes, on Workers Paid | N4; Cloudflare and Discord accounts |
| N7 | [N7-web-book.md](N7-web-book.md) | new | Yes | N6 |
| N8 | [N8-discord-bot.md](N8-discord-bot.md) | new | Yes. Error 1015 risk on feed posts only | N6 |

N9 ([#59]) was answered during this work. Battle.net has no Forever API namespace, and the Classic
profile APIs have no professions endpoint (`research/2026-10-03-companion-n9.md`, Part B).
#59 was closed as not planned on 2026-10-04.

## Decisions made 2026-10-04 (Alex)

- N2 marker is tombstone-shaped: `{ _tombstone = true, _optout = 1, lastUpdate }`.
- `GuildCrafts.VERSION` goes to 4 with N2; `DATA_FORMAT_VERSION` stays 3; #34 becomes v5.
- "Hide in my view" affects this client's UI and tooltip only.
- The companion block is a separate SavedVariable, `GuildCraftsExport`.
- Multi-tenant design, launching with one operator-provisioned tenant (Alex's guild).
- Cloudflare Workers Paid ($5/month).
- One new monorepo for companion, Worker and web app: `lxhwes/GuildCrafts-Companion`.
- Unsigned companion binaries for the first testers; Certum later.

## Findings from this work

- A plain opt-out marker would be undone by today's clients. F1's carry-over restores its
  recipes, and they're relayed at the marker's revision (`research/optout-v3-compat.lua`).
- The tombstone-resurrection guard rejects entries that have a 0-recipe profession, such as
  Herbalism or Skinning (`Data.lua:1932-1943`). Today a roster pass clears ordinary tombstones
  and hides this. N2 has to fix it, or opt-in fails.
- A full-guild export is about 2–2.5 MB as CSV or row-per-recipe JSON for 100 members, and about
  250 KB with a recipe dictionary (`research/export-size.lua`).
- `SlashHandler` lowercases all input (`Core.lua:483`), so any command that takes a member name
  must read the raw input.
- The client writes SavedVariables by renaming the old file to `.bak` and writing a new one in
  place. The companion has to debounce and verify the parse.

## In-game probes to run (beta, any character in a guild)

The commands are in the N1 and N3 specs; all three are parse-checked and 255 characters or
fewer. Add them to `docs/ingame-commands.md` and the gist when the work starts. Record the
results in `spec/migration-forever.md`.

| Tag | What it answers | Spec |
|---|---|---|
| EB | How long a 1 MB `SetText` takes in a multi-line EditBox, and whether it stores it all | N1 |
| DT | Whether `date` takes the `!` UTC prefix; client vs server clock skew | N1 |
| CLUB | Whether `C_Club.GetGuildClubId` returns an ID on Forever | N3 |

## Research

- `research/2026-10-03-hosting-discord.md`: Cloudflare limits and pricing, Discord OAuth and
  interactions, alternatives, cost.
- `research/2026-10-03-companion-n9.md`: companion language, signing, keychain, file watching,
  parsers, policy, N9.
- `research/optout-v3-compat.lua`, `research/export-size.lua`: run from the repository root
  with `lua5.1`.

[#6]: https://github.com/lxhwes/GuildCrafts-Forever/issues/6
[#59]: https://github.com/lxhwes/GuildCrafts-Forever/issues/59
