# Hosting stack and Discord research (N4, N6, N7, N8)

Web research by a subagent, 2026-10-03. Every claim carries the source the agent cited. Items
marked UNVERIFIED had no primary source.

## Cloudflare Workers, D1, KV, R2

| Limit | Free | Paid ($5/mo min) | Source |
|---|---|---|---|
| Requests | 100k/day | 10M/mo incl., +$0.30/M | https://developers.cloudflare.com/workers/platform/pricing/ |
| CPU per request | 10 ms | 30 s default, 5 min max (15 min cron) | https://developers.cloudflare.com/workers/platform/limits/ |
| Request body | 100 MB (Free/Pro zone) | same | limits page |
| Cron triggers / account | 5 | 250 | limits page |
| D1 databases / account | 10 | 50,000 | https://developers.cloudflare.com/d1/platform/limits/ |
| D1 DB size / account storage | 500 MB / 5 GB | 10 GB / 1 TB | D1 limits |
| D1 max row or BLOB | 2,000,000 bytes | same | D1 limits |
| D1 queries per invocation | 50 | 1,000 | D1 limits |
| D1 Time Travel | 7 days | 30 days | D1 limits |
| D1 rows read | 5M/day | 25B/mo incl. | https://developers.cloudflare.com/d1/platform/pricing/ |
| D1 rows written | 100k/day | 50M/mo incl., +$1/M | D1 pricing |
| KV writes | 1,000/day | 1M/mo incl. | https://developers.cloudflare.com/kv/platform/limits/ |
| R2 | 10 GB-mo, 1M Class A, 10M Class B, free egress | $0.015/GB-mo | https://developers.cloudflare.com/r2/pricing/ |

- Free plan: exceeding D1 daily limits makes queries error until the reset.
- `JSON.parse` of a 1–2 MB snapshot likely exceeds 10 ms CPU (UNVERIFIED). Free is risky for uploads.
- A 2 MB snapshot can't fit one D1 row. Raw snapshots go to R2.
- KV is eventually consistent, up to 60 s or more
  (https://developers.cloudflare.com/kv/concepts/how-kv-works/). It can't meet "a revoked token
  fails within one request". Keep token hashes in D1. Read replication is off by default; if
  enabled, use `first-primary` Sessions for auth reads
  (https://developers.cloudflare.com/d1/best-practices/read-replication/).
- Database per tenant: bindings are static in Wrangler config, so onboarding a tenant means a
  redeploy; each migration runs per database; Free allows 10. Use a `tenant_id` column.
- D1 has no row-level security (UNVERIFIED as a documented negative; SQLite has none). Enforce
  tenancy in a query helper.
- Rate Limiting binding GA 2025-09-19, period 10 or 60 s, per location, eventually consistent
  (https://developers.cloudflare.com/workers/runtime-apis/bindings/rate-limit/). Free-plan
  availability UNVERIFIED.
- Deleted D1 rows stay recoverable via Time Travel for 7 or 30 days. The privacy policy must say so.

## Discord OAuth and membership

- User-token path: scopes `identify guilds.members.read`, then
  `GET /users/@me/guilds/{guild.id}/member` (returns `roles`).
  https://docs.discord.com/developers/resources/user
- Bot-token path (recommended): `GET /guilds/{id}/members/{user}`. No privileged intent listed;
  only List Guild Members needs `GUILD_MEMBERS`. https://docs.discord.com/developers/resources/guild
  OAuth then needs only `identify`, no user tokens are stored, and cron can re-check roles.
- Access tokens last 7 days (`expires_in: 604800`). Use `state`.
  https://docs.discord.com/developers/topics/oauth2

## HTTP interactions on Workers

- Verify `X-Signature-Ed25519` + `X-Signature-Timestamp`; 401 on failure; PING → PONG. Workers
  Web Crypto supports Ed25519. https://docs.discord.com/developers/interactions/receiving-and-responding
- First response within 3 s; type 5 deferred, then PATCH `@original` within 15 min.
- Ephemeral flag `64`; `allowed_mentions: {parse: []}`.
- Register with `integration_types: [0]`, `contexts: [0]` (guild install, guild context only).
  Server-side, reject a missing or unbound `guild_id`.
- Autocomplete: type 8, max 25 choices.
- Feed: bot needs Send Messages (and in practice View Channel) in the channel; 2,000-char cap.
  Cron can POST with `Authorization: Bot …`.
- Risk: Workers' shared egress IPs hit Discord Error 1015 intermittently
  (https://github.com/discord/discord-api-docs/issues/7137). Interaction responses are unaffected.
  Treat feed posts as best-effort with backoff.
- An HTTP-only bot never receives `GUILD_DELETE`. Detect removal from cron (403/404 on the guild)
  and purge after a grace period (UNVERIFIED that this is reliable). Webhook events give
  `APPLICATION_AUTHORIZED` with the guild. https://docs.discord.com/developers/events/webhook-events

## Linked Roles

At most 5 integer/datetime/boolean metadata fields. Can't verify a WoW character.

## Alternatives

- Supabase: free tier pauses after a week idle; Pro $25/mo. Discord auth built in, but RLS can't
  ask Discord about membership. Out on budget.
- Deno Deploy: Classic shut down 2026-07-20; platform churn.
- Fly.io: ~$2.19/mo shared-cpu-1x + volume; no free tier; LiteFS in limited maintenance. Fixed
  egress IP avoids Error 1015. Fallback for outbound Discord REST only.

## Cost (10 tenants, one 1 MB upload/day each, 1k views/day)

- Workers Paid $5/mo covers it. Full-rewrite uploads ≈ 750k D1 row writes/day (over Free's
  100k); diff upserts likely < 100k/day. R2 ~300 MB at 30-day retention: free.

## Discord developer terms

- Developer ToS §5(b): delete API Data when no longer necessary, when the app stops, or on
  Discord's request. §5(a) privacy policy required with a deletion path. §5(c) encrypt at rest.
  Live page returned 403 to the agent; text from a 2022 mirror and snippets (partly UNVERIFIED).
- Store Discord user ID, role IDs and sessions only. Don't persist Discord display names.
  Purge a tenant when the bot is removed. Account for Time Travel retention.

## Recommendation (agent's)

Workers Paid, one Worker (API, static web app, interactions, cron, webhook events), one shared
D1 with `tenant_id`, raw snapshots in R2 purged by cron, token hashes in D1, signed-cookie
sessions backed by D1, OAuth `identify` only with bot-token role checks.
