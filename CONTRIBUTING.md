# Contributing to GuildCrafts for WoW Forever

Thanks for helping. This fork adapts dkruenbo's GuildCrafts for WoW Forever, and contributions
are welcome. Planned work and open findings are in
[spec/forever-plan.md](spec/forever-plan.md). Check there, or in the
[issues](https://github.com/lxhwes/GuildCrafts-Forever/issues), before starting something large.

## Scope

- This fork maintains the Forever flavor only (`GuildCrafts/GuildCrafts_Camelot.toc`,
  Interface 16001). [docs/ORIGIN.md](docs/ORIGIN.md) explains why.
- Never edit the five Classic TOCs (`GuildCrafts.toc`, `GuildCrafts_Vanilla.toc`,
  `GuildCrafts_Wrath.toc`, `GuildCrafts_Cata.toc`, `GuildCrafts_Mists.toc`) or
  `GuildCrafts/Data/Data_*.lua`. They stay as upstream shipped them. Classic fixes belong
  upstream at [dkruenbo/GuildCrafts](https://github.com/dkruenbo/GuildCrafts).
- Feature-detect every API before calling it, and `pcall` anything that might error. Never
  branch on the interface number.
- Forever runs the Mainline API, but it isn't retail. Check every API against the `forever`
  branch of [Gethe/wow-ui-source](https://github.com/Gethe/wow-ui-source/tree/forever). That
  branch is the source of truth here, not retail documentation or memory of retail.
- Read the relevant upstream RFC in [RFC/](RFC/) before changing sync or election code.

## Development setup

```bash
git clone https://github.com/lxhwes/GuildCrafts-Forever.git
cd GuildCrafts-Forever
```

Symlink the `GuildCrafts` folder from the clone into the Forever client's `Interface/AddOns/`,
keeping the name `GuildCrafts`. On macOS or Linux:

```bash
ln -s "$PWD/GuildCrafts" "<Forever client folder>/Interface/AddOns/GuildCrafts"
```

On Windows, create a directory junction from a Command Prompt:

```bat
mklink /J "<Forever client folder>\Interface\AddOns\GuildCrafts" "<clone>\GuildCrafts"
```

Then `/reload` in game after each change. A checkout reports its version as `dev` in
`/gc comms`.

## Verification

Three regression scripts cover profession drop and relearn, Forever member keys, and the
profession gate. Run them from the repository root under PUC Lua 5.1:

```bash
lua5.1 tools/test-profession-sync.lua
lua5.1 tools/test-forever-identity.lua
lua5.1 tools/test-profession-gate.lua
```

Each exits non-zero on a failure. They stub the WoW APIs, so they don't exercise the game
client or the addon message transport. Add a case when you fix a bug they could have caught.
[docs/testing.md](docs/testing.md) has the full testing guide.

For any change in behaviour, include in-game evidence in the PR. Paste the chat output that
shows it working, for example `/gc dump`, `/gc comms` or `[debug]` lines from `/gc debug`.
For sync or election changes, a run with two clients in the same guild is expected.

## Pull requests

- Keep each PR focused on one change.
- Use a conventional commit title, such as `fix(sync): keep drop history on relearn`. Types are
  `feat`, `fix`, `docs`, `test`, `refactor`, `style` and `chore`.
- When behaviour changes, update the docs it affects and add a line under `## Unreleased` in
  [CHANGELOG.md](CHANGELOG.md).
- Say what the problem was, why it happened if you know, what you changed, and how you
  checked it.
- PRs are squash-merged into `main`.

## Reporting a bug

Open an issue at
[lxhwes/GuildCrafts-Forever](https://github.com/lxhwes/GuildCrafts-Forever/issues) with:

- the addon version, from the first line of `/gc comms`;
- the client build, from `/dump GetBuildInfo()`;
- what you expected and what happened;
- steps to reproduce it;
- the output of `/gc dump` and `/gc comms`;
- the full text of any Lua error;
- whether you were in an instance or in combat when it happened.

If you can reproduce it, type `/gc debug` first and include the `[debug]` lines. Debug mode
turns off at every login and `/reload`.

## Licence

By contributing, you agree that your contributions are licensed under the
[MIT License](LICENSE).
