# N2: Per-character opt-out (audit X3) — implementation spec

Issue [#52](https://github.com/lxhwes/GuildCrafts-Forever/issues/52). Written 2026-10-04 against
`main` at `4c9492b`; line numbers are at that commit. Status: ready to build once the Oct 28
freeze has passed and the launch build is out. Ship before or with N1; every external path
depends on it.

## Start here (for a new session)

1. Read `CLAUDE.md`, this file, `spec/curseforge-audit.md` row X3, and RFC 0002 and 0003
   (historical; check them against the code).
2. Run `lua5.1 spec/later/research/optout-v3-compat.lua` from the repository root. It shows what
   today's clients do with each marker shape.
3. Read `Data:MergeIncoming`, `CarryOverProfessions`, `MergeDelta` and `PruneRoster`
   (`Modules/Data.lua:1893-2264`), then `tools/test-profession-sync.lua` for the harness.
4. TDD: the regression tests below go in first as `test(optout):`.

## Two features

- **N2a, hide in my view.** A local, account-wide list of members this client doesn't show. It
  affects this client's UI and item tooltips only.
- **N2b, stop publishing me.** A character withdraws its own data from every peer, and the
  withdrawal survives merge, carry-over, prune and reloads.

They share nothing but the issue. Build N2b first; it's the privacy prerequisite.

## Decisions

| Date | Decision | Why |
|---|---|---|
| 2026-10-04 | The N2b marker is tombstone-shaped: `{ _tombstone = true, _optout = 1, lastUpdate = rev }` | Alex. Today's clients hide a tombstone on receipt. A plain marker gets its recipes restored by F1's carry-over and relayed at the marker's revision (verified with the compat script) |
| 2026-10-04 | `GuildCrafts.VERSION` goes to 4; `DATA_FORMAT_VERSION` stays 3; protocol v4 in [#34] becomes v5 | Alex. Version-3 clients then print "running a newer version, please update" (`Comms.lua:1507-1515`), which shortens the window where they still show opted-out members. A `DATA_FORMAT_VERSION` bump would trigger an equal-version pull of every entry (`Comms.lua:705-714`) |
| 2026-10-04 | N2a hides from this client's UI and tooltip only. `!gc`, export and companion ignore it | Alex |
| 2026-10-04 | The own opt-out flag lives in `GuildCraftsCharDB` (per character), stored as 1 | It follows the character across guild changes and survives `/gc reset`, which wipes only `GuildCraftsDB` (`Core.lua:517-520`). Forever can't group alts (X3). If H7 ([#10]) changes what `/gc reset` wipes, it must keep `optOut` |
| 2026-10-04 | Command names `/gc optout`, `/gc optin`, `/gc hide <name>`, `/gc unhide <name>`, `/gc hidden` | Short and match the issue. Confirm with Alex at PR time |

## Code facts that shape the design

- Readers skip anything without `professions` (`Data.lua:2406`, `:2569`, `:2631`,
  `Tooltip.lua:73`, `UI/MainFrame.lua:943`; the member list at `:856` goes through
  `GetMembersByProfession`). A tombstone-shaped marker disappears from
  views, tooltips and `!gc` with no reader changes.
- `StripSyncFields` sends tombstones as `{ _tombstone, lastUpdate }` (`Data.lua:1742-1744`), so
  today's clients relay a marker without `_optout`.
- `GetVersionVector` includes tombstones (`Data.lua:1801-1805`), so markers propagate through
  normal sync. (RFC 0003 §4 says otherwise; the code wins.)
- Peers never replace your own entry (`Data.lua:1905-1910`). The only exception,
  `RestoreOwnProfessions` (`:1855`), fills empty professions, ignores tombstones and never
  advances your revision. So the owner's client is the only writer of its marker.
- `GetMemberEntry(key, true)` deletes a tombstone to make a live entry (`Data.lua:648-651`).
  `MergeDelta` clears a tombstone when a delta is newer (`:2052-2060`).
- `PruneRoster` clears any tombstone whose member is in the roster (`Data.lua:2196-2203`). It
  was added for F35-style roster gaps. It expires tombstones after 30 days (`:2234-2244`).
- The resurrection guard rejects an incoming live entry with any 0-recipe profession
  (`Data.lua:1932-1943`). Verified 2026-10-04: an entry with Herbalism (no recipes) is blocked.
  Today the roster-pass clear above hides this. A marker is exempt from that clear, so opt-in
  would be blocked forever without a fix.
- Own scans call `BroadcastNewRecipes`, `BroadcastLocalAdvertise` and `BroadcastTimestampTouch`
  (`Data.lua:1269-1292`, `:1474-1497`, `:1708-1722`), and `/gc drop` calls
  `BroadcastProfessionRemoval` (`:868`). All four live in `Comms.lua:1082-1232`.
- `!gc` answers through `Data:SearchRecipes` and `SearchRecipesByKey` (`Core.lua:432-438`), the
  same functions the UI search uses.
- `SlashHandler` lowercases its input (`Core.lua:483`), but the roster lookup behind
  `NormalizeMemberKey` is case-sensitive (`ForeverIdentity.lua:73-83`). Name arguments must be
  taken from the raw input.

## N2b design: stop publishing me

### Owner side

- `GuildCraftsCharDB.optOut = 1` when opted out, `nil` otherwise. Accessor
  `Data:IsOwnOptedOut()`.
- The owner keeps its live entry locally and keeps scanning, so `/gc optin` needs no rescan.
- `/gc optout`:
  1. Set the flag.
  2. `AdvanceRevision(ownEntry)` so the marker is newer than every peer's copy.
  3. Broadcast `DELTA_AD` with the new revision so peers pull now rather than at next login.
  4. Print: `Opted out. Guildmates running GuildCrafts 2.2+ will stop showing this character
     after their next sync. Older versions may keep showing it until they update.`
- `/gc optin`: clear the flag, `AdvanceRevision`, broadcast `DELTA_AD`, print a confirmation.
- `StripSyncFields(entry)` for the owner's own key while opted out returns
  `{ _tombstone = true, _optout = 1, lastUpdate = entry.lastUpdate }`. This is the only place
  the marker is created; `ProcessSyncRequest` and `HandleSyncPull` both go through it
  (`Comms.lua:688`, `:1045`). The restore-own path (`:694`) sends a requester its own entry and
  skips tombstones, so it never carries a marker.
- The four broadcast functions return early when `memberKey` is the player and
  `IsOwnOptedOut()`. `DELTA_AD` from steps 3 above is the one exception, sent explicitly.
- `!gc` replies from the owner's client leave the owner out. Give `SearchRecipes` and
  `SearchRecipesByKey` a filter option rather than filtering inside, because the UI shares them.
- The owner's own UI and tooltip still show the owner, with a "not shared" note in the member
  view.

### Peer side (MergeIncoming and friends)

- Incoming marker: the existing tombstone branch already accepts it when newer
  (`Data.lua:1916-1921`). Keep `_optout` when storing.
- Incoming plain tombstone at an equal revision (a v3 client relaying a marker without the
  flag) doesn't replace a local marker; the existing `>` comparison already does this.
- Local marker vs incoming live entry: accept only when strictly newer (existing rule), and skip
  the 0-recipe resurrection guard when the local entry has `_optout`. Better, make the guard
  skip gathering professions (`Data:IsGatheringProfession`) for every tombstone, which also
  fixes rejoining members with Herbalism or Skinning.
- `MergeDelta` with a local marker: keep the existing rule (a strictly newer delta clears it).
  An opted-out owner sends no deltas, so a newer delta means the owner opted in.

### PruneRoster

- Don't clear a tombstone that has `_optout` while its member is in the roster.
- Don't expire a marker after 30 days while its member is in the roster.
- When a marker's member is absent from the roster, use the same 7-day `_absentSince` grace as
  live entries, then replace it with a plain tombstone at `lastUpdate = now`. That tombstone
  expires normally. Revival after expiry is F36 ([#15]) and applies to any ex-member.

### Compatibility with version-3 clients (accepted residual)

Verified with `spec/later/research/optout-v3-compat.lua` against `4c9492b`:

- A v3 client that receives the marker hides the member at once.
- Its next roster pass deletes the marker, because the member is still in the guild.
- If another v3 client still holds an older live copy, that copy can come back, until a v4
  client resends the marker.

So a v3 client can flicker between hidden and shown. There is no wire-level fix: nothing can
change what an old client does. The `VERSION` 4 nudge and the release notes are the mitigation.
`docs/user-guide.md` must say this plainly.

### Losing the flag

Deleting the `WTF` folder loses `GuildCraftsCharDB.optOut`. The next scan would publish a live
entry that beats the marker everywhere. Optional hardening, not required for done-when: when a
peer's copy of your own key arrives as an `_optout` marker newer than your local entry, set the
flag again and print "You opted out earlier; /gc optin to publish again". Your own fresh scan
usually advances your revision first, so this only catches some cases. Document the limit.

## N2a design: hide in my view

- `GuildCraftsDB.global._hiddenMembers[guid] = 1` (account-wide, keyed by GUID, so it holds
  across guilds). `MigrateToGuildPartition` and `MigrateToRecipeDB` iterate `db.global`, so check
  that they ignore a table without `lastUpdate` or `professions`. They do at `4c9492b`
  (`Data.lua:617`, `:365`), but add a test.
- `/gc hide <name>` resolves through `NormalizeMemberKey` on the raw-case argument and accepts a
  GUID as well. Offline members may not resolve until H3 ([#6]) lands; say so in the error.
- `/gc unhide <name>` and `/gc hidden`, which lists hidden members by display name.
- Filtered in: `GetMembersByProfession`, the UI's use of `SearchRecipes`, and
  `Tooltip:RebuildIndex`. Hiding or unhiding calls `Tooltip:InvalidateIndex()` and
  `UI:Refresh()`.
- Not filtered: `!gc`, `/gc export`, the companion block (N3).
- A member row button can come later; the slash commands are enough for done-when.

## Tests

Add `tools/test-optout.lua` (harness from `tools/test-profession-sync.lua`):

1. Owner opts out: `StripSyncFields(own)` returns the marker with a revision greater than
   before; the broadcast functions send nothing for the owner's key.
2. Peer with a live copy merges the marker: entry becomes the marker; `GetMembersByProfession`,
   `SearchRecipes` and the tooltip index don't list the member.
3. Carry-over can't revive it: merge an older live entry after the marker; still the marker.
4. Equal-revision plain tombstone (v3 relay) doesn't replace the marker.
5. `PruneRoster` with the member in the roster keeps the marker, including 31 days later.
6. `PruneRoster` with the member absent: `_absentSince` set, then after 7 days a plain
   tombstone at `now`.
7. Opt-in: a strictly newer live entry with Herbalism (0 recipes) replaces the marker.
8. `MergeDelta` older than the marker is blocked; newer clears it.
9. `!gc` path: owner's client with the flag set leaves the owner out of `SearchRecipes` results
   when called with the `!gc` filter.
10. N2a: hidden member is gone from the UI functions and tooltip index but present in the `!gc`
    search path and in `Export:Collect()` (once N1 exists).
11. `_hiddenMembers` survives `MigrateToGuildPartition` and `MigrateToRecipeDB`.
12. Stored values are 1, never booleans.

Add the suite to CI and `docs/testing.md`.

## Two-client check (`docs/testing.md`)

Add a step to the two-client section: A opts out, B syncs. B's member list, tooltip and a `!gc`
for one of A's recipes no longer show A. `/reload` on B: still gone. A opts in and B syncs: A
is back.

## Docs

- `docs/user-guide.md`: what opt-out does and doesn't do (older versions, deleting `WTF`, alts
  opt out one by one), and how hiding differs.
- CHANGELOG `### New features`, and a note that the protocol version is now 4.
- `CLAUDE.md`: "Both are currently 3" becomes `VERSION` 4, `DATA_FORMAT_VERSION` 3.
- `spec/forever-plan.md`: nothing left. [#34] was retitled to protocol v5 on 2026-10-04, and the
  plan was updated to match then.

## Done when (from the issue)

- [ ] `/gc optout` and `/gc optin`, with a confirmation line in chat.
- [ ] An opted-out member disappears from every peer's view, tooltip and `!gc` reply after sync,
      and stays gone across reloads, prune and carry-over.
- [ ] Regression test for merge, carry-over and prune with the marker; two-client checklist step
      added to `docs/testing.md`.

[#6]: https://github.com/lxhwes/GuildCrafts-Forever/issues/6
[#10]: https://github.com/lxhwes/GuildCrafts-Forever/issues/10
[#15]: https://github.com/lxhwes/GuildCrafts-Forever/issues/15
[#34]: https://github.com/lxhwes/GuildCrafts-Forever/issues/34
