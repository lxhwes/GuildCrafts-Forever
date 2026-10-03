# Origin

GuildCrafts was written by dkruenbo and published at
https://github.com/dkruenbo/GuildCrafts under the MIT licence. Upstream stopped at
2.0.2 and was marked unmaintained on 2026-09-08.

This repository carries that history unchanged and adds a WoW Forever flavor.
dkruenbo gave written permission to fork and added Alex Howes as an author on the
CurseForge project (ID 1469206), so Forever ships as another flavor of the same addon.

## Scope

- Alex Howes maintains the Forever flavor only.
- The Classic Era, TBC, Wrath, Cata and Mists flavors are inherited from upstream. Their
  TOCs and `Data/` files are kept as upstream shipped them. They are not maintained or
  published from here: the release workflow packages the Forever flavor only.

## Author's permission

Both messages are from the upstream author to Alex Howes. They're signed `_Lektor`; dkruenbo's commits in
this repository's history carry the author name `_lektor`. They're quoted verbatim.

Permission to fork and continue the addon:

> Absolutely, go for it! I'm really glad to hear you got it working on the Forever beta.
>
> You're more than welcome to fork the source and continue working on it. I won't be
> developing Forever support myself, so I'm happy to see someone else pick it up if they
> want to.
>
> There are also a couple of RFCs in the GitHub repo documenting the sync protocol and
> overall architecture. They should give Claude some useful context when working through the
> codebase, especially around the DR/BDR election and sync protocol.
>
> Good luck with it, and thanks for wanting to keep GuildCrafts going! _Lektor

Permission to keep that message here as the record:

> You have my permission to include my message above as an explicit record of authorization
> in the repo. Feel free to quote it or include a slightly adapted version if that's easier
> for CurseForge.

The RFCs mentioned in the first message are in [`RFC/`](../RFC/).
