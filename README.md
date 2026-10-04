# GuildCrafts for WoW Forever

GuildCrafts was written by [dkruenbo](https://github.com/dkruenbo/GuildCrafts) (`_Lektor`).
Alex Howes maintains this WoW Forever flavor with the author's permission. The permission and
its terms are in
[docs/ORIGIN.md](https://github.com/lxhwes/GuildCrafts-Forever/blob/main/docs/ORIGIN.md).
Licensed under MIT, see [LICENSE](LICENSE).

GuildCrafts builds a shared recipe book for your guild. When you open a profession window, it
records the recipes you know. It then shares them with every other guild member running
GuildCrafts, over the guild's addon message channel.

## Status

- This fork supports WoW Forever only: Interface 16001, client 1.60.1, currently in beta.
  Launch is planned for 2026-11-04.
- No Forever build has been published to CurseForge yet. Until one is, install from a GitHub
  checkout (below).
- The five Classic TOCs (Classic Era, TBC, Wrath, Cata, Mists) and `GuildCrafts/Data/` came
  with upstream. They stay in the tree untouched, but this fork doesn't maintain or publish
  them. If you play a Classic flavor, use upstream
  [dkruenbo/GuildCrafts](https://github.com/dkruenbo/GuildCrafts).

## What it does

- Records your recipes and their reagents each time you open a profession window.
- Syncs recipes between GuildCrafts users in the same guild. New recipes go out as soon as
  they're scanned, and each login runs a catch-up sync.
- Lets you browse by profession: who has it and at what skill, what each member can craft, and
  every recipe the guild knows with its crafters.
- Searches recipe, profession and member names.
- Adds a crafter list to item tooltips.
- Saves favorite recipes and members per character.
- Links recipes to chat with shift-click, and posts a crafter list to guild chat. Posting
  hasn't been confirmed on Forever yet.
- Has a whisper button for crafters. It doesn't handle Forever's two-word names yet (F20 in the
  plan).
- Answers `!gc <recipe>` typed in guild chat. This reply hasn't been confirmed on Forever yet.
- Pauses outgoing sync during combat, instances, zone changes and Forever's addon restrictions.

The recipe book only covers guild members who run GuildCrafts and have opened their
profession windows. A guildmate without the addon, or one who hasn't scanned yet, isn't in it.

## Install

When release builds exist, the zip unpacks to a single `GuildCrafts` folder. Put it in the
Forever client's `Interface/AddOns/`.

For now, install from a checkout:

```bash
git clone https://github.com/lxhwes/GuildCrafts-Forever.git
```

1. Find the `GuildCrafts` folder inside the clone. It's the one holding
   `GuildCrafts_Camelot.toc`.
2. Copy or symlink that folder into the Forever client's `Interface/AddOns/`. Its name there
   must stay `GuildCrafts`.
3. Restart the client, or type `/reload` if it's running.

The checkout carries all six TOC files. Forever loads only `GuildCrafts_Camelot.toc`. A
checkout reports its version as `dev` in `/gc comms`.

## First run

1. Log in on a character that's in a guild.
2. Open each of your profession windows once. Chat prints
   `Scanned <profession>: <n> new recipe(s) found.` for each new batch.
3. Type `/gc`, or click the minimap button, to open the window.
4. Type `/gc dump` to check what was stored for you.

About five seconds after login, GuildCrafts lists any profession it hasn't seen recipes for
yet. Open those windows too. After you learn new recipes, open the window again to share them.

## Documentation

- [User guide](https://github.com/lxhwes/GuildCrafts-Forever/blob/main/docs/user-guide.md):
  views, search, commands, known limitations and troubleshooting
- [Contributing](https://github.com/lxhwes/GuildCrafts-Forever/blob/main/CONTRIBUTING.md):
  scope, setup, pull requests and bug reports
- [Testing](https://github.com/lxhwes/GuildCrafts-Forever/blob/main/docs/testing.md)
- [Releasing](https://github.com/lxhwes/GuildCrafts-Forever/blob/main/docs/releasing.md)
- [Forever plan](https://github.com/lxhwes/GuildCrafts-Forever/blob/main/spec/forever-plan.md):
  planned work to launch and the open findings
- [Origin and permission](https://github.com/lxhwes/GuildCrafts-Forever/blob/main/docs/ORIGIN.md)
- [Upstream RFCs](https://github.com/lxhwes/GuildCrafts-Forever/tree/main/RFC): upstream's
  architecture, sync protocol, data model, UI and release design. They're historical
  reference and describe upstream's Classic behaviour, so check the code where Forever differs.
- [Changelog](CHANGELOG.md)

## Licence

MIT. See [LICENSE](LICENSE).
