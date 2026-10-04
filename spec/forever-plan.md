# GuildCrafts Forever — beta plan

Written 2026-10-03 against `main` at `8f0dc69`. This is the single list of planned work. It
merges Alex's beta plan with:
- every item still open in `spec/migration-forever.md`;
- the 2026-09-28 fork review (finding IDs F1–F21 and C1–C6, indexed at the end);
- the legacynext reuse review;
- the open items from the 2026-10-02/03 sessions;
- Alex's documentation review (`spec/documentation-refresh-plan.md`, kept local), as D1.

`spec/migration-forever.md` is the record of what was decided and verified. This file is what's
left to do. When Phase 0 creates GitHub Issues, each item here becomes one issue and this file
keeps only the phase structure.

Planning targets: beta ends **Oct 21**, launch **Nov 4**, raids **Dec 9**. This plan cites no
source for these dates. Confirm them against Blizzard's announcements before anything depends on
them.

Goal, in order: get the codebase into the best shape it can be, then put it in front of the
guild. Nothing goes to guildmates until Phase 2's exit gate passes.

---

## Phase 0 — Tracking (Oct 3–4, an evening)

Work is not tracked anywhere authoritative yet:

- GitHub Issues is enabled on the fork, and it has no issues. Checked on 2026-10-03 with
  `curl -s https://api.github.com/repos/lxhwes/GuildCrafts-Forever`, which returns
  `"has_issues": true`. The only entries under `/issues` are PRs #1 and #2.
- `ROADMAP.md` is upstream's and points at **upstream's** issue tracker.
- `spec/migration-forever.md` mixed finished tasks, findings and open questions. The open
  questions moved here on 2026-10-03, so it's now a record only.
- `spec/fork-review.md` is a local, uncommitted working note. Every finding it raised that's
  still open is defined in the index at the end of this file, so committed docs no longer
  depend on it.
- `plan.md`, the first draft of this plan, is also local. Its H3 and H4 were dropped by mistake
  during consolidation and were restored here on 2026-10-03.

Do:

1. **GitHub Issues on the fork is the tracker.** Issues is already enabled, so this step is
   creating them. One issue per item in this plan. Labels: `blocker`, `hardening`, `testing`,
   `post-launch`, `needs-ingame`. A milestone per phase.
2. **Rewrite `ROADMAP.md`** for the fork: a short Forever section on top, upstream's history
   kept below under "Upstream (dkruenbo/GuildCrafts)". This moved to D1 cut 2. Until then,
   `ROADMAP.md` carries a history banner that points here.
3. **Decide what happens to the local working notes.** Either commit `spec/fork-review.md` as
   a dated historical review, or keep it local. The same goes for
   `spec/legacynext-reuse-plan.md`, `spec/documentation-refresh-plan.md` and `plan.md`. All are
   optional now that this plan carries their open items.

Why first: guild testing generates reports. Without a tracker, they land in Discord and vanish.

---

## Phase 1 — Hardening (Oct 4–10)

Each item: what, why, how, done-when. Items are listed by ID. Blockers are tagged `blocker` and
go first regardless of position.

### Data integrity

#### H1. CI — `blocker`
- **Why:** three regression suites guard the bugs that can destroy guild data, and nothing runs
  them. `release.yml` is the only workflow.
- **How:** add `.github/workflows/ci.yml`, triggered on push and PR. It runs:
  - luacheck against `GuildCrafts/.luacheckrc`;
  - `lua5.1 tools/test-profession-sync.lua`;
  - `lua5.1 tools/test-forever-identity.lua`;
  - `lua5.1 tools/test-profession-gate.lua`.

  Pin actions to commit SHAs (`release.yml` pins only the packager; see H18). Lint is at 51
  warnings (48 undefined globals plus F10 and two others). Either get it to zero first, or fail
  only on new warnings.
- **Done when:** a failing test fails the PR, and `main` is protected on it.

#### H2. Server time for sync revisions — `blocker`
- **Why:** `lastUpdate` and drop markers use `time()`, the client's local clock. Receivers apply
  removals "only if newer". A guildmate with a fast clock stamps ahead of everyone, and their
  stale drop beats a correct relearn.
- **How:**
  - Probe that `GetServerTime` is sane on Forever (`needs-ingame`). It's documented in
    `SystemTimeDocumentation.lua`.
  - Replace `time()` everywhere it arbitrates between peers, and clamp timestamps that are in
    the future. Local-only timers (UI, cooldowns) can stay.
  - Existing stamps are close enough to server time that no migration is needed. Say so in the
    changelog.
- **Done when:** the harness has a clock-skew case — peer A is 20 minutes fast and drops, peer B
  relearns — and the relearn wins.

#### H3. Persist GUID → name — `hardening`, unverified
- **Status:** a draft finding from `plan.md`, not yet reproduced in game or in the harness.
  Reproduce it first. If it doesn't reproduce, close it as rejected and record the evidence.
- **Why:** `ForeverIdentity` resolves names from `GetGuildRosterInfo`, which returns offline
  members only when the roster is set to show them. Nothing sets it. Offline members may render
  as raw GUIDs or drop out of lists.
- **How:** store the last known display name on the member entry, and refresh it whenever the
  roster resolves. Don't toggle the global show-offline setting. That would change the player's
  own roster UI.
- **Done when:** a member who has been offline since your login shows by name.

#### H4. Cold-start sender resolution — `hardening`, unverified
- **Status:** a draft finding from `plan.md`, not yet reproduced in game or in the harness.
  Reproduce it first. If it doesn't reproduce, close it as rejected and record the evidence.
- **Why:** roster data is often empty right after login, and misses only retry after a 5-second
  floor (`ROSTER_RESCAN_INTERVAL` in `ForeverIdentity.lua`). A sync message arriving in that
  window may fail to resolve its sender.
- **How:** queue unresolved messages and drain the queue on `GUILD_ROSTER_UPDATE` instead of
  relying on the interval.
- **Done when:** a harness case where a message arrives before the roster is populated resolves
  once the roster event fires.

#### H9. `/gc drop` after an empty read — `blocker`
- **Why:** `Data:ReadCurrentProfessions` reports an empty `GetProfessions()` as a complete read
  whenever the function exists. Forever has no skill-line fallback to cross-check. So
  `/gc drop alchemy` removes Alchemy and broadcasts it while the player still knows Alchemy.
  Reproduced with a stubbed harness on `8f0dc69`.
- **How:** an empty `GetProfessions()` counts as complete only when a skill-line fallback
  exists. Otherwise `/gc drop` refuses and asks the player to try again.
- **Done when:** a `tools/test-profession-sync.lua` case for an empty Forever read passes.

#### H10. Scanning a guildmate's recipes as your own (F5) — `blocker`, `needs-ingame`
- **Why:** the scan skips linked and NPC views but not the guild views. Opening a guildmate's
  recipes from the roster, or the guild "All Recipes" list, files those recipes under your name
  and broadcasts them. Forever ships Blizzard's guild-recipe UI, gated by
  `C_TradeSkillUI.IsGuildTradeSkillsEnabled()`.
- **How:** mirror Blizzard's local-crafting test
  (`Blizzard_ProfessionsTemplates/Blizzard_Professions.lua:377-383`): reject Linked, Guild,
  GuildMember and NPC views. Probe `IsGuildTradeSkillsEnabled()` and whether
  `IsTradeSkillGuild`/`IsTradeSkillGuildMember` exist.
- **Done when:** opening a guildmate's profession from the roster prints no "Scanned" line.

#### H11. Restore your own data from peers (F1, rest) — `hardening`
- **Why:** peers now keep your recipes when your client reads empty (carry-over, `fd788e6` and
  `f0522c4`). But your own key is never merged back from peers, so a client that starts with
  empty SavedVariables stays empty until every profession window is reopened.
- **How:** when the local entry for your own key has no recipes for a profession that is still
  known, merge peers' recipes into it. Never remove anything this way.
- **Done when:** a harness case with empty local SavedVariables shows recipes back after sync.

#### H12. Sync robustness — `hardening`
Validated by the two-client checklist (`docs/testing.md`, run in Phase 2) and wave 1.
- **F8:** a DR that sees a higher term stops heartbeating but keeps `myRole = "DR"`, so a
  re-elected DR stays silent (`Comms.lua` term adoption and the `RecomputeElection` role-change
  branch).
- **F13:** the election watchdog resets on every recompute. Any node receiving a retry≥2 request
  evicts the DR and BDR guild-wide.
- **BDR never evicted:** when the BDR logs out, the DR keeps it in `addonUsers`. Only the DR is
  ever evicted (`CheckDRAlive`), and roster eviction was removed (`OnGuildRosterUpdate`).
  Two-client checklist step F2.
- **Paused deltas are dropped, not queued:** a recipe delta suppressed by SyncPausePolicy is
  never resent. The peer only catches up at its next login sync (two-client step R8).
- **F7:** RESUME duplicates transfers. Large chunks drain at about 800 B/s, so RESUME fires after
  4 s and re-queues chunks that are still in flight.
- **A returning DR may get no sync (from reading the code, unverified):** a client that still
  lists a returning peer doesn't answer its HELLO, and the DR never sends a sync request of its
  own. `docs/testing.md` works around it with a 4-minute offline gap. Reproduce before fixing.

#### H13. Favorites write booleans to SavedVariables — `hardening`
- **Why:** `Modules/Favorites.lua` stores `= true`. The project rule is 1/0 until a boolean
  round-trip is proven on Forever.
- **How:** store `1`. On read, accept either `1` or `true`.

### Diagnostics

#### H5. `/gc report` — `blocker` for Phase 3
- **Why:** testers will report bugs as "it didn't work". Open question Q4 (the first dump showed
  zero recipes, cause unknown) is exactly the kind of bug that needs state from the reporter's
  client.
- **How:** a copyable report:
  - addon version;
  - all four `GetBuildInfo()` returns (this also closes Q1);
  - player key and guild partition key;
  - per-profession recipe counts;
  - sync role (DR/BDR/other);
  - restriction states;
  - the last ~50 lines of a debug ring buffer kept in SavedVariables.

  Show it in a copy box, not as chat spam. legacynext's copyable EditBox
  (`LegacyNext/Debug/Debug.lua:680-760`) is a working pattern.
- **Done when:** you can diagnose Q4 from a report alone.

#### H6. Scan diagnostics — `hardening`
- **Why:** Q4 is unexplained. Either no window was opened before the first dump, or the scan
  exited silently. "Silently" is the problem.
- **How:** every scan early-exit logs a reason to the H5 ring buffer.
- **Done when:** a zero-recipe dump always has a logged reason next to it.

### Correctness on Forever

#### H14. Chat and whisper on Forever — `blocker` for Phase 3
- **F20:** the `[W]` button builds `"/w " .. name .. " Can you craft…"`. With two-word Forever
  names, "Geo" becomes the target and "Prizm" the start of the message (`UI:OpenWhisper`). Use a
  tell API instead. `ChatFrame_SendTell` isn't in the vendored sparse checkout, so it needs a
  lookup first.
- **`!gc` replies use the global `SendChatMessage`.** Forever documents `SendChatMessage` only
  under `C_ChatInfo` (`ChatInfoDocumentation.lua:564`, `HasRestrictions`). Probe whether the
  global exists (`needs-ingame`), and feature-detect.
- **F4:** `!gc` echoes the asker's text into guild chat as the responder, and misses skip the
  cooldown. Any guildmate can make the DR post arbitrary text, repeatedly.

#### H15. Scan gate and categories — `hardening`
- **F21:** a `""` profession name is truthy, so the scan reports "not tracked" and never
  retries. Fall back to `GetProfessionInfoByRecipeID`.
- **F11:** scan retries every 1–2 s with no cap and no cancel when the window closes. Use
  `TRADE_SKILL_SHOW` plus `TRADE_SKILL_DATA_SOURCE_CHANGED`, with capped retries and a token so
  newer events cancel older retries.
- **F12:** the modern scan reads `info.categoryName`, but the struct only has `categoryID`.
  Use `GetCategoryInfo`.
- **F16:** `IsSpellKnownCompat` tries the global `IsSpellKnown` first. Recipe Registry found it
  returns false for recipe IDs on Forever. Prefer `C_SpellBook.IsSpellKnown`.

#### H16. Tooltip taint and rebuilds — `hardening`
- **F10:** `Tooltip.lua:147` writes the global `_`, a taint source on Mainline (luacheck W111).
- **F9:** the index debounce never debounces, because `C_Timer.After` returns nothing. Every
  sync chunk schedules another full rebuild.

#### H17. Profession coverage — `hardening`, needed for wave 2
- **C1/F3:** First Aid isn't tracked. Healing potions and bandages moved to First Aid on
  Forever, so they're invisible. Fishing isn't tracked either.
- **C2:** gathering professions have recipes (in game, Herbalism held 13 on 2026-10-03), but
  `IsGatheringProfession` hides the Recipes view for Herbalism and Skinning. Show it whenever any
  member has recipes.
- **C3:** the specialisation table is TBC's. Keep the vanilla ones if their spell IDs carry
  over; drop the rest.
- **Empty-search copy:** a search with no hits says "Nobody in the guild knows '<query>'"
  (`UI/MainFrame.lua:1233`). The database only covers addon users who have scanned, so say that
  instead.

### Restrictions and lifecycle

#### H7. `/gc reset` and `ReloadUI()` (F14) — `hardening`
- **Why:** `ReloadUI()` is reported protected on Forever. A reset that errors leaves the user
  unsure whether their data was cleared.
- **How:** probe (`needs-ingame`). If protected, reset the data and tell the user to `/reload`.
- **Also:** `/gc reset` clears all of `GuildCraftsDB`, which includes the minimap position and the
  Online/Tooltip settings, not only recipes. Either keep settings or say so in the reset message.

#### H18. Release workflow guards — `hardening`, before the first publish
Found while writing `docs/releasing.md`:
- the manual-dispatch publish guard accepts any tag on HEAD, not only `v*`, and a branch whose
  commit carries a tag passes too;
- the publish step's checks run after the upload, so they report a bad upload but can't stop it;
- with no `CF_API_KEY`, the CurseForge upload is skipped but the GitHub release is still created;
- `actions/checkout` and `actions/upload-artifact` are `@v4`, not SHA-pinned.
- **Done when:** a dispatch on a non-`v*` tag refuses to publish, and a missing token fails the
  job before any release is created.

#### H8. Close the remaining open questions — `needs-ingame`
- `RE` probe at a dungeon boss pull: does `ADDON_RESTRICTION_STATE_CHANGED` fire? The
  restriction pause depends on it.
- Then decide the SyncPausePolicy follow-ups left out of `71526af`:
  - hold `HELLO`/`HEARTBEAT`/`GC_ACK` during a Chat restriction;
  - keep the DR watchdog fresh under Map or Chat;
  - keep `!gc` silent under any restriction;
  - add a grace period after a restriction lifts.

### Documentation

#### D1. Documentation refresh
- **Why:** the repo's docs still describe the Classic addon. A guildmate or contributor has no
  current page for install, testing or release. The scope comes from Alex's review in
  `spec/documentation-refresh-plan.md`, which stays local.
- **Cut 1 (now, before the first tester build):**
  - rewrite `README.md` for the Forever fork;
  - write `docs/user-guide.md`;
  - rewrite `CONTRIBUTING.md`, with a bug-report section;
  - write `docs/releasing.md`, the one release runbook;
  - write `docs/testing.md`, with the solo and two-client checklists moved out of
    `spec/migration-forever.md`;
  - trim `CLAUDE.md`;
  - fix this plan (H3 and H4 restored, Issues status, date targets, protocol v4 naming);
  - add history banners to the inherited RFCs, specs, `ROADMAP.md` and
    `CURSEFORGE_DESCRIPTION.md`;
  - mark the fork boundary in `CHANGELOG.md`.
- **Cut 2 (after the Oct 28 feature freeze):**
  - write `docs/architecture.md` from source, after Phase 1's sync changes land;
  - rewrite `ROADMAP.md`;
  - propose a shared CurseForge description. This needs the upstream author's agreement;
  - archive moves for the inherited docs, only if still wanted.
- **Status:** cut 1 written 2026-10-03 on `docs/refresh-cut1`, not yet merged.
- **Done when:** cut 1 is merged before Phase 2, and cut 2 is merged before launch.

**Phase 1 exit gate:**
- CI green on `main`.
- Every `blocker` (H1, H2, H5, H9, H10, H14) merged.
- The rest either merged or deferred in an issue with a reason.
- H8 answered or explicitly deferred.
- D1 cut 1 merged.

---

## Phase 2 — First tester build (Oct 10–11)

These are the gates. [`docs/releasing.md`](../docs/releasing.md) has the commands and the
order for each one.

Before tagging:
- dkruenbo has added your CurseForge account to project 1469206 with upload rights.
- A CurseForge API token is stored as the `CF_API_KEY` repository secret.
- `CHANGELOG.md` has a version heading in place of `## Unreleased`, in the format the packager's
  `manual-changelog` expects.
- A no-publish dry run of `release.yml` passed on the commit you're about to tag, and you
  inspected its artifact. The first dry run passed on 2026-10-03 (run `37093088953`).
- H18's guards are in, so a missing token or a stray tag can't publish half a release.

Then:
1. Tag `v2.1.0-forever-beta.1` (confirm the convention with Lektor if he answered). Pushing a
   `v*` tag publishes.
2. Check the published file on CurseForge. It's release type **beta**, not release. It carries
   exactly one game version tag, and nothing changed for the other five flavors.
3. Run the two-client checklist ([`docs/testing.md`](../docs/testing.md)) with **one** guildmate
   before anyone else installs it. If they're on a different server prefix (`Player-4613-` vs
   `Player-4619-`), that also answers how a cross-server sender name looks and whether a whisper
   reaches them.

**Phase 2 exit gate:** the two-client checklist passes end to end, including a drop on one
client while the other is offline, then reconnect.

---

## Phase 3 — Guild testing (Oct 11–21)

Do **not** announce to 100 people at once. Sync bugs scale with the number of clients, and
DR/BDR election behaviour at 20+ online is the part nobody has exercised.

| Wave | Who | Size | Focus |
|---|---|---|---|
| 1 | Hand-picked, technical | 3–5 | Election with several clients, drop/relearn, restriction pause in a dungeon |
| 2 | Broad profession coverage | 10–15 | Every profession scanned at least once; tooltip and search |
| 3 | Open to the guild | Everyone | Load, election at scale, performance |

Each wave runs ~3 days. Move on only when the previous wave has no open `blocker`.

**Feedback channel:** one guild Discord thread, pinned instructions: install, open each
profession window once, `/gc report` and paste it when anything looks wrong. Every report
becomes an issue.

**What to watch for at wave 3 specifically:** sync traffic volume, login hitching, and whether
election settles. These only show up at scale.

**Note:** beta characters and SavedVariables will not carry into launch. Beta testing validates
behaviour, not data. Don't build anything that migrates beta data.

---

## Phase 4 — Launch (Oct 21 – Nov 4)

1. Fix whatever waves 2–3 surfaced. Freeze features on **Oct 28**.
2. After the freeze, do D1 cut 2.
3. When the launch build appears on the `forever` branch, re-run the solo checklist
   (`docs/testing.md`) on it and bump the pin in the docs.
4. Tag `v2.1.0-forever`, publish as **release** on the launch date (target Nov 4), following
   `docs/releasing.md`.
5. Send Lektor the link. He offered to share it with his guild.
6. Post in the Forever addon communities once it's live, not before.

---

## Tooling (any time, never gating)

Decided on 2026-10-02 from the legacynext reuse review:
- **Own vendor checkout of Gethe/wow-ui-source `forever`.** Pin it, and include
  `Blizzard_Professions*`, `Blizzard_Communities`, `Blizzard_ChatFrame*`,
  `Blizzard_APIDocumentationGenerated`, `SharedXML*` and `FrameXML*`. legacynext's checkout is
  another project's shared state, and its sparse set lacks the professions and chat code.
- **Copy and adapt legacynext's skills.** The sandbox can't write `.claude/skills`, so Alex
  installs them:
  - `forever-api-lookup`: re-bucket for Professions, Communities and ChatFrame;
  - `ingame-script`: point it at `docs/ingame-commands.md`;
  - `safe-commit`: add a hard fail on any diff to the five Classic TOCs or `Data/Data_*.lua`.

---

## Post-launch (parked)

- **Recipe data:**
  - C5: Forever-specific recipes are all tagged Vanilla internally, invisibly. Generate from
    DB2s via wago.tools when it's worth it. Spell ID ≥ 1,000,000 tagged 858 of 861 correctly in
    Recipe Registry's data.
  - C6: recipe sources and "known by" on blueprints need a static map.
- **C4:** cooldowns. The modern scan reads none; `C_Spell.GetSpellCooldown`, guarded by
  `issecretvalue`.
- **Compact sync encoding (protocol v4).** Protocol `VERSION` and `DATA_FORMAT_VERSION` are
  already 3 since `f0522c4` (profession drop history), so this change would ship as version 4.
  It was called "wire format v3" before that bump.
  - recipe-ID sets instead of recipe tables (591 B vs 3,554 B for 120 recipes);
  - chunks of about 2 KB, sized by bytes rather than members;
  - a version-vector digest in HELLO/HEARTBEAT;
  - deltas carrying a base version;
  - separate "content changed" from "member active".
- **Blizzard's guild recipe API.** Decide whether to build on it if
  `IsGuildTradeSkillsEnabled()` is true.
- **UI/UX:** ranked search, member page with tabs, cold-start states, ScrollBox rendering,
  resizable layout, short tooltip, settings panel and Addon Compartment, accessibility (fork
  review §3).
- **Code hygiene:**
  - `Compat.lua` for the scattered feature-detect branches;
  - one scan pipeline;
  - an event bus;
  - remove AceGUI (7,109 lines, never used);
  - update LibDBIcon for the compartment.
- **Ace3 upstream Forever fixes** newer than r1403: AceDB `1e98fc0`, `5e2e0d3` and `afabc91`.
  The last removes the realm from `charKey`, which may change profile keys, so evaluate before
  taking it.
- **F15:** fuzzy search keeps `y`, so "agylity" misses.
- The 99-fallback expansion pruning, if Forever ever raises its expansion level. The skill-line
  gate (`c16b09f`) already covers Jewelcrafting and Inscription.
- Anything raid-adjacent waits for Dec 9.

---

## Open questions

| # | Question | Where it's answered |
|---|---|---|
| Q1 | Full client build number for the 2026-10-02/03 runs | H5 (`GetBuildInfo()` in the report) |
| Q2 | Does `ADDON_RESTRICTION_STATE_CHANGED` fire at a boss pull? API and enums are verified (`RA`, `RS`) | H8 (`RE`) |
| Q4 | Why the first `/gc dump` on 2026-10-02 stored nothing | H5, H6 |
| Q5 | Sender name and whisper reach for a guildmate on another server prefix | Phase 2 two-client run |
| Q6 | Does ChatThrottleLib v32 clear the chat taint in game? | Wave 1 |
| Q7 | Date and channel of dkruenbo's two messages, for `docs/ORIGIN.md` | Alex |

Q3 (solo checklist) closed on 2026-10-03: items 3–9 all passed.

---

## Decisions log

| Date | Decision |
|---|---|
| 2026-10-02 | Publish the Forever flavor only, under dkruenbo's CurseForge project 1469206. Keep the other five TOCs and `Data/` untouched in the repo |
| 2026-10-02 | Forever loads through `GuildCrafts_Camelot.toc`; `_Forever` isn't read by the client |
| 2026-10-02 | Forever members are keyed by GUID (`Modules/ForeverIdentity.lua`, Camelot TOC only) |
| 2026-10-02 | Only `/gc drop` removes a profession that holds recipes |
| 2026-10-02 | Jewelcrafting and Inscription are gated on the client's skill lines |
| 2026-10-02 | Own vendor checkout; copy legacynext's skills rather than symlinking |
| 2026-10-03 | Plain Lua 5.1 regression scripts in `tools/test-*.lua`, not busted |
| 2026-10-03 | Documentation refresh in two cuts (D1). Inherited docs get history banners in place rather than moving to an archive |
| Open | Build on Blizzard's guild recipe API (post-launch) |

---

## Finding index (fork review, 2026-09-28)

Status as of `8f0dc69`.

| ID | Finding | Status |
|---|---|---|
| F1 | Empty SavedVariables wipe your recipes on every peer | Peers keep them now (`fd788e6`, `f0522c4`); restoring your own copy is H11 |
| F2 | `GetProfessions` read as five slots | Closed: Forever's slots are prof1, prof2, First Aid, Fishing, Cooking (`Camelot/Blizzard_ProfessionsBook.lua:21`, `PROF` probe) |
| F3 | First Aid not tracked | Open, H17 |
| F4 | `!gc` echo abuse | Open, H14 |
| F5 | Guild views scanned as your own | Open, H10 |
| F6 | Sync whispers strip the realm | Fixed on Forever: whisper targets come from the roster (`9faf497`) |
| F7 | RESUME duplicates transfers | Open, H12 |
| F8 | DR silent after a higher term | Open, H12 |
| F9 | Tooltip debounce never debounces | Open, H16 |
| F10 | Tooltip writes the global `_` | Open, H16 |
| F11 | Scan retries uncapped | Open, H15 |
| F12 | Categories lost (`categoryName`) | Open, H15 |
| F13 | Election watchdog resets on every recompute | Open, H12 |
| F14 | `/gc reset` calls `ReloadUI()` | Open, H7 |
| F15 | Fuzzy search keeps `y` | Post-launch |
| F16 | `IsSpellKnown` checked before `C_SpellBook` | Open, H15 |
| F17 | Identity split on Forever | Fixed (`9faf497`) |
| F18 | ChatThrottleLib v31 taint | Library updated to v32 (`a1c0554`); not yet checked in game, Q6 |
| F19 | Empty read purges every profession | Fixed (`fd788e6`, `f0522c4`); remaining hole is H9 |
| F20 | Whisper button breaks two-word names | Open, H14 |
| F21 | Empty profession name stops the scan | Open, H15 |
| C1 | First Aid and Fishing untracked; JC/Inscription rows | JC/Inscription gated (`c16b09f`); First Aid and Fishing open, H17 |
| C2 | Gathering recipes hidden | Open, H17 |
| C3 | TBC specialisation table | Open, H17 |
| C4 | No cooldowns from the modern scan | Post-launch |
| C5 | Every recipe tagged Vanilla | Post-launch |
| C6 | Recipe sources empty | Post-launch |

## What this plan deliberately doesn't do

- No new features before Phase 3. The fork's job during the beta is to be trustworthy.
- No changes to the other five flavors' TOCs or data, ever, and nothing published for them.
- No testing beyond the guild during the beta. The guild is the test bed; the public gets the
  launch build.
