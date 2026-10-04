# N8: Discord bot — implementation spec

Issue [#58](https://github.com/lxhwes/GuildCrafts-Forever/issues/58). Written 2026-10-04. Status:
blocked on N6 ([#56]). Lives in the new repository (ADR AD1), inside the N6 Worker
(`worker/src/discord/`). When that repo exists, move this file there.

## Start here (for a new session)

1. Read `spec/later/N4-adr-external-services.md` (threats S6, S7, I4, DS1, DS2) and
   `spec/later/N6-backend.md`.
2. Read the "HTTP interactions on Workers" section of
   `spec/later/research/2026-10-03-hosting-discord.md`.
3. Alex sets the application's Interactions Endpoint URL to `https://<host>/interactions` after
   the first deploy. Discord sends a PING to verify it.

## App setup

- HTTP interactions only, no gateway connection and no privileged intents.
- Install link scopes: `bot applications.commands`. Permissions: View Channel, Send Messages.
- Global commands, every one registered with `integration_types: [0]` (guild install) and
  `contexts: [0]` (guild channels only). A registration script (`npm run commands:register`)
  owns the definitions.

## Commands

| Command | Options | Reply |
|---|---|---|
| `/craft` | `recipe` (string, autocomplete), `private` (boolean, optional) | Who can craft it: up to 10 crafters with profession, skill and specialisation, sorted by skill; then "and N more" with the web book link |
| `/crafter` | `member` (string, autocomplete), `private` | That member's professions with skill, recipe counts and a book link |
| `/gcbook` | — | The tenant's web book link, always ephemeral |
| `/gcfeed` | `channel` (channel, optional), `off` (boolean) | Admin only. `default_member_permissions` = Manage Server, plus the N6 admin check server-side |

- Every reply is built by one helper that always sets `allowed_mentions: { parse: [] }` and
  escapes Discord markdown (`\ * _ ~ | > #` and backticks) in names and recipe names.
- Replies are ephemeral (flag 64) when `private` is true. A tenant setting picks the default.
- The footer always shows "Data as of <upload time>" as a Discord timestamp (`<t:unix:R>`).

## Request handling

1. Verify `X-Signature-Ed25519` and `X-Signature-Timestamp` over the raw body with
   `crypto.subtle` (Ed25519). Failure → 401. PING → PONG.
2. No `guild_id`, a `context` other than 0, or a `guild_id` with no active tenant → ephemeral
   "GuildCrafts isn't set up for this server." Nothing else is read.
3. `RL_USER` keyed by the Discord user ID, 10 commands per 60 s. Over the limit → ephemeral
   "Slow down a moment."
4. Load the tenant's latest snapshot from R2. Cache the parsed object in isolate memory keyed by
   snapshot ID. Answer within 3 s, or send a deferred reply (type 5) and edit `@original`.
5. Autocomplete (type 4 → type 8): prefix match first, then substring, at most 25 choices,
   names cut to 100 characters. Autocomplete seems to have no deferred reply (unverified), so it
   must answer within 3 s, loading from R2 only when the cache is cold.

## "New recipes learned" feed

- Off by default (`feed_enabled = 0`). An admin turns it on with `/gcfeed channel:#crafting` or
  on the web admin page.
- N6 computes the diff on upload. For each member present in both the previous and the new
  snapshot, recipes in the new one that weren't in the old one become events. Members new to the
  snapshot produce none, so a first sync doesn't flood the channel. A member with more than 10
  new recipes in one upload becomes one summary event ("Geo Prizm learned 37 Alchemy recipes").
- Cron every 10 minutes posts pending events: one message per tenant, up to 2,000 characters,
  through the same reply helper (no mentions). On 429 or error 1015, back off and retry next
  run.
- Before posting, drop events whose member isn't in the latest snapshot. That covers members
  who opted out (N2) between uploads.
- Events are deleted 7 days after posting (N6 retention).

## Tests

- Signature: valid, wrong key, tampered body, missing headers.
- Every command in an unbound guild, in a DM payload (no `guild_id`) and in a user-install
  context: refused, and no snapshot read happens (spy on R2).
- Every reply and feed message: `allowed_mentions.parse` is an empty array (test the helper and
  sample every command's output).
- Hostile names are escaped (the same fixture as N7, plus `@everyone`, `<@123>`, `` ` ``).
- Rate limit: the 11th command inside 60 s gets the slow-down reply.
- Feed: off by default; a first-time member creates no events; a member missing from the latest
  snapshot has unposted events dropped.

## Done when (from the issue)

- [ ] Installed in a second, unbound server, the bot refuses every command.
- [ ] The feed is off by default and respects opt-out.
- [ ] Rate-limited per user.

[#56]: https://github.com/lxhwes/GuildCrafts-Forever/issues/56
