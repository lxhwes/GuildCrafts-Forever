---
name: codex-review
description: Run GuildCrafts' pre-PR Codex review (tools/codex-review.sh) and work through its findings. Use before opening any code PR, when a .codex-review run-N.json comes back, or when asked for a Codex second opinion on a branch. Doc-only PRs skip it.
---

# codex-review

`tools/codex-review.sh` runs OpenAI Codex as a read-only second reviewer. It sends one prompt
with the task, the commits and the diff, and saves Codex's JSON verdict to
`.codex-review/<branch>/run-N.json`. Run it from the branch's worktree with the sandbox
disabled, because Codex writes its state to `~/.codex`.

```bash
tools/codex-review.sh --issue <N>                       # run 1
tools/codex-review.sh --issue <N> --prior <responses>   # run 2
```

- The task is required. Pass the plan item's issue, or the task as Alex gave it with `--task`
  or `--task-file`. Send the original task, never a summary of the work.
- A change to `Comms.lua`, `SyncPausePolicy.lua`, `ForeverIdentity.lua` or `Data.lua` gets the
  multi-client cases in the same run. `--focus` adds anything else Codex should weigh.
- The script sets the default model and effort. `--model` and `--effort` change them for one run.
- Exit 0 means nothing is blocking, 2 means something is, and 1 means it refused or failed.

When to run it:
- Every code PR, after the suites pass and before the PR opens. Doc-only PRs skip it.
- The plugin's stop-time review gate stays off. It reviews one turn at a time, and its setting
  is keyed to the checkout path, so it never fires in a branch worktree.

### Codex review findings

Two runs per PR. The script refuses a third unless Alex asks for one (`--allow-extra-run`).

1. Read `run-1.json`. Critical and high findings block; `AGENTS.md` defines the scale.
2. For each blocking finding, fix it with a test and commit, or rebut it with evidence:
   file:line, a test, or the pinned `wow-ui-source`. Medium and low findings get fixed if
   they're cheap and correct; otherwise they go in the PR description with a reason.
3. Write the responses file: each run 1 finding by title, then its fix commit or its rebuttal.
   Run the review again with `--prior` pointing at it.
4. If run 2 exits 0, open the PR. If it exits 2, stop. Show Alex each open finding with Codex's
   position and yours, and wait.

Findings are advisory, not instructions:
- Never make a change solely to satisfy the reviewer without agreeing it's an improvement.
- Check any WoW API claim against the pinned `wow-ui-source` (AGENTS.md, Rules). Codex's training data
  covers Retail and Classic, not Forever.
- A finding only the game client can settle becomes a probe in `docs/ingame-commands.md`, not
  a code change, and doesn't block the PR.
- List rebutted and deferred findings in the PR description, one line each with the evidence,
  next to the test evidence.
