---
paths:
  - "GuildCrafts/Modules/Comms.lua"
  - "GuildCrafts/Modules/SyncPausePolicy.lua"
  - "GuildCrafts/Modules/ForeverIdentity.lua"
  - "GuildCrafts/Modules/Data.lua"
---

<!-- These globs match High-risk paths in CLAUDE.md's Agent conventions block. Change both together. -->

# Sync, election and member data

- Read the relevant upstream RFC in `RFC/` before changing sync or election code. They are
  historical, so check them against source and `spec/migration-forever.md`.
- Addon messages are restricted during encounters. Extend `SyncPausePolicy.lua` rather than
  adding a parallel mechanism. Each send site in `Comms.lua` checks `ShouldPause()` itself;
  only `CRITICAL_SIGNALS` bypass it, because dropping heartbeats splits the election.
- `GuildCrafts.VERSION` and `DATA_FORMAT_VERSION` (`Core.lua`) are wire protocol versions.
  Bump one only when the sync protocol changes, and always when it does.
- Never purge data, or broadcast a removal, because a read came back empty or partial. Empty
  SavedVariables, an unread profession slot or a missing fallback API all looked like a
  dropped profession, and the removal reached every peer (F1, F2, F19).
- Recipes seen in someone else's view (a linked, guild or guildmate profession window) are
  theirs. Never file them under the player (F5).

## Election and transfer

A current architecture doc is planned (D1 cut 2, #22). Until then:

- DR (Designated Router): first `addonUsers` key in sort order. On Forever that's the
  lowest GUID string (server ID, then character ID), not a name. Answers all `SYNC_REQUEST`s
  and broadcasts `HEARTBEAT` every 60s
- BDR (Backup DR): second in sort order; responds at retry=1
- `syncRetryCount`: 0 = ask DR, 1 = ask BDR, 2 = evict both and re-elect
- `currentTerm`: in memory only, reset on reload, raised by any higher-term message. Only
  `HEARTBEAT` and `SYNC_RESPONSE` are dropped when stale (term < currentTerm)
- `SyncPausePolicy`: suspends outgoing sync during combat, instances, zone transitions
  and active addon restrictions (`C_RestrictedActions`)
- Chunked transfers: one chunk per second via timer, sessionId + RESUME recovery.
  Timeouts and sizes are the constants at the top of `Comms.lua`.
