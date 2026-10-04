# GuildCrafts — in-game commands

This file is mirrored to the secret gist https://gist.github.com/lxhwes/6ccdf7ad7451481d916410b65beff5ce (file `gc-forever-probes.md`), and the gist is never edited by hand.

Publish with:

```
gh gist edit 6ccdf7ad7451481d916410b65beff5ce --filename gc-forever-probes.md docs/ingame-commands.md
```

## GC

Run after login to see which TOC loaded: `@project-version@ 1469206` means GuildCrafts_Camelot.toc, and `2.0.2 nil` means another TOC.

```
/run local ok,v=pcall(C_AddOns.GetAddOnMetadata,"GuildCrafts","Version"); local _,p=pcall(C_AddOns.GetAddOnMetadata,"GuildCrafts","X-Curse-Project-ID"); print("GC",ok,v,p,C_AddOns.IsAddOnLoaded("GuildCrafts"));
```

## TOC

Run after login to see which TOC the client chose and why it did or didn't load: 16001 means the Camelot/Forever TOC, 20506 means the TBC GuildCrafts.toc, followed by loadable, reason, enable state and loaded.

```
/run local A=C_AddOns;local n="GuildCrafts";local _,_,_,l,r=A.GetAddOnInfo(n);print("TOC",A.GetAddOnInterfaceVersion(n),l,r,A.GetAddOnEnableState(n),A.IsAddOnLoaded(n));
```

## TS

Run with a profession window open to check the recipe scan inputs: prints profession name, parent profession name, recipe IDs returned and how many are learned.

```
/run local T=C_TradeSkillUI;local p=T.GetBaseProfessionInfo()or{};local d=T.GetAllRecipeIDs()or{};local n=0;for _,r in ipairs(d)do local i=T.GetRecipeInfo(r);n=n+(i and i.learned and 1 or 0);end;print("TS",p.professionName,p.parentProfessionName,#d,n);
```

## EXP

Run anywhere to read the expansion level APIs and client build: prints GetClassicExpansionLevel, GetExpansionLevel, GetServerExpansionLevel, LE_EXPANSION_LEVEL_CURRENT, build version and interface number, with nil for any API that doesn't exist.

```
/run print("EXP",GetClassicExpansionLevel and GetClassicExpansionLevel(),GetExpansionLevel and GetExpansionLevel(),GetServerExpansionLevel and GetServerExpansionLevel(),LE_EXPANSION_LEVEL_CURRENT,(GetBuildInfo()),select(4,GetBuildInfo()));
```

## PROF

Run after login, no window open. One line per `GetProfessions()` slot (1-7): slot, index, profession name. Forever's own ProfessionsBook reads slots as prof1, prof2, First Aid, Fishing, Cooking.

```
/run local t={GetProfessions()};for i=1,7 do local x=t[i];print("PROF",i,x,x and (GetProfessionInfo(x)));end;
```

## SKL

Run anywhere. `true`/`false` for whether each skill-line API exists: `C_SkillLine`, global `GetNumSkillLines`, global `GetSkillLineInfo`, `C_SkillInfo`. GuildCrafts falls back to the first three when `GetProfessions()` returns nothing.

```
/run print("SKL",C_SkillLine~=nil,GetNumSkillLines~=nil,GetSkillLineInfo~=nil,C_SkillInfo~=nil);
```

## ME

Run anywhere. Both returns of `UnitFullName`, `UnitName` and `UnitNameUnmodified`, then `UnitGUID`, `GetRealmName` and `GetNormalizedRealmName`.

```
/run local a,b=UnitFullName("player");local c,d=UnitName("player");local e,f=UnitNameUnmodified("player");print("ME",a,b,c,d,e,f,UnitGUID("player"),GetRealmName(),GetNormalizedRealmName());
```

## GR

Run in a guild. First line: whether `GetGuildRosterInfo` exists, member count, guild name. Run the second command only if the first says `true`: one line per online member with roster index, roster name and GUID (17th return). Your own row shows the roster's name shape for you.

```
/run print("GR",GetGuildRosterInfo~=nil,GetNumGuildMembers and GetNumGuildMembers(),(GetGuildInfo("player")));
```

```
/run for i=1,GetNumGuildMembers() do local n,_,_,_,_,_,_,_,o,_,_,_,_,_,_,_,g=GetGuildRosterInfo(i);if o then print("GR",i,n,g);end;end;
```

## SND

Run in a guild. Sends one tiny addon message (prefix `GCP`, text `x`) to GUILD and prints the sender name as the client reports it back to you. This is the name shape AceComm hands GuildCrafts. Other addons ignore the prefix.

```
/run local f=CreateFrame("Frame");C_ChatInfo.RegisterAddonMessagePrefix("GCP");f:RegisterEvent("CHAT_MSG_ADDON");f:SetScript("OnEvent",function(_,_,p,_,_,s)if p=="GCP"then print("SND",s);end;end);C_ChatInfo.SendAddonMessage("GCP","x","GUILD");
```

## RA

Run anywhere. Whether the restriction API exists: `C_RestrictedActions`, `GetAddOnRestrictionState`, `Enum.AddOnRestrictionType`, `Enum.AddOnRestrictionState`, then `C_ChatInfo.InChatMessagingLockdown()`. Expect `true true true true false` outside any restriction.

```
/run local R=C_RestrictedActions;print("RA",R~=nil,R and R.GetAddOnRestrictionState~=nil,Enum.AddOnRestrictionType~=nil,Enum.AddOnRestrictionState~=nil,C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown());
```

## RS

Run anywhere, after RA prints `true`. One line per restriction type: name, enum value, current state (0 Inactive, 1 Activating, 2 Active). Outside any restriction every state should be 0.

```
/run for k,v in pairs(Enum.AddOnRestrictionType)do print("RS",k,v,C_RestrictedActions.GetAddOnRestrictionState(v));end;
```

## RE

Run before entering a dungeon; a `/reload` disarms it, zoning does not. Prints `RE armed`, then one line per `ADDON_RESTRICTION_STATE_CHANGED`: time, type, state. At a boss pull expect type 1 (Encounter) with state 1 or 2; at the kill or wipe, type 1 with state 0. An error saying the event is unknown means the client doesn't have it.

```
/run local f=CreateFrame("Frame");f:RegisterEvent("ADDON_RESTRICTION_STATE_CHANGED");f:SetScript("OnEvent",function(_,_,t,s)print("RE",date("%H:%M:%S"),t,s);end);print("RE armed");
```

## PSL

Run anywhere. Every profession skill line the client reports, with its profession and parent names. Shows whether Jewelcrafting and Inscription exist on this client at all.

```
/run local T=C_TradeSkillUI;for _,id in ipairs(T.GetAllProfessionTradeSkillLines()or{})do local i=T.GetProfessionInfoBySkillLineID(id);print("PSL",id,i and i.professionName,i and i.parentProfessionName);end;
```

## SP

Run any time GuildCrafts is loaded. GuildCrafts' own pause state: `ShouldPause()`, then the combat, instance and transition flags, then the restriction types currently held (comma-separated enum values; 1 = Encounter, 4 = Map, 5 = Chat). Outside everything: `SP false false false false` and nothing after.

```
/run local P=GuildCrafts.SyncPausePolicy;local t={};for k in pairs(P._restrictions or {})do t[#t+1]=k;end;print("SP",P:ShouldPause(),P._inCombat,P._inInstance,P._inTransition,table.concat(t,","));
```

## GRO

Run in a guild twice, once with the roster's Show Offline Members unchecked and once checked: total members, online members, offline rows with a name, and how many of those have a GUID. An offline count of 0 with it unchecked means the roster lists only online members; offline rows with a GUID count of 0 means those rows have no GUID.

```
/run local R=GetGuildRosterInfo;if not R then print("GRO nil");return;end;local t,o=GetNumGuildMembers();local f,g=0,0;for i=1,t do local n,_,_,_,_,_,_,_,x,_,_,_,_,_,_,_,u=R(i);if n and not x then f=f+1;if u then g=g+1;end;end;end;print("GRO",t,o,f,g);
```

## CHL

Run anywhere. `true`/`false` for whether each chat API exists: global `ChatEdit_InsertLink`, global `ChatFrame_OpenChat`, `ChatFrameUtil.InsertLink`, `ChatFrameUtil.OpenChat`. GuildCrafts' shift-click link and `[W]` button call the first two; `false` there means both error on click.

```
/run print("CHL",ChatEdit_InsertLink~=nil,ChatFrame_OpenChat~=nil,ChatFrameUtil~=nil and ChatFrameUtil.InsertLink~=nil,ChatFrameUtil~=nil and ChatFrameUtil.OpenChat~=nil);
```

## TIME

Run anywhere (H2). `GetServerTime()`, local `time()`, server minus local in seconds, and server time as UTC. The UTC time should match the real UTC time, and the difference should be a few seconds at most on a clock that syncs over the network. `nil` means `GetServerTime` is missing.

```
/run local s=GetServerTime and GetServerTime();local l=time();print("TIME",s,l,s and s-l,s and date("!%Y-%m-%d %H:%M:%S",s));
```

## BLD

Run anywhere (Q1). Every `GetBuildInfo()` return: version, build number, build date, interface number, localized version, build info.

```
/run print("BLD",GetBuildInfo());
```

## GTS

Run with your own profession window open, then again with a guildmate's profession opened from the guild roster, if the client offers one (H10). One line per `C_TradeSkillUI` function: its name, then its return value. `nil` means the function doesn't exist, and text instead of `true`/`false` is the error it raised. On your own profession, everything after `IsGuildTradeSkillsEnabled` should be `false`.

```
/run local T=C_TradeSkillUI;for _,f in ipairs{"IsGuildTradeSkillsEnabled","IsTradeSkillLinked","IsTradeSkillGuild","IsTradeSkillGuildMember","IsNPCCrafting"}do local g=T[f];print("GTS",f,g and tostring(select(2,pcall(g)))or"nil");end;
```

## CHT

Run anywhere (H14). `true`/`false` for global `SendChatMessage`, `C_ChatInfo.SendChatMessage`, whether the two are the same function, global `ChatFrame_SendTell`, `ChatFrameUtil.SendTell`, `ChatFrameUtil.ReplyTell`. GuildCrafts' `!gc` replies call the first.

```
/run local C,U=C_ChatInfo,ChatFrameUtil;print("CHT",SendChatMessage~=nil,C.SendChatMessage~=nil,SendChatMessage==C.SendChatMessage,ChatFrame_SendTell~=nil,U~=nil and U.SendTell~=nil,U~=nil and U.ReplyTell~=nil);
```

## TELL

Run anywhere, after CHT (H14). Opens a whisper to your own two-word name and sends nothing. Prints your name and whether a tell function exists. If the chat box header reads `Tell First Surname:` with both words, the tell API handles two-word names. Press Escape to close it.

```
/run local n=UnitName("player");local U=ChatFrameUtil;local f=U and U.SendTell or ChatFrame_SendTell;print("TELL",n,f~=nil);if f then f(n);end;
```

## RL

Run anywhere (H7). `true`/`false` for whether `ReloadUI` and `C_UI.Reload` exist, then whether `ReloadUI` is still Blizzard's untainted copy.

```
/run print("RL",ReloadUI~=nil,C_UI~=nil and C_UI.Reload~=nil,issecurevariable("ReloadUI"));
```

## RLX

Run last, out of combat, when a reload is fine (H7). It calls `ReloadUI()` from addon code the way `/gc reset` does. If the UI reloads, it isn't protected. If you see `RLX call` and then an `RLX ADDON_ACTION_FORBIDDEN` or `ADDON_ACTION_BLOCKED` line, or a popup, and the UI doesn't reload, it is protected.

```
/run local f=CreateFrame("Frame");pcall(f.RegisterEvent,f,"ADDON_ACTION_FORBIDDEN");pcall(f.RegisterEvent,f,"ADDON_ACTION_BLOCKED");f:SetScript("OnEvent",function(_,e,a,x)print("RLX",e,a,x);end);print("RLX call");ReloadUI();
```
