# Releasing GuildCrafts for WoW Forever

This is the one release procedure for this fork. It follows `.github/workflows/release.yml`
and `.pkgmeta` as they stand on `main`.

Only the Forever flavor is ever published from this repository. That was the condition of the
upstream author's permission (`docs/ORIGIN.md`). CurseForge project 1469206 is shared with
upstream, so a file tagged for a Classic flavor would land next to upstream's own files.
Never upload a zip made by hand, because `GuildCrafts/` holds all six TOCs.

The last verified run is the 2026-10-03 dry run, run `37093088953`, which packaged `main` at
`8f0dc69`. No real CurseForge upload has been made yet. Dated packaging experiments are in
`spec/migration-forever.md` under "Packaging".

---

## How the workflow stays Forever-only

`release.yml` is the only release path. It runs in this order. Steps 1 to 3 each fail the job
before anything uploads.

1. The strip step deletes `GuildCrafts.toc`, `_Vanilla`, `_Wrath`, `_Cata`, `_Mists` and
   `Data/` from the checkout. It then requires exactly one TOC, `GuildCrafts_Camelot.toc`, with
   `## Interface: 16xxx` and no `## Interface-<Type>` lines.
2. The first packaging step runs the packager with `-d -g forever`. `-d` skips every
   upload, and no tokens are in that step's environment. `-g forever` makes `release.sh` exit
   if any non-Forever TOC is left (`release.sh:1314`).
3. The gate reads the packager log, the zip and the package folder. It fails unless:
   - the log has exactly one `Game version:` line, every version is `1.6x.y`, and the build
     type is `non-retail version-forever`;
   - the zip has one top-level folder, `GuildCrafts`, and its only TOC outside `Libs/` is
     `GuildCrafts/GuildCrafts_Camelot.toc` (Interface `16xxx`);
   - neither the zip nor the folder holds `GuildCrafts/Data/`;
   - the zipped ChatThrottleLib is v32 or later.

   On success it prints `forever-gate: OK (Game version: …; <zip>; CTL v<n>)`.
4. The zip is uploaded as the run artifact `guildcrafts-forever`, on every run.
5. The publish step runs only for a tag push, or a manual run with `publish` set. It re-runs
   the packager with `-c -o -g forever`. `-c` skips copying files and `-o` keeps the folder the
   gate checked, so the uploaded zip is rebuilt from exactly that folder. `CF_API_KEY` and
   `GITHUB_TOKEN` are only present in this step.

The checks inside the publish step run after the upload. They flag a bad upload: a missing
CurseForge upload, a non-Forever version in an `Uploading …` line, or no `Success!`. They can't
undo it. The gate in step 3 is what prevents one.

### Why `.pkgmeta` `ignore` isn't enough

`release.sh` reads every TOC in the folder to decide which game versions to tag, before it
applies `ignore:`. `ignore:` only runs while files are copied. In the 2026-10-02 experiment,
ignoring the five Classic TOCs gave a zip holding only the Camelot TOC that was still tagged
`5.5.4, 4.4.2, 3.4.3, 2.5.6, 1.60.1, 1.15.7`. That's why the workflow deletes the files. The
`ignore:` entries only keep them out of local packager runs.

### Pins

- The packager is pinned to commit `e50a250f8705041e40f2fa1ddcb280a686d65aa0`
  (BigWigsMods/packager v2.6.1), set in `PACKAGER_SHA`. Bump it on purpose, then dry-run.
- `actions/checkout` and `actions/upload-artifact` are referenced as `@v4`. Those are moving
  tags, not commit SHAs.

---

## Versions

GuildCrafts has three version values. Only the first changes per release.

| Value | Where | Changes when |
|---|---|---|
| Display version | `## Version: @project-version@` in `GuildCrafts_Camelot.toc` | Every package. The packager writes the tag name, or the short commit hash for an untagged build |
| `GuildCrafts.VERSION` | `GuildCrafts/Core.lua` | Only when the sync wire protocol changes. Currently `3` |
| `GuildCrafts.DATA_FORMAT_VERSION` | `GuildCrafts/Core.lua` | Only when the sync payload structure changes. Currently `3` |

`GuildCrafts.DISPLAY_VERSION` reads the loaded TOC's `## Version:` at load. From a source
checkout the token is still unfilled, so it reads `dev`. `/gc comms` prints it on its first
line: `--- Comms Status (GuildCrafts <version>) ---`.

Never edit the `## Version:` lines in the five Classic TOCs. They stay as upstream shipped
them, and nothing is published for those flavors.

### Tags

Planned tags, from `spec/forever-plan.md`:

- first tester build: `v2.1.0-forever-beta.1`;
- launch build: `v2.1.0-forever`.

This convention is not yet confirmed with the upstream author. Confirm it before the first
tag.

The packager sets the CurseForge release type from the tag name, case-insensitively. A tag
containing `alpha` is an Alpha file. Otherwise a tag containing `beta` is a Beta file.
Anything else is a Release file.

CurseForge's upload API has no private draft. Alpha is the most restricted type: the file is
still listed on the project's Files tab, but clients set to Release or Beta don't install it.

---

## Before the first release

1. Confirm the upstream author has added your CurseForge account to project 1469206 with
   upload rights. This isn't in place yet.
2. Create a CurseForge API token on your CurseForge account.
3. Store it as a repository secret from your own terminal. Never paste the token into chat,
   a file or a commit.
   ```bash
   gh secret set CF_API_KEY --repo lxhwes/GuildCrafts-Forever
   ```
4. Confirm the secret exists. This lists the name and date only, never the value.
   ```bash
   gh secret list --repo lxhwes/GuildCrafts-Forever
   ```

Without `CF_API_KEY`, the packager skips CurseForge without an error and still creates the
GitHub release. The publish step then fails with `No CurseForge upload. Is CF_API_KEY set?`,
and a GitHub release is left behind.

---

## Release steps

### 1. Prepare the commit

1. Rename `## Unreleased` in `CHANGELOG.md` to the version and date, in the form
   `## 2.1.0-forever-beta.1 — YYYY-MM-DD`, and merge that to `main`.
2. Run the regression scripts from the repository root (see `docs/testing.md`).
   ```bash
   for t in tools/test-*.lua; do lua5.1 "$t" || echo "FAILED: $t"; done
   ```
3. Run the solo checklist in `docs/testing.md` on the commit you'll tag.
4. Fetch and note the full SHA you'll tag.
   ```bash
   git fetch origin && git rev-parse origin/main
   ```

### 2. Dry-run that commit

A tag can't be dry-run before it's pushed, and pushing a `v*` tag publishes. So dry-run the
SHA. The zip and TOC carry the short SHA instead of the tag name; everything else is the same.

1. Start a no-publish run. `--ref` picks which copy of `release.yml` runs; `-f ref=` picks
   what gets packaged. `publish` defaults to false.
   ```bash
   gh workflow run release.yml --repo lxhwes/GuildCrafts-Forever --ref main -f ref=<sha>
   ```
2. Find the run ID. Check the event is `workflow_dispatch` and the start time is yours.
   ```bash
   gh run list --repo lxhwes/GuildCrafts-Forever --workflow release.yml -L 1
   ```
3. Watch that run until it ends. Expect the gate line
   `forever-gate: OK (Game version: 1.60.1; GuildCrafts-<short-sha>-forever.zip; CTL v32)` and
   a skipped publish step.
   ```bash
   gh run watch <run-id> --repo lxhwes/GuildCrafts-Forever --exit-status
   ```
4. Download that run's artifact.
   ```bash
   gh run download <run-id> --repo lxhwes/GuildCrafts-Forever -n guildcrafts-forever -D ~/Downloads/gc-<run-id>
   ```

### 3. Inspect the artifact

Run these in `~/Downloads/gc-<run-id>`. Set `Z` first:

```bash
Z=$(ls GuildCrafts-*-forever.zip)
```

1. Check the only TOC outside `Libs/` is `GuildCrafts/GuildCrafts_Camelot.toc`.
   ```bash
   unzip -Z1 "$Z" | grep '\.toc$' | grep -v /Libs/
   ```
2. Check there's no `Data/` folder. Expect `0`.
   ```bash
   unzip -Z1 "$Z" | grep -c '^GuildCrafts/Data/'
   ```
3. Check the TOC header shows `## Interface: 16001`, `## Version: <short-sha>` and
   `## X-Curse-Project-ID: 1469206`.
   ```bash
   unzip -p "$Z" GuildCrafts/GuildCrafts_Camelot.toc | head -9
   ```
4. Check the README opens with dkruenbo's credit.
   ```bash
   unzip -p "$Z" GuildCrafts/README.md | head -4
   ```
5. Check `LICENSE` has both copyright lines, dkruenbo's and Alex Howes's.
   ```bash
   unzip -p "$Z" GuildCrafts/LICENSE | grep Copyright
   ```
6. Check ChatThrottleLib is v32.
   ```bash
   unzip -p "$Z" GuildCrafts/Libs/AceComm-3.0/ChatThrottleLib.lua | grep -Eo 'CTL_VERSION = [0-9]+'
   ```
7. Optionally install the unzipped folder on the Forever client and check `/gc comms` reads
   `--- Comms Status (GuildCrafts <short-sha>) ---`.

Stop here if anything is off. Nothing has been published yet.

### 4. Tag and publish

Pushing a `v*` tag publishes at once. There is no confirmation step. Push tags to `origin`
(`lxhwes/GuildCrafts-Forever`) only, never to `upstream`.

1. Tag the SHA you dry-ran.
   ```bash
   git tag v2.1.0-forever-beta.1 <sha>
   ```
2. Push the tag. This starts the publishing run.
   ```bash
   git push origin v2.1.0-forever-beta.1
   ```
3. Find the run ID. Check the event is `push` and the branch column shows the tag.
   ```bash
   gh run list --repo lxhwes/GuildCrafts-Forever --workflow release.yml -L 1
   ```
4. Watch it. Expect the gate line, then
   `Uploading GuildCrafts-v2.1.0-forever-beta.1-forever.zip (1.60.1 beta) to https://wow.curseforge.com/…`
   followed by `Success!`.
   ```bash
   gh run watch <run-id> --repo lxhwes/GuildCrafts-Forever --exit-status
   ```

### 5. Check the upload

1. On CurseForge, open project 1469206, then Files, then the new file. Check it lists exactly
   one game version, WoW Forever `1.60.x`, and the release type the tag implies. Nothing may
   be tagged Classic, TBC, Wrath, Cata or Mists. If anything else is listed, archive or delete
   the file at once and record what the file page showed.
2. Check the other flavors' files on the project are unchanged.
3. Check the GitHub release exists and carries the zip.
   ```bash
   gh release view v2.1.0-forever-beta.1 --repo lxhwes/GuildCrafts-Forever
   ```
4. Install the CurseForge build on the Forever client and check `/gc comms` reads
   `--- Comms Status (GuildCrafts v2.1.0-forever-beta.1) ---`.
5. Record the run ID, file page and results in `spec/migration-forever.md`.

---

## Publishing from a manual run

`workflow_dispatch` with `publish` set also publishes:

```bash
gh workflow run release.yml --repo lxhwes/GuildCrafts-Forever --ref main -f ref=<tag> -f publish=true
```

Its only guard is the "Refuse to publish anything but a tag" step. That step runs
`git tag --points-at HEAD | head -n1` and fails only when no tag at all points at the checked-out
commit. It doesn't check for a `v*` name. So:

- any tag passes, including one that isn't `v*`;
- a branch or SHA passes too, if its commit happens to carry a tag;
- if several tags point at the commit, the packager picks one by its own ordering, and that
  tag sets the version and release type. It may not be the one the step printed.

Use this path only to retry a failed publish for an existing `v*` tag, and pass that tag name
as `ref`. Check CurseForge first. The publish step's checks run after the upload, so a failed
run may already have uploaded a file, and a retry would upload a second one.

---

## Open items

- Changelog upload, Phase 2. `.pkgmeta` `manual-changelog` sends the whole `CHANGELOG.md`
  as each file's changelog. Most of it is upstream's Classic history. Not solved yet; see
  Phase 2 in `spec/forever-plan.md`.
- Action pins. `actions/checkout@v4` and `actions/upload-artifact@v4` aren't pinned to
  commit SHAs.
