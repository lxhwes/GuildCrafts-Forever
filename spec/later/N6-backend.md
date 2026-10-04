# N6: Web backend: tenancy, auth and isolation — implementation spec

Issue [#56](https://github.com/lxhwes/GuildCrafts-Forever/issues/56). Written 2026-10-04. Status:
blocked on the ADR (N4, [#54]). Lives in the new repository (ADR AD1), under `worker/`. When that
repo exists, move this file there.

## Start here (for a new session)

1. Read `spec/later/N4-adr-external-services.md` end to end: decisions AD2–AD4 and AD7–AD12, the
   data model, the rule-to-mechanism table and the threat model. This spec implements them.
2. Read `spec/later/research/2026-10-03-hosting-discord.md` for limits and Discord API details.
3. Alex creates the Cloudflare account (Workers Paid), the D1 database, the R2 bucket and the
   Discord application. Their IDs go in `wrangler.jsonc`; the secrets go in with
   `wrangler secret put`.

## Stack

TypeScript Worker with Hono (routing), Valibot (validation), Vitest with
`@cloudflare/vitest-pool-workers` (tests run against local D1 and R2). Static web app (N7) as
Workers static assets from the same Worker.

Bindings: `DB` (D1), `SNAPSHOTS` (R2, private, no public domain), rate limiters `RL_TOKEN`,
`RL_USER`, `RL_IP`. Secrets: `DISCORD_BOT_TOKEN`, `DISCORD_PUBLIC_KEY`, `DISCORD_CLIENT_ID`,
`DISCORD_CLIENT_SECRET`.

## Tenant-scoped access layer

- `src/repo/` is the only code that touches `env.DB` or `env.SNAPSHOTS`. An ESLint
  `no-restricted-syntax` rule fails the build on `env.DB` or `env.SNAPSHOTS` anywhere else.
- Every repo function takes a `TenantContext` as its first argument. A `TenantContext` is made
  only by `fromSession()` or `fromUploadToken()`, never from a URL, header or body value. Its
  `tenantId` is a branded type, so a raw string won't compile.
- A URL tenant ID that doesn't match the context's tenant returns 404, the same as an unknown
  tenant.
- Every SQL statement has `tenant_id = ?` bound from the context. A test greps `src/repo/` for
  statements on tenant tables without it.

## Endpoints

| Method and path | Caller | Notes |
|---|---|---|
| `POST /api/v1/upload` | upload token | The only endpoint a token can reach |
| `GET /auth/login?t=<tenant>` | anyone | Redirects to Discord with `scope=identify` and `state` |
| `GET /auth/callback` | Discord | Exchanges the code, gets `/users/@me`, checks membership with the bot token, creates a session; the same "no access" page for an unknown tenant and a non-member |
| `POST /auth/logout` | session | |
| `GET /api/v1/t/:tenant/book` | session | Latest sanitised snapshot from R2, `ETag` = snapshot ID |
| `GET /api/v1/t/:tenant/meta` | session | Uploaded and generated times, counts, `isAdmin` |
| `GET, POST /api/v1/t/:tenant/tokens`, `DELETE …/tokens/:id` | admin | Issue (plaintext returned once), list (label, created, last used), revoke |
| `PUT /api/v1/t/:tenant/settings` | admin | Viewer role, admin role, feed channel, feed on or off, reset the guild-key pin |
| `DELETE /api/v1/t/:tenant` | admin | Typed confirmation; purges everything |
| `POST /interactions` | Discord | N8 |
| `POST /discord/events` | Discord | Signed webhook events (`APPLICATION_AUTHORIZED`) |
| cron daily | — | Retention purge, expired sessions, bot-presence check per tenant |
| cron every 10 min | — | Feed posting (N8) |

Unauthenticated requests to session endpoints get 401 for any tenant ID, valid or not, so a 401
reveals nothing. A session for tenant A asking for tenant B gets 404.

At launch, tenants are created by the operator: `npm run tenant:create -- --discord-guild <id>`
runs a migration-style insert through `wrangler d1 execute`. Self-serve creation is a later
milestone (ADR AD3).

## Sessions and membership

- Session ID: 32 random bytes in an `HttpOnly; Secure; SameSite=Lax; Path=/` cookie, stored as
  SHA-256 in D1. Expires 8 h after creation.
- Membership: `GET /guilds/{guild}/members/{user}` with the bot token. 404 means not a member.
  If the tenant has `viewer_role_id`, the member's `roles` must include it.
- Re-check when `checked_at` is older than 10 minutes, on the request that notices. A failed
  check deletes the session.
- Admin: the guild owner (`GET /guilds/{id}`), or a member whose roles carry Administrator or
  Manage Server (`GET /guilds/{id}/roles`), or the tenant's `admin_role_id`. Computed at login
  and re-checked before every admin action.
- State-changing requests require a matching `Origin` header.

## Upload pipeline

1. Bearer token → SHA-256 → `upload_tokens` row, not revoked, tenant `active`. Otherwise 401.
2. `RL_TOKEN` (limit 12 per 60 s window; the daily cap of 48 per tenant is counted in D1).
3. `Content-Length` over 2 MB → 413. Read the stream with the same cap.
4. `JSON.parse`, then the Valibot schema 1 with caps: 1,000 members, 5,000 recipes, strings 64
   characters for names and 128 for recipe names, depth 6, only known fields kept. Any member
   object carrying `_optout`, `_tombstone` or `optOut` is dropped (defence in depth for N2).
5. Guild-key pin: unpinned → pin and audit; pinned and different → 409, audit.
6. Re-serialise the sanitised object canonically and write `t/<tenant>/<snapshotId>.json` to R2.
7. N8 diff, only if the feed is on and a previous snapshot exists.
8. One D1 batch: insert the snapshot row; insert feed events; update `last_used_at`; audit row.
9. Delete snapshots older than the previous one, rows and objects.

## Retention and deletion

- Daily cron: delete expired sessions; feed events 7 days after posting; audit rows older than
  90 days; orphaned R2 objects. R2 lifecycle rule: delete after 35 days.
- Bot-presence check: `GET /guilds/{id}` with the bot token. Three daily failures in a row
  (403 or 404) set `suspended`; seven more days purge the tenant.
- Tenant deletion: delete the R2 prefix `t/<tenant>/`, then every D1 row with the tenant ID, then
  the tenant row. The test queries every table.
- The privacy page states that D1 Time Travel keeps deleted rows for up to 30 days.

## Tests (the matrix is the point)

- For every endpoint: no credentials, own tenant, other tenant, unknown tenant, revoked token,
  expired session, member who lost the role. Expected status per cell in one table-driven test.
- Upload: oversized, malformed JSON, schema violations, unknown fields stripped, opt-out-marked
  member dropped, guild-key mismatch, rate limit, revoked token fails on the very next request.
- Tenant deletion leaves zero rows in every table and zero R2 objects under the prefix.
- Repo lint: no `env.DB` outside `src/repo/`; every tenant-table statement binds `tenant_id`.
- Discord API calls are stubbed with `fetchMock`; no test calls Discord.

## Done when (from the issue)

- [ ] The test suite proves cross-tenant reads and writes fail, for every endpoint.
- [ ] Tokens are revocable, and a revoked token fails within one request.
- [ ] Tenant deletion leaves nothing behind (checked by a query).
- [ ] Someone other than the author reviews it against the threat model. Open: who. If Claude
      writes the code, Alex's review counts; a second reviewer is better for launch to other
      guilds.

[#54]: https://github.com/lxhwes/GuildCrafts-Forever/issues/54
[#56]: https://github.com/lxhwes/GuildCrafts-Forever/issues/56
