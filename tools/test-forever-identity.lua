-- Forever member-key regressions (Modules/ForeverIdentity.lua) with a stubbed roster.
-- Run from the repository root: lua5.1 tools/test-forever-identity.lua
-- Roster and name shapes match the ME, GR and SND probes from 2026-10-02.
local now = 1000
local roster
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
GuildCrafts = {
    DATA_FORMAT_VERSION = 3,
    NewModule = function() return { ScheduleTimer = function() end } end,
    Debug = function() end,
    Print = function() end,
    Printf = function() end,
}
dofile("GuildCrafts/Modules/Data.lua")
dofile("GuildCrafts/Modules/ForeverIdentity.lua")
local Data = GuildCrafts.Data

local function reset()
    now = now + 10  -- step past the identity module's roster rescan interval
    roster = {
        { "Geo Prizm", true, me },
        { "Motiv Hysteria", true, motiv },
        { "Kuw Pal", false, kuw },
    }
    Data._playerKey, Data._guildKey, Data._guildMigrated, Data._memberKeysNormalized = nil, nil, nil, nil
    Data.db = { global = {} }
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
