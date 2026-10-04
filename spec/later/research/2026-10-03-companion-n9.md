# Companion and N9 research (N5, N9)

Web research by a subagent, 2026-10-03. Items marked UNVERIFIED had no primary source.

## Companion language and distribution

- Go recommended: one static binary, no cgo. Antivirus flags on Go binaries are "almost always a
  false positive" (https://go.dev/doc/faq#virus). Stripping with `-ldflags="-s -w"` triggered
  `Trojan:Win32/Wacatac.C!ml`; dropping the flags fixed it
  (https://groups.google.com/g/golang-nuts/c/Au1FbtTZzbk). Don't strip symbols.
- PyInstaller: worst for false positives (https://github.com/microsoft/apm/issues/487).
- Rust: static binary; keyring v4 split adds setup. False-positive rate UNVERIFIED.
- Signing (https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/code-signing-options):
  - Azure Artifact Signing ~$9.99/mo; individuals only in USA and Canada. No instant SmartScreen trust.
  - EV certs no longer bypass SmartScreen; reputation builds over time for every cert type.
  - SignPath Foundation: free, needs an already-released OSS project with reputation, public CI,
    a signing policy, manual approval (https://signpath.org/terms.html).
  - Certum Open Source cloud cert from €49 (https://shop.certum.eu/open-source-code-signing-on-simplysign.html).
  - Apple Developer ID $99/yr; notarize zip/pkg/dmg only.

## Keychain

- `zalando/go-keyring`: no cgo; macOS via `/usr/bin/security`; Windows Credential Manager.
  Limits ~2.5 KB on Windows, ~3 KB macOS. A token fits.
- Python `keyring`: on macOS any script from the same interpreter reads secrets without a prompt.

## How WoW writes SavedVariables

- On logout or `/reload`: rename `X.lua` → `X.lua.bak`, then create `X.lua` and write in place.
  No temp-file-and-rename. A crash mid-write leaves a truncated `.lua`
  (https://github.com/Stanzilla/WoWUIBugs/issues/241).
- Watcher: watch the directory; expect Rename, Create, several Writes; debounce ~2 s; require a
  full parse and stable size + mtime before upload; retry on parse failure; never read `.bak`.
- Folders: `_retail_`, `_classic_`, `_classic_era_`. Forever beta uses `_classic_beta_`
  (https://www.curseforge.com/wow/addons/foreverui). wago.tools lists build 1.60.1.70205
  (2026-10-03) under `wow_classic_beta`. Launch folder name UNVERIFIED.
- Battle.net `product.db` (`%ProgramData%\Battle.net\Agent\product.db`) is protobuf; WowUp
  reads install paths from it. Use as a hint with a manual folder picker.

## Parsers that never execute code

- slpp (Python): doesn't decode `\n` or `\ddd`. Reject.
- luaparse (JS): full 5.1 parser, last push 2022.
- full_moon (Rust): lossless; we'd decode escapes ourselves.
- mmobeus/luadata: data-only, built for SavedVariables, 0 stars; escape coverage UNVERIFIED.
- gopher-lua executes code. Don't use.
- Recommendation: own literal-only parser (~300 lines), Go native fuzzing.
- Must handle: raw bytes (not UTF-8), 5.1 escapes incl. `\ddd` ≤ 255 and backslash-newline,
  `--[[ ]]` comments, exponent numbers. How the client writes inf/NaN: UNVERIFIED, probe in game.

## Prior art

- TSM desktop app: user sets the WoW folder; uploads and writes back AppHelper SavedVariables.
- wowaudit client: team API key; syncs when the game closes or reloads.
- Warcraft Logs uploader: account login; user points at the WoW folder.
- WowUp: finds installs through product.db.

## Policy

- UI Add-On Development Policy: free, not obfuscated, no excessive chat, no ads
  (https://us.forums.blizzard.com/en/wow/t/ui-add-on-development-policy/24534). Silent on
  external programs.
- EULA §1.C.vi bans unauthorized software that "reads, or 'mines' information generated or
  stored by the Platform"
  (https://www.blizzard.com/en-us/legal/fba4d00f-c7e4-4883-b8b9-1b4500a402ea/blizzard-end-user-license-agreement).
  TSM, wowaudit and Raider.IO operate openly; tolerated by inference, no explicit approval found.

## N9: Battle.net API for Forever — No (2026-10-03)

- Classic namespaces: `*-classic1x-*` (Era), `*-classic-*` (Mists Progression),
  `*-classicann-*` (Anniversary). No Forever namespace
  (https://community.developer.battle.net/documentation/world-of-warcraft-classic/guides/namespaces).
- Classic Profile APIs have Guild Roster but no Character Professions endpoint.
- Forum thread "When will we gain API access to Forever APIs?" (2026-09-18), no blue reply
  (https://us.forums.blizzard.com/en/blizzard/t/when-will-we-gain-api-access-to-forever-apis/59595).
- Forever has no realms (https://www.wowhead.com/forever/news/no-more-realms-in-wow-forever-382866),
  so realmSlug-keyed paths may not map even if access opens.
- Even with access, professions would need a new Classic endpoint. Addon + companion stays necessary.
