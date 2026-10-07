---
name: track
description: Keep GuildCrafts' GitHub issues and spec/forever-plan.md current. Use it without being asked whenever the session-start "Tracking:" line shows drift or PRs to apply; after any PR merges; when Alex pastes in-game results; when a new finding or bug comes up mid-session; before opening a PR (to write its Tracking block); and before closing, ticking or creating any plan issue.
---

# track

Status lives only in the GitHub issues. `spec/forever-plan.md` holds phases, gates, the ID
index and decisions. `tools/check-plan-index.sh` checks the two agree. This skill makes the
changes that need judgement. Every change it makes leaves a one-line trail.

Act on unambiguous, structured evidence only. When a reference matches nothing, or more than
one line, change nothing for it and list it for Alex. A wrong tick or close is worse than a
missing one.

Run `gh` as a standalone command, so the sandbox exclusion applies. Repo: `lxhwes/GuildCrafts-Forever`.

## 1. Start of session, or when asked "what's the state"

Read the hook's `Tracking:` line. If it shows drift, run `bash tools/check-plan-index.sh` and
work through each line with the sections below. Report what you changed in one list.

## 2. Apply a merged PR's Tracking block

For each PR the check lists as "Tracking block not applied":

1. Read the block: `gh pr view N --json body,mergeCommit`. Lines are `Finishes:`, `Progress:`,
   `Evidence-only:`. An item is `#N` (whole issue), `#N F30` (the checklist line holding that
   finding ID), or `#N "text"` (the line containing that text).
2. For each item, check whether a retry already applied it. Skip it only if the target issue has
   a comment starting `Tracking: PR #<P> <action> <item>.` (a merge sha may follow) for this
   action and item, and the
   change it records is visible: the box is ticked, the issue is closed, or the line cites #P.
   Another item from the same PR on the same issue doesn't count.
3. Resolve the item to exactly one line, or to the whole issue. If zero or several lines match,
   skip it and add it to the "unmatched" list.
4. Apply it:
   - `Finishes` + whole issue: close with `gh issue close N --reason completed`, then comment
     `Tracking: PR #P finishes #N.` Add the merge sha after it.
   - `Finishes` + line: change `- [ ]` to `- [x]` and append ` (#P)`. Then comment
     `Tracking: PR #P finishes <item>.` Here `<item>` is the finding ID or the quoted text from the block.
   - `Progress`: comment `Tracking: PR #P progresses <item>.` Don't tick anything.
   - `Evidence-only`: append ` (#P)` to the line. Then comment `Tracking: PR #P cites <item>.`
   Make the change first and write its marker comment after it. A marker then always means
   the change happened.
   Edit bodies by fetching the current body, changing the one line, and writing it back with
   `gh issue edit N --body-file -`. Never write from a stale copy.
5. If closing a sub-issue leaves its umbrella with every sub-issue closed, and the umbrella's
   own Done-when boxes are all ticked, close the umbrella. Its comment lists the sub-issues and
   their PRs. Otherwise leave it open and say what's left.
6. Last, comment on the PR: `Tracking applied: <n> closed, <n> ticked, <n> linked.` Add
   `Unmatched: …` if anything was skipped. Write this marker only after every item is done.
   The check reads only the latest `Tracking applied:` comment and keeps reporting the PR while
   it lists `Unmatched:`. Once Alex settles those items, post a new marker without it.
7. Update the plan only for structure, never for status. Add a new row or link for a new
   issue, move a closed item onto its phase's `Done:` line, and add a decisions-log row for any
   decision the PR made. Those edits go on a branch like any other change.

## 3. Alex pastes in-game results

1. Record them in `spec/migration-forever.md` under a dated heading (CLAUDE.md, gist workflow).
2. Tick the matching boxes in the IG tracker (`ingame-session` label) and in each answered
   issue. Append `` `migration-forever.md YYYY-MM-DD` `` to each, and say which output line
   answers it.
3. A result that contradicts an issue's premise gets a comment on that issue. Don't close it.
   Ask Alex.

## 4. A new finding mid-session

Draft it in the `.github/ISSUE_TEMPLATE/plan-item.yml` shape: `<ID>: <title>`, the plan-link
header, Why, Findings with `file:line` at a named commit, and Done when.
- ID: the next free plan ID, or the finding ID, or for a sub-issue its parent's ID plus a number (`H12.5`).
- Set the milestone, labels, and a `wave-N` label in Phase 3. Link the parent with
  `gh api -X POST repos/lxhwes/GuildCrafts-Forever/issues/<parent>/sub_issues -F sub_issue_id=<id>`.
  The `id` comes from `gh api repos/.../issues/<n> --jq .id`.
- Show it to Alex as one line (`<ID>: <title> → milestone, labels, parent`), then create it
  unless he objects. Add its plan row and `[#N]` link on the current branch.

## 5. Before opening a PR

Write the PR's Tracking block from what the diff actually does. List an issue under `Finishes`
only if this PR completes every Done-when item it names. Never write a closing keyword (close,
fix, resolve and their forms) next to an issue number anywhere in the PR or its commits. CI
rejects it.

## Evidence formats

A ticked box cites one of the following on the same line:
- a merged PR `(#95)`
- a backticked commit on `main`
- `` `migration-forever.md YYYY-MM-DD` ``
- `decisions log YYYY-MM-DD`
- a workflow run ID or URL
- a comment link

A `not_planned` close carries a one-line reason.
