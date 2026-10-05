# GuildCrafts Forever — beta plan

Written 2026-10-03 against `main` at `8f0dc69`. It merges Alex's beta plan with:
- every item still open in `spec/migration-forever.md`;
- the 2026-09-28 fork review ([`spec/fork-review.md`](fork-review.md), finding IDs F1–F21 and
  C1–C6, indexed at the end);
- the legacynext reuse review (kept local);
- the open items from the 2026-10-02/03 sessions;
- Alex's documentation review (`spec/documentation-refresh-plan.md`, kept local), as D1;
- the CurseForge comment audit ([`spec/curseforge-audit.md`](curseforge-audit.md), 2026-10-03,
  finding IDs F22–F40, indexed at the end).

Work items live in [GitHub Issues](https://github.com/lxhwes/GuildCrafts-Forever/issues), one per
plan ID, each with its why, how and done-when. This file keeps the phases, their gates, the
ID-to-issue index and the decisions log. `spec/migration-forever.md` is the record of what was
decided and verified.

Planning targets: beta ends **Oct 21**, launch **Nov 4**, raids **Dec 9**. This plan cites no
source for these dates. Confirm them against Blizzard's announcements before anything depends on
them.

Goal, in order: get the codebase into the best shape it can be, then put it in front of the
guild. Nothing goes to guildmates until Phase 2's exit gate passes.

---

## Phase 0 — Tracking (done 2026-10-03)

- Issues [#4]–[#39] created from this plan, titled with their plan IDs. [#44] (H19) and [#45]
  (Q8) added from the CurseForge audit. [#51]–[#66] (N1–N9, G1–G7) added from the Later
  backlog.
- Labels: `blocker`, `hardening`, `testing`, `needs-ingame`, `post-launch`, and the existing
  `documentation`. The Later backlog added `feature`, `external`, `security` and `research`.
- One milestone per phase, plus Post-launch and Later.
- The `ROADMAP.md` rewrite moved to D1 cut 2 ([#22]). Until then it carries a history banner
  that points here.

- Local working notes, decided 2026-10-03: `spec/fork-review.md` is committed as a dated
  historical review, because the issues cite its finding IDs. The legacynext reuse review and
  the documentation review stay local. The first-draft `plan.md` was deleted.

---

## Phase 1 — Hardening (Oct 4–10)

[Milestone](https://github.com/lxhwes/GuildCrafts-Forever/milestone/1). Blockers go first
regardless of position.

| ID | Issue | Item | Tags |
|---|---|---|---|
| H1 | [#4] | ~~CI: luacheck and the regression suites~~ | Done: PR #41, issue closed 2026-10-04 |
| H2 | [#5] | Server time for sync revisions | `blocker`, `needs-ingame` |
| H3 | [#6] | Persist GUID → name (unverified); roster-based prune (F35) | `hardening`, `needs-ingame`; `blocker` if the GRO probe confirms F35 |
| H4 | [#7] | Sender resolution: cold start (unverified) and unresolved senders dropped (F26) | `hardening` |
| H5 | [#8] | ~~`/gc report`~~ | Done: PR #50, issue closed 2026-10-04 |
| H6 | [#9] | Scan diagnostics | `hardening` |
| H7 | [#10] | `/gc reset` and `ReloadUI()` (F14) | `hardening`, `needs-ingame` |
| H8 | [#11] | SyncPausePolicy follow-ups after Q2; silent send failures (F34) | `needs-ingame` |
| H9 | [#12] | ~~`/gc drop` after an empty read~~ | Done: PR #43, issue closed 2026-10-04 |
| H10 | [#13] | Guild views scanned as your own (F5) | `blocker`, `needs-ingame` |
| H11 | [#14] | ~~Restore your own data from peers (F1)~~ | Done: PR #69, issue closed 2026-10-04 |
| H12 | [#15] | Sync robustness (F7, F8, F13, F27, F28, F36 and three more) | `hardening` |
| H13 | [#16] | ~~Favorites write booleans to SavedVariables~~ | Done: PR #67, issue closed 2026-10-04 |
| H14 | [#17] | Chat and whisper on Forever (F4, F20, F22–F25) | `blocker` for Phase 3 |
| H15 | [#18] | Scan gate and categories (F11, F12, F16, F21, F32) | `hardening` |
| H16 | [#19] | ~~Tooltip taint and rebuilds (F9, F10)~~ | Done: F10 in PR #41, F9 in PR #68, issue closed 2026-10-04 |
| H17 | [#20] | Profession coverage (C1/F3, C2, C3) | `hardening`, needed for wave 2 |
| H18 | [#21] | Release workflow guards | `hardening`, before the first publish |
| H19 | [#44] | Sync load and frame time (F29–F31, F33), measured with M1–M4 | `hardening`; F29 before wave 1, the rest before wave 3 |
| D1 cut 1 | [#3] | Documentation refresh, cut 1 | Merged 2026-10-03 |

**Phase 1 exit gate:**
- CI green on `main`.
- Every `blocker` (H1, H2, H5, H9, H10, H14) merged. H1, H5 and H9 done (PRs #41, #50, #43).
- The rest either merged or deferred in its issue with a reason.
- H8 answered or explicitly deferred.
- The GRO and CHL probes run. If GRO confirms F35 or CHL confirms F25, that fix is merged.
- D1 cut 1 merged. Done: PR [#3].

---

## Phase 2 — First tester build (Oct 10–11)

[Milestone](https://github.com/lxhwes/GuildCrafts-Forever/milestone/2). The gates before
tagging, and the tag and check steps, are in [#23]. [`docs/releasing.md`](../docs/releasing.md)
has the commands and the order for each one.

After the tag, run the two-client checklist ([`docs/testing.md`](../docs/testing.md)) with
**one** guildmate before anyone else installs it. If they're on a different server prefix, that
also answers Q5 ([#27]).

**Phase 2 exit gate:** the two-client checklist passes end to end, including a drop on one
client while the other is offline, then reconnect.

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

[Milestone](https://github.com/lxhwes/GuildCrafts-Forever/milestone/4).

1. Fix whatever waves 2–3 surfaced. Freeze features on **Oct 28**.
2. After the freeze, do D1 cut 2 ([#22]).
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

[Milestone](https://github.com/lxhwes/GuildCrafts-Forever/milestone/5).

| ID | Issue | Item |
|---|---|---|
| C4 | [#30] | Cooldowns from the modern scan |
| C5 | [#31] | Forever recipe data from DB2s |
| C6 | [#32] | Recipe sources and "known by" |
| F15 | [#33] | Fuzzy search keeps `y` |
| — | [#34] | Compact sync encoding (protocol v4) |
| — | [#35] | Decide on Blizzard's guild recipe API |
| — | [#36] | UI/UX (fork review §3) |
| — | [#37] | Code hygiene |
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
| N1 | [#51] | `/gc export` copy frame | N2 [#52] for the opt-out filter; N1 can ship first |
| N2 | [#52] | Per-character opt-out (audit X3) | [#34] if bundled with protocol v4 |
| N3 | [#53] | Companion export block in SavedVariables | N1 [#51], N2 [#52], H3 [#6] |
| N4 | [#54] | Design: companion, web and Discord bot (ADR + threat model) | N1 [#51] schema draft |
| N5 | [#55] | Companion uploader | N3 [#53], N4 [#54], N6 [#56] |
| N6 | [#56] | Web backend: tenancy, auth and isolation | N4 [#54] |
| N7 | [#57] | Web recipe book | N6 [#56] |
| N8 | [#58] | Discord bot | N6 [#56] |
| N9 | [#59] | Spike: does Blizzard's web API cover Forever? | — |

G: in game.

| ID | Issue | Item | Depends on |
|---|---|---|---|
| G1 | [#60] | Recipe-scroll tooltip alert | An in-game probe; C5 [#31] if no API exists; H16 [#19] |
| G2 | [#61] | Coverage view: single-crafter and missing recipes | C5 [#31], for missing recipes only |
| G3 | [#62] | Reagent check in recipe detail | — |
| G4 | [#63] | Favorite crafter online alert | H19 [#44] (F33) |
| G5 | [#64] | "Recently learned" feed | H2 [#5] |
| G6 | [#65] | Raid consumables view (for Dec 9) | H15 [#18], C4 [#30] |
| G7 | [#66] | Public API for other addons | N2 [#52] |

---

## Open questions

| # | Question | Issue | Answered by |
|---|---|---|---|
| Q1 | Full client build number for the 2026-10-02/03 runs | [#24] | H5 (`GetBuildInfo()` in the report) |
| Q2 | Does `ADDON_RESTRICTION_STATE_CHANGED` fire at a boss pull? | [#25] | The `RE` probe; unblocks H8 |
| Q4 | Why the first `/gc dump` on 2026-10-02 stored nothing | [#26] | H5, H6 |
| Q5 | Sender name and whisper reach for a guildmate on another server prefix | [#27] | Phase 2 two-client run |
| Q6 | Does ChatThrottleLib v32 clear the chat taint in game? | [#28] | Wave 1 |
| Q7 | Date and channel of [@dkruenbo](https://github.com/dkruenbo)'s two messages, for `docs/ORIGIN.md` | [#29] | Alex |
| Q8 | Do GUILD addon messages reach a client inside an instance? `Comms.lua` assumes not; three upstream reports suggest they do | [#45] | The R4 probe in `spec/curseforge-audit.md`, Phase 2 two-client run |

Q3 (solo checklist) closed on 2026-10-03: items 3–9 all passed.

---

## Decisions log

| Date | Decision |
|---|---|
| 2026-10-02 | Publish the Forever flavor only, under [@dkruenbo](https://github.com/dkruenbo)'s CurseForge project 1469206. Keep the other five TOCs and `Data/` untouched in the repo |
| 2026-10-02 | Forever loads through `GuildCrafts_Camelot.toc`; `_Forever` isn't read by the client |
| 2026-10-02 | Forever members are keyed by GUID (`Modules/ForeverIdentity.lua`, Camelot TOC only) |
| 2026-10-02 | Only `/gc drop` removes a profession that holds recipes |
| 2026-10-02 | Jewelcrafting and Inscription are gated on the client's skill lines |
| 2026-10-02 | Own vendor checkout; copy legacynext's skills rather than symlinking |
| 2026-10-03 | Plain Lua 5.1 regression scripts in `tools/test-*.lua`, not busted |
| 2026-10-03 | Documentation refresh in two cuts (D1). Inherited docs get history banners in place rather than moving to an archive |
| 2026-10-03 | GitHub Issues is the tracker. This file keeps phases, gates and the ID index |
| 2026-10-03 | H1: get luacheck to zero warnings first, then CI fails on any warning |
| 2026-10-03 | Later backlog N1–N9, G1–G7 added from `spec/later-backlog.md`; N4 design gates all external services |
| 2026-10-04 | N1–N8 specs in `spec/later/`. N2 marker tombstone-shaped; protocol `VERSION` 4 with N2 (#34 becomes v5); companion block in a separate `GuildCraftsExport` SavedVariable; external stack on Cloudflare Workers Paid in a new monorepo, multi-tenant with one tenant at launch |
| Open | Build on Blizzard's guild recipe API (post-launch, [#35]) |

---

## Finding index (fork review, 2026-09-28)

Status as of `8f0dc69`.

| ID | Finding | Status |
|---|---|---|
| F1 | Empty SavedVariables wipe your recipes on every peer | Closed: peers keep them (`fd788e6`, `f0522c4`); your own empty professions refill from the DR at sync, H11 PR #69 |
| F2 | `GetProfessions` read as five slots | Closed: Forever's slots are prof1, prof2, First Aid, Fishing, Cooking (`Camelot/Blizzard_ProfessionsBook.lua:21`, `PROF` probe) |
| F3 | First Aid not tracked | Open, H17 [#20] |
| F4 | `!gc` echo abuse | Open, H14 [#17] |
| F5 | Guild views scanned as your own | Open, H10 [#13] |
| F6 | Sync whispers strip the realm | Fixed on Forever: whisper targets come from the roster (`9faf497`) |
| F7 | RESUME duplicates transfers | Open, H12 [#15] |
| F8 | DR silent after a higher term | Open, H12 [#15]. The stale DR keeps answering `!gc` (audit R4) |
| F9 | Tooltip debounce never debounces | Closed: one rebuild per sync burst and one in-combat retry, H16 PR #68 |
| F10 | Tooltip writes the global `_` | Closed: fixed by H1's zero-warning pass (PR #41) |
| F11 | Scan retries uncapped | Open, H15 [#18] |
| F12 | Categories lost (`categoryName`) | Open, H15 [#18] |
| F13 | Election watchdog resets on every recompute | Open, H12 [#15] |
| F14 | `/gc reset` calls `ReloadUI()` | Open, H7 [#10] |
| F15 | Fuzzy search keeps `y` | Post-launch [#33] |
| F16 | `IsSpellKnown` checked before `C_SpellBook` | Open, H15 [#18] |
| F17 | Identity split on Forever | Fixed (`9faf497`) |
| F18 | ChatThrottleLib v31 taint | Library updated to v32 (`a1c0554`); not yet checked in game, Q6 [#28] |
| F19 | Empty read purges every profession | Fixed (`fd788e6`, `f0522c4`); the last hole, H9 [#12], fixed by PR #43 |
| F20 | Whisper button breaks two-word names | Open, H14 [#17] |
| F21 | Empty profession name stops the scan | Open, H15 [#18] |
| C1 | First Aid and Fishing untracked; JC/Inscription rows | JC/Inscription gated (`c16b09f`); First Aid and Fishing open, H17 [#20] |
| C2 | Gathering recipes hidden | Open, H17 [#20]. `TradeSkillRecipeInfo.isGatheringRecipe` exists at the pin (audit X6) |
| C3 | TBC specialisation table | Open, H17 [#20]. The table hard-codes spell IDs, against the project rule; decide whether it's an accepted exception (audit X5) |
| C4 | No cooldowns from the modern scan | Post-launch [#30] |
| C5 | Every recipe tagged Vanilla | Post-launch [#31] |
| C6 | Recipe sources empty | Post-launch [#32] |

## Finding index (CurseForge comment audit, 2026-10-03)

Evidence and line numbers (at `60c6b32`) are in
[`spec/curseforge-audit.md`](curseforge-audit.md); the audit row is in brackets.

| ID | Finding | Status |
|---|---|---|
| F22 | `!gc` fallback delays collide: whole-second jitter, fixed 5 s BDR [R1, R2] | Open, H14 [#17] |
| F23 | `!gc` cooldown is stamped only on the client that posted [R7] | Open, H14 [#17] |
| F24 | `GC_ACK` goes out before the post; a failed post silences every responder [R8] | Open, H14 [#17] |
| F25 | Shift-click link and `[W]` call `ChatEdit_InsertLink`/`ChatFrame_OpenChat` unguarded; Forever's UI uses `ChatFrameUtil` [U6] | Open, H14 [#17]; CHL probe |
| F26 | Messages from a sender whose name doesn't resolve are dropped silently, though the payload carries a GUID [R5, D2] | Open, H4 [#7] |
| F27 | `RegisterAddonMessagePrefix` result unchecked; a client that can't receive can still be elected DR [D1] | Open, H12 [#15] |
| F28 | Any `HEARTBEAT` refreshes the DR watchdog, so a second DR keeps a dead one alive [D6, E1] | Open, H12 [#15] |
| F29 | A paused DR drains its whole sync queue in one frame and discards the work [P2] | Open, H19 [#44] |
| F30 | Each login makes every online client send a full-vector `SYNC_REQUEST` [P4] | Open, H19 [#44] |
| F31 | Every zone change sends `HELLO` plus a `SYNC_REQUEST`, with no pending-sync guard [P5] | Open, H19 [#44] |
| F32 | Every `TRADE_SKILL_LIST_UPDATE` runs a full profession scan [P6] | Open, H15 [#18] |
| F33 | Two roster passes per `GUILD_ROSTER_UPDATE`; `UI:Refresh` on every delta with no debounce [P7, P8] | Open, H19 [#44]; measure (M2) before fixing |
| F34 | Send failures other than throttling are dropped silently, `HELLO` included [D5] | Open, H8 [#11]; logging in H6 [#9] |
| F35 | `PruneRoster` trusts any roster with two rows; an online-only roster would tombstone members offline 7+ days [L2, L3] | Open, H3 [#6]; GRO probe |
| F36 | The 45-day prune writes no tombstone, and ex-members revive after tombstone expiry [L4] | Open, H12 [#15] |
| F37 | `!gc` misses `\|Hspell:` links and recipe links for item-producing recipes [`!gc` (c), U6] | Post-launch [#36] |
| F38 | Login reminder repeats every login and nags when a profession can't store recipes [L5] | Post-launch [#36] |
| F39 | Row click expands reagents only on the +/- glyph [U3] | Post-launch [#36] |
| F40 | The newer-version warning prints a raw GUID [D3] | Post-launch [#37] |

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
