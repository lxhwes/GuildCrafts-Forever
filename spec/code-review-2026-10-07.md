# GuildCrafts Forever — code review follow-ups (2026-10-07)

Written 2026-10-07 against `main` at `dc89970`. It folds six findings from an outside read of the
fork into `spec/forever-plan.md`. It defines finding IDs **F41–F46**, plan IDs **H25** and
**H26**, and open question **Q9**. No other file uses these IDs yet.

Most of this is placement and scoping, not new code. Two findings conflict with recorded
decisions. They're marked, and they wait on Alex.

---

## Instructions for Claude Code

Read `CLAUDE.md` first. Its rules win over anything here, especially: never touch the five
Classic TOCs or `Data/Data_*.lua`, and never commit, push, open a PR, or create issues without
Alex's explicit instruction.

1. **Check each finding against `main`** before acting. Line numbers here are at `dc89970`. If a
   finding is already fixed or wrong, say so and drop it. Don't force it into the plan.
2. **Draft, don't create.** For H25 and H26, draft issue bodies in the existing format (title
   `<ID>: <title>`, plan-link header, **Findings**, **Done when** checklist; copy #15 or #104).
   For F43–F46, draft comments for the existing issues named below. Show Alex all drafts in one
   message. Create or post only the ones he approves.
3. **Edit `spec/forever-plan.md`** on a `docs/plan-review-2026-10-07` branch, once the issues
   exist:
   - Add the H25 and H26 rows to the Phase 3 table, after H23.
   - Add Q9 to Open questions.
   - Add the decisions-log rows from §3 that Alex confirms. Leave unconfirmed ones as `Open`.
   - Add a "Finding index (code review, 2026-10-07)" section after the CurseForge index, using
     the table in §4.
   - Add a sentence to the opening list citing this file, the same way it cites
     `spec/curseforge-audit.md`.
4. **Commit this file** as `spec/code-review-2026-10-07.md` in the same branch. It's the source
   for F41–F46, like `spec/fork-review.md` is for F1–F21.
5. Stop and wait for Alex before opening the PR.

Doc-only work, so no Codex review is needed (`CLAUDE.md`, "Codex review").

---

## 1. Findings

### F41: the multi-client simulator is buried in the identity suite → H25

**What's there.** `tools/test-forever-identity.lua` (~L527–1080) has a working multi-client
simulator, `Sim`. It gives each node its own `Data`, `ForeverIdentity` and `Comms`, sends
messages through the real `SendMessage` and `OnCommReceived`, runs timers on a shared clock,
and supports `partition`, `logoff` and `flush`. It covers F8, F13, F28, DR handoff, and five
H22 delta cases.

**Problem.** It's a fixture inside an identity test file. Wave 1's riskiest work (the joint
returning-DR fix in #15/#44, BDR eviction, paused deltas, F7, F27, F36) all needs this
simulator. Someone writing those fixes won't look for it in `test-forever-identity.lua`, and a
second copy is the likely result.

**How.**
- Move `Sim` and its helpers (`copy`, `newSim`, `Sim:*`, `assertAgreed`, the shared
  `test`/`check` runner if needed) to `tools/lib/sim.lua`, loaded with `dofile`. Plain Lua 5.1,
  per the 2026-10-03 decision; no busted.
- Move the election and delta scenarios to `tools/test-election.lua` (election F8/F13/F28 and
  handoff) and `tools/test-delta-sync.lua` (delta H22). Identity tests stay where they are.
- Add both new suites to `.github/workflows/ci.yml`, the Verification block in `CLAUDE.md`, and
  `docs/testing.md`.
- Add **known-gap** scenarios for wave 1, written to pass against current behaviour and named
  for the issue they pin: returning DR after a partition longer than `HEARTBEAT_TIMEOUT`, BDR
  eviction, a delta sent while the DR is paused, a RESUME duplicate (F7), and a deaf client
  elected DR (F27). Each one says in a comment what the fix should change. These become the
  regression tests when the fixes land.

**Scope.** `tools/`, CI and docs only. No addon code changes.

**Done when.**
- [ ] The test count across the suites is unchanged after the move (same scenarios, new files).
- [ ] `test-forever-identity.lua` no longer defines `Sim`.
- [ ] CI runs `test-election.lua` and `test-delta-sync.lua`.
- [ ] One known-gap scenario per wave-1 sync item listed above.

**Placement.** Phase 3, wave 1, `testing`. It lands before the joint returning-DR fix. It's
tools-only, so it can also land in the Phase 2 window without affecting the tag.

### F42: `currentTerm` adds state without proving authority → H26

**What's there.** The DR is a pure function of `addonUsers`: the lowest key in sort order.
`currentTerm` is a per-node counter that goes up when that node promotes itself. Nodes never
vote on it. Any higher term from any message is adopted (`Comms.lua` ~L1858), and stale
`HEARTBEAT` and `SYNC_RESPONSE` are dropped (~L468, ~L964). F8 was a bug caused by terms, fixed
in PR #96 by recomputing after the handler (`steppedDown`, ~L1917).

**Question.** Does the term catch any case that membership agreement doesn't? If not, it's
something to maintain that can only cause F8-style bugs.

**How (investigate first, then decide).**
1. After H25, add a test switch that disables term adoption and the stale-term drops. Run every
   election and delta scenario with it on. Don't ship the switch.
2. If they all pass, terms do nothing those scenarios can see. Write the scenario that would
   need a term (a partitioned stale DR whose heartbeat arrives late?) and check whether
   membership plus `HEARTBEAT_TIMEOUT` already handles it.
3. Record the result on the issue, then pick one:
   - **Remove terms.** Stop sending `term` and stop reading it. This is wire-compatible with
     builds that send it: they guard on `type(envelope.term) == "number"`, and a missing term
     skips both the adoption and the drop. No `VERSION` bump, but check that claim against
     `ProcessIncoming` before relying on it.
   - **Keep terms.** Write down the case they cover in the `CLAUDE.md` Architecture section,
     with the scenario that proves it.

**Interaction.** The returning-DR fix (#15/#44, decided 2026-10-06) is exactly where terms
matter: a returning DR may be on an old term while the network moved on. Decide H26 before
designing that fix, or as its first step. Don't design the fix around terms and then remove
them.

**Done when.**
- [ ] The investigation result is recorded on the issue, with the scenarios run.
- [ ] Remove or keep is decided and logged in the plan's decisions log.
- [ ] If removed: the code is gone, the election and delta suites pass, the two-client
      checklist passes in game, and the `CLAUDE.md` Architecture section is updated.

**Placement.** Phase 3, wave 1, `hardening`, `needs-ingame`. Gated on H25.

### F43: `Data.lua` and `Comms.lua` keep growing → #37 (Code hygiene)

**What's there.** `Data.lua` 2941 lines (upstream 2354), `Comms.lua` 1993 (upstream 1572),
`MainFrame.lua` 3043. `Data.lua` does scanning, storage, migrations, merging, pruning and
search. `Comms.lua` mixes the election with sync transport.

**Constraint (read before splitting).** The five Classic TOCs list `Modules\Data.lua` and
`Modules\Comms.lua` and may not be edited. A new file added only to `GuildCrafts_Camelot.toc`
leaves Classic loading a `Comms.lua` without its election code. Three options:
- Forever-only overlay modules that replace functions after load, the pattern
  `ForeverIdentity.lua` uses. Classic keeps its copy.
- Accept that the Classic TOCs no longer load cleanly. This needs Q9 settled first.
- Don't split; extract internal sections instead (locals, section banners, a table of contents
  at the top).

**How.** Not during the beta. Comment on #37 with the split candidates (merge and prune out of
`Data.lua`; election, heartbeat and watchdog out of `Comms.lua`), the TOC constraint, and the
three options. Pick one when #37 starts, after the Oct 28 freeze.

**Placement.** Post-launch, #37. H25 needs no addon split, because the simulator loads whole
modules.

### F44: the repo carries five flavors it doesn't publish → Q9 (decision for Alex)

**What's there.** The five Classic TOCs and `Data/` stay in the repo. `.pkgmeta` `ignore` and
`release.yml` remove them before packaging.

**Conflict.** This was decided on 2026-10-02 ("Keep the other five TOCs and `Data/` untouched
in the repo"), and `CLAUDE.md` makes it a rule. The review recommended deleting them without
knowing that. **Don't act on F44.** It's raised as a question.

**Q9: Should the fork keep the five Classic TOCs and `Data/`?**
- *Keep (status quo).* Matches the permission terms in `docs/ORIGIN.md` and the decisions log,
  and keeps the repo comparable with upstream. Costs: the `.pkgmeta`/`release.yml` stripping,
  the planned `safe-commit` hard-fail, the "Classic is unaffected" tests, and the F43 split
  constraint.
- *Delete.* Removes those costs. But the repo stops being a superset of upstream, and it needs a
  check of whether `docs/ORIGIN.md`'s terms say anything about it.

Answered by Alex. Suggested timing: when #37 starts, because that's when the cost of keeping
them becomes concrete. Until then the status quo stands.

### F45: documentation volume → D1 cut 2 (#22)

**What's there.** About 5k lines across `spec/` and `docs/`, a 264-line `CLAUDE.md`, and about
9.8k lines of addon Lua. `spec/fork-review.md` is already bannered historical. Six upstream
specs (`implementation-plan*.md`, `improvements.md`, `tech-stack.md`, `migration-{classic-era,
wotlk,mop}.md`) are bannered in place.

**Constraint.** The 2026-10-03 decision says inherited docs get history banners in place rather
than moving to an archive. This finding doesn't override that.

**How.** Comment on #22 with criteria for cut 2, inside the 10-03 decision:
- `CLAUDE.md`: move reference material an agent doesn't need every session (the Codex review
  procedure, gist rules, Forever tooling detail) into `docs/` and link it. Keep rules, the docs
  map, versions, and verification.
- Dated reviews (`fork-review.md`, `curseforge-audit.md`, this file): once every finding in a
  review is closed or moved to an issue, a history banner is enough. No upkeep.
- `spec/forever-plan.md`: after launch, collapse the finished phase tables to one line each,
  linking the closed milestone.
- If moving bannered upstream docs to `spec/upstream/` still seems worth it after that, propose
  reversing the 10-03 decision separately.

**Placement.** Phase 4, after the freeze, inside D1 cut 2. No doc trimming during the beta.

### F46: comments narrate upstream's patch history → #37, plus a rule for now

**What's there.** Inherited comments cite upstream patch numbers and versions ("Patch 3",
"1.1.7+", "false-DR") instead of saying what the code does. New code in the fork doesn't do
this.

**How.**
- From now on: when a PR changes a function, rewrite that function's upstream-history comments
  to describe current behaviour. Fork plan IDs (H22, F8) are fine, since they link to issues.
  No comment-only PRs during the beta.
- Post-launch: one sweep under #37, done before or with the F43 split so comments move once.
- Add a one-line rule for this to `CLAUDE.md`, but only with Alex's OK.

**Placement.** The rule takes effect now (on Alex's OK). The sweep is post-launch, #37.

---

## 2. Proposed plan rows

Phase 3 table, after H23:

| ID | Issue | Item | Tags |
|---|---|---|---|
| H25 | [#TBD] | Simulator in its own module; election and delta suites; wave-1 known-gap scenarios (F41) | `testing`. Tools only. Lands before the wave-1 joint returning-DR fix |
| H26 | [#TBD] | Do DR terms earn their keep? Investigate with the H25 simulator, then remove or document (F42) | `hardening`, `needs-ingame`. Gated on H25; decided before the returning-DR fix is designed |

Open questions:

| # | Question | Issue | Answered by |
|---|---|---|---|
| Q9 | Keep the five Classic TOCs and `Data/` in the fork? (F44) | — | Alex, when #37 starts |

Post-launch table: no new rows. Add "(F43, F46)" to #37's Item cell.

Phase 4 step 2: append "(scope includes F45)".

## 3. Proposed decisions-log rows

| Date | Decision |
|---|---|
| 2026-10-07 | The multi-client `Sim` moves out of `test-forever-identity.lua` into `tools/lib/sim.lua`, with election and delta suites of their own (H25). Wave-1 sync fixes start as known-gap scenarios there |
| 2026-10-07 | H26 is decided before the returning-DR fix (#15/#44) is designed |
| 2026-10-07 | F43 (module split) and F46 (comment sweep) go to #37 post-launch. Any split must respect the untouched Classic TOCs, or wait for Q9 |
| 2026-10-07 | F45 is in scope for D1 cut 2 and stays within the 2026-10-03 history-banner decision |
| Open | Q9: keep the five Classic TOCs and `Data/` |

## 4. Finding index (code review, 2026-10-07)

| ID | Finding | Status |
|---|---|---|
| F41 | The multi-client simulator lives in `test-forever-identity.lua`, where wave-1 work won't find it | Open, H25 |
| F42 | `currentTerm` is a per-node counter nodes never vote on; caused F8 | Open, H26 |
| F43 | `Data.lua`/`Comms.lua` grew 25%; election, merge and scan are mixed | Post-launch, #37 |
| F44 | Five unpublished flavors kept in the repo | Question Q9; the status quo stands (decision 2026-10-02) |
| F45 | Docs about half the size of the addon code; some already historical | D1 cut 2, #22 |
| F46 | Inherited comments narrate upstream patch history | Rule for touched functions now; sweep in #37 |

## 5. Out of scope

- **Validating the shape of incoming data.** The review saw `HasFutureStamp` and more `type()`
  checks in `MergeIncoming`, but recipe tables still aren't checked for the right structure.
  Not one of the six. If wanted, it's a separate `hardening` item for wave 1 or 2. Start by
  listing every path where network data reaches storage or the UI without a check (sync
  response and push, delta, `ExtractToRecipeDB`, tooltip index).
- No new features and no addon code changes before Phase 3, per the plan. H25 changes only
  `tools/`, CI and docs.

---

## 6. Checked at `ab56976` (2026-10-07)

Every finding was checked against `main` at `ab56976` before the issues were created. None was
dropped. The addon code and `tools/test-forever-identity.lua` are unchanged from `dc89970`
(`git diff --stat dc89970 ab56976`), so the Lua line numbers above hold. Corrections:

- **Issues.** H25 is [#138], H26 [#139], Q9 [#140]. F43 and F46 went into #37's body, F45 into
  #22's body, rather than comments, so the `track` skill can tick them.
- **Plan layout.** #136 split Phase 3 into per-wave tables with `ID | Issue | Scope` columns.
  H25 and H26 are rows in the Wave 1 table. Open questions use an `Answered in` column and the
  finding indexes an `Issue` column.
- **Wave-1 targets.** The joint returning-DR fix is H12.3 (#117) under #15, not "#15/#44". BDR
  eviction is H12.1 (#115) and paused deltas H12.2 (#116). The known-gap scenarios pin #117,
  #115, #116, #112 (F7) and #113 (F27). F36 (#114) has no known-gap scenario.
- **F41.** The simulator section starts at L529 (`Sim` itself at L544) and carries 15 scenarios:
  10 election, 5 delta.
- **F42.** The wire-compatibility claim holds on reading, not yet on test: `ProcessIncoming`
  copies `envelope.term` into `payload.term` (`Comms.lua:1851`), adoption needs a number
  (`:1858`), and both drops guard on `payload.term and` (`:468`, `:964`).
- **F44.** `docs/ORIGIN.md`'s Scope section says the Classic TOCs and `Data/` "are kept as
  upstream shipped them". Deleting them means rewriting that section.
- **F45.** `CLAUDE.md` was 286 lines at `ab56976`, not 264. The tracked `spec/*.md` plus
  `docs/*.md` is 6239 lines, not about 5k (7587 with `spec/later/`), against 9769 lines of addon
  Lua.
- **F46.** Five comments match: `Core.lua:444`, `Comms.lua:321`, `:398`, `:1032`, `Data.lua:683`.
  The sweep is small. Alex approved the `CLAUDE.md` rule on 2026-10-07.
- **Decisions.** Alex confirmed all four 2026-10-07 rows in §3. The second reads "before H12.3
  (#117)" in the plan.

[#138]: https://github.com/lxhwes/GuildCrafts-Forever/issues/138
[#139]: https://github.com/lxhwes/GuildCrafts-Forever/issues/139
[#140]: https://github.com/lxhwes/GuildCrafts-Forever/issues/140
