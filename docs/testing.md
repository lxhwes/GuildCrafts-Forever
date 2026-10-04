# Testing GuildCrafts on WoW Forever

Reusable test procedures. Dated results go in `spec/migration-forever.md`, never here.
In-game probes are referred to by their tag (`TOC`, `RA`, `SP` and so on) and live in
`docs/ingame-commands.md`. Run them from there.

---

## Regression scripts

Run them all from the repository root before every commit and every release:

```bash
lua5.1 tools/test-profession-sync.lua   # profession drop/relearn and empty-read floor
lua5.1 tools/test-forever-identity.lua  # Forever GUID member keys and roster names
lua5.1 tools/test-profession-gate.lua   # Jewelcrafting/Inscription skill-line gate
lua5.1 tools/test-report.lua            # /gc report and the debug ring buffer
lua5.1 tools/test-favorites.lua         # favorites stored as 1, not booleans
lua5.1 tools/test-tooltip-index.lua     # tooltip index rebuild debounce (F9)
bash tools/test-release-preflight.sh     # release.yml publish refusals (H18)
```

If `lua5.1` isn't on your PATH, Alex's PUC Lua 5.1.5 toolchain is at
`/Users/alex/code/legacynext/tools/lua51/bin/lua`. Use it in place of `lua5.1`.

Each script prints a `PASS` or `FAIL` line per check and a final count, and exits non-zero on a
failure. They load the real addon files against stubbed WoW APIs. They don't run the game
client, AceComm or the addon channel, so they say nothing about message delivery, timing or
what a Forever API returns. The manual checklists below cover that.

---

## Conventions for in-game tests

- Results. Record each run in `spec/migration-forever.md` with the date, the `/gc comms`
  version line and the pasted output. A step nobody ran stays unrun; never fill one in from
  what the code should do.
- Version line. `/gc comms` prints `--- Comms Status (GuildCrafts <version>) ---`. From a
  source checkout `<version>` is `dev`. From a package it's the tag, or the short commit hash
  for a dry-run artifact.
- Chat. GuildCrafts prefixes its lines with `GuildCrafts:`. `[debug]` lines only print after
  `/gc debug`, and debug mode resets at every login and `/reload`, so turn it on again each
  time.
- Report. `/gc report` opens a copy box with the client build, keys, recipe counts, sync and
  pause state, and the last 200 debug lines, kept even with debug mode off and across
  `/reload`. Paste it with any result that looks wrong.
- Keys. On Forever each member is keyed by GUID (`Player-4619-…`). `/gc dump` prints yours on
  its first line, `Local player: <key>`. `/gc comms` lists each addon user as `<name> <GUID>`.
- Offline gaps. When a step logs a client out and back in, wait at least 4 minutes between.
  A client that still lists a peer doesn't answer that peer's HELLO, and the DR never sends a
  sync request of its own. After the return, allow 2 minutes for a heartbeat and a sync.
- Scoring. Each step is Pass, Fail, or Known gap. Known gap means the result matches the
  current behaviour written next to that step, which is already tracked in
  `spec/forever-plan.md`. Record it, but don't score it as a failure of the test.

---

## Solo checklist

One Forever character in a guild. From a source checkout, install the whole `GuildCrafts/`
folder (all six TOCs). From a package, only the Camelot TOC is present.

| # | Do | Expect |
|---|---|---|
| 1 | Open the AddOns list | GuildCrafts listed, not flagged out of date |
| 2 | `TOC` probe | `TOC 16001 true … true true` |
| 3 | Log in | No Lua errors (BugSack, or the default error frame) |
| 4 | `/gc` | The main window opens |
| 5 | Look at the main window | No expansion filter buttons; the search box reaches the scope dropdown |
| 6 | Look at the profession list | No Jewelcrafting or Inscription |
| 7 | Open and close a profession window, then `/gc dump` | Your key on the first line, and a non-zero recipe count for that profession |
| 8 | In `/gc`, pick that profession, then your name | The same recipes as the dump counted |
| 9 | `/gc comms` | First line `--- Comms Status (GuildCrafts dev) ---` from a checkout, or the tag version from a package |

---

## Two-client checklist

The solo list never runs the DR/BDR election or the sync protocol. This needs you (A) and one
guildmate (B), on the same build, in the same guild.

**Work out the expected DR first.** Election picks the lowest member key by plain byte order
(`Comms.lua:291-301`). Get both keys from `/gc dump`, compare them character by character
after `Player-`, and call the lower one LOW and the other HIGH.

**Note the server prefixes.** If A and B have different GUID prefixes (`Player-4613-` and
`Player-4619-`), section W also answers open question Q5 in `spec/forever-plan.md`.

### S — Setup

| Step | Who | Do | Expect |
|---|---|---|---|
| S1 | both | `/gc dump` | `Local player: <key>`. Note both keys; decide LOW and HIGH |
| S2 | both | `/gc comms` | The version line for the build you installed (see Conventions) |
| S3 | both | `RA` probe | `RA true true true true false`. If not, skip section R |

### E — Election

| Step | Who | Do | Expect |
|---|---|---|---|
| E1 | A only | Log in alone. Wait 30s. `/gc comms` | `My role: DR`, `DR: <A>`, `BDR: none`, `Total addon users: 1` |
| E2 | A | `/gc debug` | `Debug mode: ON` |
| E3 | B | Log in. Wait 30s | On A: `[debug] HELLO from <B> v3`, then `[debug] Sent HELLO reply to <B>` |
| E4 | both | `/gc comms` | Both print the same `DR: <LOW>` and `BDR: <HIGH>`. LOW shows `My role: DR`, HIGH `My role: BDR`. `Total addon users: 2`, both keys listed |
| E5 | LOW | Wait for HIGH's sync request (about 15s after E3) | With debug on, LOW prints `[debug] Handling SYNC_REQUEST from <HIGH> (role: DR )`, then `Sync with <HIGH> — already converged.` or `Sending SYNC_PULL to <HIGH> …` |

**Fail:** both clients say `My role: DR`, either shows `Total addon users: 1` after 60s, or
the two disagree on `DR:`.

If B is LOW, B's debug is off after its login at E3. Run `/gc debug` on B as soon as it loads,
or skip E5 and rely on W.

E5 shows the SYNC_REQUEST arrived over GUILD. It doesn't show LOW's reply reached HIGH; that
reply is a WHISPER, checked in W.

### F — Failover when a client logs out

This tests the election when a client goes offline. It doesn't touch professions.

| Step | Who | Do | Expect |
|---|---|---|---|
| F1 | HIGH | Log out | — |
| F2 | LOW | Wait 60s. `/gc comms` | Desired: `Total addon users: 1`, `BDR: none`. Current behaviour: still `Total addon users: 2` and `BDR: <HIGH>`. Only the DR is ever evicted (`Comms.lua:443-466`). This is a known gap (H12, "BDR never evicted"). If it shows 1, record it: the code has no path for that |
| F3 | HIGH | Log back in. Wait 90s (LOW still lists HIGH, so HIGH finds LOW at LOW's next 60s heartbeat). Both `/gc comms` | Back to the E4 state |
| F4 | HIGH | `/gc debug` | `Debug mode: ON` |
| F5 | LOW | Log out | — |
| F6 | HIGH | Wait up to 4 minutes. The watchdog checks every 60s and the timeout is 180s | `[debug] DR heartbeat timeout — removing <LOW>`, `[debug] You are now the Designated Router (DR).`, `[debug] DR term advanced to <n>`, and a `Role changed: BDR → DR` line |
| F7 | HIGH | `/gc comms` | `My role: DR`, `DR: <HIGH>`, `BDR: none` |
| F8 | LOW | Log back in. Wait 60s. Both `/gc comms`. Check again after 5 minutes | Desired: both agree on `DR: <LOW>` and `BDR: <HIGH>`, and stay that way |

**Fail:** F6 never fires within 4 minutes, or F8 leaves the two disagreeing after 2 minutes.

At F8 LOW returns with a lower term than the one HIGH adopted at F6. Note whether HIGH printed
`Dropping stale HEARTBEAT`. Finding F8 (H12) says a DR that adopts a higher term stops
heartbeating but keeps its role. If HIGH later prints `DR heartbeat timeout — removing <LOW>`
again, or both end up as DR, record it against F8 as a known gap.

### P — Delta propagation over GUILD

A delta only goes out when a scan finds new recipes. Use a profession window that has never
been opened on that character, or learn one new recipe from a trainer first. Deltas go to
GUILD, so this section says nothing about WHISPER.

| Step | Who | Do | Expect |
|---|---|---|---|
| P1 | both | `/gc debug` | `Debug mode: ON` |
| P2 | A | Open the profession window | A: `Scanned <Prof>: <N> new recipe(s) found.`, `[debug] Broadcast DELTA_UPDATE (add) for <A> <Prof>` |
| P3 | B | Watch chat | `[debug] DELTA_UPDATE (add) from <A> for <A>`, plus one `[debug] Delta merged: <A> <Prof> <recipeKey>` per recipe |
| P4 | B | `/gc`, then `<Prof>`, then A's name | The same N recipes |
| P5–P7 | swap A and B | Repeat P2–P4 the other way | Same, mirrored |

**Fail:** P3 prints nothing, or P4 shows a different count. P3 prints the sender after it has
been resolved to a GUID, so it should equal A's key from S1.

### W — WHISPER reach

Every sync reply goes by WHISPER: SYNC_RESPONSE and SYNC_PULL from the DR, SYNC_PUSH and
SYNC_RESUME back to it. On Forever the whisper target is the roster name, `First Surname`,
which has a space in it. Whether an addon whisper to that name arrives is unverified (Q5).

A client only asks for a sync when it sees a peer it doesn't already list. So HIGH has to
have dropped LOW first. F6 does that, which makes F8 the natural place to run W.

| Step | Who | Do | Expect |
|---|---|---|---|
| W1 | HIGH | Keep debug on from F4. Watch chat while LOW logs in at F8 | `[debug] Sent SYNC_REQUEST (retry=0)` within about 30s of LOW's login, then `[debug] Received SYNC_RESPONSE chunk 1 / 1 from <LOW> — merged: …`. That second line proves a whisper from LOW reached HIGH |
| W2 | both | If the prefixes differ, `SND` probe on A, then on B | A's listener stays armed, so A prints a second `SND` line with B's raw sender name as A's client reports it |

To run W on its own: LOW logs out, HIGH waits until it prints
`DR heartbeat timeout — removing <LOW>` (up to 4 minutes), then LOW logs in.

**Fail:** HIGH never prints `Received SYNC_RESPONSE` within 2 minutes of LOW's login. A
`SYNC_REQUEST timeout — retrying` line on HIGH means the reply never came. If LOW had debug on
in time, `SendMessage: no whisper target for <HIGH>` means LOW couldn't resolve a name.

X checks the opposite direction, HIGH whispering LOW. If A is LOW, A's `Received SYNC_PUSH`
line at X4 is the proof. If A is HIGH, B listing A's new recipe at X5 is the proof, because
that recipe can only reach B by SYNC_PUSH.

The `[W]` whisper button in the main window is a separate path, chat rather than the addon
channel. Current behaviour with two-word names: `/w Geo Prizm …` targets `Geo` and puts `Prizm`
in the message. That's open issue F20 (H14), a known gap.

### X — Full snapshot exchange

Prerequisites: both clients have run P, and each has a profession with an unlearned recipe
they can learn from a trainer.

| Step | Who | Do | Expect |
|---|---|---|---|
| X1 | A | Log out | — |
| X2 | B | Learn one recipe and open that profession window, then log out | `Scanned <Prof>: 1 new recipe(s) found.` |
| X3 | A | Log in, `/gc debug`, learn one recipe and open that window | `Scanned <Prof>: 1 new recipe(s) found.` |
| X4 | B | Log in. Wait 2 minutes | If A is LOW, A prints `Handling SYNC_REQUEST from <B>`, `Sending SYNC_PULL to <B> (<n> member keys)`, then `Received SYNC_PUSH chunk 1 / 1 from <B> — merged: true`. If A is HIGH, A prints `Received SYNC_RESPONSE chunk 1 / 1 from <B> — merged: true` and `Responding to SYNC_PULL from <B> with <n> members`. Other lines may appear between them |
| X5 | both | `/gc dump`, then `/gc` and each other's profession | Both totals match. Each client lists the other's new recipe |

**Fail:** after 2 minutes either client lacks the other's new recipe, or the totals differ.

Evidence: A's debug lines from X4, and both `/gc dump` outputs from X5.

### O — Profession dropped while the other client is offline

Unlearning a profession costs that character its skill. Use a beta character and a primary
crafting profession (call it Prof) with few recipes. Gathering professions won't do, because
the Recipes view hides Herbalism and Skinning (C2).

Prerequisite: B lists A under Prof in `/gc`.

| Step | Who | Do | Expect |
|---|---|---|---|
| O1 | B | `/gc dump`, note `Total`. Log out | — |
| O2 | A | `/gc debug`. Unlearn Prof in game, then `/gc drop <Prof>` | `Removed <Prof> and its recipes.` and `[debug] Broadcast DELTA_UPDATE (remove) for <A> <Prof>` |
| O3 | A | `/gc dump` | Prof no longer listed under `[YOU]` |
| O4 | B | At least 4 minutes after O1, log in. Wait 2 minutes. `/gc dump`, then `/gc` and Prof | `Total` recipes down by A's old Prof count. A no longer listed under Prof |

**Fail:** after 2 minutes B still lists A under Prof.

If `/gc drop` prints `Could not read current professions…`, retry after a few seconds. If it
removes Prof while A still knows it, that's H9, a known gap: record it.

Evidence: A's O2 lines, B's dumps from O1 and O4.

### L — Relearn, then reconnect

Checks that a peer which missed both the drop and the relearn doesn't bring the old recipes
back.

Prerequisite: B lists A's recipes for Prof (re-run P with Prof if O has just removed it), and
holds K of them.

| Step | Who | Do | Expect |
|---|---|---|---|
| L1 | B | Note K from `/gc` → Prof → A. Log out | — |
| L2 | A | Unlearn Prof, `/gc drop <Prof>` | `Removed <Prof> and its recipes.` |
| L3 | A | Relearn Prof at a trainer, learn at least one recipe, open the window | `Scanned <Prof>: <N> new recipe(s) found.` |
| L4 | A | `/gc dump` | Prof: N recipes |
| L5 | B | At least 4 minutes after L1, log in. Wait 2 minutes. `/gc` → Prof → A | Exactly A's current N recipes. None of the K pre-drop recipes that A hasn't relearned |
| L6 | A | `/gc dump` | Prof still N recipes |

**Fail:** B shows more than N recipes for A, or any recipe A doesn't currently know, or A's
own count grows at L6.

Evidence: K, N, B's recipe list at L5, A's dumps from L4 and L6.

### C — Chunked transfer and RESUME

`SYNC_CHUNK_SIZE` is 5 member entries per chunk, one chunk a second. A transfer only splits
when the requester lacks 6 or more member entries. Two clients alone can't reach that, so run
this during wave 1 or later.

Prerequisites: the DR's `/gc dump` shows `Total: <M> members` with M of 7 or more. The
requester is not the DR.

| Step | Who | Do | Expect |
|---|---|---|---|
| C1 | requester | Log out. Move the account's `SavedVariables/GuildCrafts.lua` (and `.lua.bak`) out of the Forever `WTF` folder | — |
| C2 | DR | `/gc debug` | `Debug mode: ON` |
| C3 | requester | Log in, `/gc debug` at once. Wait 2 minutes | DR: `Handling SYNC_REQUEST from <R>`, `SendChunked started: SYNC_RESPONSE → <R> <n> chunk(s)` with n of 2 or more, then `Sent chunk <i> / <n>` for each chunk. Requester: `Received SYNC_RESPONSE chunk <i> / <n>` for every i |
| C4 | requester | `/gc dump` | `Total` members equals the DR's M, less one if the DR holds an entry for the requester. Your own entry is never replaced from peers; since H11 only known professions with no recipes are filled from the DR's copy |

**Fail:** a chunk never arrives and the requester shows no `RESUME:` line, or C4's member
count is short by more than that one.

RESUME may fire on its own: `RESUME: requesting <k> chunk(s) for session …` on the requester
and `RESUME: resending …` on the DR. Current behaviour (F7, H12): large chunks drain slowly,
so RESUME can fire after 4s and resend chunks that were still in flight. Duplicate
`Received SYNC_RESPONSE chunk` lines are that known gap. The test passes if C4 passes.

Evidence: all `Sent chunk`, `Received SYNC_RESPONSE chunk` and `RESUME:` lines, and both
dumps. Don't use `/gc reset` for C1: it calls `ReloadUI()`, which may be protected on Forever
(F14, H7).

### R — Restriction pause and recovery

Needs S3 to pass, and A must be LOW. B's catch-up at R8 depends on A being the DR: after a
`/reload`, B only finds A through A's heartbeat. Entering an instance already pauses sync on
its own, so this section isolates the restriction by watching the debug lines and the `SP`
probe.

| Step | Who | Do | Expect |
|---|---|---|---|
| R1 | A | `RE` probe, then `/gc debug` | `RE armed`, `Debug mode: ON` |
| R2 | A | Enter a dungeon. Wait 15s, then `SP` | `[debug] SyncPausePolicy: inside instance — sync paused`; `SP true false true false` (the 12s zone-transition flag has cleared) |
| R3 | A | Pull the first boss. During the fight run `SP` | Ignore `RE` lines with type 0 (Combat). Expect `RE <time> 1 1` or `RE <time> 1 2`, `[debug] SyncPausePolicy: restriction Encounter active — sync paused`, and `SP true true true false 1` (combat is set too) |
| R4 | A | Kill or wipe. Wait 10s, then `SP` | `RE <time> 1 0`, `[debug] SyncPausePolicy: restriction Encounter lifted`, and `SP true false true false` with nothing after (combat's 6s grace has run out) |
| R5 | A | Still inside, open a profession with a new recipe (see P) | `Scanned … new`, then `[debug] BroadcastNewRecipes suppressed (SyncPausePolicy) for <Prof>` |
| R6 | B | Watch chat | Nothing from A |
| R7 | A | Leave the instance. Wait 20s | `[debug] SyncPausePolicy: instance grace expired — sync resumed` |
| R8 | B | `/gc dump`, then `/reload`, wait 90s, `/gc dump` | Desired: B has A's new recipes without a reload. Current behaviour: suppressed deltas are dropped, not queued (`Comms.lua:1062-1066`), so the first dump lacks them and the second has them. That's a known gap (H12, "Paused deltas are dropped") |
| R9 | A | Learn or scan another new recipe outside the instance | B prints `DELTA_UPDATE (add) from <A>`, so sending has recovered |
| R10 | A | Optional: pull a boss again and `/reload` mid-fight. `SP` | Ends with `1`, from the state read at `OnEnable` |

**Fail:** R3's debug line is missing while `RE` fires, which means GuildCrafts didn't register
the event. B receives A's delta at R6. R9 doesn't reach B. If R3 shows no `RE` line at all,
the event never fired on Forever: record that as the answer to Q2, not as a GuildCrafts
failure.

Evidence: every `RE` and `SP` line, A's debug lines from R2 to R9, and B's two R8 dumps.
