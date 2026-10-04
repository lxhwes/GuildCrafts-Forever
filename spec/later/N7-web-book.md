# N7: Web recipe book — implementation spec

Issue [#57](https://github.com/lxhwes/GuildCrafts-Forever/issues/57). Written 2026-10-04. Status:
blocked on N6 ([#56]). Lives in the new repository (ADR AD1), under `web/`, served as static
assets by the N6 Worker. When that repo exists, move this file there.

## Start here (for a new session)

1. Read `spec/later/N4-adr-external-services.md` (AD9, threats I3 and I5) and
   `spec/later/N6-backend.md` (the `book` and `meta` endpoints, sessions).
2. Read `docs/export-format.md` (from N1) for the data.
3. Read the addon's search behaviour so results feel familiar: `Data:SearchRecipes` and its
   fuzzy mode (`GuildCrafts/Modules/Data.lua:2550-2700` at `4c9492b`), and
   `Data:GetStalenessTag` (`:1119`).

## Stack

Vite, Preact and TypeScript, built to static files. Preact renders text nodes, so escaping is
the default; `dangerouslySetInnerHTML` is banned by an ESLint rule. No third-party scripts,
fonts or analytics. The Worker sends
`Content-Security-Policy: default-src 'self'; img-src 'self'; style-src 'self'; frame-ancestors 'none'`,
`X-Robots-Tag: noindex, nofollow` and `Referrer-Policy: no-referrer`.

## Pages

- `/t/<tenant>/`, signed out: a "Sign in with Discord" button and nothing else. The page looks
  the same for any tenant ID, valid or not.
- Signed in, not a member: one line ("You need to be in this guild's Discord server") and a
  sign-out link.
- Signed in member: a header with the guild name and **"Data as of <upload time>"**, in the
  viewer's local time, with the snapshot's `generatedAt` in a tooltip. Then one search box and
  three tabs:
  - **Recipes**: substring match on recipe names, plus the addon's fuzzy fallback (vowel
    stripping) when nothing matches. Each result lists its crafters: name, profession, skill and
    max, and specialisation.
  - **Members**: members by name; a member shows professions with skill and their recipes,
    grouped by category.
  - **Professions**: each profession's members sorted by skill.
- Stale marker: when a member's `lastUpdate` is 30 days or more before now, show `Nd ago`
  (under 60 days) or `Nmo ago`, as `Data:GetStalenessTag` does in game.
- Unresolved names (`name: null`) show as "Unknown member" and are listed last.

The whole snapshot loads once (about 40 KB gzipped for 100 members) and search runs in the
browser. Re-fetch when the tab regains focus if the `meta` snapshot ID has changed.

## Phone-friendly

One column under 640 px; tap targets at least 44 px; usable at 360 px wide; the search box stays
visible while scrolling. Test in Chrome's device mode at 360 × 740.

## Optional, later

Recipe links to a database site. Wowhead has a Forever section, but its URL scheme for Forever
items and spells is unverified. Check it before building links.

## Tests

- Component tests (Vitest and Testing Library) with a hostile fixture. Names and recipe names
  include `<img src=x onerror=alert(1)>`, `"><script>alert(1)</script>`, `javascript:alert(1)`,
  `@everyone`, a right-to-left override character, a 500-character name and combining-character
  stacking. Assert that each renders as literal text and that no element or attribute was
  created from it.
- Playwright against `wrangler dev` with a seeded tenant and stubbed Discord:
  - a signed-out visitor sees only the sign-in button;
  - a non-member sees no data;
  - a member can search;
  - the network log shows no request for another tenant's data.
- The fixture contains no opted-out members, because the addon never exports them. The N6
  sanitiser test covers marked members. Here, assert that a member absent from the latest
  snapshot doesn't appear even if the previous snapshot had them.

## Done when (from the issue)

- [ ] Signed-in members of the bound Discord server can search; anyone else gets nothing.
- [ ] Opted-out members never appear.
- [ ] Output escaping is tested with hostile names.

[#56]: https://github.com/lxhwes/GuildCrafts-Forever/issues/56
