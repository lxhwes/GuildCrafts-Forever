# GuildCrafts user guide (WoW Forever)

This guide covers the Forever flavor of GuildCrafts, the only flavor this fork maintains. Plan
IDs such as H9 or F20 point to entries in
[spec/forever-plan.md](../spec/forever-plan.md).

## Install and first run

Installation is in the [README](../README.md#install). No Forever build is on CurseForge yet,
so for now you install from a GitHub checkout.

On first login:

1. Be on a character that's in a guild. Outside a guild, GuildCrafts doesn't sync.
2. Open each of your profession windows once.
3. Type `/gc`, or left-click the minimap button, to open the main window.

About five seconds after each login, GuildCrafts checks your professions. It lists any that
have no stored recipes yet, so you know which windows to open. Herbalism and Skinning are left
out of that list.

## Scanning

GuildCrafts can only read your recipes while a profession window is open. Nothing is
recorded until you open it.

- Each time you open a window, GuildCrafts records any recipe it hasn't seen before, with its
  reagents. Chat shows `Scanned <profession>: <n> new recipe(s) found.`
- New recipes go to other GuildCrafts users straight away, unless sync is paused (see
  [Known limitations](#known-limitations)).
- Open the window again after learning recipes. GuildCrafts doesn't notice new recipes until
  you do.
- Opening any profession window also marks your data as current. Guildmates delete an entry
  that hasn't been refreshed in 45 days. If your own data is over 30 days old, you get a
  reminder in chat at login.

## The main window

The left panel lists professions with a count of members who have each one. Crafting
professions come first. Mining, Herbalism, Skinning and Cooking follow after a divider.

Pick a profession, then use the Members and Recipes buttons above the right panel to switch
views. The `< Back` link at the top of the left panel returns to the profession list.

The dot next to "Sync" in the title bar shows sync state. Green means synced. Yellow means a
sync is in progress. Red means GuildCrafts can't see any other GuildCrafts user online. Hover
it for the current Designated Router, the number of addon users, and when you last synced.

### Members view

The left panel lists members who have the profession. Each row shows:

- a dot: green if they're online with GuildCrafts, yellow if they're online but GuildCrafts
  wasn't detected, grey if they're offline;
- their skill level;
- a specialisation tag, if one was detected;
- `[30d ago]` or similar if their data is more than 30 days old;
- `(left guild)` if they're no longer on the guild roster. Their entry is deleted after
  7 days.

Click a member to see their recipes in the right panel, with when they last scanned.

- A `+` before a recipe means reagents are known. Click the row to show them.
- A `~` means no reagent data has reached you for that recipe.
- Hover a recipe name for the item or spell tooltip.
- Shift-click a recipe name to link it in chat.

### Recipes view

The right panel lists every recipe in the profession that any GuildCrafts user knows.

- Each row shows up to two crafters, then `(+n)` for the rest. You come first, then online
  members.
- Hover the crafter names for the full list.
- `[W]` opens a whisper to a crafter. With more than one crafter, it shows a list to pick from.
  It hasn't been checked in game yet (see [Known limitations](#known-limitations)).
- `[G]` posts the crafter list to guild chat. Each recipe can be posted once every 30 seconds.
  If the client has no send API or raises an error, GuildCrafts says so in your chat window
  and `/gc report` logs the reason.

Herbalism and Skinning don't have a Recipes view. See [Profession coverage](#profession-coverage).

## Search and filters

Type in the search box at the top. The button to its right cycles the search scope.

| Scope | Searches |
|---|---|
| All | Recipe names (right panel) and member names (left panel) |
| Item | Recipe names only |
| Profession | Profession names, filtering the left panel |
| Member | Member names, filtering the left panel |

Search matches any part of a name and ignores case. It doesn't correct typos. Clear the box to
return to the profession list.

Recipe results show the profession, crafters, `[W]`, `[G]` and a favorite star, as in the
Recipes view.

"Nobody in the guild knows '...'" only means no GuildCrafts user who has scanned knows the
recipe. Guildmates without the addon, or who haven't opened that profession window, aren't
in the database.

The buttons along the bottom of the window are toggles:

- `[Online]` shows only online crafters in counts, member lists and crafter lists. You always
  appear in crafter lists.
- `[Tooltip]` turns the crafter list in item tooltips on or off.
- `[Minimap]` shows or hides the minimap button.

Forever has no expansion filter buttons.

## Favorites and tooltips

Click the star next to a member or a recipe to make it a favorite. Click it again to remove
it. Stars appear in the Members view, the member recipe list and recipe search results.

The star icon at the top right of the left panel opens Favorites. It has Members and Recipes
tabs. Click the star icon again to go back.

Favorites belong to the character, not the account. They're stored in `GuildCraftsCharDB`,
separately from the recipe data.

Hovering an item adds a `GuildCrafts:` section to its tooltip. It lists up to ten crafters,
online members first in green, with their profession and any specialisation. Items match by
item ID. Recipes stored by spell ID, such as enchants, match by name.

## Asking from guild chat

Anyone in the guild can type `!gc <recipe>` in guild chat. They don't need GuildCrafts
installed.

- One GuildCrafts user replies with up to three matching recipes and up to two crafters for
  each, online members first.
- You can shift-click an item link into the query.
- If the name finds nothing and the query has four or more letters, it tries again ignoring
  vowels, which catches some typos.
- If nothing matches, the reply says no guild crafter was found. Replies never repeat the
  query text.
- Once a query has been answered, found or not, the same query isn't answered again for 30
  seconds.
- If a reply can't be sent (no send API, or the client raises an error), that GuildCrafts user
  doesn't tell the others it answered, so the next one in line can still reply. `/gc report`
  logs the failure.

The reply hasn't been confirmed on Forever yet (H14).

## Slash commands

| Command | What it does |
|---|---|
| `/gc` | Opens or closes the main window |
| `/gc dump` | Prints your member key, the guild key, each of your stored professions with its recipe count, and the total members and recipes in the database |
| `/gc comms` | Prints the GuildCrafts version, your sync role, the DR and BDR, whether a sync is pending, the sync queue length, and each addon user seen with their protocol version |
| `/gc report` | Opens a box with a diagnostic report to copy into a bug report: version, client build, your keys, recipe counts, sync and pause state, and recent debug lines. Press Ctrl-C to copy it |
| `/gc debug` | Turns debug output in chat on or off. It's off again after every login and `/reload` |
| `/gc mem` | Prints how much memory GuildCrafts is using |
| `/gc minimap` | Shows or hides the minimap button |
| `/gc drop <profession>` | Removes one of your stored professions and its recipes, and tells the guild. Use it only after unlearning the profession |
| `/gc reset` | Deletes `GuildCraftsDB` and reloads the UI. See [Troubleshooting](#troubleshooting) before using it |

Any other text after `/gc` prints the command list.

About `/gc drop`:

- It matches the profession name without regard to case, for example `/gc drop alchemy`.
- It reads your current professions first. If the profession is still known, it refuses. If
  the read fails or comes back empty, it says it couldn't read your professions and asks you
  to try again.
- It's the only way to remove a profession that has recipes. If a profession with recipes is
  missing from the client's list at login, GuildCrafts keeps it.

## Profession coverage

| Profession | On Forever |
|---|---|
| Alchemy, Blacksmithing, Enchanting, Engineering, Leatherworking, Tailoring | Tracked |
| Mining | Tracked. The Smelting window counts as Mining |
| Cooking | Tracked |
| Herbalism, Skinning | Scanned and stored, but their page shows "gathering profession, no recipes" (C2) |
| Jewelcrafting, Inscription | Hidden, because the Forever client doesn't offer them |
| First Aid, Fishing | Not tracked (C1, F3) |

Herbalism has recipes on Forever. GuildCrafts stores them, and they show up in search and
tooltips. The profession page still treats Herbalism and Skinning as having no recipes, and
hides their Recipes view.

## Known limitations

These are open in the current beta build. Each has a plan ID.

- First Aid and Fishing aren't tracked (C1, F3; H17). On Forever, bandages and healing potions
  are First Aid recipes, so they don't appear.
- Herbalism and Skinning recipes are hidden on the profession page (C2; H17).
- Cooldowns aren't captured. The scanner Forever uses doesn't read them (C4, after launch).
- Specialisation detection uses upstream's TBC table. On Forever, tags may be wrong or missing
  while that's reviewed (C3; H17).
- Recipes are listed without category headings. The scanner reads a category field Forever
  doesn't provide (F12; H15).
- The `[W]` whisper button and shift-click links use Forever's chat API, and `[W]` sets the
  two-word name as the whisper target directly. Neither has been checked in game yet (F20, F25;
  H14).
- `!gc` replies and `[G]` both send guild chat with `C_ChatInfo.SendChatMessage`, or the older
  `SendChatMessage` global if that's missing. Forever marks the function as restricted, and an
  addon post through it hasn't been checked in game yet (H14).
- Outgoing sync pauses during combat (plus 6 seconds), inside instances (plus 15 seconds after
  leaving), for 12 seconds after a zone change, and while Forever reports an Encounter,
  Challenge Mode, PvP match, Map or Chat restriction. A new recipe scanned during a pause isn't
  resent. Guildmates pick it up at their next login sync (H12).
- Clients inside an instance don't answer `!gc`. If every GuildCrafts user is in an instance,
  nobody answers.
- An empty search result doesn't prove nobody in the guild knows a recipe. The database only
  holds GuildCrafts users who have opened their profession windows.
- `/gc reset` reloads the UI with `ReloadUI()`, which is reported to be blocked for addons on
  Forever. This is unverified (F14; H7).

## Troubleshooting

### My recipes don't show

Open the profession window, then type `/gc dump`. Your profession should list a non-zero
recipe count. If it reads 0, type `/gc report`, press Ctrl-C, and paste the text into your bug
report.

### A guildmate is missing

They need GuildCrafts installed and must open their profession windows. In the Members view,
a yellow dot means they're online but GuildCrafts wasn't detected for them. If the Sync dot is
red, GuildCrafts can't see any other addon user online. `/gc comms` lists the addon users it
has seen.

### "<Profession> wasn't detected on this character"

GuildCrafts prints this when a profession you have recipes for is missing from the client's
list. It keeps the recipes. If you unlearned the profession, type `/gc drop <profession>` to
remove it for the guild. If you still know it, ignore the message.

### What `/gc reset` does

`/gc reset` sets `GuildCraftsDB` to nil and reloads the UI.

- It deletes all recipe data stored on this account, for every guild.
- It also clears the minimap button position and the `[Online]` and `[Tooltip]` settings,
  which live in `GuildCraftsDB`.
- Favorites survive. They're in the per-character `GuildCraftsCharDB`.
- It doesn't rescan. At the next sync, GuildCrafts copies your recipes back from the guild's
  copy for each profession you still know, and prints `Restored <n> <profession> recipes`. This
  needs a DR running this version. Open each profession window to rescan anything newer.
- Other members' data comes back from other GuildCrafts users when you sync.

If the UI doesn't reload (F14), type `/reload` yourself.

## Reporting a bug

Open an issue at
[lxhwes/GuildCrafts-Forever](https://github.com/lxhwes/GuildCrafts-Forever/issues).
[CONTRIBUTING.md](../CONTRIBUTING.md#reporting-a-bug) lists what to include.
