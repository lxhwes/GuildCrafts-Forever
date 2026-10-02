# GuildCrafts — Project Notes for AI Assistants

## What this project is

WoW Classic addon supporting multiple game versions via multi-TOC:
- Classic Era (Interface 11507)
- TBC Anniversary (Interface 20506)
- WotLK Classic (Interface 30403)
- Cata Classic (Interface 40402)
- MoP Classic (Interface 50504)
- WoW Forever (Interface 16001, beta; Mainline API)

Lua, AceAddon-3.0 framework.
Tracks guild members' profession recipes and syncs them across all addon users
via a DR/BDR election system over the GUILD addon message channel.

---

## Build & Release

### Zip a release
Always exclude `.DS_Store` — macOS creates it whenever Finder opens the folder:

```bash
zip -r GuildCrafts-X.Y.Z.zip GuildCrafts/ -x "*.DS_Store"
```

### Version bump checklist
These must match before committing a version bump:

| File | Field |
|---|---|
| `GuildCrafts/GuildCrafts.toc` | `## Version: X.Y.Z` |
| `GuildCrafts/GuildCrafts_Vanilla.toc` | `## Version: X.Y.Z` |
| `GuildCrafts/GuildCrafts_Wrath.toc` | `## Version: X.Y.Z` |
| `GuildCrafts/GuildCrafts_Cata.toc` | `## Version: X.Y.Z` |
| `GuildCrafts/GuildCrafts_Mists.toc` | `## Version: X.Y.Z` |
| `CHANGELOG.md` | `## X.Y.Z — YYYY-MM-DD` |

`GuildCrafts_Camelot.toc` (Forever) is not bumped by hand: its `## Version:` is
`@project-version@`, filled in by the CurseForge packager. Forever reads the `_Camelot`
suffix and ignores `_Forever` (verified in game, 1.60.1, 2026-10-02).

`GuildCrafts.DISPLAY_VERSION` is read from the loaded TOC's `## Version:` at load, and reads
`dev` when running unpackaged. `/gc comms` prints it on its first line.

`GuildCrafts.VERSION` (integer) and `GuildCrafts.DATA_FORMAT_VERSION` (integer)
are wire protocol versions — only increment when the sync protocol changes.
Currently both are `2`.

---

## Git Workflow

- Branch naming: `feature/patch-N-description`
- PRs are **squash-merged** into `main`, branch deleted after merge
- Force-push to feature branches is fine (they're never shared before PR)
- After a rebase, use `git push --force-with-lease`

### Important
Never commit, push, create a PR, or merge without explicit instruction from the user.

### Full ship sequence for a patch

```bash
git push -u origin feature/patch-N-description
gh pr create --title "feat: ..." --base main
gh pr merge <num> --squash --delete-branch --subject "feat: ..."
zip -r GuildCrafts-X.Y.Z.zip GuildCrafts/ -x "*.DS_Store"
```

---

## CHANGELOG Conventions

- Date format: `YYYY-MM-DD`
- Sections: `### New features`, `### Improvements`, `### Fixes`

---

## Architecture Quick Reference

- **DR** (Designated Router): alphabetically first addon user; answers all
  `SYNC_REQUEST`s and broadcasts `HEARTBEAT` every 60s
- **BDR** (Backup DR): second alphabetically; responds at retry=1
- `syncRetryCount`: 0 = ask DR, 1 = ask BDR, 2 = evict both and re-elect
- `currentTerm`: monotone integer incremented on DR promotion; stale messages
  (term < currentTerm) are silently dropped
- `SyncPausePolicy`: suspends all outgoing sync during combat, instances, and
  zone transitions (grace periods: 6s / 15s / 12s)
- Chunked transfers: one chunk per second via timer, `SYNC_CHUNK_SIZE = 5`
  members per chunk; Patch 3 adds sessionId + RESUME recovery

## Key Constants (Comms.lua)

| Constant | Value | Meaning |
|---|---|---|
| `SYNC_TIMEOUT` | 120s | Wait for SYNC_RESPONSE before retry |
| `SYNC_RETRY_TIMEOUT` | 15s | Wait on subsequent retries |
| `HEARTBEAT_TIMEOUT` | 180s | 3 missed heartbeats → DR presumed dead |
| `PROGRESS_TIMEOUT` | 4s | Chunk gap before sending RESUME |
| `SESSION_TTL` | 35s | How long sender keeps chunk cache |
| `MAX_RESUME_ATTEMPTS` | 3 | RESUME tries before falling back to full retry |

---

## Planned Work

`spec/implementation-plan-v2.md` is the source of truth for all planned patches.

Current status:
- ✅ Patch 1 — SyncPausePolicy + Partial Scan Protection (v1.4.0)
- ✅ Patch 2 — DELTA_AD broadcast (v1.5.0)
- ✅ Patch 3 — Chunk RESUME recovery (v1.6.0)
- ✅ Patch 4 — Per-peer backoff (v1.7.0)
- ✅ Patch 5 — Tombstone pruning (v1.8.0)
- ✅ Multi-expansion support — branch: `feature/multi-expansion-support`
- 🚧 WoW Forever support — branch: `feature/forever-support`; see `spec/migration-forever.md`

---

## Folder Structure

```
GuildCrafts/
  Core.lua                 -- Bootstrap, events, slash commands
  GuildCrafts.toc          -- TBC Anniversary (default)
  GuildCrafts_Vanilla.toc  -- Classic Era
  GuildCrafts_Wrath.toc    -- WotLK Classic
  GuildCrafts_Cata.toc     -- Cata Classic
  GuildCrafts_Mists.toc    -- MoP Classic
  GuildCrafts_Camelot.toc  -- WoW Forever (Mainline API)
  Modules/
    Data.lua               -- Scanning, merging, pruning, compat wrappers
    ForeverIdentity.lua    -- Forever only (Camelot TOC): GUID member keys, roster names
    Comms.lua              -- Sync protocol, DR/BDR election
    SyncPausePolicy.lua    -- Combat/instance pause
    Favorites.lua          -- Bookmark system
    Tooltip.lua            -- Item tooltip injection
    MinimapButton.lua      -- LDB minimap icon
  Data/
    Data_TBC.lua           -- TBC recipe keys (static)
    Data_WOTLK.lua         -- WotLK recipe keys (static)
    Data_CATA.lua          -- Cata recipe keys (static)
    Data_MOP.lua           -- MoP recipe keys (static)
  UI/
    MainFrame.lua          -- All UI panels
  Libs/                    -- Embedded libraries
```

---

## No Automated Tests

There is no test suite. Verification is manual in-game. Key things to check
after any sync-layer change: `/gc comms` debug output, chunk delivery in a
multi-user guild session, role election log.

---

## In-game commands (gist workflow)

Claude can't run the game, and the Forever beta runs on Alex's other PC. In-game
commands reach that PC through one secret gist, not through chat.

- Gist: https://gist.github.com/lxhwes/6ccdf7ad7451481d916410b65beff5ce
  (file `gc-forever-probes.md`). It's secret, which means unlisted: anyone with the link can open it.
- Source of truth: `docs/ingame-commands.md` in this repo. The gist mirrors that file.
  Never edit the gist by hand.
- Claude's sandbox can't authenticate `gh`, so Alex publishes each update:
  `! gh gist edit 6ccdf7ad7451481d916410b65beff5ce --filename gc-forever-probes.md docs/ingame-commands.md`
- After an update, Claude confirms the change by fetching the raw gist URL.

Rules for every command in the file:
- One command per fenced block, so GitHub shows a copy button for each.
- `/run` lines must be 255 characters or fewer. WoWLua doesn't load on 1.60.1.70170.
- End every statement with `;`, and never use `--` comments.
- Parse-check with Lua 5.1 `luac -p` as written and again with newlines stripped.
- Feature-detect or `pcall` anything that might be nil, because one error kills the whole line.
- Put a tag at the start of each `print` (for example `GC`, `TOC`, `EXP`, `TS`) so pasted output can be matched to its command.
- Above each block, one line saying when to run it (for example "with a profession window open") and how to read the output.
- Alex pastes results back into chat. Record them in `spec/migration-forever.md` and never assume a result.
