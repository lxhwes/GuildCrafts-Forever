-- /gc report and debug ring buffer regressions (Modules/Report.lua) with stubbed WoW APIs.
-- Run from the repository root: lua5.1 tools/test-report.lua
local now = 1000
local printed = {}
local frames = {}
local prefixResult = 0
local me = "Player-4619-012F81BC"

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
    now, printed, frames, prefixResult = 1000, {}, {}, 0
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

----------------------------------------------------------------------
-- !gc and [G] guild chat sends (H14: send API, F4, F24)
----------------------------------------------------------------------

local chatSent, chatTimers, chatAcks
local CRAFTERS = { { key = "Player-1-AA" } }

local function sendTo(api)
    return function(text, chatType)
        chatSent[#chatSent + 1] = { api = api, text = text, chatType = chatType }
    end
end

-- Each case gets fresh send stubs and timers; everything it swaps is put back.
local function chatTest(name, fn)
    test(name, function()
        local saved = {
            cSend = C_ChatInfo.SendChatMessage, gSend = SendChatMessage, inInstance = IsInInstance,
            search = Data.SearchRecipes, searchKey = Data.SearchRecipesByKey, online = Data.IsMemberOnline,
            ack = Comms.BroadcastGcAck,
        }
        chatSent, chatTimers, chatAcks = {}, {}, {}
        C_ChatInfo.SendChatMessage = sendTo("C_ChatInfo")
        SendChatMessage = sendTo("global")
        IsInInstance = function() return false end
        GuildCrafts.ScheduleTimer = function(_, f, delay) chatTimers[#chatTimers + 1] = { f = f, delay = delay } end
        Comms.BroadcastGcAck = function() chatAcks[#chatAcks + 1] = #chatSent end
        Data.SearchRecipes = function() return {} end
        Data.SearchRecipesByKey = function() return {} end
        Data.IsMemberOnline = function() return false end
        Comms.myRole = "DR"
        Comms.addonUsers = { [me] = { lastSeen = now }, ["Player-1-AA"] = { lastSeen = now } }
        GuildCrafts._chatPostCooldowns = {}
        GuildCrafts._gcQueryCooldowns = nil
        GuildCrafts._gcLastGuildCraftsMsg, GuildCrafts._gcLastAddonAck = 0, 0

        local ok, err = pcall(fn)

        C_ChatInfo.SendChatMessage, SendChatMessage, IsInInstance = saved.cSend, saved.gSend, saved.inInstance
        Data.SearchRecipes, Data.SearchRecipesByKey, Data.IsMemberOnline = saved.search, saved.searchKey, saved.online
        Comms.BroadcastGcAck = saved.ack
        GuildCrafts.ScheduleTimer = nil
        if not ok then error(err, 0) end
    end)
end

-- Ask in guild chat and fire the responder's timer, as the DR would.
local function ask(msg)
    local before = #chatTimers
    GuildCrafts:OnGuildChatMessage("CHAT_MSG_GUILD", msg)
    if #chatTimers == before then return false end
    chatTimers[#chatTimers].f()
    return true
end

local function logText() return table.concat(Report:GetLogLines(), "\n") end

chatTest("[G] posts through C_ChatInfo.SendChatMessage when it exists", function()
    GuildCrafts:PostCraftersToGuildChat("Flask of Petrification", 13506, CRAFTERS)
    assert(#chatSent == 1, "sent " .. #chatSent .. " line(s)")
    assert(chatSent[1].api == "C_ChatInfo", "sent through " .. chatSent[1].api)
    assert(chatSent[1].chatType == "GUILD", "chat type " .. tostring(chatSent[1].chatType))
    has(chatSent[1].text, "[GuildCrafts] Flask of Petrification: Motiv Hysteria")
end)

chatTest("[G] falls back to the global SendChatMessage", function()
    C_ChatInfo.SendChatMessage = nil
    GuildCrafts:PostCraftersToGuildChat("Flask of Petrification", 13506, CRAFTERS)
    assert(#chatSent == 1 and chatSent[1].api == "global", "fallback not used")
end)

chatTest("[G] with no send API prints a message, logs it and keeps no cooldown", function()
    C_ChatInfo.SendChatMessage, SendChatMessage = nil, nil
    GuildCrafts:PostCraftersToGuildChat("Flask of Petrification", 13506, CRAFTERS)
    assert(#printed == 1, "printed " .. #printed .. " line(s)")
    has(printed[1], "Couldn't post")
    has(logText(), "Guild chat send failed")
    assert(GuildCrafts._chatPostCooldowns[13506] == nil, "cooldown stamped on a failed post")
end)

chatTest("[G] counts a send that raises as failed", function()
    C_ChatInfo.SendChatMessage = function() error("blocked") end
    GuildCrafts:PostCraftersToGuildChat("Flask of Petrification", 13506, CRAFTERS)
    has(printed[1] or "", "Couldn't post")
    has(logText(), "blocked")
end)

chatTest("!gc miss never echoes the asker's text", function()
    assert(ask("!gc |cffff0000Buy gold at evil.example|r"), "no reply scheduled")
    assert(#chatSent == 1, "sent " .. #chatSent .. " line(s)")
    assert(chatSent[1].api == "C_ChatInfo", "sent through " .. chatSent[1].api)
    assert(not chatSent[1].text:lower():find("evil", 1, true), "asker text echoed: " .. chatSent[1].text)
    has(chatSent[1].text, "[GuildCrafts] No guild crafter found")
end)

chatTest("!gc miss starts the cooldown", function()
    assert(ask("!gc nosuchrecipe"), "no reply scheduled")
    assert(not ask("!gc nosuchrecipe"), "repeat miss answered inside the cooldown")
    assert(#chatSent == 1, "sent " .. #chatSent .. " line(s)")
    now = now + 31
    assert(ask("!gc nosuchrecipe"), "miss not answered after the cooldown")
end)

chatTest("!gc hit posts DB names, then sends GC_ACK", function()
    Data.SearchRecipes = function()
        return { { recipeName = "Flask of Petrification", profName = "Alchemy", crafters = CRAFTERS } }
    end
    assert(ask("!gc flask of petrification and spam"), "no reply scheduled")
    assert(#chatSent == 1, "sent " .. #chatSent .. " line(s)")
    has(chatSent[1].text, "[GuildCrafts] Flask of Petrification (Alchemy): Motiv Hysteria")
    assert(not chatSent[1].text:find("spam", 1, true), "asker text echoed: " .. chatSent[1].text)
    assert(#chatAcks == 1, "sent " .. #chatAcks .. " ACK(s)")
    assert(chatAcks[1] == 1, "ACK went out before the post")
end)

chatTest("!gc failed post sends no GC_ACK and no cooldown", function()
    C_ChatInfo.SendChatMessage = function() error("restricted") end
    SendChatMessage = nil
    assert(ask("!gc nosuchrecipe"), "no reply scheduled")
    assert(#chatAcks == 0, "ACK sent for a failed post")
    has(logText(), "restricted")
    assert(ask("!gc nosuchrecipe"), "failed post started the cooldown")
end)

chatTest("!gc with no send API doesn't raise and sends no GC_ACK", function()
    C_ChatInfo.SendChatMessage, SendChatMessage = nil, nil
    Data.SearchRecipes = function()
        return { { recipeName = "Flask of Petrification", profName = "Alchemy", crafters = CRAFTERS } }
    end
    assert(ask("!gc flask of petrification"), "no reply scheduled")
    assert(#chatAcks == 0, "ACK sent with no send API")
    has(logText(), "Guild chat send failed")
end)

test("/gc report opens a copy box holding the report", function()
    GuildCrafts:SlashHandler("report")
    local edit
    for _, f in ipairs(frames) do local t = rawget(f, "text"); if t and t:find("Addon: ", 1, true) then edit = f end end
    assert(edit, "no edit box received the report")
    assert(#printed == 0, "report spilled into chat: " .. tostring(printed[1]))
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
