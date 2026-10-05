-- /gc report, debug ring buffer and /gc reset regressions with stubbed WoW APIs.
-- Run from the repository root: lua5.1 tools/test-report.lua
local now = 1000
local printed = {}
local frames = {}
local prefixResult = 0
local me = "Player-4619-012F81BC"
local reloads = 0

time = function() return now end
date = function(format) return os.date(format, now) end
GetTime = function() return now end
GetRealmName = function() return "Realm" end
GetSpellInfo = function() return nil end
IsInGuild = function() return true end
InCombatLockdown = function() return false end
GetBuildInfo = function() return "1.60.1", "70170", "Sep 30 2026", 16001, "1.60.1", "Release" end
string.trim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
Enum = { RegisterAddonMessagePrefixResult = { Success = 0, DuplicatePrefix = 1, InvalidPrefix = 2, MaxPrefixes = 3 } }
C_ChatInfo = { RegisterAddonMessagePrefix = function() return prefixResult end }
C_AddOns = { GetAddOnMetadata = function() return "@project-version@" end }
ReloadUI = function() reloads = reloads + 1 end

-- Frames: every method is a no-op except the ones the copy box reads back.
local frameStub
frameStub = function()
    local f = { shown = false }
    return setmetatable(f, { __index = function(_, key)
        if key == "SetText" then return function(self, text) self.text = text end end
        if key == "Show" then return function(self) self.shown = true end end
        if key == "Hide" then return function(self) self.shown = false end end
        if key == "IsShown" then return function(self) return self.shown end end
        if key == "CreateTexture" or key == "CreateFontString" then return function() return frameStub() end end
        return function() end
    end })
end
CreateFrame = function()
    local f = frameStub()
    frames[#frames + 1] = f
    return f
end
UIParent = frameStub()
ChatFontNormal = {}
UISpecialFrames = {}

local addon = {
    NewModule = function(self, name)
        local m = { ScheduleTimer = function() end, RegisterComm = function() end, RegisterEvent = function() end }
        self[name] = m
        return m
    end,
    Print = function(_, ...) printed[#printed + 1] = table.concat({ ... }, " ") end,
    RegisterChatCommand = function() end,
}
LibStub = function(name)
    if name == "AceAddon-3.0" then return { NewAddon = function() return addon end } end
    return nil
end

dofile("GuildCrafts/Core.lua")
dofile("GuildCrafts/Modules/Data.lua")
dofile("GuildCrafts/Modules/SyncPausePolicy.lua")
dofile("GuildCrafts/Modules/Comms.lua")
dofile("GuildCrafts/Modules/Report.lua")
local Data, Comms, Pause, Report = GuildCrafts.Data, GuildCrafts.Comms, GuildCrafts.SyncPausePolicy, GuildCrafts.Report

local db
Data.GetGuildDB = function() return db end
Data.GetPlayerKey = function() return me end
Data.GetGuildKey = function() return "Grim-Realm" end
Data.GetMemberName = function(_, key) return key == me and "Geo Prizm" or "Motiv Hysteria" end
Data.NormalizeMemberKey = function(_, key) return key == "Motiv Hysteria" and "Player-1-AA" or nil end
Data.db = { global = {} }

local function reset()
    now, printed, frames, prefixResult, reloads = 1000, {}, {}, 0, 0
    GuildCraftsCharDB = nil
    GuildCrafts.debugMode = false
    db = {
        [me] = { lastUpdate = 900, dropped = { Tailoring = 800 }, professions = {
            Alchemy = { lastUpdate = 900, recipes = { [1] = {}, [2] = {}, [3] = {} } },
            Mining = { recipes = {} },
        } },
        ["Player-1-AA"] = { lastUpdate = 950, professions = { Cooking = { recipes = { [4] = {} } } } },
    }
    Data._currentProfs = { Alchemy = true, Mining = true }
    Pause:OnInitialize()
    Comms:OnInitialize()
    Comms:OnEnable()
    Report:OnInitialize()
end

local function has(text, needle)
    assert(text:find(needle, 1, true), "missing: " .. needle .. "\n--- report ---\n" .. text)
end

local tests = {}
local function test(name, fn) tests[#tests + 1] = { name, fn } end

test("debug lines are kept with debug mode off and not printed", function()
    GuildCrafts:Debug("hello", 42, nil)
    local lines = Report:GetLogLines()
    assert(lines[#lines]:find("hello 42 nil", 1, true), "debug line not recorded: " .. tostring(lines[#lines]))
    assert(#printed == 0, "debug printed with debug mode off")
end)

test("ring buffer keeps the newest lines in order after wrapping", function()
    for i = 1, Report.LOG_SIZE + 25 do GuildCrafts:Debug("line", i) end
    local lines = Report:GetLogLines()
    assert(#lines == Report.LOG_SIZE, "buffer size " .. #lines)
    assert(lines[1]:find("line 26$"), "oldest kept line is " .. lines[1])
    assert(lines[#lines]:find("line " .. (Report.LOG_SIZE + 25) .. "$"), "newest line is " .. lines[#lines])
end)

test("log persists in GuildCraftsCharDB with only strings and numbers", function()
    GuildCrafts:Debug("persist me", true)
    local saved = GuildCraftsCharDB and GuildCraftsCharDB.debugLog
    assert(saved, "log not stored in GuildCraftsCharDB")
    local function check(t)
        for k, v in pairs(t) do
            assert(type(k) == "string" or type(k) == "number", "key type " .. type(k))
            if type(v) == "table" then check(v)
            else assert(type(v) == "string" or type(v) == "number", "value type " .. type(v)) end
        end
    end
    check(saved)
    -- A reload hands the same table back.
    Report:OnInitialize()
    local lines = Report:GetLogLines()
    local found = false
    for _, line in ipairs(lines) do found = found or line:find("persist me true", 1, true) ~= nil end
    assert(found, "line lost across reload")
end)

test("lines logged before initialize are kept", function()
    GuildCraftsCharDB = { debugLog = nil }
    Report._log = nil
    GuildCrafts:Debug("early bird")
    Report:OnInitialize()
    local found = false
    for _, line in ipairs(Report:GetLogLines()) do found = found or line:find("early bird", 1, true) ~= nil end
    assert(found, "pre-initialize line lost")
end)

test("long lines are truncated", function()
    GuildCrafts:Debug(string.rep("x", 1000))
    local lines = Report:GetLogLines()
    assert(#lines[#lines] <= Report.LINE_MAX, "line length " .. #lines[#lines])
end)

test("report carries version, build, keys and recipe counts", function()
    local text = Report:Build()
    has(text, "Addon: dev, protocol 3, data format 3")
    has(text, "Client: 1.60.1 | 70170 | Sep 30 2026 | 16001 | 1.60.1 | Release")
    has(text, "Player: " .. me .. " (Geo Prizm)")
    has(text, "Guild: Grim-Realm")
    has(text, "Detected professions: Alchemy, Mining")
    has(text, "Alchemy: 3 recipes, revision 900")
    has(text, "Mining: 0 recipes")
    has(text, "Dropped: Tailoring at 800")
    has(text, "Database: 2 members, 4 recipes")
end)

test("report carries sync, discovery and pause state", function()
    Comms.myRole, Comms.currentDR, Comms.currentBDR, Comms.currentTerm = "BDR", "Player-1-AA", me, 4
    Comms.addonUsers = { [me] = { version = 3, lastSeen = now }, ["Player-1-AA"] = { version = 3, lastSeen = now } }
    Data._onlineCache = {}
    Pause._inInstance = true
    local text = Report:Build()
    has(text, "Role: BDR, term 4")
    has(text, "DR: Player-1-AA (Motiv Hysteria)")
    has(text, "Addon users: 2 known, 1 online, status disconnected")
    has(text, "Prefix registration: 0 (Success)")
    has(text, "Last message received: never")
    has(text, "Unresolved-sender drops: 0")
    has(text, "Pause: true (combat false, instance true, transition false, restrictions none)")
end)

test("prefix registration failure is reported by name", function()
    prefixResult = 3
    Comms:OnInitialize()
    Comms:OnEnable()
    has(Report:Build(), "Prefix registration: 3 (MaxPrefixes)")
end)

test("received messages and unresolved senders are counted", function()
    Comms.Deserialize = function() return true, { t = "HELLO", p = {} } end
    Comms:OnCommReceived("GuildCrafts", "Uxx", "GUILD", "Stranger Danger")
    now = 1100
    Comms:OnCommReceived("GuildCrafts", "Uxx", "GUILD", "Motiv Hysteria")
    now = 1130
    local text = Report:Build()
    has(text, "Last message received: 30s ago")
    has(text, "Unresolved-sender drops: 1")
    local lines = Report:GetLogLines()
    has(table.concat(lines, "\n"), "Stranger Danger")
end)

test("only messages from a resolved peer count as received", function()
    Comms.Deserialize = function() return true, { t = "HEARTBEAT", p = {} } end
    Data.NormalizeMemberKey = function(_, key) return key == "Geo Prizm" and me or nil end
    Comms:OnCommReceived("GuildCrafts", "Uxx", "GUILD", "Geo Prizm")
    Data.NormalizeMemberKey = function(_, key) return key == "Motiv Hysteria" and "Player-1-AA" or nil end
    has(Report:Build(), "Last message received: never")
end)

test("repeated identical lines collapse into one with a count", function()
    GuildCrafts:Debug("Scanned Alchemy: no new recipes.")
    local before = #Report:GetLogLines()
    for _ = 1, 4 do GuildCrafts:Debug("Scanned Alchemy: no new recipes.") end
    local lines = Report:GetLogLines()
    assert(#lines == before, "repeats took " .. (#lines - before) .. " extra line(s)")
    assert(lines[#lines]:find("Scanned Alchemy: no new recipes. (x5)", 1, true), "count missing: " .. lines[#lines])
    GuildCrafts:Debug("something else")
    lines = Report:GetLogLines()
    assert(lines[#lines]:find("something else$"), "a new line was folded into the repeat")
end)

test("failed sends are logged and counted", function()
    Comms.Serialize = function() return "x" end
    Comms.SendCommMessage = function(_, _, _, _, _, _, callback, arg)
        callback(arg, 1, 1, false)
    end
    Comms:SendMessage("HELLO", {}, "GUILD")
    local text = Report:Build()
    has(text, "Send failures: 1")
    has(table.concat(Report:GetLogLines(), "\n"), "Send failed: HELLO GUILD")
end)

test("a failing section is reported and the rest still builds", function()
    Data.GetGuildDB = function() error("db exploded") end
    local ok, text = pcall(Report.Build, Report)
    Data.GetGuildDB = function() return db end
    assert(ok, "Build raised: " .. tostring(text))
    has(text, "db exploded")
    has(text, "Role: ")
    has(text, "Client: 1.60.1")
end)

test("report ends with the debug log", function()
    GuildCrafts:Debug("last words")
    local text = Report:Build()
    has(text, "Debug log")
    assert(text:find("last words", 1, true) > text:find("Debug log", 1, true), "log not after its heading")
end)

test("/gc report opens a copy box holding the report", function()
    GuildCrafts:SlashHandler("report")
    local edit
    for _, f in ipairs(frames) do local t = rawget(f, "text"); if t and t:find("Addon: ", 1, true) then edit = f end end
    assert(edit, "no edit box received the report")
    assert(#printed == 0, "report spilled into chat: " .. tostring(printed[1]))
end)

local function copy(t)
    if type(t) ~= "table" then return t end
    local c = {}
    for k, v in pairs(t) do c[k] = copy(v) end
    return c
end

local function same(a, b, path)
    path = path or "value"
    if type(a) ~= "table" or type(b) ~= "table" then
        assert(a == b, path .. ": " .. tostring(a) .. " ~= " .. tostring(b))
        return
    end
    for k, v in pairs(a) do same(v, b[k], path .. "." .. tostring(k)) end
    for k in pairs(b) do assert(a[k] ~= nil, path .. "." .. tostring(k) .. " was added") end
end

-- Raw SavedVariables as AceDB-3.0 lays them out, with Data.db pointing into them.
local function savedVariables()
    GuildCraftsDB = {
        global = {
            minimap = { hide = true, minimapPos = 200, lock = true },
            _recipeDB = { [4] = { name = "Feast", reagents = { { 1, 2 } } } },
            ["Grim-Realm"] = {
                [me] = { lastUpdate = 900, professions = { Alchemy = { recipes = { [1] = {} } } } },
                ["Player-1-AA"] = { lastUpdate = 950, _tombstone = 940 },
            },
            ["Other Guild-Realm"] = { ["Player-1-BB"] = { lastUpdate = 10, professions = {} } },
            ["Legacy-Realm"] = { lastUpdate = 5, professions = {} },
        },
        profileKeys = { ["Geo Prizm - Realm"] = "Default" },
        profiles = { Default = { showOnlineOnly = true, showTooltipCrafters = false, expansionFilter = { ORIG = false } } },
    }
    Data.db = { global = GuildCraftsDB.global, profile = GuildCraftsDB.profiles.Default }
    GuildCrafts.db = Data.db
    GuildCraftsCharDB.favoriteRecipes = { [4] = 1 }
    GuildCraftsCharDB.favoriteMembers = { ["Player-1-AA"] = 1 }
    GuildCraftsCharDB.optOut = 1
    GuildCrafts:Debug("before reset")
end

test("/gc reset clears guild, recipe and sync data", function()
    savedVariables()
    local global = GuildCraftsDB.global
    GuildCrafts:SlashHandler("reset")
    assert(GuildCraftsDB and GuildCraftsDB.global == global, "GuildCraftsDB.global was replaced, AceDB would lose it")
    assert(Data.db.global == global, "Data.db.global no longer points at the saved table")
    for key in pairs(global) do
        assert(key == "minimap", "reset left " .. tostring(key))
    end
    assert(reloads == 1, "ReloadUI called " .. reloads .. " times")
end)

test("/gc reset keeps every setting, favorites and the debug log", function()
    savedVariables()
    local minimap, profiles, profileKeys = copy(GuildCraftsDB.global.minimap), copy(GuildCraftsDB.profiles), copy(GuildCraftsDB.profileKeys)
    local charDB, charTable = copy(GuildCraftsCharDB), GuildCraftsCharDB
    GuildCrafts:SlashHandler("reset")
    same(GuildCraftsDB.global.minimap, minimap, "minimap")
    same(GuildCraftsDB.profiles, profiles, "profiles")
    same(GuildCraftsDB.profileKeys, profileKeys, "profileKeys")
    assert(GuildCraftsCharDB == charTable, "GuildCraftsCharDB was replaced")
    same(GuildCraftsCharDB, charDB, "GuildCraftsCharDB")
end)

test("/gc reset says what it cleared and that settings were kept", function()
    savedVariables()
    GuildCrafts:SlashHandler("reset")
    local text = table.concat(printed, "\n")
    has(text, "Cleared all guild members, recipes and sync data")
    has(text, "Kept your settings (minimap button, Online filter, Tooltip crafters) and favorites")
    has(text, "Reloading")
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
assert(failed == 0, failed .. " report regression(s) failed")
print(#tests .. " report regressions passed")
