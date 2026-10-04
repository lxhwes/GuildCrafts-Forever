# ADR N4: Companion, web recipe book and Discord bot

Issue [#54](https://github.com/lxhwes/GuildCrafts-Forever/issues/54). Status: **Proposed**,
2026-10-04. Decisions marked "Alex" were made by Alex on 2026-10-04; the rest are proposals for
review. The ADR becomes Accepted when the issue's done-when boxes are ticked.

Evidence: `spec/later/research/2026-10-03-hosting-discord.md` and
`spec/later/research/2026-10-03-companion-n9.md`, each claim with its source. Privacy rules 1–10
are in `spec/later-backlog.md`, "Privacy and guild segregation".

## Context

Guildmates want "who can craft X" when nobody is logged in (N7), and from Discord (N8). The
game can't send data out, and nothing it produces can prove to a server that an upload is
genuine. So a desktop companion (N5) reads the file the game already wrote (N3) and uploads it
to a backend (N6), and Discord is the trust anchor for who may see it.

N9 is closed as a no for now: Battle.net has no Forever API namespace, and the Classic profile
APIs have no professions endpoint (research file, Part B).

## Decisions

| ID | Decision | By |
|---|---|---|
| AD1 | One new repository, a monorepo for companion, Worker and shared schema fixtures. Repository `lxhwes/GuildCrafts-Companion` (name confirmed by Alex 2026-10-04). N5–N8 move to its tracker once this ADR is accepted; the issues here close with a link. N1–N3 and `docs/export-format.md` stay in the addon repo, which owns the schema | Alex (repo and name) |
| AD2 | Cloudflare Workers Paid ($5/mo). One Worker serves the API, the static web app, Discord interactions, cron and Discord webhook events. D1 for metadata, R2 for snapshots | Alex |
| AD3 | Multi-tenant data model and isolation tests from day one. At launch there is one tenant, Alex's guild, provisioned by the operator. Self-serve tenant creation by any Discord admin is a later milestone with its own go-live checklist (privacy policy, abuse contact, deletion path) | Alex |
| AD4 | Tenancy by a `tenant_id` column in one shared D1 database, not a database per tenant. Every query goes through one tenant-scoped access layer | Proposed. Per-tenant D1 needs a redeploy per tenant and N-way migrations (research) |
| AD5 | Companion in Go: one static binary, `zalando/go-keyring`, fsnotify, our own literal-only Lua parser with Go native fuzzing. CLI first (`setup`, `watch`, `upload --dry-run`); a tray icon later if wanted. No auto-update in v1: print a notice when a newer GitHub release exists | Proposed (Go recommended by research) |
| AD6 | Unsigned Windows binaries for the first few guildmates, with SHA-256 checksums and GitHub build-provenance attestations. Certum's open-source certificate (about €49) before wider release; SignPath Foundation later. Don't strip symbols (`-s -w` triggers Defender ML detections) | Alex |
| AD7 | Tenant = one Discord server ID. Each tenant pins the guild key of its first accepted upload and rejects uploads for any other key. Admins see the pinned key and can reset it; pins and resets are audit-logged | Proposed |
| AD8 | Viewers sign in with Discord OAuth, scope `identify` only. Membership and role checks use the bot token (`GET /guilds/{id}/members/{user}`, no privileged intent needed). No user OAuth tokens are stored | Proposed |
| AD9 | The book is served as a document: the Worker validates and sanitises each upload, stores it in R2, and the browser downloads the latest snapshot (about 250 KB, ~40 KB gzipped for 100 members) and searches it client-side. The bot reads the same object. D1 holds no recipe rows | Proposed. Avoids ~30k D1 row writes per upload and keeps the read path to one access-checked object |
| AD10 | Snapshot retention: the latest and the previous (the previous only for N8's diff). Older ones are deleted at upload time; an R2 lifecycle rule at 35 days is the backstop | Proposed |
| AD11 | Upload tokens: 32 random bytes, base64url, prefixed `gcu_`, shown once, stored as SHA-256 in D1 (not KV: KV can take 60 s or more to propagate, so revocation wouldn't take effect within one request). D1 read replication stays off | Proposed |
| AD12 | Opt-out is enforced at the source (N2 marker, N1/N3 filters). The backend can't see opted-out members, so it can only guarantee that a member who opts out is gone after the next upload | Proposed |

## Architecture

```
WoW client (addon)                  player's PC                       Cloudflare
  N1 /gc export ─► clipboard
  N3 PLAYER_LOGOUT ─► GuildCrafts.lua ─► N5 companion ──HTTPS──► Worker /api/v1/upload ─► R2 t/<tenant>/<snap>.json
                       (GuildCraftsExport)   token in OS keychain        │                       D1 snapshots, tokens, audit
                                                                         ├─► /t/<tenant>/ web app (N7) ◄── Discord OAuth (identify)
                                                                         └─► /interactions (N8) ◄── Discord (Ed25519-signed)
                                                                             cron: retention, membership re-checks, bot-removal checks
```

## Data model (D1)

```sql
tenants(id TEXT PRIMARY KEY,               -- 16 random bytes, base32; appears in URLs
        discord_guild_id TEXT UNIQUE NOT NULL,
        guild_key TEXT,                     -- pinned by the first upload (AD7)
        viewer_role_id TEXT, admin_role_id TEXT,
        feed_channel_id TEXT, feed_enabled INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL,               -- active | suspended | deleting
        created_at INTEGER NOT NULL)
upload_tokens(id TEXT PRIMARY KEY, tenant_id TEXT NOT NULL, token_hash BLOB UNIQUE NOT NULL,
              label TEXT, created_by TEXT NOT NULL, created_at INTEGER NOT NULL,
              last_used_at INTEGER, revoked_at INTEGER)
snapshots(id TEXT PRIMARY KEY, tenant_id TEXT NOT NULL, r2_key TEXT NOT NULL, schema INTEGER,
          generated_at INTEGER, uploaded_at INTEGER, token_id TEXT, members INTEGER,
          recipes INTEGER, bytes INTEGER)
sessions(id_hash BLOB PRIMARY KEY, tenant_id TEXT NOT NULL, discord_user_id TEXT NOT NULL,
         is_admin INTEGER NOT NULL, created_at INTEGER, expires_at INTEGER, checked_at INTEGER)
feed_events(id TEXT PRIMARY KEY, tenant_id TEXT NOT NULL, snapshot_id TEXT, member_guid TEXT,
            member_name TEXT, recipe_key INTEGER, recipe_name TEXT, created_at INTEGER,
            posted_at INTEGER)
audit_log(id TEXT PRIMARY KEY, tenant_id TEXT NOT NULL, at INTEGER, actor_type TEXT,
          actor_id TEXT, action TEXT, detail TEXT)   -- detail never holds member names
```

Every table except `tenants` has `tenant_id` and an index leading with it.

## Privacy rules mapped to mechanisms

| Rule | Mechanism | Verified by |
|---|---|---|
| 1 Segregate at the source | N3 writes only enabled partitions to `GuildCraftsExport`; N5 parses only that statement and only the bound guild key; AD7 guild-key pin rejects other guilds | N3 two-guild test; N5 multi-guild fixture test; N6 pin test |
| 2 Tenant = Discord server | AD7; tenant IDs are random; no directory or search; `X-Robots-Tag: noindex` and `robots.txt` disallow all | N6 tests: unknown tenant → 404 |
| 3 Discord OAuth for viewers | AD8; membership and optional role at login and when `checked_at` is older than 10 min; sessions expire after 8 h | N6 tests with a stubbed Discord API |
| 4 Write-only tenant tokens | AD11; the upload endpoint is the only thing a token can call; it replaces its own tenant's snapshot only | N6 tests: token on any read endpoint → 401; token for tenant A on tenant B → 404 |
| 5 Hard isolation | AD4; access layer takes a `TenantContext` built only from a session or token; raw `env.DB` is forbidden outside it (lint rule); 404 for other tenants | N6 matrix test: every endpoint × {own, other, none, revoked} |
| 6 Uploads are untrusted | Schema validation with caps (2 MB body, 1,000 members, 5,000 recipes, 64-char names, depth 6), sanitised re-serialisation, per-token rate limit; HTML via text nodes only, strict CSP; Discord `allowed_mentions: {parse: []}` and markdown escaping | N6 fuzz and hostile-name tests; N7 and N8 escaping tests |
| 7 Consent | Officer-level: tenant creation and token issue need a Discord admin; uploader: `/gc companion on`; member: `/gc optout`; `docs/user-guide.md` and a privacy page say what leaves the game | Review |
| 8 Minimisation and retention | Schema carries names, GUIDs, professions, skill, specialisation, recipes, timestamps only. AD10; sessions purged at expiry; feed events 7 days after posting; audit log 90 days; tenant deletion purges R2 prefix and every D1 row | N6 deletion test queries every table |
| 9 Blizzard's addon rules | The addon stays free and readable and sends nothing out; the companion only reads written files and never touches the game process | Review |
| 10 State the trust limit | The admin page and privacy page say a token holder can upload made-up data for their own tenant only | Review |

## Threat model (STRIDE)

| # | Threat | Mitigation | Residual risk (accepted) |
|---|---|---|---|
| S1 | Forged upload by a legitimate token holder | Admin issues tokens per person; audit log; revoke; guild-key pin | A token holder can publish made-up data for their own tenant (rule 10) |
| S2 | Stolen upload token | OS keychain; never logged; shown once; per-token rate limit; `last_used_at` shown to admins; revocation effective on the next request | Malware on the uploader's PC can read the keychain |
| S3 | Session cookie theft | `HttpOnly; Secure; SameSite=Lax`, 8 h expiry, hashed session IDs in D1, Origin check on state-changing requests | A stolen cookie works until expiry or the next failed membership check |
| S4 | OAuth login CSRF or code injection | `state` bound to a short-lived cookie; exact redirect URI | None known |
| S5 | Non-member reaches a tenant's book | Bot-token membership and role check at login and every 10 min | Up to 10 min after someone leaves the Discord server |
| S6 | Forged Discord interaction | Ed25519 signature check on every request; 401 on failure | None known |
| S7 | Bot used in an unbound server, in DMs or as a user install | Commands registered with `integration_types: [0]`, `contexts: [0]`; server-side check that `guild_id` maps to an active tenant | None known |
| T1 | Tampering in transit | HTTPS only; HSTS | None |
| T2 | Upload of another guild's partition (other-guild-partition case) | N3 writes only enabled guilds; N5 binds one guild key and reads nothing else; AD7 pin rejects a different key | A player who enables the same guild key in two tenants could upload it to both; both are that guild's own servers |
| T3 | Malicious JSON (bombs, deep nesting, huge strings) | Body cap before parse, depth and count caps, strict schema, unknown fields dropped | CPU cost of rejecting a 2 MB body, bounded by rate limits |
| T4 | Malicious SavedVariables file aimed at the companion | Literal-only parser, no `load`; fuzzed; size cap; only one statement parsed | Bugs the fuzzer misses |
| R1 | "I didn't upload that" | Audit log records token ID, snapshot ID and time; tokens are per person | Audit kept 90 days |
| I1 | Cross-tenant read (IDOR) | Tenant taken from the session or token, never from the body; one access layer; matrix tests | A bug in the access layer itself; mitigated by review (N6 done-when) |
| I2 | Opted-out member shown | N2 marker, N1/N3 filters; latest-snapshot-only storage | Version-3 addon clients that haven't updated may still export the member; the web book shows the last upload until a new one arrives |
| I3 | XSS through hostile names or recipe names | Text nodes only, no `innerHTML`; CSP `default-src 'self'`, no inline script; hostile-name test fixtures | None known |
| I4 | Discord mention or markdown injection | `allowed_mentions: {parse: []}`; escape markdown in names | None known |
| I5 | Tenant enumeration | Random 128-bit IDs; 404 for every miss; noindex; no directory | A leaked tenant link reveals that the tenant exists, not its data |
| I6 | Companion leaks local paths or the account folder name | Uploads only the bound block; `--dry-run` prints the exact bytes; a test asserts no path or account string appears | None known |
| I7 | Logs hold member names | Logs carry IDs and counts only; Workers logs retention left at default and not exported | Cloudflare's own log retention |
| I8 | Snapshot bucket exposed | Private R2 bucket with no public access or custom domain; served only through the Worker | None known |
| I9 | Deleted data recoverable | Deleting a tenant purges R2 and D1 | D1 Time Travel keeps deleted rows for 30 days; say so on the privacy page |
| DS1 | Upload or command floods | Workers Rate Limiting binding per token, per Discord user and per IP on OAuth; body caps | The binding is per location and eventually consistent |
| DS2 | Discord REST error 1015 from shared Worker IPs | Interaction replies are unaffected; feed posts and cron checks back off and retry | Feed delays; move outbound REST to a small VM if chronic |
| DS3 | Cost runaway | $5 plan; billing notification at $10; caps above | Pay-as-you-go overage until an alert is acted on |
| E1 | Viewer acts as admin | Admin = server owner, or a member whose roles carry Administrator or Manage Server, or the tenant's `admin_role_id`, computed with the bot token at action time | None known |
| E2 | Companion binary replaced (supply chain) | GitHub Actions builds, checksums, build-provenance attestations; later signed | Unsigned v1 binaries; users must check checksums |

## Policy risk

Blizzard's EULA §1.C.vi forbids unauthorised software that reads information the platform
generates or stores. TSM, wowaudit and Raider.IO all read SavedVariables openly, which suggests
the practice is tolerated, but there is no explicit approval. Keep the companion read-only, free
and open source, and never touching the game process.

## Consequences

- Alex runs a $5/month Cloudflare account and a Discord application (bot token, public key,
  OAuth client secret as Worker secrets).
- A second repository with its own CI, releases and tracker.
- The addon owns the export schema. The new repo vendors a fixture generated by the addon's
  `tools/test-export.lua` so both sides test against the same bytes.
- Opening to other guilds later needs the self-serve milestone, a privacy page and a deletion
  contact. Isolation is already in place.

## Rejected alternatives

- **Database per tenant.** Redeploy per tenant, N-way migrations, 10-database Free cap.
- **Supabase.** Free tier pauses after a week idle, Pro is $25/month, and RLS can't ask Discord
  about membership.
- **Deno Deploy.** Deploy Classic shut down on 2026-07-20; platform churn.
- **Fly.io VM.** Workable at ~$2–5/month, but it's a server to patch. Kept as the fallback for
  outbound Discord REST if error 1015 becomes chronic.
- **Upload the raw SavedVariables file.** Leaks every guild partition (rule 1).
- **Battle.net API (N9).** No Forever access today.

## Done when (from the issue)

- [ ] ADR merged, in this repo or the new one, with every privacy rule mapped to a mechanism.
- [ ] Threat model lists each threat, its mitigation and its accepted residual risk.
- [ ] Decision on whether N5–N8 move to the new repo's tracker. (AD1 proposes yes.)
