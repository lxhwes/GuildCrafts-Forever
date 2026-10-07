# Tracking cleanup and automation: session prompt

Written 2026-10-07. Paste everything below the rule into a new Claude Code session to run it.

---

Tidy up GuildCrafts-Forever's planning and issue tracking so status lives in one place and progress is easy to follow. This came out of a review on 2026-10-07 against `main` at `dc89970`. Things may have moved since then, so re-check each finding against the live issues and `spec/forever-plan.md` before acting on it, and skip anything already fixed.

**The goal behind every item:** I steer the work sessions. Keeping the tracking current should happen on its own, accurately, without me doing bookkeeping or remembering to ask for it. So:
- **Prefer deterministic automation.** A GitHub Action or script that reads structured data (a PR's Tracking section, a merge event, a checklist) beats a convention someone has to remember. Where judgement is needed, put the routine in a project skill or hook so Claude runs it every time, not only when asked.
- **Accuracy over coverage.** Automation acts only on unambiguous, structured evidence. When the evidence is ambiguous, it flags the item and asks; it never guesses. A wrong tick or close is worse than a missing one.
- **Visible, not noisy.** Every automated change leaves a one-line trail (an issue comment or a commit) saying what changed and why. Drift is reported in one place, not as a stream of comments.

Ground rules:
- Follow `CLAUDE.md`. Use the GitHub MCP tools, or `gh` with the sandbox disabled.
- **This one-time cleanup:** show me the full list of GitHub changes before making any (reopening, retitling or relabelling issues, creating labels or sub-issues, editing issue bodies), then make them in one pass after a single approval. The automation built in item 8 then keeps things current without asking, within the limits above.
- Repo file changes go on one `docs/tracking-cleanup` branch. Commit and open a draft PR only when I say so.
- Don't touch the release itself. We already have CurseForge upload rights and are holding the tester build on purpose.

## 1. Reopen #15, and stop it happening again

#15 (H12, sync robustness) closed as "completed" at 2026-10-07 00:27:06 UTC, three seconds after #109 merged. #109's description says "Decide to fix #15's returning DR…", and GitHub reads "Fix #15" as an instruction to close the issue. #15 still holds the wave-1 work: F7, F27, F36, BDR eviction, paused deltas, the returning DR, and the merge-guard and paused-delta notes in its 2026-10-05/06 comments.

- Reopen #15 (state reason: reopened) and confirm it's still in the Phase 3 milestone. Add one comment saying why it was reopened.
- Search the other closed issues for the same accident: compare each closing PR's body with the issue's remaining Done-when items.
- Add `.github/pull_request_template.md`. It should cover: a Summary; tests run; Codex review status (rebutted findings, one line each, as `CLAUDE.md` asks); `Closes #N` only when the PR finishes the whole issue, otherwise `Refs #N` / `Part of #N`, never "fix/close/resolve #N" in prose; and a checkbox that the plan row and the issue checklist are updated.
- Add the same rule to `CLAUDE.md` under Git Workflow.
- Optional: a CI step that fails when a PR body has a closing keyword next to an issue number and the PR isn't labelled as finishing it. Only add it if it stays small; otherwise propose it.

## 2. One place for status

The plan says status lives in the issues, but its tables carry status text too, and the two have drifted:
- **#44 (H19):** the F29 checkbox and its Done-when line are unticked, though PR #95 fixed F29.
- **#17:** titled "H14: Whisper and !gc on Forever (F4, F20, SendChatMessage)"; the plan row says "Chat and whisper on Forever (F4, F20, F22–F25)".
- **#18:** titled "H15: Scan gate and categories (F11, F12, F16, F21)"; the plan row adds F32.
- **F32:** the plan contradicts itself. H15's row says "F11's event rework and F32 move to H19", but the finding index says "Open, H15 [#18]" and the wave-3 list says "H15's F11 event rework and F32". Work out where F32 actually belongs from the issue comments, and make every mention agree.
- **`hardening` label:** described as "Phase 1 hardening work", but it's used on Phase 3 and post-launch issues. Reword it.
- **#23 (P2):** the checklist still lists upload rights as pending. Tick it, and note that the tag is held on purpose.

Then restructure `spec/forever-plan.md` so status lives only in the issues:
- Phase tables become ID / issue / one-line scope / gate. Drop the running status text.
- Struck-through done rows can shrink to one line or move to a "Done" list per phase.
- Keep the decisions log, the gates and the finding index. The index's Status column can go once item 3 makes each finding its own issue.
- Add a short "Now" block at the top: current phase, next gate, open blockers, last updated.

Write `tools/check-plan-index.sh` (bash + `gh`, the same style as `tools/test-release-preflight.sh`). For each plan row it checks that the `[#N]` link exists, the issue title starts with the row's ID, and the issue's milestone matches the phase. Make it runnable locally. Add it to CI only if `gh` works there without new secrets; otherwise say why not.

## 2b. Every finished gate cites its evidence

A ticked gate or Done-when item must point at the thing that finished it. The plan already does this informally ("Done: PR #93"); make it the rule and check it.

Accepted evidence, by kind of item:
- **Code or docs:** a merged PR (`#N`) or a commit SHA on `main` (7+ hex characters).
- **In-game check or probe:** a dated entry in `spec/migration-forever.md`, cited as `migration-forever.md YYYY-MM-DD`. There's no PR for these.
- **CI or release step:** a workflow run ID or URL. #23 already cites dry run `37093088953` this way.
- **External or decision:** a link to the decisions-log row or a comment, such as upload rights being granted.

Where it applies:
- Ticked boxes in every issue's Done-when and Before-tagging lists.
- Every phase exit gate in `spec/forever-plan.md`.
- Every closed plan issue: it must be closed by a PR or carry a closing comment with evidence. `not_planned` closes need a one-line reason instead.

Enforcement:
- Write the rule into `CLAUDE.md` next to the issue-format line, and into the issue template (item 7).
- Extend `tools/check-plan-index.sh` to flag:
  - ticked items with no evidence in issue bodies and plan gates;
  - closed issues with no linked PR and no evidence comment;
  - any cited PR that isn't merged, or SHA that isn't on `main`.
- The automatic side of this is built in item 8.
- Run the check once over the current issues and backfill the gaps you find. A ticked box with no findable evidence goes back to unticked, with a comment saying why. List these for me before changing them.

## 3. Split the multi-finding issues into sub-issues

H12 (#15), H14 (#17), H15 (#18), H17 (#20) and H19 (#44) each cover findings that land in different phases. Partial progress is recorded as comments like "Phase 1 part merged; issue moved to Phase 3".

- For each open finding, create a GitHub sub-issue titled `<F-ID or C-ID>: <title>`, following the `CLAUDE.md` issue format. Use the parent's labels and the milestone and wave that finding needs. Candidates: F7, F27, F36, BDR eviction, paused deltas and returning DR (#15); F22, F23 and F25's `[W]` click check (#17); F11 and F32 (#18, or #44 if item 2 moves F32); C1/F3, C2 and C3 (#20); F30, F31, F33 and M1–M4 (#44).
- Findings already fixed stay as ticked lines in the parent. No sub-issue for those.
- Link each sub-issue to its parent. The parents stay open as umbrellas and close when their last sub-issue closes.
- The H12 returning-DR fix and H19's DR-elect pull are one joint fix (decisions log, 2026-10-06). Make it one sub-issue, linked from both parents, not two.
- Add the new issue numbers to the plan's link list and finding index.

## 4. Track the Phase 3 waves

Wave assignments exist only as a bullet list under Phase 3. Create `wave-1`, `wave-2` and `wave-3` labels and apply them from that list. Then add one line to Phase 3 saying a wave starts only when the previous wave's label has no open `blocker`, with the filter URL.

## 5. Group in-game checks by when they can be run

About 15 open issues carry `needs-ingame`, and nothing says when each check can be run. Alex's game time is the bottleneck. Create one tracking issue per session type, each a checklist linking the issues it answers and the probe or `docs/testing.md` step to run:
- **Phase 2 two-client run:** Q4 #26, Q5 #27, Q8 #45, H4's cold-start question #7, H22's check M #104, F25's `[W]` click #17.
- **Next dungeon:** Q2 #25 and H8 #11 (the `RE` probe).
- **Waves 1–3:** whatever the wave lists need.

Check each claim against the issues and `docs/testing.md` before writing it down. Link these trackers from the plan's phases.

## 6. Optional: a GitHub Project

Propose, don't build yet: a Project (v2) with fields Phase, Wave, Status (Todo / In progress / Needs in-game / On hold / Done) and Run-during. Three views:
- the next in-game session;
- the Phase 2 gate;
- a timeline against Oct 10, Oct 21 and Nov 4.

Also propose replacing the Later tables' "Depends on" column with GitHub's issue dependencies ("blocked by"). The MCP tools can't create Projects, and `gh project` needs the `project` scope, so tell me what I'd need to grant.

## 7. Issue template

Add `.github/ISSUE_TEMPLATE/plan-item.yml`, an issue form that enforces the `CLAUDE.md` format: an `<ID>: <title>` title, the plan-link header, Why, Findings, Done-when, and a label and milestone reminder. Its Done-when help text should show the evidence format from item 2b (for example `- [x] F29 fixed (#95)`). Add `config.yml` if blank issues should stay allowed. Recheck this template against the sub-issue convention from item 3.

## 8. Keep it current automatically

Items 1–7 fix today's state. This item keeps it fixed while I'm steering sessions, with no extra steps from me.

**a. A structured Tracking section in every PR.** The PR template from item 1 gets a machine-readable block:

```
### Tracking
Finishes: #15 F7, #104
Progress: #44 F30
Evidence-only: #23 "dry run"
```

- `Finishes` means "tick this item or close this issue".
- `Progress` means "link this PR, leave the item open".
- `Evidence-only` means "cite this PR on an item without finishing anything else".
- Items are named by issue number plus finding ID, or by a quoted unique substring of the checklist line.
- Claude fills this block in when it opens any PR, from what the diff actually does. Put that in `CLAUDE.md`.

**b. A `tracking.yml` workflow.** Same repo, `GITHUB_TOKEN` with `issues: write`, no new secrets.
- **On PR merged:** parse the Tracking block. Tick each matching checklist item with ` (#PR)` appended, close the issues and sub-issues listed under `Finishes` with a comment linking the PR, and comment the PR link on `Progress` items. If a reference matches zero or several lines, change nothing for it and comment on the PR listing what didn't match.
- **On issue closed:** if the closing PR's Tracking block doesn't list the issue under `Finishes`, reopen it automatically, comment why, and link the PR. This is the guard that would have caught #15. A manual close with no evidence comment gets a `needs-evidence` label and one comment, not a reopen.
- **When the last sub-issue of a parent closes:** close the parent with a comment listing its sub-issues and their PRs.
- Keep the parsing in a script under `.github/scripts/`, with a test in the `tools/test-*` style that runs in CI. Cover:
  - the #15 case;
  - an ambiguous reference;
  - a PR with no Tracking block, which must change nothing.

**c. Drift surfaced in one place.** A scheduled run of `tools/check-plan-index.sh` (daily, plus on every push to `main`) keeps one pinned "Tracking drift" issue up to date. It edits that issue's body in place rather than adding comments, and closes it when the check is clean.

**d. Session start.** Add a SessionStart hook in `.claude/settings.json` that runs the check script quietly and prints a short summary, for example "Tracking: 2 drift items, Phase 2 gate 5/7, next in-game session: two-client run (6 checks)". Then every session I steer starts with the current state. If the check needs the network and can't reach it, print one line and move on; never block the session.

**e. A `track` project skill** for what needs judgement, which Claude runs without being asked:
- **After a PR merges in a session:** confirm the Action did the right thing, and update the plan's "Now" block and the decisions log if a decision was made.
- **When I paste in-game results:** record them in `spec/migration-forever.md` (already a rule), then tick the matching in-game tracker items and issue checkboxes, citing `migration-forever.md YYYY-MM-DD`.
- **When a new finding comes up mid-session:** draft the issue in the template format with milestone, wave and parent. Show it in one line and create it unless I object.

Reference the skill from `CLAUDE.md` so it loads in every session.

**f. Accuracy checks on the automation itself.** Before turning on the reopen-on-close behaviour, dry-run the workflow against the last 30 merged PRs and closed issues. Report what it would have done; #15 should be the only reopen. Only enable it after I've seen that report.

## Order and done-when

Do 1 → 2 → 2b → 3 → 4 → 5, then 8 (with its 8f dry run before enabling), then propose 6, then 7. Item 8 is the part that matters most long-term. Before wave 1 starts, items 1, 3 and 4 matter most.

Done when:
- #15 is open again.
- Every drift item above is fixed or explained.
- The plan carries no status text and the check script passes.
- The check script also passes the evidence check: every ticked gate and closed issue cites a PR, commit, run or migration entry.
- Every open finding from the umbrella issues has its own sub-issue with a milestone and wave label.
- The in-game trackers exist.
- `tracking.yml` works and its parser tests pass. Its dry run over recent history has been shown to me.
- The SessionStart summary and the `track` skill are in place, so the next session starts with the tracking state and keeps it current without my asking.
- The repo changes sit on one branch, ready for me to review.

Finish with a short summary of every GitHub change made, with links.
