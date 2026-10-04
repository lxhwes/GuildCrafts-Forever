# GuildCrafts Forever — beta plan

Written 2026-10-03 against `main` at `8f0dc69`. This is the single list of planned work. It
merges Alex's beta plan with:
- every item still open in `spec/migration-forever.md`;
- the 2026-09-28 fork review (finding IDs F1–F21 and C1–C6, indexed at the end);
- the legacynext reuse review;
- the open items from the 2026-10-02/03 sessions.

`spec/migration-forever.md` is the record of what was decided and verified. This file is what's
left to do. When Phase 0 creates GitHub Issues, each item here becomes one issue and this file
keeps only the phase structure.

Beta ends **Oct 21**. Launch **Nov 4**. Raids **Dec 9**.

Goal, in order: get the codebase into the best shape it can be, then put it in front of the
guild. Nothing goes to guildmates until Phase 2's exit gate passes.

---

## Phase 0 — Tracking (Oct 3–4, an evening)

Work is not tracked anywhere authoritative:

- `ROADMAP.md` is upstream's and points at **upstream's** issue tracker.
- `spec/migration-forever.md` mixed finished tasks, findings and open questions. The open
  questions moved here on 2026-10-03, so it's now a record only.
- `spec/fork-review.md` is a local, uncommitted working note. Every finding it raised that's
  still open is defined in the index at the end of this file, so committed docs no longer
  depend on it.

Do:

1. **GitHub Issues on the fork is the tracker.** One issue per item in this plan. Labels:
   `blocker`, `hardening`, `testing`, `post-launch`, `needs-ingame`. A milestone per phase.
2. **Rewrite `ROADMAP.md`** for the fork: a short Forever section on top, upstream's history
   kept below under "Upstream (dkruenbo/GuildCrafts)".
3. **Decide what happens to the local working notes.** Either commit `spec/fork-review.md` as
   a dated historical review, or keep it local. The same goes for
   `spec/legacynext-reuse-plan.md`. Both are optional now that this plan carries their open
   items.

Why first: guild testing generates reports. Without a tracker, they land in Discord and vanish.

---

## Phase 1 — Hardening (Oct 4–10)

Each item: what, why, how, done-when. Ordered by risk within each group.

### Data integrity

#### H1. CI — `blocker`
- **Why:** three regression suites guard the bugs that can destroy guild data, and nothing runs
  them. `release.yml` is the only workflow.
- **How:** add `.github/workflows/ci.yml`, triggered on push and PR. It runs:
  - luacheck against `GuildCrafts/.luacheckrc`;
  - `lua5.1 tools/test-profession-sync.lua`;
  - `lua5.1 tools/test-forever-identity.lua`;
  - `lua5.1 tools/test-profession-gate.lua`.

  Pin action SHAs as `release.yml` does. Lint is at 51 warnings (48 undefined globals plus F10
  and two others). Either get it to zero first, or fail only on new warnings.
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
Validated by the two-client checklist (Phase 2) and wave 1.
- **F8:** a DR that sees a higher term stops heartbeating but keeps `myRole = "DR"`, so a
  re-elected DR stays silent (`Comms.lua` term adoption and the `RecomputeElection` role-change
  branch).
- **F13:** the election watchdog resets on every recompute. Any node receiving a retry≥2 request
  evicts the DR and BDR guild-wide.
- **BDR never evicted:** when the BDR logs out, the DR keeps it in `addonUsers`. Only the DR is
  ever evicted (`CheckDRAlive`), and roster eviction was removed (`OnGuildRosterUpdate`).
  Two-client checklist step D2.
- **Paused deltas are dropped, not queued:** a recipe delta suppressed by SyncPausePolicy is
  never resent. The peer only catches up at its next login sync (two-client step R8).
- **F7:** RESUME duplicates transfers. Large chunks drain at about 800 B/s, so RESUME fires after
  4 s and re-queues chunks that are still in flight.

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

### Restrictions and lifecycle

#### H7. `/gc reset` and `ReloadUI()` (F14) — `hardening`
- **Why:** `ReloadUI()` is reported protected on Forever. A reset that errors leaves the user
  unsure whether their data was cleared.
- **How:** probe (`needs-ingame`). If protected, reset the data and tell the user to `/reload`.

#### H8. Close the remaining open questions — `needs-ingame`
- `RE` probe at a dungeon boss pull: does `ADDON_RESTRICTION_STATE_CHANGED` fire? The
  restriction pause depends on it.
- Then decide the SyncPausePolicy follow-ups left out of `71526af`:
  - hold `HELLO`/`HEARTBEAT`/`GC_ACK` during a Chat restriction;
  - keep the DR watchdog fresh under Map or Chat;
  - keep `!gc` silent under any restriction;
  - add a grace period after a restriction lifts.

**Phase 1 exit gate:**
- CI green on `main`.
- Every `blocker` (H1, H2, H5, H9, H10, H14) merged.
- The rest either merged or deferred in an issue with a reason.
- H8 answered or explicitly deferred.

---

## Phase 2 — First tester build (Oct 10–11)

Before tagging:
- dkruenbo has added your CurseForge account to project 1469206 with upload rights.
- A CurseForge API token is stored as `CF_API_KEY`, set from your own terminal:
  `gh secret set CF_API_KEY --repo lxhwes/GuildCrafts-Forever`.
- `CHANGELOG.md` is ready for `manual-changelog`. Every line is indented two spaces, and the top
  section is `## Unreleased`. Give it a version heading.

Then:
1. Tag `v2.1.0-forever-beta.1` (confirm the convention with Lektor if he answered).
2. Dry-run `release.yml` via `workflow_dispatch` with `publish: false`. Download the artifact,
   inspect it. The first dry run passed on 2026-10-03 (run `37093088953`).
3. Publish as release type **beta**, not release. Check on CurseForge that the file carries
   exactly one game version tag, and that nothing changed for the other five flavors.
4. Run the two-client checklist (`spec/migration-forever.md`) with **one** guildmate before
   anyone else installs it. If they're on a different server prefix (`Player-4613-` vs
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
2. When the launch build appears on the `forever` branch, re-run the solo checklist on it and
   bump the pin in the docs.
3. Tag `v2.1.0-forever`, publish as **release** on Nov 4.
4. Send Lektor the link. He offered to share it with his guild.
5. Post in the Forever addon communities once it's live, not before.

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
- **Wire format v3:**
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
  - update LibDBIcon for the compartment;
  - mark the RFCs that describe upstream-only behaviour.
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
| F18 | ChatThrottleLib v31 taint | Fixed (`a1c0554`); in-game check is Q6 |
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
