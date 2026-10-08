# GuildCrafts Forever — beta plan

Written 2026-10-03 against `main` at `8f0dc69`. It merges Alex's beta plan with:
- every item still open in `spec/migration-forever.md`;
- the 2026-09-28 fork review ([`spec/fork-review.md`](fork-review.md), finding IDs F1–F21 and
  C1–C6, indexed at the end);
- the legacynext reuse review (kept local);
- the open items from the 2026-10-02/03 sessions;
- Alex's documentation review (`spec/documentation-refresh-plan.md`, kept local), as D1;
- the CurseForge comment audit ([`spec/curseforge-audit.md`](curseforge-audit.md), 2026-10-03,
  finding IDs F22–F40, indexed at the end);
- the code review ([`spec/code-review-2026-10-07.md`](code-review-2026-10-07.md), 2026-10-07,
  finding IDs F41–F46, indexed at the end).

Work items live in [GitHub Issues](https://github.com/lxhwes/GuildCrafts-Forever/issues), one per
plan ID, each with its why, findings and done-when. Status lives only there. This file keeps the
phases, their gates, the ID-to-issue index and the decisions log. `spec/migration-forever.md` is
the record of what was decided and verified.

Current state: `bash tools/check-plan-index.sh --summary` prints the phase gate, drift and the
next in-game session, and runs at every session start. Without arguments it lists each drift item.
Open blockers: [`label:blocker`](https://github.com/lxhwes/GuildCrafts-Forever/issues?q=is%3Aopen+label%3Ablocker).

Planning targets: beta ends **Oct 21**, launch **Nov 4**, raids **Dec 9**. This plan cites no
source for these dates. Confirm them against Blizzard's announcements before anything depends on
them.

Goal, in order: get the codebase into the best shape it can be, then put it in front of the
guild. Nothing goes to guildmates until Phase 2's exit gate passes.

---

## Phase 0 — Tracking (done 2026-10-03)

- Issues [#4]–[#39] created from this plan, titled with their plan IDs. [#44] (H19) and [#45]
  (Q8) added from the CurseForge audit. [#51]–[#66] (N1–N9, G1–G7) added from the Later
  backlog. [#80] (H20) added 2026-10-04 from the open item in `docs/releasing.md`. [#104]–[#106]
  (H22–H24) added 2026-10-06 from a read of the sync code at `538491c`. Sub-issues [#112]–[#130]
  and in-game trackers [#131]–[#135] added 2026-10-07. [#138]–[#140] (H25, H26, Q9) added
  2026-10-07 from the code review.
- Labels: `blocker`, `hardening`, `testing`, `needs-ingame`, `post-launch`, and the existing
  `documentation`. The Later backlog added `feature`, `external`, `security` and `research`.
  `wave-1`–`wave-3` and `ingame-session` added 2026-10-07.
- One milestone per phase, plus Post-launch and Later.
- The `ROADMAP.md` rewrite moved to D1 cut 2 ([#22]). Until then it carries a history banner
  that points here.

- Local working notes, decided 2026-10-03: `spec/fork-review.md` is committed as a dated
  historical review, because the issues cite its finding IDs. The legacynext reuse review and
  the documentation review stay local. The first-draft `plan.md` was deleted.

---

## Phase 1 — Hardening (Oct 4–10)

[Milestone](https://github.com/lxhwes/GuildCrafts-Forever/milestone/1). Everything still open
from Phase 1 moved to the phase that needs it on 2026-10-04 (decisions log).

Done: H1 [#4], H2 [#5], H5 [#8], H6 [#9], H7 [#10], H9 [#12], H10 [#13], H11 [#14], H13 [#16], H16 [#19], H18 [#21], H20 [#80], Q1 [#24], D1 cut 1 [#3]

Closed as not planned: H3 [#6]

**Phase 1 exit gate**, met 2026-10-05; the milestone is closed:
- [x] CI green on `main`: first green run `37169051274`
- [x] Every `blocker` merged: H1 (#41), H2 (#93), H5 (#50), H9 (#43). H10 stopped being a blocker and H14 isn't one unless a CHT, TELL or CHL probe reproduces a failure (decisions log 2026-10-04)
- [x] The rest merged, or deferred in its issue with a reason (decisions log 2026-10-04, Phase 1 close-out)
- [x] H8 answered or explicitly deferred: deferred to wave 1 with Q2 (decisions log 2026-10-04)
- [x] The GRO and CHL probes run (`migration-forever.md 2026-10-04`)
- [x] D1 cut 1 merged (#3)

---

## Phase 2 — First tester build (Oct 10–11)

[Milestone](https://github.com/lxhwes/GuildCrafts-Forever/milestone/2). The gates before
tagging, and the tag and check steps, are in [#23]. [`docs/releasing.md`](../docs/releasing.md)
has the commands and the order for each one.

After the tag, run the two-client checklist ([`docs/testing.md`](../docs/testing.md)) with
**one** guildmate before anyone else installs it. IG1 lists everything that run answers.

| ID | Issue | Scope |
|---|---|---|
| P2 | [#23] | Tester build prerequisites and the tag |
| H4 | [#7] | Senders that arrive before the roster loads: the cold-start premise |
| F25 | [#121] | `[W]` click on a two-word name (H14) |
| IG1 | [#131] | In-game session: the two-client run |

Q4 ([#26]), Q5 ([#27]) and Q8 ([#45]) are answered in the same run; see Open questions.

Done: H21 [#98]

**Phase 2 exit gate:**
- [ ] The two-client checklist passes end to end, including a drop on one client while the other is offline, then reconnect (IG1 [#131])

---

## Phase 3 — Guild testing (Oct 11–21)

[Milestone](https://github.com/lxhwes/GuildCrafts-Forever/milestone/3).

Do **not** announce to 100 people at once. Sync bugs scale with the number of clients, and
DR/BDR election behaviour at 20+ online is the part nobody has exercised.

| Wave | Who | Size | Focus |
|---|---|---|---|
| 1 | Hand-picked, technical | 3–5 | Election with several clients, drop/relearn, restriction pause in a dungeon, Q6 ([#28]) |
| 2 | Broad profession coverage | 10–15 | Every profession scanned at least once; tooltip and search |
| 3 | Open to the guild | Everyone | Load, election at scale, performance |

Each wave runs ~3 days. A wave starts only when the previous wave's label has no open
`blocker`: [wave 1](https://github.com/lxhwes/GuildCrafts-Forever/issues?q=is%3Aopen+label%3Ablocker+label%3Awave-1),
[wave 2](https://github.com/lxhwes/GuildCrafts-Forever/issues?q=is%3Aopen+label%3Ablocker+label%3Awave-2).
Umbrella issues stay open until their last sub-issue closes.

### Wave 1

| ID | Issue | Scope |
|---|---|---|
| H8 | [#11] | SyncPausePolicy follow-ups after Q2; silent send failures (F34) |
| H12 | [#15] | Sync robustness (umbrella) |
| F7 | [#112] | RESUME duplicates transfers; finalize per sender and session |
| F27 | [#113] | A client that can't receive can be elected DR |
| F36 | [#114] | The 45-day prune writes no tombstone |
| H12.1 | [#115] | The BDR is never evicted |
| H12.2 | [#116] | Paused deltas are dropped, not queued |
| H12.3 | [#117] | A newly elected or returning DR pulls before it answers (joint with H19's DR-elect pull) |
| H12.4 | [#118] | The merge-side partial-scan guard uses raw counts |
| H25 | [#138] | Simulator in its own module; election and delta suites; wave-1 known-gap scenarios (F41). Tools only; lands before H12.3 |
| H26 | [#139] | Do DR terms earn their keep? Investigate with the H25 simulator, then remove or document (F42). Decided before H12.3 is designed |
| H14 | [#17] | Chat and whisper on Forever (umbrella) |
| F22 | [#119] | `!gc` fallback delays collide |
| F23 | [#120] | `!gc` cooldown is stamped only on the client that posted |
| IG2 | [#132] | In-game session: next dungeon (Q2, H8) |
| IG3 | [#133] | In-game session: wave 1 |

### Wave 2

| ID | Issue | Scope |
|---|---|---|
| H17 | [#20] | Profession coverage (umbrella) |
| C1/F3 | [#122] | First Aid and Fishing are not tracked |
| C2 | [#123] | Recipes view hidden for gathering professions |
| C3 | [#124] | The specialisation table is TBC's |
| IG4 | [#134] | In-game session: wave 2 |

### Wave 3

| ID | Issue | Scope |
|---|---|---|
| H19 | [#44] | Sync load and frame time (umbrella) |
| F30 | [#125] | Each login makes every client send a full `SYNC_REQUEST`; after H12.3 and H22 |
| F31 | [#126] | Every zone change sends `HELLO` and a `SYNC_REQUEST` |
| F33 | [#127] | Roster passes and UI refresh on every update |
| H19.1 | [#128] | M1–M4 measurements |
| F11 | [#129] | Scan event rework and the scan-side partial-scan guard |
| F32 | [#130] | Every `TRADE_SKILL_LIST_UPDATE` runs a full scan |
| IG5 | [#135] | In-game session: wave 3 |

### Any wave

| ID | Issue | Scope |
|---|---|---|
| H22 | [#104] | Deltas can leave permanent gaps; two-client check M runs in IG1 |

H24 ([#106], resends that never settle) is bandwidth, not correctness, so it's in Post-launch.

Done: H15 [#18], H23 [#105]

**Feedback channel:** one guild Discord thread, pinned instructions: install, open each
profession window once, `/gc report` and paste it when anything looks wrong. Every report
becomes an issue.

**What to watch for at wave 3 specifically:** sync traffic volume, login hitching, and whether
election settles. These only show up at scale.

**Note:** beta characters and SavedVariables will not carry into launch. Beta testing validates
behaviour, not data. Don't build anything that migrates beta data.

---

## Phase 4 — Launch (Oct 21 – Nov 4)

[Milestone](https://github.com/lxhwes/GuildCrafts-Forever/milestone/4).

| ID | Issue | Scope |
|---|---|---|
| D1 cut 2 | [#22] | Documentation refresh, cut 2 |

1. Fix whatever waves 2–3 surfaced. Freeze features on **Oct 28**.
2. After the freeze, do D1 cut 2 ([#22]). Its scope includes F45.
3. When the launch build appears on the `forever` branch, re-run the solo checklist
   (`docs/testing.md`) on it and bump the pin in the docs.
4. Tag `v2.1.0-forever`, publish as **release** on the launch date (target Nov 4), following
   `docs/releasing.md`.
5. Send Lektor the link. He offered to share it with his guild.
6. Post in the Forever addon communities once it's live, not before.

Q7 ([#29]) is a `docs/ORIGIN.md` fix that can land any time before launch.

---

## Tooling (any time, never gating)

Decided on 2026-10-02 from the legacynext reuse review. Not tracked as issues:
- ~~**Own vendor checkout of Gethe/wow-ui-source `forever`.**~~ Superseded 2026-10-04: one
  shared checkout at `~/code/wow-ui-source-forever`, outside both repos, so it's no longer
  another project's state. Its sparse set now includes `Blizzard_Professions*`,
  `Blizzard_Communities`, `Blizzard_ChatFrame*`, `Blizzard_GuildControlUI` and
  `Blizzard_DeprecatedChatInfo`, alongside the API docs, `SharedXML*` and `FrameXML*`. Each
  repo records the pin it last reconciled against (`.claude/forever-tools/pin`).
- ~~**Copy and adapt legacynext's skills.**~~ Superseded 2026-10-04: copies drift, as
  legacynext's own two copies of its queue did within a day. `forever-api-lookup`,
  `ingame-script` and `beta-build-bump` come from the `forever-tools` plugin, enabled for this
  project only. Settings that differ per project are in `.claude/forever-tools/config.env`;
  the call-site buckets are re-bucketed for Professions, chat and guild there.
  - Still open: a GuildCrafts `safe-commit` with a hard fail on any diff to the five Classic
    TOCs or `Data/Data_*.lua`. It stays per project, because the gates differ.
- Tracking, decided 2026-10-07: `tools/check-plan-index.sh`, the session-start summary, the
  `track` skill and the PR Tracking block keep this file and the issues in step.

---

## Post-launch (parked)

[Milestone](https://github.com/lxhwes/GuildCrafts-Forever/milestone/5).

| ID | Issue | Item |
|---|---|---|
| H24 | [#106] | Sync resends entries that never settle. Needs M2 numbers from H19.1 [#128] |
| C4 | [#30] | Cooldowns from the modern scan |
| C5 | [#31] | Forever recipe data from DB2s |
| C6 | [#32] | Recipe sources ("known by" moved to G1 [#60]) |
| F15 | [#33] | Fuzzy search keeps `y` |
| — | [#34] | Compact sync encoding (protocol v5). H22 [#104] takes the delta base version early; H24 [#106] may fold in its drop digest |
| — | [#35] | Decide on Blizzard's guild recipe API |
| — | [#36] | UI/UX (fork review §3) |
| — | [#37] | Code hygiene (F43, F46) |
| — | [#38] | Ace3 fixes newer than r1403 |
| — | [#39] | 99-fallback expansion pruning |

Anything raid-adjacent waits for Dec 9.

---

## Later (ideas, not committed)

[Milestone](https://github.com/lxhwes/GuildCrafts-Forever/milestone/6). Feature ideas from
[`spec/later-backlog.md`](later-backlog.md), which has the privacy rules and the suggested order.
Nothing here starts before the Oct 28 feature freeze has passed and the launch build is out.
Implementation specs for N1–N8, with the 2026-10-04 design decisions, are in
[`spec/later/`](later/README.md).

N: out of game (export, companion, web, Discord). N4's design gates every external service.

| ID | Issue | Item | Depends on |
|---|---|---|---|
| N1 | [#51] | `/gc export` copy frame | N2 [#52] for the opt-out filter; N1 can ship first. EB and TIME probes |
| N2 | [#52] | Per-character opt-out (audit X3) | — (takes protocol `VERSION` 4 on its own) |
| N3 | [#53] | Companion export block in SavedVariables | N1 [#51], N2 [#52], H3 [#6]; CLUB probe |
| N5 | [#55] | Companion uploader | N3 [#53], N4 [#54], N6 [#56] |
| N6 | [#56] | Web backend: tenancy, auth and isolation | N4 [#54]; Cloudflare and Discord accounts |
| N7 | [#57] | Web recipe book | N6 [#56] |
| N8 | [#58] | Discord bot | N6 [#56] |

G: in game.

| ID | Issue | Item | Depends on |
|---|---|---|---|
| G1 | [#60] | Recipe-scroll tooltip alert | An in-game probe; C5 [#31] if no API exists; H16 [#19] |
| G2 | [#61] | Coverage view: single-crafter and missing recipes | C5 [#31], for missing recipes only |
| G3 | [#62] | Reagent check in recipe detail | — |
| G4 | [#63] | Favorite crafter online alert | H19 [#44] (F33 [#127]) |
| G5 | [#64] | "Recently learned" feed | H2 [#5] |
| G6 | [#65] | Raid consumables view (for Dec 9) | H15 [#18], C4 [#30] |
| G7 | [#66] | Public API for other addons | N2 [#52] |

Done: N4 [#54]

Closed as not planned: N9 [#59]

---

## Open questions

Each question's issue holds its status; the last column names the session that answers it.

| # | Question | Issue | Answered in |
|---|---|---|---|
| Q2 | Does `ADDON_RESTRICTION_STATE_CHANGED` fire at a boss pull? | [#25] | IG2 [#132], the `RE` probe |
| Q4 | Why the first `/gc dump` on 2026-10-02 stored nothing | [#26] | IG1 [#131], solo from first-run state |
| Q5 | Sender name and whisper reach for a guildmate on another server prefix | [#27] | IG1 [#131], only with a guildmate on another prefix |
| Q6 | Does ChatThrottleLib v32 clear the chat taint in game? | [#28] | IG3 [#133] |
| Q7 | Date and channel of [@dkruenbo](https://github.com/dkruenbo)'s two messages, for `docs/ORIGIN.md` | [#29] | Alex |
| Q8 | Do GUILD addon messages reach a client inside an instance? `Comms.lua` assumes not; three upstream reports suggest they do | [#45] | IG1 [#131], the R4 probe in `spec/curseforge-audit.md` |
| Q9 | Keep the five Classic TOCs and `Data/` in the fork? (F44) | [#140] | Alex, when [#37] starts |

Q3 (solo checklist, no issue) passed on 2026-10-03: items 3–9.

---

## Decisions log

| Date | Decision |
|---|---|
| 2026-10-02 | Publish the Forever flavor only, under [@dkruenbo](https://github.com/dkruenbo)'s CurseForge project 1469206. Keep the other five TOCs and `Data/` untouched in the repo |
| 2026-10-02 | Forever loads through `GuildCrafts_Camelot.toc`; `_Forever` isn't read by the client |
| 2026-10-02 | Forever members are keyed by GUID (`Modules/ForeverIdentity.lua`, Camelot TOC only) |
| 2026-10-02 | Only `/gc drop` removes a profession that holds recipes |
| 2026-10-02 | Jewelcrafting and Inscription are gated on the client's skill lines |
| 2026-10-02 | ~~Own vendor checkout; copy legacynext's skills rather than symlinking~~ (superseded 2026-10-04) |
| 2026-10-03 | Plain Lua 5.1 regression scripts in `tools/test-*.lua`, not busted |
| 2026-10-03 | Documentation refresh in two cuts (D1). Inherited docs get history banners in place rather than moving to an archive |
| 2026-10-03 | GitHub Issues is the tracker. This file keeps phases, gates and the ID index |
| 2026-10-03 | H1: get luacheck to zero warnings first, then CI fails on any warning |
| 2026-10-03 | Later backlog N1–N9, G1–G7 added from `spec/later-backlog.md`; N4 design gates all external services |
| 2026-10-04 | N1–N8 specs in `spec/later/`. N2 marker tombstone-shaped; protocol `VERSION` 4 with N2 (#34 becomes v5); companion block in a separate `GuildCraftsExport` SavedVariable; external stack on Cloudflare Workers Paid in a new monorepo, multi-tenant with one tenant at launch |
| 2026-10-04 | H14 ([#17]) isn't a blocker unless a CHT, TELL or CHL probe reproduces a failure |
| 2026-10-04 | G1 ([#60]) owns "known by" on recipe items; C6 ([#32]) covers recipe sources only |
| 2026-10-04 | The changelog upload is tracked as H20 ([#80]) and lands before the first publish |
| 2026-10-04 | One shared Forever checkout (`~/code/wow-ui-source-forever`) and the `forever-tools` plugin for the three shared skills, replacing the 10-02 own-checkout and copy decisions |
| 2026-10-04 | H3 ([#6]) closed as rejected: GRO showed the roster lists offline members with GUIDs |
| 2026-10-04 | H10 ([#13]) isn't a blocker: 70205 offers no guild view. The scan guard still lands as insurance |
| 2026-10-04 | Phase 1 close-out: Phase 1 takes H2, H4's F26 fallback, H7, H12's F8/F13/F28, H14's send API, F4 and F24, H15's F12/F16/F21, H17's search copy, H19's F29 and H20. The rest is deferred to the wave that needs it (Phase 3) |
| 2026-10-04 | H15's F11 event rework and F32 move to H19 for wave 3; they need M2's event counts first |
| 2026-10-06 | H12's returning DR ([#15]) and H19's DR-elect pull ([#44], F30) share a root cause, so they're fixed together in wave 1: a newly elected or returning DR pulls from the BDR or the previous DR before it answers requests. A DR that misses a delta (H22) whispers `SYNC_PULL` for that member, with no wire change. F30's herd fix lands after it and after H22 ([#104]), because today the herd is how a new DR catches up |
| 2026-10-06 | H22 ([#104]) and H23 ([#105]) go in Phase 3; H24 ([#106]) is post-launch unless M2 shows it's large |
| 2026-10-06 | H22's `base` is the owner's last recipe revision, kept locally as `recipeRev`, not `lastUpdate` before the scan. No-change scans bump `lastUpdate` without a delta (`Data.lua:1888` at `538491c`), so that version would mismatch on nearly every delta and trigger a guild-wide pull. Removals follow the same rule, because `MergeProfessionRemoval` raised the revision too. Skill-ups don't move `base`; deltas never carry skill levels |
| 2026-10-07 | Status lives only in the issues. This file keeps phases, gates, the ID index and decisions; `tools/check-plan-index.sh` checks the two agree and prints the summary at session start |
| 2026-10-07 | Issues close only through a merged PR's Tracking block (applied by the `track` skill) or by hand with an evidence comment. CI rejects closing keywords; squash merges take the PR body, and merge commits are off. #15 had closed from a squash commit body |
| 2026-10-07 | Findings that land in different phases are sub-issues of their umbrella. A sub-issue with no finding ID takes its parent's ID plus a number (H12.1). The joint DR fix is H12.3 ([#117]) under #15; F30 ([#125]) is blocked by it and by H22 |
| 2026-10-07 | The multi-client `Sim` moves out of `test-forever-identity.lua` into `tools/lib/sim.lua`, with election and delta suites of their own (H25, [#138]). Wave-1 sync fixes start as known-gap scenarios there |
| 2026-10-07 | H26 ([#139]) is decided before H12.3 ([#117]), the joint returning-DR fix, is designed |
| 2026-10-07 | F43 (module split) and F46 (comment sweep) go to [#37] post-launch. Any split respects the untouched Classic TOCs, or waits for Q9 ([#140]). Until the sweep, a PR that changes a function rewrites that function's upstream-history comments (`AGENTS.md` Rules) |
| 2026-10-07 | F45 is in scope for D1 cut 2 ([#22]) and stays within the 2026-10-03 history-banner decision |
| 2026-10-08 | Shared agent rules live in `AGENTS.md`, which `CLAUDE.md` imports. Claude-only workflow stays in `CLAUDE.md`; sync and in-game guidance are path-scoped rules in `.claude/rules/` |
| 2026-10-08 | Nightly plan drift runs as a scheduled `plan-index.yml` job, not a `/schedule` routine: cloud sessions block GitHub GraphQL, which `tools/check-plan-index.sh` uses |
| Open | Build on Blizzard's guild recipe API (post-launch, [#35]) |
| Open | Q9: keep the five Classic TOCs and `Data/` ([#140]) |

---

## Finding index (fork review, 2026-09-28)

Open findings link their issue; done ones name what closed them.

| ID | Finding | Issue |
|---|---|---|
| F1 | Empty SavedVariables wipe your recipes on every peer | Done: `fd788e6`, `f0522c4`; H11 [#14], PR #69 |
| F2 | `GetProfessions` read as five slots | Not a bug on Forever: prof1, prof2, First Aid, Fishing, Cooking (`PROF` probe) |
| F3 | First Aid not tracked | [#122] |
| F4 | `!gc` echo abuse | Done: PR #90 ([#17]) |
| F5 | Guild views scanned as your own | Done: PR #85 ([#13]) |
| F6 | Sync whispers strip the realm | Done on Forever: `9faf497` |
| F7 | RESUME duplicates transfers | [#112] |
| F8 | DR silent after a higher term | Done: PR #96 ([#15]) |
| F9 | Tooltip debounce never debounces | Done: PR #68 ([#19]) |
| F10 | Tooltip writes the global `_` | Done: PR #41 ([#19]) |
| F11 | Scan retries uncapped | [#129]; retry cap done in PR #76 |
| F12 | Categories lost (`categoryName`) | Done: PR #89 ([#18]) |
| F13 | Election watchdog resets on every recompute | Done: PR #96 ([#15]) |
| F14 | `/gc reset` calls `ReloadUI()` | Done: PR #88 ([#10]) |
| F15 | Fuzzy search keeps `y` | [#33] |
| F16 | `IsSpellKnown` checked before `C_SpellBook` | Done: PR #89 ([#18]) |
| F17 | Identity split on Forever | Done: `9faf497` |
| F18 | ChatThrottleLib v31 taint | [#28]; library at v32 in `a1c0554` |
| F19 | Empty read purges every profession | Done: `fd788e6`, `f0522c4`, PR #43 ([#12]) |
| F20 | Whisper button breaks two-word names | [#121]; code done in PR #79 |
| F21 | Empty profession name stops the scan | Done: PR #89 ([#18]) |
| C1 | First Aid and Fishing untracked; JC/Inscription rows | [#122]; JC/Inscription gated in `c16b09f` |
| C2 | Gathering recipes hidden | [#123] |
| C3 | TBC specialisation table | [#124] |
| C4 | No cooldowns from the modern scan | [#30] |
| C5 | Every recipe tagged Vanilla | [#31] |
| C6 | Recipe sources empty | [#32]; "known by" is G1 [#60] |

## Finding index (CurseForge comment audit, 2026-10-03)

Evidence and line numbers (at `60c6b32`) are in
[`spec/curseforge-audit.md`](curseforge-audit.md); the audit row is in brackets.

| ID | Finding | Issue |
|---|---|---|
| F22 | `!gc` fallback delays collide: whole-second jitter, fixed 5 s BDR [R1, R2] | [#119] |
| F23 | `!gc` cooldown is stamped only on the client that posted [R7] | [#120] |
| F24 | `GC_ACK` goes out before the post; a failed post silences every responder [R8] | Done: PR #90 ([#17]) |
| F25 | Shift-click link and `[W]` call `ChatEdit_InsertLink`/`ChatFrame_OpenChat` unguarded [U6] | [#121]; code done in PR #79 |
| F26 | Messages from a sender whose name doesn't resolve are dropped silently [R5, D2] | Done: PR #94; cold start [#7] |
| F27 | `RegisterAddonMessagePrefix` result unchecked; a client that can't receive can be elected DR [D1] | [#113] |
| F28 | Any `HEARTBEAT` refreshes the DR watchdog, so a second DR keeps a dead one alive [D6, E1] | Done: PR #96 ([#15]) |
| F29 | A paused DR drains its whole sync queue in one frame [P2] | Done: PR #95 ([#44]) |
| F30 | Each login makes every online client send a full-vector `SYNC_REQUEST` [P4] | [#125] |
| F31 | Every zone change sends `HELLO` plus a `SYNC_REQUEST`, with no pending-sync guard [P5] | [#126] |
| F32 | Every `TRADE_SKILL_LIST_UPDATE` runs a full profession scan [P6] | [#130] |
| F33 | Two roster passes per `GUILD_ROSTER_UPDATE`; `UI:Refresh` on every delta [P7, P8] | [#127] |
| F34 | Send failures other than throttling are dropped silently [D5] | [#11]; logging and a counter done in PR #76 |
| F35 | `PruneRoster` trusts any roster with two rows [L2, L3] | Not reproduced: GRO 2026-10-04; H3 [#6] closed as rejected |
| F36 | The 45-day prune writes no tombstone [L4] | [#114] |
| F37 | `!gc` misses `\|Hspell:` links and item-producing recipe links [`!gc` (c), U6] | [#36] |
| F38 | Login reminder repeats every login [L5] | [#36] |
| F39 | Row click expands reagents only on the +/- glyph [U3] | [#36] |
| F40 | The newer-version warning prints a raw GUID [D3] | [#37] |

## Finding index (code review, 2026-10-07)

Evidence and line numbers (at `ab56976`) are in
[`spec/code-review-2026-10-07.md`](code-review-2026-10-07.md).

| ID | Finding | Issue |
|---|---|---|
| F41 | The multi-client simulator lives in `test-forever-identity.lua`, where wave-1 work won't find it | [#138] |
| F42 | `currentTerm` is a per-node counter nodes never vote on; caused F8 | [#139] |
| F43 | `Data.lua`/`Comms.lua` grew about 25% over upstream; election, merge and scan are mixed | [#37] |
| F44 | Five unpublished flavors kept in the repo | Question Q9 [#140]; the status quo stands (decisions log 2026-10-02) |
| F45 | Docs need upkeep out of proportion to the addon; some are already historical | [#22] |
| F46 | Inherited comments narrate upstream patch history | [#37]; rule for touched functions in `CLAUDE.md` |

## What this plan deliberately doesn't do

- No new features before Phase 3. The fork's job during the beta is to be trustworthy.
- No changes to the other five flavors' TOCs or data, ever, and nothing published for them.
- No testing beyond the guild during the beta. The guild is the test bed; the public gets the
  launch build.

[#3]: https://github.com/lxhwes/GuildCrafts-Forever/pull/3
[#4]: https://github.com/lxhwes/GuildCrafts-Forever/issues/4
[#5]: https://github.com/lxhwes/GuildCrafts-Forever/issues/5
[#6]: https://github.com/lxhwes/GuildCrafts-Forever/issues/6
[#7]: https://github.com/lxhwes/GuildCrafts-Forever/issues/7
[#8]: https://github.com/lxhwes/GuildCrafts-Forever/issues/8
[#9]: https://github.com/lxhwes/GuildCrafts-Forever/issues/9
[#10]: https://github.com/lxhwes/GuildCrafts-Forever/issues/10
[#11]: https://github.com/lxhwes/GuildCrafts-Forever/issues/11
[#12]: https://github.com/lxhwes/GuildCrafts-Forever/issues/12
[#13]: https://github.com/lxhwes/GuildCrafts-Forever/issues/13
[#14]: https://github.com/lxhwes/GuildCrafts-Forever/issues/14
[#15]: https://github.com/lxhwes/GuildCrafts-Forever/issues/15
[#16]: https://github.com/lxhwes/GuildCrafts-Forever/issues/16
[#17]: https://github.com/lxhwes/GuildCrafts-Forever/issues/17
[#18]: https://github.com/lxhwes/GuildCrafts-Forever/issues/18
[#19]: https://github.com/lxhwes/GuildCrafts-Forever/issues/19
[#20]: https://github.com/lxhwes/GuildCrafts-Forever/issues/20
[#21]: https://github.com/lxhwes/GuildCrafts-Forever/issues/21
[#22]: https://github.com/lxhwes/GuildCrafts-Forever/issues/22
[#23]: https://github.com/lxhwes/GuildCrafts-Forever/issues/23
[#24]: https://github.com/lxhwes/GuildCrafts-Forever/issues/24
[#25]: https://github.com/lxhwes/GuildCrafts-Forever/issues/25
[#26]: https://github.com/lxhwes/GuildCrafts-Forever/issues/26
[#27]: https://github.com/lxhwes/GuildCrafts-Forever/issues/27
[#28]: https://github.com/lxhwes/GuildCrafts-Forever/issues/28
[#29]: https://github.com/lxhwes/GuildCrafts-Forever/issues/29
[#30]: https://github.com/lxhwes/GuildCrafts-Forever/issues/30
[#31]: https://github.com/lxhwes/GuildCrafts-Forever/issues/31
[#32]: https://github.com/lxhwes/GuildCrafts-Forever/issues/32
[#33]: https://github.com/lxhwes/GuildCrafts-Forever/issues/33
[#34]: https://github.com/lxhwes/GuildCrafts-Forever/issues/34
[#35]: https://github.com/lxhwes/GuildCrafts-Forever/issues/35
[#36]: https://github.com/lxhwes/GuildCrafts-Forever/issues/36
[#37]: https://github.com/lxhwes/GuildCrafts-Forever/issues/37
[#38]: https://github.com/lxhwes/GuildCrafts-Forever/issues/38
[#39]: https://github.com/lxhwes/GuildCrafts-Forever/issues/39
[#44]: https://github.com/lxhwes/GuildCrafts-Forever/issues/44
[#45]: https://github.com/lxhwes/GuildCrafts-Forever/issues/45
[#51]: https://github.com/lxhwes/GuildCrafts-Forever/issues/51
[#52]: https://github.com/lxhwes/GuildCrafts-Forever/issues/52
[#53]: https://github.com/lxhwes/GuildCrafts-Forever/issues/53
[#54]: https://github.com/lxhwes/GuildCrafts-Forever/issues/54
[#55]: https://github.com/lxhwes/GuildCrafts-Forever/issues/55
[#56]: https://github.com/lxhwes/GuildCrafts-Forever/issues/56
[#57]: https://github.com/lxhwes/GuildCrafts-Forever/issues/57
[#58]: https://github.com/lxhwes/GuildCrafts-Forever/issues/58
[#59]: https://github.com/lxhwes/GuildCrafts-Forever/issues/59
[#60]: https://github.com/lxhwes/GuildCrafts-Forever/issues/60
[#61]: https://github.com/lxhwes/GuildCrafts-Forever/issues/61
[#62]: https://github.com/lxhwes/GuildCrafts-Forever/issues/62
[#63]: https://github.com/lxhwes/GuildCrafts-Forever/issues/63
[#64]: https://github.com/lxhwes/GuildCrafts-Forever/issues/64
[#65]: https://github.com/lxhwes/GuildCrafts-Forever/issues/65
[#66]: https://github.com/lxhwes/GuildCrafts-Forever/issues/66
[#80]: https://github.com/lxhwes/GuildCrafts-Forever/issues/80
[#98]: https://github.com/lxhwes/GuildCrafts-Forever/issues/98
[#104]: https://github.com/lxhwes/GuildCrafts-Forever/issues/104
[#105]: https://github.com/lxhwes/GuildCrafts-Forever/issues/105
[#106]: https://github.com/lxhwes/GuildCrafts-Forever/issues/106
[#112]: https://github.com/lxhwes/GuildCrafts-Forever/issues/112
[#113]: https://github.com/lxhwes/GuildCrafts-Forever/issues/113
[#114]: https://github.com/lxhwes/GuildCrafts-Forever/issues/114
[#115]: https://github.com/lxhwes/GuildCrafts-Forever/issues/115
[#116]: https://github.com/lxhwes/GuildCrafts-Forever/issues/116
[#117]: https://github.com/lxhwes/GuildCrafts-Forever/issues/117
[#118]: https://github.com/lxhwes/GuildCrafts-Forever/issues/118
[#119]: https://github.com/lxhwes/GuildCrafts-Forever/issues/119
[#120]: https://github.com/lxhwes/GuildCrafts-Forever/issues/120
[#121]: https://github.com/lxhwes/GuildCrafts-Forever/issues/121
[#122]: https://github.com/lxhwes/GuildCrafts-Forever/issues/122
[#123]: https://github.com/lxhwes/GuildCrafts-Forever/issues/123
[#124]: https://github.com/lxhwes/GuildCrafts-Forever/issues/124
[#125]: https://github.com/lxhwes/GuildCrafts-Forever/issues/125
[#126]: https://github.com/lxhwes/GuildCrafts-Forever/issues/126
[#127]: https://github.com/lxhwes/GuildCrafts-Forever/issues/127
[#128]: https://github.com/lxhwes/GuildCrafts-Forever/issues/128
[#129]: https://github.com/lxhwes/GuildCrafts-Forever/issues/129
[#130]: https://github.com/lxhwes/GuildCrafts-Forever/issues/130
[#131]: https://github.com/lxhwes/GuildCrafts-Forever/issues/131
[#132]: https://github.com/lxhwes/GuildCrafts-Forever/issues/132
[#133]: https://github.com/lxhwes/GuildCrafts-Forever/issues/133
[#134]: https://github.com/lxhwes/GuildCrafts-Forever/issues/134
[#135]: https://github.com/lxhwes/GuildCrafts-Forever/issues/135
[#138]: https://github.com/lxhwes/GuildCrafts-Forever/issues/138
[#139]: https://github.com/lxhwes/GuildCrafts-Forever/issues/139
[#140]: https://github.com/lxhwes/GuildCrafts-Forever/issues/140
