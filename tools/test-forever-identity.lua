-- Forever member-key regressions (Modules/ForeverIdentity.lua) with a stubbed roster,
-- and Comms' sender resolution on top of it (F26).
-- Run from the repository root: lua5.1 tools/test-forever-identity.lua
-- Roster and name shapes match the ME, GR and SND probes from 2026-10-02.
local now = 1000
local roster
local logged = {}
local noop = function() end
local me, motiv, kuw = "Player-4619-012F81BC", "Player-4619-010E2E63", "Player-4613-005A5F36"

time = function() return now end
GetTime = function() return now end
GetClassicExpansionLevel = function() return 0 end
GetSpellInfo = function() return nil end
IsInGuild = function() return true end
GetGuildInfo = function() return "Grim" end
GetRealmName = function() return "Classic Beta PvP" end
UnitFullName = function() return "Geo", "Prizm" end
UnitName = function() return "Geo", "Prizm" end
UnitNameUnmodified = function() return "Geo", "Prizm" end
UnitGUID = function() return me end
GetNumGuildMembers = function() return #roster end
GetGuildRosterInfo = function(i)
    local r = roster[i]
    return r[1], nil, nil, nil, nil, nil, nil, nil, r[2], nil, nil, nil, nil, nil, nil, nil, r[3]
end
local function NewAddon()
    return {
        VERSION = 3,
        DATA_FORMAT_VERSION = 3,
        NewModule = function()
            return { ScheduleTimer = noop, CancelTimer = noop, ScheduleRepeatingTimer = noop, RegisterComm = noop }
        end,
        Debug = function(_, ...)
            local parts = {}
            for i = 1, select("#", ...) do parts[i] = tostring((select(i, ...))) end
            logged[#logged + 1] = table.concat(parts, " ")
        end,
        Print = noop,
        Printf = noop,
    }
end
GuildCrafts = NewAddon()
dofile("GuildCrafts/Modules/Comms.lua")
local Comms = GuildCrafts.Comms
local Data
local sent = {}
local realSendMessage = Comms.SendMessage
Comms.SendMessage = function(_, kind, payload) sent[#sent + 1] = { kind, payload } end

-- Deliver one addon message as AceComm would, with the envelope already decoded.
local function receive(sender, msgType, payload, distribution)
    Comms.Deserialize = function() return true, { t = msgType, v = 3, term = 0, p = payload or {} } end
    Comms:OnCommReceived("GuildCrafts", "Uxx", distribution or "GUILD", sender)
end

local function wasLogged(needle)
    for _, line in ipairs(logged) do
        if line:find(needle, 1, true) then return true end
    end
    return false
end

local function reset()
    now = now + 10  -- step past the identity module's roster rescan interval
    roster = {
        { "Geo Prizm", true, me },
        { "Motiv Hysteria", true, motiv },
        { "Kuw Pal", false, kuw },
    }
    -- Fresh modules, so ForeverIdentity's name maps start empty.
    dofile("GuildCrafts/Modules/Data.lua")
    dofile("GuildCrafts/Modules/ForeverIdentity.lua")
    Data = GuildCrafts.Data
    Data.db = { global = {} }
    logged, sent = {}, {}
    Comms:OnInitialize()
    Comms.addonUsers[me] = { version = 3, lastSeen = now }
    GuildCrafts._gcLastAddonAck = nil
end

-- Cold start: the roster hasn't loaded, so no sender name resolves.
local function coldStart()
    roster = {}
    now = now + 10
end

local tests = {}
local function test(name, fn) tests[#tests + 1] = { name, fn } end

test("player key is the player GUID", function()
    assert(Data:GetPlayerKey() == me)
end)

test("pre-GUID self entry moves to the GUID key", function()
    Data.db.global["Grim-Classic Beta PvP"] = {
        ["Geo-Prizm"] = { lastUpdate = 5, professions = { Alchemy = { recipes = { [1] = {} } } } },
    }
    local gdb = Data:GetGuildDB()
    assert(gdb[me] and gdb[me].professions.Alchemy, "entry not under GUID")
    assert(gdb["Geo-Prizm"] == nil, "legacy key left behind")
end)

test("roster names, beta keys and realm-suffixed senders resolve to GUIDs", function()
    assert(Data:NormalizeMemberKey("Motiv Hysteria") == motiv)
    assert(Data:NormalizeMemberKey("Motiv-Hysteria") == motiv)
    assert(Data:NormalizeMemberKey("Kuw Pal-SomeRealm") == kuw)
    assert(Data:NormalizeMemberKey(kuw) == kuw)
end)

test("unknown names resolve to nil", function()
    assert(Data:NormalizeMemberKey("Nobody Here") == nil)
end)

test("display and whisper names come from the roster", function()
    Data:GetPlayerKey()
    assert(Data:GetMemberName(kuw) == "Kuw Pal")
    assert(Data:GetMemberName(me) == "Geo Prizm")
    assert(Data:GetWhisperTarget(motiv) == "Motiv Hysteria")
    assert(Data:GetWhisperTarget("Player-1-ABC") == nil, "whisper target for unknown GUID")
end)

test("online cache is keyed by GUID", function()
    Data:RebuildOnlineCache()
    assert(Data:IsMemberOnline(motiv) == true)
    assert(Data:IsMemberOnline(kuw) == false)
end)

test("roster pruning marks only non-roster keys absent", function()
    local gdb = Data:GetGuildDB()
    gdb[me] = { lastUpdate = 10, professions = {} }
    gdb[motiv] = { lastUpdate = 10, professions = {} }
    gdb["Ghost Member"] = { lastUpdate = 10, professions = {} }
    Data:PruneRoster()
    assert(gdb[motiv]._absentSince == nil, "roster member marked absent")
    assert(gdb["Ghost Member"]._absentSince ~= nil, "non-roster key not marked")
    assert(gdb[me]._absentSince == nil, "self marked absent")
end)

test("H22: pruning keeps a partial copy a delta left at revision 0", function()
    local gdb = Data:GetGuildDB()
    gdb[me] = { lastUpdate = 10, professions = {} }
    gdb[motiv] = { lastUpdate = 0, professions = { Alchemy = { lastUpdate = 900, recipes = { [1] = { name = "New" } } } } }
    gdb[kuw] = { lastUpdate = 0, professions = {} }
    Data:PruneRoster()
    assert(gdb[motiv] and gdb[motiv].professions.Alchemy.recipes[1], "partial copy pruned")
    assert(gdb[kuw] == nil, "empty revision-0 entry kept")
end)

test("H22: inactive pruning counts a fresh delta kept below an old revision", function()
    now = now + 100 * 86400
    local old, gdb = now - 50 * 86400, Data:GetGuildDB()
    gdb[me] = { lastUpdate = now, professions = {} }
    gdb[motiv] = { lastUpdate = old, professions = { Alchemy = { lastUpdate = now, recipes = { [1] = {} } } } }
    gdb[kuw] = { lastUpdate = old, professions = { Alchemy = { lastUpdate = old, recipes = { [1] = {} } } } }
    Data:PruneRoster()
    assert(gdb[motiv], "entry with a fresh delta pruned as inactive")
    assert(gdb[kuw] == nil, "inactive entry kept")
    -- A partial copy at revision 0 that never got repaired ages out the same way.
    gdb[kuw] = { lastUpdate = 0, professions = { Alchemy = { lastUpdate = old, recipes = { [1] = {} } } } }
    Data:PruneRoster()
    assert(gdb[kuw] == nil, "stale partial copy kept")
end)

test("HELLO from an unresolved sender is keyed by its payload GUID", function()
    coldStart()
    receive("Kuw Pal", "HELLO", { sender = kuw, version = 3 })
    assert(Comms.addonUsers[kuw], "sender not registered")
    assert(Comms.unresolvedSenderDrops == 0, "HELLO counted as dropped")
    assert(Comms.senderFallbacks == 1, "fallback not counted")
    assert(wasLogged("Sender fallback: HELLO from Kuw Pal keyed by payload GUID " .. kuw), "fallback not logged")
end)

test("an unresolvable member still takes part in the DR election", function()
    coldStart()
    receive("Kuw Pal", "HELLO", { sender = kuw, version = 3 })
    -- 4613 sorts before 4619, so every client must elect the cross-server member.
    assert(Comms.currentDR == kuw, "DR is " .. tostring(Comms.currentDR))
    assert(Comms.myRole == "BDR", "role is " .. tostring(Comms.myRole))
end)

test("HEARTBEAT from an unresolved DR is keyed by its payload GUID", function()
    coldStart()
    receive("Kuw Pal", "HEARTBEAT", { dr = kuw, timestamp = now })
    assert(Comms.addonUsers[kuw], "DR not registered")
    assert(Comms.lastDRHeartbeat == now, "heartbeat not recorded")
    assert(Comms.unresolvedSenderDrops == 0, "HEARTBEAT counted as dropped")
end)

test("a roster spelling with a server suffix still matches the sender", function()
    roster[3] = { "Kuw Pal-Server", false, kuw }
    receive("Kuw Pal", "HELLO", { sender = kuw, version = 3 })
    assert(Comms.addonUsers[kuw], "suffixed roster spelling refused")
end)

test("a payload GUID the roster gives to someone else is refused", function()
    receive("Evil Twin", "HELLO", { sender = motiv, version = 3 })
    assert(Comms.addonUsers[motiv] == nil, "impersonated GUID registered")
    assert(Comms.unresolvedSenderDrops == 1, "refusal not counted as a drop")
    assert(Comms.senderFallbackRefusals == 1, "refusal not counted")
    assert(wasLogged("Dropped HELLO from unresolved sender Evil Twin"), "drop not logged")
    assert(wasLogged("roster names it Motiv Hysteria"), "refusal reason not logged")
end)

test("a payload claiming our own GUID is refused", function()
    Data:GetPlayerKey()
    coldStart()
    receive("Evil Twin", "HEARTBEAT", { dr = me, timestamp = now })
    assert(Comms.lastDRHeartbeat == 0, "spoofed heartbeat recorded")
    assert(Comms.senderFallbackRefusals == 1, "refusal not counted")
end)

test("payload values that aren't player GUIDs are refused", function()
    coldStart()
    for _, claim in ipairs({ "Kuw Pal", "Kuw-Pal", "Creature-0-4613-0-1-2-3", "Player-4613", 7 }) do
        receive("Kuw Pal", "HELLO", { sender = claim, version = 3 })
    end
    receive("Kuw Pal", "HELLO", { version = 3 })
    local count = 0
    for _ in pairs(Comms.addonUsers) do count = count + 1 end
    assert(count == 1, count .. " addon users after bad claims")
    assert(Comms.unresolvedSenderDrops == 6, "drops: " .. Comms.unresolvedSenderDrops)
end)

test("a payload GUID is only taken from the GUILD channel", function()
    coldStart()
    receive("Kuw Pal", "HELLO", { sender = kuw, version = 3 }, "WHISPER")
    assert(Comms.addonUsers[kuw] == nil, "whispered claim accepted")
    assert(Comms.unresolvedSenderDrops == 1, "whispered claim not dropped")
end)

test("one name can't claim a second GUID, and one GUID can't take a second name", function()
    coldStart()
    local other = "Player-4613-005A5F37"
    receive("Kuw Pal", "HELLO", { sender = kuw, version = 3 })
    receive("Kuw Pal", "HELLO", { sender = other, version = 3 })
    assert(Comms.addonUsers[other] == nil, "second GUID for one name accepted")
    receive("Someone Else", "HELLO", { sender = kuw, version = 3 })
    assert(Comms.senderFallbackRefusals == 2, "refusals: " .. Comms.senderFallbackRefusals)
end)

test("messages without a payload GUID still drop for an unknown sender", function()
    coldStart()
    receive("Kuw Pal", "GC_ACK")
    receive("Kuw Pal", "SYNC_REQUEST", { sender = kuw, vector = {}, retry = 0 })
    assert(Comms.addonUsers[kuw] == nil, "sender registered without a fallback")
    assert(GuildCrafts._gcLastAddonAck == nil, "GC_ACK handled")
    assert(Comms.unresolvedSenderDrops == 2, "drops: " .. Comms.unresolvedSenderDrops)
end)

test("a recent fallback resolves the same sender's later messages", function()
    coldStart()
    receive("Kuw Pal", "HELLO", { sender = kuw, version = 3 })
    Comms.addonUsers[kuw] = nil
    now = now + 60
    receive("Kuw Pal", "GC_ACK")
    assert(GuildCrafts._gcLastAddonAck == now, "GC_ACK dropped")
    assert(Comms.addonUsers[kuw], "GC_ACK sender not touched")
    assert(Comms.unresolvedSenderDrops == 0, "drops: " .. Comms.unresolvedSenderDrops)
    assert(wasLogged("Sender fallback: GC_ACK from Kuw Pal keyed by cached " .. kuw), "cache hit not logged")
end)

test("a cached sender's SYNC_REQUEST can't name a different requester", function()
    coldStart()
    local other = "Player-4613-00000001"
    receive("Kuw Pal", "HELLO", { sender = kuw, version = 3 })
    receive("Kuw Pal", "SYNC_REQUEST", { sender = other, vector = {}, retry = 0 })
    assert(Comms.addonUsers[other] == nil, "requester GUID taken from the payload")
    assert(Comms.senderFallbackRefusals == 1, "refusal not counted")
    receive("Kuw Pal", "SYNC_REQUEST", { sender = kuw, vector = {}, retry = 0 })
    assert(Comms.unresolvedSenderDrops == 0, "drops: " .. Comms.unresolvedSenderDrops)
end)

test("a resolved sender can't claim another GUID in HELLO, HEARTBEAT or SYNC_REQUEST", function()
    receive("Motiv Hysteria", "HELLO", { sender = kuw, version = 3 })
    receive("Motiv Hysteria", "HEARTBEAT", { dr = kuw, timestamp = now })
    receive("Motiv Hysteria", "SYNC_REQUEST", { sender = kuw, vector = {}, retry = 0 })
    assert(Comms.addonUsers[kuw] == nil, "claimed GUID registered")
    assert(Comms.addonUsers[motiv] == nil, "mismatched message handled")
    assert(Comms.lastDRHeartbeat == 0, "mismatched heartbeat recorded")
    assert(Comms.senderFallbackRefusals == 3, "refusals: " .. Comms.senderFallbackRefusals)
    assert(Comms.unresolvedSenderDrops == 0, "mismatch counted as unresolved")
    assert(wasLogged("Sender mismatch: HEARTBEAT from Motiv Hysteria (" .. motiv .. ") claims " .. kuw),
        "mismatch not logged")
    receive("Motiv Hysteria", "HELLO", { sender = motiv, version = 3 })
    assert(Comms.addonUsers[motiv], "matching HELLO dropped")
end)

-- Kuw's stored entry before anyone tries to change it.
local function kuwAlchemy()
    local gdb = Data:GetGuildDB()
    gdb[kuw] = { lastUpdate = 500, professions = { Alchemy = { lastUpdate = 500, recipes = { [1] = { name = "Old" } } } } }
    return gdb[kuw]
end

test("H23: a DELTA_UPDATE for another member is refused for add, touch and remove_profession", function()
    local entry = kuwAlchemy()
    receive("Motiv Hysteria", "DELTA_UPDATE", { type = "add", member = kuw, profession = "Alchemy",
        recipes = { [2] = { name = "Forged" } }, lastUpdate = 600, dropped = 0 })
    receive("Motiv Hysteria", "DELTA_UPDATE", { type = "touch", member = kuw, profession = "Alchemy",
        lastUpdate = 700 })
    receive("Motiv Hysteria", "DELTA_UPDATE", { type = "remove_profession", member = kuw,
        profession = "Alchemy", lastUpdate = 800, x = 1 })
    local alchemy = entry.professions.Alchemy
    assert(alchemy and alchemy.recipes[1], "forged removal applied")
    assert(alchemy.recipes[2] == nil, "forged recipe added")
    assert(entry.lastUpdate == 500 and alchemy.lastUpdate == 500, "forged revision applied")
    assert(entry.dropped == nil, "forged drop recorded")
    assert(Comms.deltaSenderRefusals == 3, "refusals: " .. tostring(Comms.deltaSenderRefusals))
    assert(Comms.senderFallbackRefusals == 0, "counted as a fallback refusal")
    assert(wasLogged("Sender mismatch: DELTA_UPDATE from Motiv Hysteria (" .. motiv .. ") claims " .. kuw),
        "mismatch not logged")
end)

test("H23: a cached sender's DELTA_UPDATE can't name another member", function()
    coldStart()
    local entry = kuwAlchemy()
    receive("Alt One", "HELLO", { sender = "Player-4613-00000001", version = 3 })
    receive("Alt One", "DELTA_UPDATE", { type = "add", member = kuw, profession = "Alchemy",
        recipes = { [2] = { name = "Forged" } }, lastUpdate = 600, dropped = 0 })
    assert(entry.professions.Alchemy.recipes[2] == nil, "forged recipe added")
    assert(Comms.deltaSenderRefusals == 1, "refusals: " .. tostring(Comms.deltaSenderRefusals))
end)

test("H23: a member's own DELTA_UPDATEs still apply on peers", function()
    receive("Motiv Hysteria", "DELTA_UPDATE", { type = "add", member = motiv, profession = "Alchemy",
        recipes = { [2] = { name = "Elixir" } }, lastUpdate = 600, dropped = 0 })
    local entry = Data:GetGuildDB()[motiv]
    assert(entry and entry.professions.Alchemy.recipes[2], "own recipe not added")
    receive("Motiv Hysteria", "DELTA_UPDATE", { type = "touch", member = motiv, profession = "Alchemy",
        lastUpdate = 700 })
    assert(entry.lastUpdate == 700, "own touch not applied: " .. entry.lastUpdate)
    receive("Motiv Hysteria", "DELTA_UPDATE", { type = "remove_profession", member = motiv,
        profession = "Alchemy", lastUpdate = 800, x = 1 })
    assert(entry.professions.Alchemy == nil and entry.dropped.Alchemy == 800, "own drop not applied")
    assert(Comms.deltaSenderRefusals == 0, "refusals: " .. tostring(Comms.deltaSenderRefusals))
end)

test("a revoked false claim doesn't come back on the next HELLO", function()
    coldStart()
    local claimed = "Player-4613-00000001"
    receive("Kuw Pal", "HELLO", { sender = claimed, version = 3 })
    roster = { { "Geo Prizm", true, me }, { "Kuw Pal", true, kuw } }
    now = now + 10
    receive("Kuw Pal", "HELLO", { sender = claimed, version = 3 })
    assert(Comms.senderFallbackRevocations == 1, "revocation not counted")
    assert(Comms.addonUsers[claimed] == nil, "false claim came back")
    assert(Comms.currentDR ~= claimed, "false claim still DR")
    receive("Kuw Pal", "HELLO", { sender = kuw, version = 3 })
    assert(Comms.currentDR == kuw, "DR is " .. tostring(Comms.currentDR))
end)

test("whispers to a fallback-keyed GUID go to the name that sent it", function()
    coldStart()
    local targets = {}
    Comms.Serialize = function() return "x" end
    Comms.SendCommMessage = function(_, _, _, _, target) targets[#targets + 1] = target end
    receive("Kuw Pal", "HELLO", { sender = kuw, version = 3 })
    realSendMessage(Comms, "SYNC_RESPONSE", {}, "WHISPER", kuw)
    assert(targets[1] == "Kuw Pal", "whisper target " .. tostring(targets[1]))
    Comms.addonUsers[kuw] = nil
    now = now + Comms.SENDER_FALLBACK_TTL + 1
    realSendMessage(Comms, "SYNC_RESPONSE", {}, "WHISPER", kuw)
    assert(#targets == 1, "whispered after the fallback expired")
end)

test("the fallback cache expires once the peer leaves the election", function()
    coldStart()
    receive("Kuw Pal", "HELLO", { sender = kuw, version = 3 })
    Comms.addonUsers[kuw] = nil  -- as the DR watchdog would
    now = now + Comms.SENDER_FALLBACK_TTL + 1
    receive("Kuw Pal", "GC_ACK")
    assert(GuildCrafts._gcLastAddonAck == nil, "expired entry used")
    assert(Comms.unresolvedSenderDrops == 1, "drops: " .. Comms.unresolvedSenderDrops)
end)

test("a peer still in the election stays resolvable past the TTL", function()
    coldStart()
    receive("Kuw Pal", "HELLO", { sender = kuw, version = 3 })
    now = now + Comms.SENDER_FALLBACK_TTL + 60
    receive("Kuw Pal", "SYNC_REQUEST", { sender = kuw, vector = {}, retry = 1 })
    receive("Kuw Pal", "GC_ACK")
    assert(GuildCrafts._gcLastAddonAck == now, "GC_ACK dropped")
    assert(Comms.unresolvedSenderDrops == 0, "drops: " .. Comms.unresolvedSenderDrops)
end)

test("a quiet claim gives way to another sender after the TTL", function()
    coldStart()
    receive("Alt One", "HELLO", { sender = kuw, version = 3 })
    now = now + Comms.SENDER_FALLBACK_TTL + 1
    receive("Alt Two", "HELLO", { sender = kuw, version = 3 })
    assert(Comms.senderFallbackRefusals == 0, "refusals: " .. Comms.senderFallbackRefusals)
    assert(Comms._senderFallback["Alt Two"], "new claimant not cached")
    assert(Comms._senderFallback["Alt One"] == nil, "quiet claimant kept")
end)

test("a full cache keeps active peers and refuses a new claim", function()
    coldStart()
    local claimed = "Player-4613-00000001"
    receive("Kuw Pal", "HELLO", { sender = claimed, version = 3 })
    for i = 2, Comms.SENDER_FALLBACK_MAX + 1 do
        now = now + 1
        receive("Alt " .. i, "HELLO", { sender = string.format("Player-4619-%08X", 0x100 + i), version = 3 })
    end
    assert(Comms._senderFallback["Kuw Pal"], "active peer's mapping evicted")
    assert(Comms.senderFallbackRefusals == 1, "refusals: " .. Comms.senderFallbackRefusals)
    assert(Comms:FallbackWhisperTarget(claimed) == "Kuw Pal", "active peer lost its whisper target")
    -- The roster then contradicts the oldest claim with no fresh HELLO to rebuild it.
    roster = { { "Geo Prizm", true, me }, { "Kuw Pal", true, kuw } }
    now = now + 10
    receive("Kuw Pal", "GC_ACK")
    assert(Comms.addonUsers[claimed] == nil, "contradicted GUID kept")
    assert(Comms.currentDR == kuw, "DR is " .. tostring(Comms.currentDR))
end)

test("the cache holds a whole roster of unresolvable members", function()
    local n = Comms.SENDER_FALLBACK_MAX + 10
    -- Roster rows without GUIDs: counted, but no name resolves.
    roster = {}
    for i = 1, n do roster[i] = { "Member " .. i, true, nil } end
    now = now + 10
    for i = 1, n do
        now = now + 1
        receive("Member " .. i, "HELLO", { sender = string.format("Player-4619-%08X", 0x100 + i), version = 3 })
    end
    assert(Comms.senderFallbackRefusals == 0, "refusals: " .. Comms.senderFallbackRefusals)
    roster[n + 1] = { "New Member", true, nil }
    local newcomer = "Player-4613-00000001"
    receive("New Member", "HELLO", { sender = newcomer, version = 3 })
    assert(Comms.addonUsers[newcomer], "newcomer refused")
    assert(Comms.currentDR == newcomer, "DR is " .. tostring(Comms.currentDR))
end)

test("a full cache drops its oldest inactive entry for a new claim", function()
    coldStart()
    local max = Comms.SENDER_FALLBACK_MAX
    for i = 1, max + 1 do
        now = now + 1
        if i == max + 1 then
            Comms.addonUsers["Player-4613-00000002"] = nil  -- Alt 2 left the election
            now = now + Comms.SENDER_FALLBACK_TTL
        end
        receive("Alt " .. i, "HELLO", { sender = string.format("Player-4613-%08X", i), version = 3 })
    end
    local count = 0
    for _ in pairs(Comms._senderFallback) do count = count + 1 end
    assert(count == max, count .. " cache entries")
    assert(Comms._senderFallback["Alt 1"], "active entry evicted")
    assert(Comms._senderFallback["Alt 2"] == nil, "inactive entry kept")
    assert(Comms._senderFallback["Alt " .. (max + 1)], "newest entry missing")
end)

test("the roster confirming the fallback GUID retires the cache entry", function()
    coldStart()
    receive("Kuw Pal", "HELLO", { sender = kuw, version = 3 })
    roster = { { "Geo Prizm", true, me }, { "Kuw Pal", true, kuw } }
    now = now + 10
    receive("Kuw Pal", "GC_ACK")
    assert(Comms._senderFallback["Kuw Pal"] == nil, "cache entry kept after the roster resolved it")
    assert(Comms.addonUsers[kuw], "confirmed peer evicted")
    assert(wasLogged("Sender fallback confirmed: Kuw Pal is " .. kuw), "confirmation not logged")
end)

test("the roster contradicting the fallback GUID evicts it and re-elects", function()
    coldStart()
    local claimed = "Player-4613-00000001"
    receive("Kuw Pal", "HELLO", { sender = claimed, version = 3 })
    assert(Comms.currentDR == claimed, "claimed GUID not elected")
    roster = { { "Geo Prizm", true, me }, { "Kuw Pal", true, kuw } }
    now = now + 10
    receive("Kuw Pal", "GC_ACK")
    assert(Comms.addonUsers[claimed] == nil, "contradicted GUID kept")
    assert(Comms.addonUsers[kuw], "roster GUID not touched")
    assert(Comms.currentDR == kuw, "DR is " .. tostring(Comms.currentDR))
    assert(Comms.senderFallbackRevocations == 1, "revocation not counted")
    assert(wasLogged("Sender fallback revoked: Kuw Pal"), "revocation not logged")
end)

test("a cached GUID the roster later gives to someone else is revoked", function()
    coldStart()
    receive("Evil Twin", "HELLO", { sender = kuw, version = 3 })
    roster = { { "Geo Prizm", true, me }, { "Kuw Pal", true, kuw } }
    now = now + 10
    receive("Evil Twin", "GC_ACK")
    assert(GuildCrafts._gcLastAddonAck == nil, "GC_ACK handled after the roster disagreed")
    assert(Comms.addonUsers[kuw] == nil, "fallback-added GUID kept")
    assert(Comms.senderFallbackRevocations == 1, "revocation not counted")
end)

test("a revoked GUID stays when its owner has also been heard from", function()
    coldStart()
    receive("Evil Twin", "HELLO", { sender = kuw, version = 3 })
    roster = { { "Geo Prizm", true, me }, { "Kuw Pal", true, kuw } }
    now = now + 10
    receive("Kuw Pal", "HELLO", { sender = kuw, version = 3 })
    receive("Evil Twin", "GC_ACK")
    assert(Comms.addonUsers[kuw], "real owner evicted")
end)

test("Classic is unaffected: no ForeverIdentity, no payload fallback", function()
    local forever = GuildCrafts
    GuildCrafts = NewAddon()
    local ok, err = pcall(function()
        dofile("GuildCrafts/Modules/Data.lua")
        dofile("GuildCrafts/Modules/Comms.lua")
        local classic = GuildCrafts.Comms
        assert(GuildCrafts.Data.CheckSenderClaim == nil, "Classic Data has the Forever claim check")
        classic.SendMessage = noop
        classic:OnInitialize()
        classic.Deserialize = function() return true, { t = "HELLO", v = 3, p = { sender = kuw } } end
        classic:OnCommReceived("GuildCrafts", "Uxx", "GUILD", "")
        assert(classic.addonUsers[kuw] == nil, "Classic took the payload GUID")
        assert(classic.unresolvedSenderDrops == 1, "Classic drop not counted")
        classic.Deserialize = function() return true, { t = "HELLO", v = 3, p = { sender = "Bob-Realm" } } end
        classic:OnCommReceived("GuildCrafts", "Uxx", "GUILD", "Bob")
        assert(classic.addonUsers["Bob-Realm"], "Classic HELLO not handled")
        -- Classic still keys HELLO by its payload sender, as before F26.
        classic.Deserialize = function() return true, { t = "HELLO", v = 3, p = { sender = "Alice-Realm" } } end
        classic:OnCommReceived("GuildCrafts", "Uxx", "GUILD", "Bob")
        assert(classic.addonUsers["Alice-Realm"], "Classic payload sender refused")
        assert(classic.senderFallbackRefusals == 0, "Classic counted a refusal")
    end)
    GuildCrafts = forever
    assert(ok, err)
end)

----------------------------------------------------------------------
-- DR election across several clients (F8, F13, F28)
-- Each client loads its own Data, ForeverIdentity and Comms. Messages go through
-- the real SendMessage and OnCommReceived on one simulated GUILD channel, own
-- GUILD messages echo back as they do in game, and timers run on the shared clock.
----------------------------------------------------------------------
local function copy(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for k, v in pairs(value) do out[k] = copy(v) end
    return out
end

local activeNode
IsInInstance = function() return activeNode ~= nil and activeNode.inInstance == true end

local Sim = {}
Sim.__index = Sim

-- members: { { "Name Surname", guid }, ... }, all online in the roster.
local function newSim(members)
    local sim = setmetatable({ nodes = {}, byName = {}, byGuid = {}, queue = {}, wire = {},
        timers = {}, sends = {}, blocked = {}, blockedWhisper = {} }, Sim)
    roster = {}
    for i, member in ipairs(members) do
        roster[i] = { member[1], true, member[2] }
        sim.byGuid[member[2]] = member[1]
    end
    now = now + 10
    return sim
end

function Sim:who(guid) return guid and (self.byGuid[guid] or guid) or "none" end

function Sim:module(node)
    local sim = self
    local function schedule(owner, fn, delay, interval)
        local handle = { node = node, owner = owner, fn = fn, due = now + delay, interval = interval }
        sim.timers[#sim.timers + 1] = handle
        return handle
    end
    return {
        ScheduleTimer = function(owner, fn, delay) return schedule(owner, fn, delay) end,
        ScheduleRepeatingTimer = function(owner, fn, delay) return schedule(owner, fn, delay, delay) end,
        CancelTimer = function(_, handle) if handle then handle.cancelled = true end end,
        RegisterComm = noop,
    }
end

function Sim:login(name)
    local guid
    for _, row in ipairs(roster) do if row[1] == name then guid = row[3] end end
    local node = { name = name, guid = guid, online = true, log = {} }
    local addon = NewAddon()
    addon.NewModule = function() return self:module(node) end
    addon.Debug = function(_, ...)
        local parts = {}
        for i = 1, select("#", ...) do parts[i] = tostring((select(i, ...))) end
        local line = table.concat(parts, " ")
        if line:find("^Error processing message") then error(name .. ": " .. line) end
        node.log[#node.log + 1] = line
    end
    local saved = GuildCrafts
    GuildCrafts = addon
    dofile("GuildCrafts/Modules/Data.lua")
    dofile("GuildCrafts/Modules/ForeverIdentity.lua")
    dofile("GuildCrafts/Modules/Comms.lua")
    GuildCrafts = saved
    addon.Data.db = { global = {} }
    addon.Data._playerKey = guid
    local comms = addon.Comms
    comms.Serialize = function(_, envelope)
        self.wire[#self.wire + 1] = copy(envelope)
        return tostring(#self.wire)
    end
    comms.Deserialize = function(_, serialized) return true, copy(self.wire[tonumber(serialized)]) end
    comms.SendCommMessage = function(_, _, message, distribution, target)
        local envelope = self.wire[tonumber(message:sub(2))]
        self.sends[#self.sends + 1] = { from = name, t = envelope.t, term = envelope.term, at = now,
            distribution = distribution, target = target, p = envelope.p }
        self.queue[#self.queue + 1] = { from = node, message = message, distribution = distribution,
            target = target }
    end
    node.addon, node.Comms = addon, comms
    comms:OnInitialize()
    self.nodes[#self.nodes + 1] = node
    self.byName[name] = node
    activeNode = node
    comms:OnLoginReady()
    activeNode = nil
    return node
end

function Sim:logoff(name)
    local node = self.byName[name]
    node.online = false
    for _, handle in ipairs(self.timers) do
        if handle.node == node then handle.cancelled = true end
    end
end

-- Messages between two clients are lost in both directions, as across an instance boundary.
function Sim:partition(a, b, on)
    self.blocked[a .. ">" .. b] = on or nil
    self.blocked[b .. ">" .. a] = on or nil
end

function Sim:flush()
    local delivered = 0
    while #self.queue > 0 do
        delivered = delivered + 1
        assert(delivered < 5000, "message storm")
        local m = table.remove(self.queue, 1)
        for _, node in ipairs(self.nodes) do
            local link = m.from.name .. ">" .. node.name
            local reaches = node.online and m.from.online and not self.blocked[link]
                and not (m.distribution == "WHISPER" and self.blockedWhisper[link])
                and (m.distribution == "GUILD" or node.name == m.target)
            if reaches then
                activeNode = node
                node.Comms:OnCommReceived("GuildCrafts", m.message, m.distribution, m.from.name)
                activeNode = nil
            end
        end
    end
end

function Sim:advance(seconds)
    local target = now + seconds
    self:flush()
    while true do
        local nextTimer
        for _, handle in ipairs(self.timers) do
            if not handle.cancelled and handle.due <= target and (not nextTimer or handle.due < nextTimer.due) then
                nextTimer = handle
            end
        end
        if not nextTimer then break end
        now = nextTimer.due
        if nextTimer.interval then nextTimer.due = now + nextTimer.interval else nextTimer.cancelled = true end
        activeNode = nextTimer.node
        if type(nextTimer.fn) == "string" then
            nextTimer.owner[nextTimer.fn](nextTimer.owner)
        else
            nextTimer.fn()
        end
        activeNode = nil
        self:flush()
    end
    now = target
    local live = {}
    for _, handle in ipairs(self.timers) do
        if not handle.cancelled then live[#live + 1] = handle end
    end
    self.timers = live
end

-- Send a GUILD message from a client as if its own code had.
function Sim:send(name, msgType, payload)
    local node = self.byName[name]
    activeNode = node
    node.Comms:SendMessage(msgType, payload, "GUILD")
    activeNode = nil
    self:flush()
end

function Sim:lastSend(name, msgType, since)
    local last
    for _, s in ipairs(self.sends) do
        if s.from == name and s.t == msgType and s.at >= (since or 0) then last = s end
    end
    return last
end

-- Every online client (or each of names) names drName as DR, only drName acts as DR,
-- every client is on the DR's term, and the DR's heartbeat went out and was accepted
-- within one interval.
function Sim:assertAgreed(drName, names)
    local dr = self.byName[drName]
    local checked
    if names then
        checked = {}
        for _, name in ipairs(names) do checked[name] = true end
    end
    assert(dr.online, drName .. " is offline")
    local beat = self:lastSend(drName, "HEARTBEAT", now - 60)
    assert(beat, drName .. " sent no HEARTBEAT in the last 60 s")
    for _, node in ipairs(self.nodes) do
        if node.online and (not checked or checked[node.name]) then
            local c = node.Comms
            assert(c.currentDR == dr.guid, node.name .. " names " .. self:who(c.currentDR) .. " as DR")
            assert((c.myRole == "DR") == (node == dr), node.name .. " has role " .. c.myRole)
            assert(c.currentTerm == beat.term, node.name .. " is on term " .. c.currentTerm
                .. ", the DR's heartbeat carries " .. beat.term)
            if node ~= dr then
                assert(now - c.lastDRHeartbeat <= 60, node.name .. " has no DR heartbeat for "
                    .. (now - c.lastDRHeartbeat) .. " s")
            end
        end
    end
end

-- GUIDs sort in this order, so the election prefers Ari, then Bel, Cid, Dov.
local ari, bel, cid, dov = "Player-4619-00000001", "Player-4619-00000002", "Player-4619-00000003",
    "Player-4619-00000004"

-- name's retry=1 request timed out: run its real retry chain, which evicts its DR and
-- BDR locally and sends the retry=2 open round.
local function openRound(sim, name)
    local node = sim.byName[name]
    local c = node.Comms
    c.syncPending, c.syncRetryCount = true, 1
    c._syncTargetedDR, c._syncTargetedBDR, c._syncLastEffectiveRetry = c.currentDR, c.currentBDR, 1
    activeNode = node
    c:OnSyncTimeout()
    activeNode = nil
    assert(sim:lastSend(name, "SYNC_REQUEST", now).p.retry == 2, "no open round sent")
    sim:flush()
end

-- Log in each name 20 s apart, then let HELLOs, syncs and the first heartbeats settle.
local function guild(...)
    local sim = newSim({ { "Ari Ash", ari }, { "Bel Birch", bel }, { "Cid Cedar", cid }, { "Dov Dune", dov } })
    for i = 1, select("#", ...) do
        sim:login((select(i, ...)))
        sim:advance(20)
    end
    sim:advance(90)
    return sim
end

test("election: clients that log in one by one agree on the lowest GUID", function()
    local sim = guild("Bel Birch", "Ari Ash", "Cid Cedar")
    sim:assertAgreed("Ari Ash")
end)

test("election F8: a DR that adopts a higher term keeps heartbeating", function()
    local sim = guild("Ari Ash", "Bel Birch")
    sim:assertAgreed("Ari Ash")
    -- Ari zones into an instance: neither side hears the other, Bel evicts Ari and takes over.
    sim.byName["Ari Ash"].inInstance = true
    sim:partition("Ari Ash", "Bel Birch", true)
    sim:advance(300)
    sim:assertAgreed("Bel Birch", { "Bel Birch" })
    -- Ari zones out. Bel's higher-term heartbeat reaches Ari, which is still the lowest GUID.
    sim.byName["Ari Ash"].inInstance = false
    sim:partition("Ari Ash", "Bel Birch", false)
    sim:advance(130)
    sim:assertAgreed("Ari Ash")
end)

test("election F13: HELLO traffic doesn't keep a logged-off DR elected", function()
    local sim = guild("Ari Ash", "Bel Birch", "Cid Cedar")
    sim:assertAgreed("Ari Ash")
    sim:logoff("Ari Ash")
    -- Cid reloads every 50 s; each HELLO re-runs everyone's election.
    for _ = 1, 8 do
        sim:advance(50)
        sim:send("Cid Cedar", "HELLO", { sender = cid, version = 3, isReply = true })
    end
    sim:advance(60)
    sim:assertAgreed("Bel Birch")
end)

test("election F13: a retry>=2 request doesn't evict a DR that is still heartbeating", function()
    local sim = guild("Ari Ash", "Bel Birch", "Cid Cedar", "Dov Dune")
    sim:assertAgreed("Ari Ash")
    local term, since = sim.byName["Ari Ash"].Comms.currentTerm, now
    -- Dov's earlier requests were lost, so it opens the round.
    openRound(sim, "Dov Dune")
    sim:advance(30)
    for _, s in ipairs(sim.sends) do
        if s.t == "SYNC_RESPONSE" and s.at >= since then
            -- Cid is who Dov re-elected; it answers in case the DR's reply is lost again.
            assert(s.from == "Ari Ash" or s.from == "Cid Cedar", s.from .. " answered the open round")
        end
    end
    assert(sim:lastSend("Ari Ash", "SYNC_RESPONSE", since), "the DR didn't answer")
    for _, name in ipairs({ "Bel Birch", "Cid Cedar" }) do
        local c = sim.byName[name].Comms
        assert(c.addonUsers[ari] and c.addonUsers[bel], name .. " evicted the DR or BDR")
        assert(c.currentTerm == term, name .. " moved to term " .. c.currentTerm)
    end
    sim:advance(60)
    sim:assertAgreed("Ari Ash")
end)

test("election F13: a paused DR keeps its role and answers the open round on resume", function()
    local sim = guild("Ari Ash", "Bel Birch", "Cid Cedar", "Dov Dune")
    local ariNode = sim.byName["Ari Ash"]
    local paused = true
    ariNode.addon.SyncPausePolicy = { ShouldPause = function() return paused end }
    local term, since = ariNode.Comms.currentTerm, now
    openRound(sim, "Dov Dune")
    sim:advance(10)
    assert(not sim:lastSend("Ari Ash", "SYNC_RESPONSE", since), "paused DR answered")
    local queue = ariNode.Comms.syncQueue
    assert(#queue == 1 and queue[1].requester == dov, "paused DR queue holds " .. #queue .. " request(s)")
    for _, name in ipairs({ "Bel Birch", "Cid Cedar" }) do
        local c = sim.byName[name].Comms
        assert(c.addonUsers[ari], name .. " evicted the paused DR")
        assert(c.currentTerm == term, name .. " moved to term " .. c.currentTerm)
    end
    -- Combat ends within Dov's 15 s retry timeout (F29).
    paused = false
    ariNode.Comms:OnSyncPauseLifted()
    sim:flush()
    assert(sim:lastSend("Ari Ash", "SYNC_RESPONSE", since), "DR didn't answer after the pause")
    sim:advance(60)
    sim:assertAgreed("Ari Ash")
end)

-- name sends a fresh SYNC_REQUEST and runs its whole retry chain: 120 s, 15 s, then the open round.
local function syncChain(sim, name)
    local node = sim.byName[name]
    node.Comms.syncRetryCount = 0
    activeNode = node
    node.Comms:SendSyncRequest()
    activeNode = nil
    sim:flush()
    sim:advance(Comms.SYNC_TIMEOUT + Comms.SYNC_RETRY_TIMEOUT + 5)
end

local function assertKeptRoles(sim, names, term)
    for _, name in ipairs(names) do
        local c = sim.byName[name].Comms
        assert(c.addonUsers[ari] and c.addonUsers[bel], name .. " evicted the DR or BDR")
        assert(c.currentTerm == term, name .. " moved to term " .. c.currentTerm)
    end
end

test("election F13: a paused DR and BDR keep their roles and the requester still syncs", function()
    local sim = guild("Ari Ash", "Bel Birch", "Cid Cedar", "Dov Dune")
    local term, since = sim.byName["Ari Ash"].Comms.currentTerm, now
    local paused = true
    for _, name in ipairs({ "Ari Ash", "Bel Birch" }) do
        sim.byName[name].addon.SyncPausePolicy = { ShouldPause = function() return paused end }
    end
    syncChain(sim, "Dov Dune")
    assert(sim:lastSend("Cid Cedar", "SYNC_RESPONSE", since), "nobody answered the open round")
    local dovComms = sim.byName["Dov Dune"].Comms
    assert(not dovComms.syncPending and (dovComms.lastSyncCompletedAt or 0) >= since, "Dov never synced")
    assertKeptRoles(sim, { "Bel Birch", "Cid Cedar" }, term)
    paused = false
    sim:advance(60)
    sim:assertAgreed("Ari Ash")
end)

test("election F13: lost replies from a heartbeating DR and BDR still end in a sync", function()
    local sim = guild("Ari Ash", "Bel Birch", "Cid Cedar", "Dov Dune")
    local term, since = sim.byName["Ari Ash"].Comms.currentTerm, now
    sim.blockedWhisper["Ari Ash>Dov Dune"] = true
    sim.blockedWhisper["Bel Birch>Dov Dune"] = true
    syncChain(sim, "Dov Dune")
    local dovComms = sim.byName["Dov Dune"].Comms
    assert(not dovComms.syncPending and (dovComms.lastSyncCompletedAt or 0) >= since, "Dov never synced")
    assertKeptRoles(sim, { "Bel Birch", "Cid Cedar" }, term)
    sim:advance(60)
    sim:assertAgreed("Ari Ash")
end)

test("election F13: the open round still re-elects when the DR and BDR are gone", function()
    local sim = guild("Ari Ash", "Bel Birch", "Cid Cedar", "Dov Dune")
    local since = now
    sim:logoff("Ari Ash")
    sim:logoff("Bel Birch")
    sim:advance(100)  -- one missed heartbeat, before any watchdog fires
    openRound(sim, "Dov Dune")
    sim:advance(5)
    assert(sim:lastSend("Cid Cedar", "SYNC_RESPONSE", since), "nobody answered the open round")
    sim:advance(60)
    sim:assertAgreed("Cid Cedar")
end)

test("election F28: after a character switch the old DR is evicted", function()
    -- Same account: Ari logs off and Bel logs in; Cid stays online throughout.
    local sim = guild("Ari Ash", "Cid Cedar")
    sim:assertAgreed("Ari Ash")
    sim:logoff("Ari Ash")
    sim:advance(5)
    sim:login("Bel Birch")
    sim:advance(300)
    assert(sim.byName["Cid Cedar"].Comms.addonUsers[ari] == nil, "Cid still lists the logged-off DR")
    sim:assertAgreed("Bel Birch")
end)

test("election: the DR changes hands and back, and every client follows", function()
    local sim = guild("Ari Ash", "Bel Birch", "Cid Cedar")
    sim:assertAgreed("Ari Ash")
    local term = sim.byName["Ari Ash"].Comms.currentTerm
    sim:logoff("Ari Ash")
    sim:advance(250)
    sim:assertAgreed("Bel Birch")
    assert(sim.byName["Bel Birch"].Comms.currentTerm > term, "the new DR didn't advance the term")
    -- Ari logs back in with a fresh session and term 0, still the lowest GUID.
    sim:login("Ari Ash")
    sim:advance(120)
    sim:assertAgreed("Ari Ash")
end)

----------------------------------------------------------------------
-- Recipe deltas across several clients (H22, #104)
----------------------------------------------------------------------

-- name opens its profession window with recipeIDs learned under prof, and the real scan runs.
local function learn(sim, name, prof, ...)
    local ids = { ... }
    C_TradeSkillUI = {
        GetBaseProfessionInfo = function() return { professionName = prof, skillLevel = 1, maxSkillLevel = 75 } end,
        GetAllRecipeIDs = function() return ids end,
        GetRecipeInfo = function(id) return { learned = true, name = "Recipe " .. id } end,
    }
    local node = sim.byName[name]
    activeNode = node
    now = now + 1
    node.addon.Data:ScanTradeSkillModern()
    activeNode = nil
    C_TradeSkillUI = nil
    sim:flush()
end

-- name's stored copy of owner's recipes under prof (recipe IDs), and its revision.
local function holds(sim, name, owner, prof)
    local node = sim.byName[name]
    local entry = node.addon.Data:GetGuildDB()[sim.byName[owner].guid]
    local ids = {}
    for key in pairs(entry and entry.professions and entry.professions[prof] and entry.professions[prof].recipes or {}) do
        ids[#ids + 1] = -key
    end
    table.sort(ids)
    return table.concat(ids, ","), entry and entry.lastUpdate
end

local function ownRevision(sim, name)
    local node = sim.byName[name]
    return node.addon.Data:GetGuildDB()[node.guid].lastUpdate
end

local function pausable(sim, name)
    local state = { paused = false }
    sim.byName[name].addon.SyncPausePolicy = { ShouldPause = function() return state.paused end }
    return state
end

local function syncRequests(sim, name, since)
    local n = 0
    for _, s in ipairs(sim.sends) do
        if s.from == name and s.t == "SYNC_REQUEST" and s.at >= since then n = n + 1 end
    end
    return n
end

test("delta H22: a peer that missed T1 has T1's recipes after T2", function()
    local sim = guild("Ari Ash", "Bel Birch", "Cid Cedar")
    learn(sim, "Bel Birch", "Alchemy", 300)
    sim:partition("Bel Birch", "Cid Cedar", true)
    learn(sim, "Bel Birch", "Alchemy", 300, 301)
    sim:partition("Bel Birch", "Cid Cedar", false)
    learn(sim, "Bel Birch", "Alchemy", 300, 301, 302)
    sim:advance(30)
    local recipes, revision = holds(sim, "Cid Cedar", "Bel Birch", "Alchemy")
    assert(recipes == "300,301,302", "Cid holds " .. recipes)
    assert(revision == ownRevision(sim, "Bel Birch"), "Cid's revision " .. tostring(revision))
end)

test("delta H22: a peer with no entry pulls the member's other professions", function()
    local sim = guild("Ari Ash", "Bel Birch", "Cid Cedar")
    learn(sim, "Bel Birch", "Alchemy", 300, 301)
    sim.byName["Cid Cedar"].addon.Data:GetGuildDB()[bel] = nil
    learn(sim, "Bel Birch", "Cooking", 400)
    sim:advance(30)
    assert(holds(sim, "Cid Cedar", "Bel Birch", "Alchemy") == "300,301", "Alchemy not pulled")
    local recipes, revision = holds(sim, "Cid Cedar", "Bel Birch", "Cooking")
    assert(recipes == "400" and revision == ownRevision(sim, "Bel Birch"), "Cooking " .. recipes)
end)

test("delta H22: a change the owner made while paused reaches everyone at its next sync", function()
    local sim = guild("Ari Ash", "Bel Birch", "Cid Cedar")
    local belPause = pausable(sim, "Bel Birch")
    learn(sim, "Bel Birch", "Alchemy", 300)
    local before = ownRevision(sim, "Bel Birch")
    belPause.paused = true
    learn(sim, "Bel Birch", "Alchemy", 300, 301)
    belPause.paused = false
    local since = now
    learn(sim, "Bel Birch", "Alchemy", 300, 301, 302)
    sim:advance(30)
    -- The DR missed 301 too, so nobody can serve it until Bel syncs (the DR-pull gap, #15).
    for _, name in ipairs({ "Ari Ash", "Cid Cedar" }) do
        local recipes, revision = holds(sim, name, "Bel Birch", "Alchemy")
        assert(recipes == "300,302", name .. " holds " .. recipes)
        assert(revision == before, name .. " moved past the missed change to " .. tostring(revision))
    end
    assert(syncRequests(sim, "Cid Cedar", since) == 1, "Cid sent " .. syncRequests(sim, "Cid Cedar", since))
    syncChain(sim, "Bel Birch")
    syncChain(sim, "Cid Cedar")
    for _, name in ipairs({ "Ari Ash", "Cid Cedar" }) do
        assert(holds(sim, name, "Bel Birch", "Alchemy") == "300,301,302", name .. " never caught up")
    end
end)

test("delta H22: a paused peer's pull waits for the pause to end", function()
    local sim = guild("Ari Ash", "Bel Birch", "Cid Cedar")
    local cidPause = pausable(sim, "Cid Cedar")
    learn(sim, "Bel Birch", "Alchemy", 300)
    cidPause.paused = true  -- in an instance, where GUILD messages don't arrive
    sim:partition("Bel Birch", "Cid Cedar", true)
    learn(sim, "Bel Birch", "Alchemy", 300, 301)
    sim:partition("Bel Birch", "Cid Cedar", false)
    learn(sim, "Bel Birch", "Alchemy", 300, 301, 302)
    sim:advance(30)
    assert(holds(sim, "Cid Cedar", "Bel Birch", "Alchemy") == "300,302", "Cid pulled while paused")
    cidPause.paused = false
    sim:advance(30)
    assert(holds(sim, "Cid Cedar", "Bel Birch", "Alchemy") == "300,301,302", "Cid never pulled")
end)

test("delta H22: deltas from a client without base stay behind until its next sync", function()
    local sim = guild("Ari Ash", "Bel Birch", "Cid Cedar")
    local belComms = sim.byName["Bel Birch"].Comms
    local send = belComms.SendMessage
    belComms.SendMessage = function(self, msgType, payload, ...)
        if msgType == "DELTA_UPDATE" then payload.base = nil end
        return send(self, msgType, payload, ...)
    end
    learn(sim, "Bel Birch", "Alchemy", 300)
    syncChain(sim, "Bel Birch")
    sim:partition("Bel Birch", "Cid Cedar", true)
    learn(sim, "Bel Birch", "Alchemy", 300, 301)
    sim:partition("Bel Birch", "Cid Cedar", false)
    learn(sim, "Bel Birch", "Alchemy", 300, 301, 302)
    sim:advance(30)
    local recipes, revision = holds(sim, "Cid Cedar", "Bel Birch", "Alchemy")
    assert(recipes == "300,302", "Cid holds " .. recipes)
    assert(revision < ownRevision(sim, "Bel Birch"), "a delta without base moved Cid's revision")
    syncChain(sim, "Bel Birch")
    syncChain(sim, "Cid Cedar")
    assert(holds(sim, "Cid Cedar", "Bel Birch", "Alchemy") == "300,301,302", "Cid never caught up")
end)

local failed = 0
for _, case in ipairs(tests) do
    reset()
    local ok, err = pcall(case[2])
    if ok then
        print("PASS " .. case[1])
    else
        failed = failed + 1
        print("FAIL " .. case[1] .. ": " .. tostring(err))
    end
end
assert(failed == 0, failed .. " identity regression(s) failed")
print(#tests .. " identity regressions passed")
