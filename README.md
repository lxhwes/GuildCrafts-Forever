# GuildCrafts for WoW Forever

GuildCrafts builds a shared recipe book for your guild. Open a profession window and it records
the recipes you know, then shares them with every guildmate running GuildCrafts. Anyone can then
see who crafts what, find crafters on item tooltips, and whisper them in one click.

If you used GuildCrafts in TBC Anniversary or another Classic flavor, it's the same addon, fixed
up for Forever.

GuildCrafts was written by [@dkruenbo](https://github.com/dkruenbo) (`_Lektor`).
[@lxhwes](https://github.com/lxhwes) maintains this WoW Forever version with the author's
permission. The permission and its terms are in
[docs/ORIGIN.md](https://github.com/lxhwes/GuildCrafts-Forever/blob/main/docs/ORIGIN.md).

## Status

- This is a test build for WoW Forever (Interface 16001, client 1.60.1), which is in beta.
- It isn't on CurseForge yet. Until it is, install it from GitHub (below).
- First Aid and Fishing aren't tracked yet.
- `[W]` whispers and `!gc` replies haven't been checked with a second player yet.
- Beta characters don't carry over to launch, so neither does beta data.
- For Classic Era, TBC, Wrath, Cata or Mists, use upstream
  [dkruenbo/GuildCrafts](https://github.com/dkruenbo/GuildCrafts). This repository keeps those
  files untouched but doesn't maintain or publish them.

## Install

1. Delete any older `GuildCrafts` folder from your Forever `Interface/AddOns/` folder.
2. On this page, click the green **Code** button, then **Download ZIP**.
3. Open the zip. Copy the `GuildCrafts` folder (the one holding `GuildCrafts_Camelot.toc`)
   into your Forever `Interface/AddOns/` folder. Keep the folder name `GuildCrafts`.
4. Restart the game, or type `/reload` if it's running.

`/gc comms` reports the version as `dev` in a test build. That's expected.

If you use git, `git clone https://github.com/lxhwes/GuildCrafts-Forever.git` and copy or
symlink the same `GuildCrafts` folder instead.

## First run

1. Log in on a character that's in a guild.
2. Open each of your profession windows once. Chat prints
   `Scanned <profession>: <n> new recipe(s) found.` for each new batch.
3. Open GuildCrafts with `/gc`, the book button on the minimap, or the GuildCrafts entry in the
   addon drawer by the minimap.

After you learn new recipes, open that profession window again to share them.

## What it does

- Browse by profession: who has it and at what skill, what each member can craft, and every
  recipe the guild knows, grouped by category.
- Search recipe, profession and member names.
- Shows crafters on item tooltips.
- Favorite recipes and members.
- Shift-click a recipe to link it in chat, `[G]` posts its crafters to guild chat, and `[W]`
  whispers a crafter.
- Answers `!gc <recipe>` typed in guild chat.
- Pauses sync during combat, instances, zone changes and Forever's addon restrictions.

The recipe book only covers guildmates who run GuildCrafts and have opened their profession
windows.

## Reporting a problem

Type `/gc report`, press Ctrl-A then Ctrl-C to copy the box, and paste it into a
[GitHub issue](https://github.com/lxhwes/GuildCrafts-Forever/issues) with a line about what
happened.

## Documentation

- [User guide](https://github.com/lxhwes/GuildCrafts-Forever/blob/main/docs/user-guide.md):
  views, search, commands, known limitations and troubleshooting
- [Changelog](CHANGELOG.md)
- [Contributing](https://github.com/lxhwes/GuildCrafts-Forever/blob/main/CONTRIBUTING.md):
  scope, setup, pull requests and bug reports
- [Forever plan](https://github.com/lxhwes/GuildCrafts-Forever/blob/main/spec/forever-plan.md):
  phases to launch, linked to the [issues](https://github.com/lxhwes/GuildCrafts-Forever/issues)
  that track the work
- [Testing](https://github.com/lxhwes/GuildCrafts-Forever/blob/main/docs/testing.md) and
  [Releasing](https://github.com/lxhwes/GuildCrafts-Forever/blob/main/docs/releasing.md)
- [Origin and permission](https://github.com/lxhwes/GuildCrafts-Forever/blob/main/docs/ORIGIN.md)
- [Upstream RFCs](https://github.com/lxhwes/GuildCrafts-Forever/tree/main/RFC): upstream's
  architecture, sync protocol, data model, UI and release design. They describe upstream's
  Classic behaviour, so check the code where Forever differs.

## Licence

MIT. See [LICENSE](LICENSE).
