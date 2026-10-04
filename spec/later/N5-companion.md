# N5: Companion uploader — implementation spec

Issue [#55](https://github.com/lxhwes/GuildCrafts-Forever/issues/55). Written 2026-10-04. Status:
blocked on N3 ([#53]), the ADR (N4, [#54]) and the upload endpoint (N6, [#56]). Lives in the new
repository (ADR AD1), under `companion/`. When that repo exists, move this file there.

## Start here (for a new session)

1. Read `spec/later/N4-adr-external-services.md` (AD5, AD6, threats T2, T4, S2, I6, E2) and
   `spec/later/research/2026-10-03-companion-n9.md`.
2. Read `spec/later/N3-companion-export.md` for the input and `docs/export-format.md` (from N1)
   for the output.
3. Ask Alex for a real `GuildCrafts.lua` from the beta with `/gc companion on`, to seed the
   parser corpus. Strip other guilds from it before committing it as a fixture.

## Shape

A Go CLI, one static binary per platform: Windows amd64 first, then macOS arm64 and amd64.

```
gccompanion setup            first-run wizard
gccompanion watch            watch and upload on change (foreground; Ctrl-C to stop)
gccompanion upload [--dry-run]   one upload now; --dry-run prints the exact body and sends nothing
gccompanion status           bound guild, file path, last upload result, server URL
gccompanion forget           delete the token from the keychain and the local config
```

Dependencies: `github.com/fsnotify/fsnotify`, `github.com/zalando/go-keyring`, the standard
library. No cgo. Build without `-ldflags "-s -w"` (Defender ML false positives).

## Setup wizard

1. Find the game folder. Check the usual locations (`C:\Program Files (x86)\World of Warcraft`,
   `/Applications/World of Warcraft`), then let the user type a path. List flavour folders that
   contain `WTF/Account`: `_classic_beta_` during the beta. The launch folder name is
   unverified; don't hard-code a single name.
2. List account folders and let the user pick one. The folder name stays local.
3. Parse that account's `SavedVariables/GuildCrafts.lua`, list the guild keys inside
   `GuildCraftsExport.guilds`, and let the user pick one. If none: "Run /gc companion on in game,
   then /reload."
4. Ask for the server URL (default the production URL) and the upload token, with the input
   masked. Check that the token starts with `gcu_`. Store it in the OS keychain (service
   `GuildCraftsCompanion`, user = server host).
5. Write `config.json` in the user config dir (`os.UserConfigDir()`): file path, bound guild
   key, server URL, last upload hash. Never the token.

## Watching

- Watch the `SavedVariables` directory, not the file. The client renames `GuildCrafts.lua` to
  `.bak`, then creates and writes a new file in place. A crash mid-write leaves it truncated.
- On any event for `GuildCrafts.lua`: debounce 2 s, then read. Upload only when the parse
  succeeds and the size and mtime were stable across two reads 1 s apart. On a parse failure,
  retry after 5 s, up to 5 times, then wait for the next event. Never read `.bak`.

## Parser

Our own literal-only parser over raw bytes. It never executes anything.

- Lex the whole file. Skip every top-level statement except `GuildCraftsExport = <table>`,
  balancing braces without building values. `GuildCraftsDB` is never materialised.
- Grammar: table constructors with `[key] = value`, `name = value` and positional values; `,`
  and `;` separators; `--` line comments and `--[[ ]]` / `--[==[ ]==]` long comments (the
  client writes `-- [n]` after array items); strings in `"` or `'` with the Lua 5.1 escapes
  `\a \b \f \n \r \t \v \\ \" \' \<newline>` and `\ddd` (1–3 digits, reject values over 255);
  long strings `[[ ]]`; numbers (decimal, exponent, hex); `true`, `false`, `nil`. Reject
  `inf`, `nan` and any other identifier in value position. How the client writes infinity and
  NaN is unverified; the export never holds either.
- Limits: file 64 MB, string 64 KB, depth 32, 2 million tokens. Each is a typed error.
- Then select `guilds[boundGuildKey]` and convert to schema 1: Lua arrays (keys 1..n) become
  JSON arrays; `recipes` dictionary keys become decimal strings; a missing member `name` becomes
  `null`. Drop anything not in the schema.
- Canonical JSON: sorted object keys, no whitespace, numbers as integers. One function,
  `BuildBody`, produces the bytes for both `--dry-run` and the real upload.

## Upload

- `POST <server>/api/v1/upload`, `Authorization: Bearer gcu_…`,
  `Content-Type: application/json`. Plain JSON in v1; the body is about 250 KB for 100 members.
- Skip the upload when the body's SHA-256 matches the last successful one.
- 429 and 5xx: exponential backoff from 30 s, up to 1 h. 401 or 404: stop and print "The token
  was revoked or the server doesn't know it. Run gccompanion setup."
- Logs: status codes, byte counts and hashes only. Never the token, the body, the account name
  or a path.

## Release

GitHub Actions on tag: build the matrix, write `SHA256SUMS`, and run
`actions/attest-build-provenance`. Unsigned at first (ADR AD6). The README covers SmartScreen
("More info → Run anyway") and checking the hash (`certutil -hashfile gccompanion.exe SHA256`).
Starting at login (Task Scheduler on Windows, a LaunchAgent on macOS) is documented, not
automated, in v1.

## Tests

1. Multi-guild fixture: `GuildCraftsDB` with three partitions and `GuildCraftsExport` with two
   guild blocks. The body holds only the bound guild. It contains none of: the other guild
   names, the account folder name, any path separator sequence from the fixture path, any key
   from `GuildCraftsDB`.
2. Fuzz `Parse` with `go test -fuzz`: seed corpus of real files, truncations at every 1 KB, and
   hand-made malformed files. No panics, no hangs (limits enforced), and errors are typed.
3. Escapes: every 5.1 escape decodes correctly; `\256` is rejected; raw bytes survive parsing
   unchanged, and invalid UTF-8 is replaced with U+FFFD at JSON conversion (counted in the
   log, never silently).
4. Dry run equals upload: an `httptest.Server` captures the body; it equals `--dry-run` stdout
   byte for byte.
5. Watcher: simulated rename, create and partial writes produce exactly one upload after the
   file settles; a truncated file produces none.
6. Keychain: the token never appears in `config.json`, logs or error strings.

## Done when (from the issue)

- [ ] Never reads or sends other partitions, the account folder name or paths (test with a
      multi-guild fixture).
- [ ] Parser fuzz-tested against malformed files.
- [ ] The dry run matches the real upload byte for byte.

[#53]: https://github.com/lxhwes/GuildCrafts-Forever/issues/53
[#54]: https://github.com/lxhwes/GuildCrafts-Forever/issues/54
[#56]: https://github.com/lxhwes/GuildCrafts-Forever/issues/56
