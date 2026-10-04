# GuildCrafts — Project Notes for AI Assistants

## What this project is

The WoW Forever fork of GuildCrafts (`lxhwes/GuildCrafts-Forever`, from `dkruenbo/GuildCrafts`,
MIT). Lua, AceAddon-3.0. It tracks guild members' profession recipes and syncs them between
addon users through a DR/BDR election over the GUILD addon message channel.

WoW Forever: Interface 16001, client 1.60.1, Mainline API, beta. It loads
`GuildCrafts/GuildCrafts_Camelot.toc` (the client reads `_Camelot`, not `_Forever`; verified in
game 2026-10-02).

Only Forever is maintained and published here. That was the condition of the upstream
author's permission (`docs/ORIGIN.md`).

## Rules

- Never edit the five Classic TOCs (`GuildCrafts.toc`, `_Vanilla`, `_Wrath`, `_Cata`, `_Mists`)
  or `GuildCrafts/Data/Data_*.lua`. They are inherited and stay untouched.
- No file published from this fork may be tagged for another flavor.
- Gethe/wow-ui-source branch `forever` at pin 9a789c0 (1.60.1.70170) is the API source of
  truth. It wins over docs and training data.
  Vendored at `/Users/alex/code/legacynext/vendor/wow-ui-source` (sparse: no
  `Blizzard_ChatFrame`, `Blizzard_Professions*` or guild roster docs; probe those in game).
- Feature-detect APIs. Never branch on interface number. Never hardcode IDs.
- SavedVariables booleans may not round-trip on Forever; store 1/0 until proven otherwise.
- Addon messages are restricted during encounters. Extend `SyncPausePolicy.lua` rather than
  adding a parallel mechanism.
- Players are keyed by GUID on Forever (`Modules/ForeverIdentity.lua`, Camelot TOC only).
  Names are "First Surname" with no realm.
- Read the relevant upstream RFC in `RFC/` before changing sync or election code. They are
  historical, so check them against source and `spec/migration-forever.md`.

---

## Docs map

| Doc | What it's for |
|---|---|
| `spec/forever-plan.md` | Phases to the Nov 4 launch, their gates, the plan-ID → issue index, decisions. Work items are GitHub Issues (#4–#45); check both before proposing work |
| `spec/migration-forever.md` | Dated decisions and in-game evidence |
| `docs/releasing.md` | The release runbook |
| `docs/testing.md` | Regression commands, solo and two-client procedures |
| `docs/ingame-commands.md` | Copyable `/run` probes, mirrored to the gist |
| `docs/user-guide.md` | Player-facing usage and limitations |
| `docs/ORIGIN.md` | Provenance and the author's permission, quoted verbatim |
| `spec/fork-review.md` | The 2026-09-28 review that defines F1–F21 and C1–C6; historical, status lives in the issues |
| `spec/curseforge-audit.md` | The 2026-10-03 audit of upstream player reports that defines F22–F40; evidence at `60c6b32` |
| `RFC/`, other `spec/*.md`, `ROADMAP.md` | Upstream history, bannered as such |

In markdown table cells, escape `|` as `\|`, even inside backticks.

---

## Build & Release

`.github/workflows/release.yml` is the only release path. **Never upload a hand-made zip.**
`zip -r GuildCrafts/` ships all six TOCs. Procedure and safeguards: `docs/releasing.md`.

Versions:
- `GuildCrafts_Camelot.toc` `## Version:` is `@project-version@`, filled in by the packager.
  Never bump a TOC version by hand.
- `GuildCrafts.DISPLAY_VERSION` is read from the loaded TOC at load. It reads `dev` when
  unpackaged. `/gc comms` prints it on its first line.
- `GuildCrafts.VERSION` and `GuildCrafts.DATA_FORMAT_VERSION` are wire protocol versions.
  Only increment them when the sync protocol changes. Both are currently `3`.

---

## Git Workflow

- Branches: `feature/<description>`, `fix/<description>`, `docs/<description>`
- PRs are squash-merged into `main`, branch deleted after merge
- Force-push to feature branches is fine (they're never shared before PR)
- After a rebase, use `git push --force-with-lease`
- New plan item: open an issue titled `<ID>: <title>` with the plan-link header, a Findings
  and a Done-when checklist, the label and phase milestone; then add its row and `[#N]` link to the plan

### Important
Never commit, push, create a PR, merge, tag, or publish without explicit instruction from the
user. A pushed `v*` tag publishes to CurseForge.

---

## CHANGELOG Conventions

- New entries go under `## Unreleased` until a release
- Date format: `YYYY-MM-DD`
- Sections: `### New features`, `### Improvements`, `### Fixes`
- Keep upstream's 2-space indentation

---

## Architecture Quick Reference

A current architecture doc is planned (D1 cut 2 in `spec/forever-plan.md`). Until then:

- **DR** (Designated Router): first `addonUsers` key in sort order. On Forever that's the
  lowest GUID string (server ID, then character ID), not a name. Answers all `SYNC_REQUEST`s
  and broadcasts `HEARTBEAT` every 60s
- **BDR** (Backup DR): second in sort order; responds at retry=1
- `syncRetryCount`: 0 = ask DR, 1 = ask BDR, 2 = evict both and re-elect
- `currentTerm`: in memory only, reset on reload, raised by any higher-term message. Only
  `HEARTBEAT` and `SYNC_RESPONSE` are dropped when stale (term < currentTerm)
- `SyncPausePolicy`: suspends outgoing sync during combat, instances, zone transitions
  (grace periods 6s / 15s / 12s) and active addon restrictions (`C_RestrictedActions`)
- Chunked transfers: one chunk per second via timer, `SYNC_CHUNK_SIZE = 5`
  members per chunk, sessionId + RESUME recovery

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

## Folder Structure

```
GuildCrafts/
  Core.lua                 -- Bootstrap, events, slash commands
  GuildCrafts_Camelot.toc  -- WoW Forever (the only maintained TOC)
  GuildCrafts*.toc         -- Five inherited Classic TOCs (untouched)
  Modules/
    Data.lua               -- Scanning, merging, pruning, compat wrappers
    ForeverIdentity.lua    -- Forever only (Camelot TOC): GUID member keys, roster names
    Comms.lua              -- Sync protocol, DR/BDR election
    SyncPausePolicy.lua    -- Combat/instance/restriction pause
    Report.lua             -- Forever only (Camelot TOC): /gc report, debug ring buffer
    Favorites.lua          -- Bookmark system
    Tooltip.lua            -- Item tooltip injection
    MinimapButton.lua      -- LDB minimap icon
  Data/                    -- Inherited Classic recipe data (untouched; not shipped)
  UI/
    MainFrame.lua          -- All UI panels
  Libs/                    -- Embedded libraries
```

---

## Verification

Run the regression tests from the repository root under PUC Lua 5.1 before every commit. If
`lua5.1` isn't on PATH, use `/Users/alex/code/legacynext/tools/lua51/bin/lua` (`luac` and
`luacheck` live alongside it).

```bash
(cd GuildCrafts && luacheck .)          # must report 0 warnings; CI fails on any
lua5.1 tools/test-profession-sync.lua   # profession drop/relearn and empty-read floor
lua5.1 tools/test-forever-identity.lua  # Forever GUID member keys and roster names
lua5.1 tools/test-profession-gate.lua   # Jewelcrafting/Inscription skill-line gate
lua5.1 tools/test-report.lua            # /gc report and the debug ring buffer
lua5.1 tools/test-favorites.lua         # favorites stored as 1, not booleans
lua5.1 tools/test-tooltip-index.lua     # tooltip index rebuild debounce (F9)
```

Each exits non-zero on a failure. They stub WoW APIs and don't exercise the game client or
transport. In-game procedures are in `docs/testing.md`.

`.github/workflows/ci.yml` runs the lint and every suite on every PR; `main` requires its
`test` check. Declare any new WoW global in `GuildCrafts/.luacheckrc` `read_globals`.

Modules capture WoW globals as locals at load (`local GetNumSkillLines = GetNumSkillLines`).
To test a client that lacks an API, nil the global and `dofile` a fresh copy of the module
(see the Forever empty-read case in `tools/test-profession-sync.lua`).

---

## In-game commands (gist workflow)

Claude can't run the game, and the Forever beta runs on Alex's other PC. In-game
commands reach that PC through one secret gist, not through chat.

- Gist: https://gist.github.com/lxhwes/6ccdf7ad7451481d916410b65beff5ce
  (file `gc-forever-probes.md`). It's secret, which means unlisted: anyone with the link can open it.
- Source of truth: `docs/ingame-commands.md` in this repo. The gist mirrors that file.
  Never edit the gist by hand.
- `gh` and `git push` fail inside the sandbox (keychain blocked). Run them with the sandbox
  disabled per command, or Alex runs:
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
