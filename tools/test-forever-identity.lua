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
    assert(Comms.unresolvedSenderDrops == 1, "matching request dropped")
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

test("a GUID the fallback added is evicted on revocation after a cache eviction", function()
    coldStart()
    local claimed = "Player-4613-00000001"
    receive("Kuw Pal", "HELLO", { sender = claimed, version = 3 })
    for i = 1, Comms.SENDER_FALLBACK_MAX do
        now = now + 1
        receive("Alt " .. i, "HELLO", { sender = string.format("Player-4619-%08X", 0x100 + i), version = 3 })
    end
    assert(Comms._senderFallback["Kuw Pal"] == nil, "first entry not evicted")
    now = now + 1
    receive("Kuw Pal", "HELLO", { sender = claimed, version = 3 })
    roster = { { "Geo Prizm", true, me }, { "Kuw Pal", true, kuw } }
    now = now + 10
    receive("Kuw Pal", "GC_ACK")
    assert(Comms.addonUsers[claimed] == nil, "contradicted GUID kept")
    assert(Comms.currentDR == kuw, "DR is " .. tostring(Comms.currentDR))
end)

test("the fallback cache is bounded and drops its oldest entry", function()
    coldStart()
    local max = Comms.SENDER_FALLBACK_MAX
    for i = 1, max + 1 do
        now = now + 1
        receive("Alt " .. i, "HELLO", { sender = string.format("Player-4613-%08X", i), version = 3 })
    end
    local count = 0
    for _ in pairs(Comms._senderFallback) do count = count + 1 end
    assert(count == max, count .. " cache entries")
    assert(Comms._senderFallback["Alt 1"] == nil, "oldest entry kept")
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
    end)
    GuildCrafts = forever
    assert(ok, err)
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
