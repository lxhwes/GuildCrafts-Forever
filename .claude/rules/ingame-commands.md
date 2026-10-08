---
paths:
  - "docs/ingame-commands.md"
---

# In-game commands and the gist

The Forever beta runs on Alex's other PC. Probes reach it through one secret gist, not chat.

- Gist: https://gist.github.com/lxhwes/6ccdf7ad7451481d916410b65beff5ce
  (file `gc-forever-probes.md`). It's secret, which means unlisted: anyone with the link can open it.
- Source of truth: `docs/ingame-commands.md`. The gist mirrors that file. Never edit the gist
  by hand.
- Sync it with this command, run on its own so the `gh *` sandbox exclusion applies:
  `gh gist edit 6ccdf7ad7451481d916410b65beff5ce --filename gc-forever-probes.md docs/ingame-commands.md`
- After an update, confirm the change by fetching the raw gist URL.

These are stricter than the `ingame-script` skill, and they win where the two differ:
- One command per fenced block, so GitHub shows a copy button for each.
- `/run` lines must be 255 characters or fewer. WoWLua doesn't load on 1.60.1.70170.
- End every statement with `;`, and never use `--` comments.
- Parse-check with Lua 5.1 `luac -p` as written and again with newlines stripped.
- Feature-detect or `pcall` anything that might be nil, because one error kills the whole line.
- Put a tag at the start of each `print` (for example `GC`, `TOC`, `EXP`, `TS`) so pasted output
  can be matched to its command.
- Above each block, one line saying when to run it (for example "with a profession window
  open") and how to read the output.
