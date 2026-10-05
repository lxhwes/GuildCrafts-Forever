-- Profession deletion regressions with stubbed WoW APIs.
-- Run from the repository root: lua5.1 tools/test-profession-sync.lua
local now = 1000
local serverNow = 1000
local known = {}
local db = {}
local messages = {}
local playerKey = "Owner-Realm"
local skillLines = {}
local debugs = {}
local timers = {}

time = function() return now end
GetServerTime = function() return serverNow end
GetRealmName = function() return "Realm" end
GetSpellInfo = function() return nil end
IsSpellKnown = function() return false end
IsInGuild = function() return true end
GetProfessions = function()
    if known.error then error("profession API unavailable") end
    return unpack(known.indices or {}, 1, 5)
end
local function classicSkillLines()
    GetNumSkillLines = function() return #skillLines end
    GetSkillLineInfo = function(index) return skillLines[index], false, nil, 1, nil, nil, 75 end
end
classicSkillLines()
GetProfessionInfo = function(index)
    local prof = known[index]
    if prof then return prof, nil, 1, 75 end
end
LibStub = function() return nil end
GuildCrafts = {
    DATA_FORMAT_VERSION = 3,
    NewModule = function() return {} end,
    Debug = function(_, ...)
        local parts = {}
        for i = 1, select("#", ...) do parts[i] = tostring((select(i, ...))) end
        debugs[#debugs + 1] = table.concat(parts, " ")
    end,
    Print = function(_, text) messages[#messages + 1] = text end,
    Printf = function(_, format, ...)
        messages[#messages + 1] = string.format(format, ...)
    end,
}
dofile("GuildCrafts/Modules/Data.lua")
dofile("GuildCrafts/Modules/Comms.lua")
dofile("GuildCrafts/Modules/SyncPausePolicy.lua")
local Data, Comms, Pause = GuildCrafts.Data, GuildCrafts.Comms, GuildCrafts.SyncPausePolicy
Data.GetGuildDB = function() return db end
Data.GetPlayerKey = function() return playerKey end
Data.GetGuildKey = function() return nil end
Data.ScheduleTimer = function(_, fn, delay)
    timers[#timers + 1] = { fn = fn, delay = delay }
end
Data.db = { global = {} }
Pause.ScheduleTimer = function(_, fn, delay)
    timers[#timers + 1] = { fn = fn, delay = delay }
    return #timers
end
Pause.CancelTimer = function() end
Comms.TouchAddonUser = function() end
local processNextSyncQueue = Comms.ProcessNextSyncQueue
local function noSyncQueue() end
local sent
Comms.SendMessage = function(_, kind, payload, _, target)
    sent[#sent + 1] = { kind = kind, payload = payload, target = target }
end
Comms.SendChunked = function(_, kind, data, target, _, complete)
    sent[#sent + 1] = { kind = kind, payload = { data = data }, target = target }
    if complete then complete() end
end

local function profession(count, start, revision)
    local recipes = {}
    for i = 1, count do recipes[(start or 0) + i] = { name = "Recipe " .. i } end
    return { recipes = recipes, lastUpdate = revision }
end
local function entry(profs, revision, drops)
    return { professions = profs, lastUpdate = revision, dropped = drops, dataFormat = 3 }
end
local function count(prof)
    local n = 0
    for _ in pairs(prof.recipes) do n = n + 1 end
    return n
end
local function reset()
    now, known, db, messages, sent = 1000, {}, {}, {}, {}
    serverNow = 1000
    playerKey = "Owner-Realm"
    skillLines = {}
    classicSkillLines()
    Data._currentProfs, Data._dropHinted, Data._detectRetries = nil, nil, nil
    Data._scanRetries, Data._scanRetryPending = nil, nil
    debugs, timers = {}, {}
    Data.db.global = {}
    C_TradeSkillUI = nil
    C_SpellBook = nil
    Enum = nil
    Pause:OnInitialize()
    Comms.ProcessNextSyncQueue = noSyncQueue
end

local tests = {}
local function test(name, fn) tests[#tests + 1] = { name, fn } end

test("relearning retains drop history in snapshots", function()
    db[playerKey] = entry({}, 900, { Alchemy = 900 })
    known = { indices = { 1 }, [1] = "Alchemy" }
    Data:DetectProfessions()
    local snapshot = Data:StripSyncFields(db[playerKey])
    assert(snapshot.dropped and snapshot.dropped.Alchemy == 900, "drop history was erased")
end)

test("offline peer accepts empty relearn snapshot without old recipes", function()
    playerKey = "Peer-Realm"
    db["Owner-Realm"] = entry({ Alchemy = profession(100) }, 800)
    assert(Data:MergeIncoming({ ["Owner-Realm"] = entry({ Alchemy = profession(0) }, 1000, { Alchemy = 900 }) }))
    assert(count(db["Owner-Realm"].professions.Alchemy) == 0)
    assert(Data:MergeIncoming({ ["Owner-Realm"] = entry({ Alchemy = profession(3, 200) }, 1001, { Alchemy = 900 }) }))
    assert(count(db["Owner-Realm"].professions.Alchemy) == 3)
end)

test("reset bypasses partial-scan guard for first nonempty snapshot", function()
    playerKey = "Peer-Realm"
    db["Owner-Realm"] = entry({ Alchemy = profession(100) }, 800)
    assert(Data:MergeIncoming({ ["Owner-Realm"] = entry({ Alchemy = profession(3, 200) }, 1000, { Alchemy = 900 }) }), "reset blocked as partial scan")
    assert(count(db["Owner-Realm"].professions.Alchemy) == 3)
end)

test("partial scans remain blocked within the same profession generation", function()
    playerKey = "Peer-Realm"
    db["Owner-Realm"] = entry({ Alchemy = profession(100) }, 950, { Alchemy = 900 })
    assert(not Data:MergeIncoming({ ["Owner-Realm"] = entry({ Alchemy = profession(3) }, 1000, { Alchemy = 900 }) }))
    assert(count(db["Owner-Realm"].professions.Alchemy) == 100)
end)

test("empty reads still carry over recipes within the same generation", function()
    playerKey = "Peer-Realm"
    db["Owner-Realm"] = entry({ Alchemy = profession(100) }, 950, { Alchemy = 900 })
    Data:MergeIncoming({ ["Owner-Realm"] = entry({ Alchemy = profession(0) }, 1000, { Alchemy = 900 }) })
    assert(count(db["Owner-Realm"].professions.Alchemy) == 100)
end)

test("drop validates freshly unlearned profession", function()
    db[playerKey] = entry({ Alchemy = profession(3) }, 800)
    Data._currentProfs = { Alchemy = true }
    known = { indices = { nil, 2 }, [2] = "Herbalism" }
    Data:DropProfession("alchemy")
    assert(not db[playerKey].professions.Alchemy, "stale login cache blocked removal")
end)

test("drop rejects freshly learned profession", function()
    db[playerKey] = entry({ Alchemy = profession(3) }, 800)
    Data._currentProfs = {}
    known = { indices = { 1 }, [1] = "Alchemy" }
    Data:DropProfession("alchemy")
    assert(db[playerKey].professions.Alchemy, "known profession was deleted")
end)

test("two distinct removals sharing a timestamp both apply", function()
    playerKey = "Peer-Realm"
    db["Owner-Realm"] = entry({ Alchemy = profession(3), Cooking = profession(3) }, 800)
    Data:MergeProfessionRemoval("Owner-Realm", "Alchemy", 1000)
    Data:MergeProfessionRemoval("Owner-Realm", "Cooking", 1000)
    assert(not next(db["Owner-Realm"].professions), "second removal was discarded")
end)

test("unrelated recipe delta cannot block an equal-timestamp removal", function()
    playerKey = "Peer-Realm"
    db["Owner-Realm"] = entry({ Alchemy = profession(3), Cooking = profession(3) }, 800)
    Data:MergeDelta("Owner-Realm", "Cooking", 400, { name = "Food" }, 1000)
    Data:MergeProfessionRemoval("Owner-Realm", "Alchemy", 1000)
    assert(not db["Owner-Realm"].professions.Alchemy)
    assert(db["Owner-Realm"].professions.Cooking.recipes[400])
end)

test("unrelated newer delta cannot block an older profession removal", function()
    playerKey = "Peer-Realm"
    db["Owner-Realm"] = entry({ Alchemy = profession(3), Cooking = profession(3) }, 800)
    Data:MergeDelta("Owner-Realm", "Cooking", 400, { name = "Food" }, 1100)
    Data:MergeProfessionRemoval("Owner-Realm", "Alchemy", 1000)
    assert(not db["Owner-Realm"].professions.Alchemy)
    assert(db["Owner-Realm"].lastUpdate == 1100)
end)

test("stale removal cannot undo relearning", function()
    playerKey = "Peer-Realm"
    db["Owner-Realm"] = entry({ Alchemy = profession(3, 200, 1100) }, 1100, { Alchemy = 900 })
    Data:MergeProfessionRemoval("Owner-Realm", "Alchemy", 1000)
    assert(count(db["Owner-Realm"].professions.Alchemy) == 3)
    assert(db["Owner-Realm"].dropped.Alchemy == 900)
end)

test("removal records history even without stored recipes or member", function()
    playerKey = "Peer-Realm"
    Comms:HandleDeltaUpdate({ type = "remove_profession", member = "Owner-Realm",
        profession = "Alchemy", lastUpdate = 1000, x = 1 }, "Owner-Realm")
    assert(db["Owner-Realm"].dropped.Alchemy == 1000)
    Data:MergeDelta("Owner-Realm", "Alchemy", 1, { name = "Old" }, 999, 0)
    assert(not db["Owner-Realm"].professions.Alchemy)
end)

test("implicit removal and own deltas remain ignored", function()
    db[playerKey] = entry({ Alchemy = profession(3) }, 800)
    Comms:HandleDeltaUpdate({ type = "remove_profession", member = playerKey,
        profession = "Alchemy", lastUpdate = 1000, x = 1 }, playerKey)
    playerKey = "Peer-Realm"
    Comms:HandleDeltaUpdate({ type = "remove_profession", member = "Owner-Realm",
        profession = "Alchemy", lastUpdate = 1000 }, "Owner-Realm")
    assert(db["Owner-Realm"].professions.Alchemy)
end)

test("recipe delta carries reset history and clears missed pre-drop recipes", function()
    db[playerKey] = entry({ Alchemy = profession(3, 200) }, 1000, { Alchemy = 900 })
    Comms:BroadcastNewRecipes(playerKey, "Alchemy", db[playerKey].professions.Alchemy.recipes)
    local payload = sent[1].payload
    assert(payload.dropped == 900)
    playerKey = "Peer-Realm"
    db["Owner-Realm"] = entry({ Alchemy = profession(100) }, 800)
    Comms:HandleDeltaUpdate(payload, "Owner-Realm")
    assert(count(db["Owner-Realm"].professions.Alchemy) == 3)
    assert(db["Owner-Realm"].dropped.Alchemy == 900)
end)

test("old-generation delta cannot restore pre-drop recipes", function()
    playerKey = "Peer-Realm"
    db["Owner-Realm"] = entry({ Alchemy = profession(3, 200) }, 1000, { Alchemy = 900 })
    Data:MergeDelta("Owner-Realm", "Alchemy", 1, { name = "Old" }, 1100, 0)
    Data:MergeDelta("Owner-Realm", "Alchemy", 2, { name = "Old legacy" }, 900)
    assert(count(db["Owner-Realm"].professions.Alchemy) == 3)
    assert(db["Owner-Realm"].dropped.Alchemy == 900)
end)

test("newer snapshot lacking drop history cannot resurrect deleted profession", function()
    playerKey = "Peer-Realm"
    db["Owner-Realm"] = entry({}, 1000, { Alchemy = 900 })
    Data:MergeIncoming({ ["Owner-Realm"] = entry({ Alchemy = profession(100), Cooking = profession(3) }, 1100) })
    assert(not db["Owner-Realm"].professions.Alchemy)
    assert(db["Owner-Realm"].dropped.Alchemy == 900)
    assert(db["Owner-Realm"].professions.Cooking)
end)

test("equal-version snapshots reconcile distinct drop histories without losing either", function()
    playerKey = "Peer-Realm"
    db["Owner-Realm"] = entry({ Cooking = profession(3), Tailoring = profession(2) }, 1000, { Alchemy = 1000 })
    assert(Data:MergeIncoming({ ["Owner-Realm"] = entry({ Alchemy = profession(3), Tailoring = profession(2) }, 1000, { Cooking = 1000 }) }))
    assert(not db["Owner-Realm"].professions.Alchemy)
    assert(not db["Owner-Realm"].professions.Cooking)
    assert(db["Owner-Realm"].dropped.Alchemy == 1000 and db["Owner-Realm"].dropped.Cooking == 1000)
    assert(db["Owner-Realm"].professions.Tailoring)
end)

test("sync exchanges drop history despite equal current-format versions", function()
    playerKey = "Peer-Realm"
    db["Owner-Realm"] = entry({}, 1000, { Alchemy = 900 })
    Comms:ProcessSyncRequest("Other-Realm", { ["Owner-Realm"] = 1000 })
    local response, pull
    for _, message in ipairs(sent) do
        if message.kind == "SYNC_RESPONSE" then response = message.payload.data end
        if message.kind == "SYNC_PULL" then pull = message.payload.memberKeys end
    end
    assert(response and response["Owner-Realm"])
    assert(pull and pull[1] == "Owner-Realm")
end)

test("sync pulls owner snapshot at equal version even before seeing its drop", function()
    playerKey = "Peer-Realm"
    db["Owner-Realm"] = entry({ Alchemy = profession(100) }, 1000)
    Comms:ProcessSyncRequest("Owner-Realm", { ["Owner-Realm"] = 1000 })
    assert(sent[2].kind == "SYNC_PULL" and sent[2].payload.memberKeys[1] == "Owner-Realm")
end)

test("local drops and relearning advance revisions within the same second", function()
    db[playerKey] = entry({ Alchemy = profession(3), Cooking = profession(3) }, 1000)
    Data:DropProfession("alchemy")
    local first = db[playerKey].lastUpdate
    Data:DropProfession("cooking")
    assert(db[playerKey].lastUpdate > first)
    local second = db[playerKey].lastUpdate
    known = { indices = { 1 }, [1] = "Alchemy" }
    Data:DetectProfessions()
    assert(db[playerKey].lastUpdate > second)
    assert(db[playerKey].dropped.Alchemy == first)
end)

test("failed live profession read leaves recipes intact", function()
    db[playerKey] = entry({ Alchemy = profession(3) }, 800)
    known = { indices = { 1 } }
    Data:DropProfession("alchemy")
    assert(db[playerKey].professions.Alchemy)
    assert(messages[1]:find("Could not read", 1, true))
end)

test("tombstone and own-data protections remain intact", function()
    db[playerKey] = entry({ Alchemy = profession(3) }, 800)
    assert(not Data:MergeIncoming({ [playerKey] = entry({}, 1000, { Alchemy = 1000 }) }))
    playerKey = "Peer-Realm"
    db["Owner-Realm"] = { _tombstone = true, lastUpdate = 1000 }
    Data:MergeProfessionRemoval("Owner-Realm", "Alchemy", 1100)
    Data:MergeDelta("Owner-Realm", "Alchemy", 1, { name = "Old" }, 900, 0)
    assert(db["Owner-Realm"]._tombstone and db["Owner-Realm"].lastUpdate == 1000)
end)

test("relearned profession scans advance beyond the drop and no-op scans never regress", function()
    db[playerKey] = entry({}, 1000, { Alchemy = 1000 })
    C_TradeSkillUI = {
        GetBaseProfessionInfo = function()
            return { professionName = "Alchemy", skillLevel = 1, maxSkillLevel = 75 }
        end,
        GetAllRecipeIDs = function() return { 201, 202, 203 } end,
        GetRecipeInfo = function(id) return { learned = true, name = "Recipe " .. id } end,
    }
    assert(Data:ScanTradeSkillModern())
    local revision = db[playerKey].lastUpdate
    assert(revision > db[playerKey].dropped.Alchemy)
    assert(db[playerKey].professions.Alchemy.lastUpdate == revision)
    assert(not Data:ScanTradeSkillModern())
    assert(db[playerKey].lastUpdate == revision)
    assert(sent[1].payload.dropped == 1000 and sent[1].payload.lastUpdate == revision)
end)

test("recipe delta at or before its own drop revision is rejected", function()
    playerKey = "Peer-Realm"
    db["Owner-Realm"] = entry({ Alchemy = profession(100) }, 800)
    Data:MergeDelta("Owner-Realm", "Alchemy", 201, { name = "Stale" }, 1000, 1000)
    assert(count(db["Owner-Realm"].professions.Alchemy) == 100)
end)

test("live drop validation uses Classic skill-line fallback", function()
    db[playerKey] = entry({ Alchemy = profession(3) }, 800)
    Data._currentProfs = {}
    skillLines = { "Alchemy" }
    Data:DropProfession("alchemy")
    assert(db[playerKey].professions.Alchemy)
end)

test("drop refuses after an empty Forever read with no skill-line fallback", function()
    -- Forever 1.60.1: no C_SkillLine, GetNumSkillLines or GetSkillLineInfo (SKL probe, 2026-10-02).
    -- Data.lua caches those globals at load, so load a copy without them.
    GetNumSkillLines, GetSkillLineInfo = nil, nil
    local classicData = GuildCrafts.Data
    dofile("GuildCrafts/Modules/Data.lua")
    local foreverData = GuildCrafts.Data
    GuildCrafts.Data = classicData
    foreverData.GetGuildDB, foreverData.GetPlayerKey = Data.GetGuildDB, Data.GetPlayerKey
    foreverData.ScheduleTimer, foreverData.db = Data.ScheduleTimer, Data.db
    db[playerKey] = entry({ Alchemy = profession(3) }, 800)
    foreverData:DropProfession("alchemy")
    assert(db[playerKey].professions.Alchemy, "empty read deleted a known profession")
    assert(not db[playerKey].dropped, "empty read recorded a drop")
    assert(#sent == 0, "empty read broadcast a removal")
    assert(messages[1]:find("Could not read", 1, true))
end)

test("Classic Era empty GetProfessions still validates a drop from skill lines", function()
    db[playerKey] = entry({ Alchemy = profession(3) }, 800)
    skillLines = { "Herbalism" }
    Data:DropProfession("alchemy")
    assert(not db[playerKey].professions.Alchemy, "skill-line read blocked a valid drop")
end)

test("profession API errors do not delete recipes", function()
    db[playerKey] = entry({ Alchemy = profession(3) }, 800)
    known.error = true
    Data:DropProfession("alchemy")
    assert(db[playerKey].professions.Alchemy)
    assert(messages[1]:find("Could not read", 1, true))
end)

test("profession touch blocks older removals despite an unrelated newer member revision", function()
    playerKey = "Peer-Realm"
    db["Owner-Realm"] = entry({ Alchemy = profession(3, 0, 800), Cooking = profession(3, 0, 1200) }, 1200)
    Comms:HandleDeltaUpdate({ type = "touch", member = "Owner-Realm",
        profession = "Alchemy", lastUpdate = 1100 }, "Owner-Realm")
    Data:MergeProfessionRemoval("Owner-Realm", "Alchemy", 1000)
    assert(db["Owner-Realm"].professions.Alchemy.lastUpdate == 1100)
    assert(db["Owner-Realm"].lastUpdate == 1200)
end)

test("unrelated profession touch does not block removal", function()
    playerKey = "Peer-Realm"
    db["Owner-Realm"] = entry({ Alchemy = profession(3, 0, 800), Cooking = profession(3, 0, 800) }, 800)
    Comms:HandleDeltaUpdate({ type = "touch", member = "Owner-Realm",
        profession = "Cooking", lastUpdate = 1100 }, "Owner-Realm")
    Data:MergeProfessionRemoval("Owner-Realm", "Alchemy", 1000)
    assert(not db["Owner-Realm"].professions.Alchemy)
    assert(db["Owner-Realm"].professions.Cooking.lastUpdate == 1100)
end)

-- H11: a client with empty SavedVariables gets its own recipes back from peers.
local function syncRequestFrom(owner)
    Comms.myRole, Comms.currentDR, Comms.syncTimer, Comms.syncRetryCount = "OTHER", nil, nil, 0
    Comms.ScheduleTimer = function() end
    playerKey = owner
    Comms:SendSyncRequest()
    for _, message in ipairs(sent) do
        if message.kind == "SYNC_REQUEST" then return message.payload end
    end
end
local function responseData()
    for _, message in ipairs(sent) do
        if message.kind == "SYNC_RESPONSE" then return message.payload.data end
    end
end

test("empty local SavedVariables get own recipes back after sync", function()
    local ownerDb, drDb = {}, { ["Owner-Realm"] = entry({ Alchemy = profession(5, 100, 500) }, 500) }
    db = ownerDb
    known = { indices = { 1 }, [1] = "Alchemy" }
    Data:DetectProfessions()
    local stamped = ownerDb["Owner-Realm"].lastUpdate
    local request = syncRequestFrom("Owner-Realm")
    assert(request and request.restoreOwn == 1, "request did not ask for its own entry")

    db, playerKey, sent = drDb, "Dr-Realm", {}
    Comms.myRole, Comms.syncProcessing = "DR", false
    Comms:HandleSyncRequest(request, "Owner-Realm")
    local data = responseData()
    assert(data and data["Owner-Realm"], "DR did not send the requester's own entry")

    db, playerKey = ownerDb, "Owner-Realm"
    assert(Data:MergeIncoming(data), "restore reported no change")
    assert(count(ownerDb["Owner-Realm"].professions.Alchemy) == 5, "recipes not restored")
    assert(ownerDb["Owner-Realm"].lastUpdate == stamped, "restore changed the member revision")
end)

test("DR still pulls the requester's fresh snapshot when restoring", function()
    db = { ["Owner-Realm"] = entry({ Alchemy = profession(5) }, 500) }
    playerKey = "Dr-Realm"
    Comms.myRole, Comms.syncProcessing = "DR", false
    Comms:HandleSyncRequest({ sender = "Owner-Realm", vector = { ["Owner-Realm"] = 1000 }, restoreOwn = 1 }, "Owner-Realm")
    local pulled
    for _, message in ipairs(sent) do
        if message.kind == "SYNC_PULL" then pulled = message.payload.memberKeys[1] end
    end
    assert(pulled == "Owner-Realm", "pull of the requester's snapshot lost")
end)

test("DR sends the requester's own entry only when asked", function()
    db = { ["Owner-Realm"] = entry({ Alchemy = profession(5) }, 500) }
    playerKey = "Dr-Realm"
    Comms:ProcessSyncRequest("Owner-Realm", { ["Owner-Realm"] = 1000 })
    local data = responseData()
    assert(not (data and data["Owner-Realm"]), "own entry sent without restoreOwn")
end)

test("request has no restoreOwn when every known profession has recipes", function()
    db[playerKey] = entry({ Alchemy = profession(3) }, 800)
    known = { indices = { 1, 2 }, [1] = "Alchemy", [2] = "Herbalism" }
    Data:DetectProfessions()
    local request = syncRequestFrom(playerKey)
    assert(request and request.restoreOwn == nil, "gathering or full professions asked for a restore")
end)

test("restore never removes or replaces own recipes", function()
    db[playerKey] = entry({ Alchemy = profession(3), Cooking = profession(0) }, 800)
    known = { indices = { 1, 2 }, [1] = "Alchemy", [2] = "Cooking" }
    Data:DetectProfessions()
    Data:MergeIncoming({ [playerKey] = entry({ Alchemy = profession(10, 50), Cooking = profession(4, 80) }, 900) })
    local alchemy = db[playerKey].professions.Alchemy
    assert(count(alchemy) == 3 and alchemy.recipes[1] and not alchemy.recipes[51], "existing recipes replaced")
    assert(count(db[playerKey].professions.Cooking) == 4, "empty profession not filled")
end)

test("restore skips professions no longer known", function()
    db[playerKey] = entry({ Alchemy = profession(3) }, 800)
    known = { indices = { 1 }, [1] = "Alchemy" }
    Data:DetectProfessions()
    Data:MergeIncoming({ [playerKey] = entry({ Alchemy = profession(3), Tailoring = profession(6) }, 900) })
    assert(not db[playerKey].professions.Tailoring, "restored a profession the character doesn't know")
end)

test("restore skips copies older than a local drop", function()
    db[playerKey] = entry({}, 1000, { Alchemy = 950 })
    known = { indices = { 1 }, [1] = "Alchemy" }
    Data:DetectProfessions()
    Data:MergeIncoming({ [playerKey] = entry({ Alchemy = profession(5) }, 900) })
    assert(count(db[playerKey].professions.Alchemy) == 0, "pre-drop recipes restored")
end)

test("restore adopts a newer drop revision from the peer copy", function()
    db = {}
    known = { indices = { 1 }, [1] = "Alchemy" }
    Data:DetectProfessions()
    Data:MergeIncoming({ [playerKey] = entry({ Alchemy = profession(5, 0, 990) }, 990, { Alchemy = 700 }) })
    assert(count(db[playerKey].professions.Alchemy) == 5)
    assert(db[playerKey].dropped and db[playerKey].dropped.Alchemy == 700, "drop history not adopted")
end)

-- H6: every scan early-exit leaves a reason in the debug log (#9).
local function logged(needle)
    for _, line in ipairs(debugs) do
        if line:find(needle, 1, true) then return true end
    end
    return false
end
local function tradeSkill(overrides)
    C_TradeSkillUI = {
        GetBaseProfessionInfo = function()
            return { professionName = "Alchemy", skillLevel = 1, maxSkillLevel = 75 }
        end,
        GetAllRecipeIDs = function() return { 201, 202, 203 } end,
        GetRecipeInfo = function(id) return { learned = id ~= 203, name = "Recipe " .. id } end,
    }
    for k, v in pairs(overrides or {}) do C_TradeSkillUI[k] = v end
end

test("linked and NPC views log why they were skipped", function()
    tradeSkill({ IsTradeSkillLinked = function() return true end })
    Data:ScanTradeSkillModern()
    assert(logged("linked"), "no reason for a linked view")
    tradeSkill({ IsNPCCrafting = function() return true end })
    Data:ScanTradeSkillModern()
    assert(logged("NPC"), "no reason for an NPC view")
    assert(not db[playerKey], "a skipped view stored data")
end)

-- H10 (#13): a guild or guildmate recipe view isn't ours to store (F5).
test("guild and guildmate views are skipped, and logged", function()
    tradeSkill({ IsTradeSkillGuild = function() return true end })
    Data:ScanTradeSkillModern()
    assert(logged("guild recipe view"), "no reason for a guild view")
    tradeSkill({ IsTradeSkillGuildMember = function() return true end })
    Data:ScanTradeSkillModern()
    assert(logged("guildmate's recipe view"), "no reason for a guildmate view")
    assert(not db[playerKey], "a guild view stored data")
end)

test("own view scans when the guild view checks return false", function()
    tradeSkill({
        IsTradeSkillGuild = function() return false end,
        IsTradeSkillGuildMember = function() return false end,
    })
    assert(Data:ScanTradeSkillModern())
    assert(count(db[playerKey].professions.Alchemy) == 2, "own recipes not stored")
end)

test("a scan without a guild database logs why", function()
    tradeSkill()
    local original = Data.GetGuildDB
    Data.GetGuildDB = function() return nil end
    local ok, err = pcall(function()
        Data:ScanTradeSkillModern()
        Data:DetectProfessions()
    end)
    Data.GetGuildDB = original
    assert(ok, err)
    assert(logged("ScanTradeSkillModern: no guild database"), "scan exit not logged")
    assert(logged("DetectProfessions: no guild database"), "detect exit not logged")
end)

test("a finished scan logs recipe ID, learned and new counts", function()
    tradeSkill()
    Data:ScanTradeSkillModern()
    assert(logged("Alchemy: 3 recipe IDs, 2 learned, 2 new"), "counts missing: " .. table.concat(debugs, " | "))
    Data:ScanTradeSkillModern()
    assert(logged("Alchemy: 3 recipe IDs, 2 learned, 0 new"), "no-op scan counts missing")
end)

test("an unchanged rescan logs one line, the same each time", function()
    tradeSkill()
    Data:ScanTradeSkillModern()
    debugs = {}
    Data:ScanTradeSkillModern()
    local first = debugs
    debugs = {}
    Data:ScanTradeSkillModern()
    assert(#first == 1, "unchanged rescan logged " .. #first .. " lines: " .. table.concat(first, " | "))
    assert(#debugs == 1 and debugs[1] == first[1], "rescans logged different lines, so they can't collapse")
end)

test("scan retries keep one timer pending and give up with a reason", function()
    tradeSkill({ IsTradeSkillReady = function() return false end })
    for _ = 1, 5 do Data:ScanTradeSkillModern() end
    assert(#timers == 1, "pending retries " .. #timers)
    local fired = 0
    while #timers > 0 and fired < 50 do
        local timer = table.remove(timers, 1)
        timer.fn()
        fired = fired + 1
    end
    assert(#timers == 0, "retries never stopped")
    -- The last event resets the budget while one retry is already pending: 10 + 1.
    assert(fired <= 11, "retried " .. fired .. " times")
    assert(logged("giving up"), "give-up not logged")
end)

test("empty recipe IDs retry with a reason and then give up", function()
    tradeSkill({ GetAllRecipeIDs = function() return {} end })
    Data:ScanTradeSkillModern()
    assert(logged("GetAllRecipeIDs() empty"), "empty read not logged")
    while #timers > 0 do table.remove(timers, 1).fn() end
    assert(logged("giving up"), "give-up not logged")
end)

test("an event-triggered scan starts with a full retry budget", function()
    tradeSkill({ GetAllRecipeIDs = function() return {} end })
    Data._scanRetries = 10  -- left over from an earlier view that exited without retrying
    Data:ScanTradeSkillModern()
    assert(#timers == 1, "a fresh scan inherited an exhausted retry budget")
    assert(not logged("giving up"), "gave up on a fresh scan")
end)

test("a successful scan resets the retry budget", function()
    local ready = false
    tradeSkill({ IsTradeSkillReady = function() return ready end })
    Data:ScanTradeSkillModern()
    table.remove(timers, 1).fn()
    ready = true
    table.remove(timers, 1).fn()
    assert(#timers == 0 and (Data._scanRetries or 0) == 0, "retry budget not reset")
end)

-- H15 (#18), F12: Forever recipes have categoryID but no categoryName (CATR, 2026-10-04).
test("a Forever recipe stores the category heading GetCategoryInfo names", function()
    local categories = { [2450] = { name = "Elixirs", parentCategoryID = 2424 } }
    tradeSkill({
        GetCategoryInfo = function(id) return categories[id] end,
        GetRecipeInfo = function(id)
            local info = { learned = true, name = "Recipe " .. id, categoryID = 2450 }
            if id == 202 then info.categoryName = "Flasks" end
            return info
        end,
    })
    -- Reagents already complete from an earlier scan: the category is still backfilled.
    Data:SetRecipeInfo(-201, "Recipe 201", nil, { { name = "Herb", count = 1 } })
    Data:ScanTradeSkillModern()
    assert(Data:GetRecipeCategory(-201) == "Elixirs", "category: " .. tostring(Data:GetRecipeCategory(-201)))
    assert(Data:GetRecipeCategory(-203) == "Elixirs", "recipe without reagents has no category")
    assert(Data:GetRecipeCategory(-202) == "Flasks", "categoryName did not win where the client has it")
    C_TradeSkillUI.GetCategoryInfo = nil
    Data.db.global = {}
    Data:ScanTradeSkillModern()
    assert(Data:GetRecipeCategory(-201) == nil, "a client without GetCategoryInfo stored a category")
end)

-- H15 (#18), F16: C_SpellBook.IsSpellKnown is preferred over the global.
test("specialisation detection asks C_SpellBook first", function()
    C_SpellBook = { IsSpellKnown = function(id) return id == 28677 end }
    db[playerKey] = entry({ Alchemy = profession(1) }, 800)
    local ok, err = pcall(function() Data:DetectSpecialisations() end)
    C_SpellBook = nil
    assert(ok, err)
    assert(db[playerKey].professions.Alchemy.specialisation == "Elixir Master",
        "spec: " .. tostring(db[playerKey].professions.Alchemy.specialisation))
end)

-- H15 (#18), F21: an empty profession name is "not ready", not "not tracked".
test("an empty profession name falls back to the recipe, then retries", function()
    local byRecipe = "Alchemy"
    tradeSkill({
        GetBaseProfessionInfo = function()
            return { professionName = "", skillLevel = 1, maxSkillLevel = 75 }
        end,
        GetProfessionInfoByRecipeID = function(id)
            assert(id == 201, "looked up recipe " .. tostring(id))
            return { professionName = byRecipe }
        end,
    })
    assert(Data:ScanTradeSkillModern(), "fallback name not used")
    assert(count(db[playerKey].professions.Alchemy) == 2, "recipes not stored under the fallback name")
    db, debugs = {}, {}
    byRecipe = ""
    Data:ScanTradeSkillModern()
    assert(not logged("not tracked"), "empty name logged as not tracked")
    assert(#timers == 1, "empty name did not retry")
    assert(logged("no profession name"), "retry reason missing: " .. table.concat(debugs, " | "))
end)

-- H2 (#5): revisions use the realm clock, so a fast local clock can't win.
local function deltaPayload(kind)
    for _, message in ipairs(sent) do
        if message.kind == "DELTA_UPDATE" and message.payload.type == kind then return message.payload end
    end
end

test("a drop from a client 20 minutes fast loses to a later relearn", function()
    local observer = { ["Owner-Realm"] = entry({ Alchemy = profession(3, 0, 900) }, 900) }
    -- PC A: the local clock is 20 minutes fast.
    now = serverNow + 1200
    db = { ["Owner-Realm"] = entry({ Alchemy = profession(3, 0, 900) }, 900) }
    known = { indices = { nil, 2 }, [2] = "Herbalism" }
    Data:DropProfession("alchemy")
    local removal = deltaPayload("remove_profession")
    db, playerKey = observer, "Peer-Realm"
    Comms:HandleDeltaUpdate(removal, "Owner-Realm")
    assert(not observer["Owner-Realm"].professions.Alchemy, "drop not applied")
    -- Five minutes later the owner relearns on PC B, whose clock is right and which
    -- carries the drop history (restored from the guild's copy).
    serverNow = serverNow + 300
    now = serverNow
    playerKey, sent = "Owner-Realm", {}
    db = { ["Owner-Realm"] = entry({}, 950, { Alchemy = removal.lastUpdate }) }
    tradeSkill()
    assert(Data:ScanTradeSkillModern())
    local relearn = deltaPayload("add")
    db, playerKey = observer, "Peer-Realm"
    Comms:HandleDeltaUpdate(relearn, "Owner-Realm")
    local alchemy = observer["Owner-Realm"].professions.Alchemy
    assert(alchemy and count(alchemy) == 2, "the fast clock's drop beat the relearn")
end)

test("far-future stamps are refused, so a correctly stamped snapshot still wins", function()
    playerKey = "Peer-Realm"
    local future = serverNow + 365 * 86400
    db["Owner-Realm"] = entry({ Alchemy = profession(3, 0, 900), Tailoring = profession(2, 0, 900) }, 900)
    assert(not Data:MergeIncoming({ ["Owner-Realm"] = entry({ Alchemy = profession(1, 0, future) }, future) }),
        "future snapshot accepted")
    assert(not Data:MergeIncoming({ ["Owner-Realm"] = entry({ Alchemy = profession(3, 0, 950) }, 950, { Cooking = future }) }),
        "snapshot with a future drop accepted")
    Comms:HandleDeltaUpdate({ type = "touch", member = "Owner-Realm",
        profession = "Alchemy", lastUpdate = future }, "Owner-Realm")
    Data:MergeDelta("Owner-Realm", "Alchemy", 9, { name = "Future" }, future, 0)
    Data:MergeProfessionRemoval("Owner-Realm", "Tailoring", future)
    assert(not Data:MergeIncoming({ ["Gone-Realm"] = { _tombstone = true, lastUpdate = future } }),
        "future tombstone accepted")
    local stored = db["Owner-Realm"]
    assert(stored.lastUpdate == 900 and stored.professions.Alchemy.lastUpdate == 900, "future stamp stored")
    assert(not stored.professions.Alchemy.recipes[9], "future delta stored")
    assert(stored.professions.Tailoring and not stored.dropped, "future removal applied")
    assert(Data:MergeIncoming({ ["Owner-Realm"] = entry({ Alchemy = profession(4, 100, serverNow) }, serverNow) }),
        "correct snapshot lost to a broken clock")
end)

test("stamps within the tolerance are accepted unchanged and keep their order", function()
    playerKey = "Peer-Realm"
    db["Owner-Realm"] = entry({ Alchemy = profession(3, 0, 900) }, 900)
    local function removal() Data:MergeProfessionRemoval("Owner-Realm", "Alchemy", 2200) end
    local function relearn() Data:MergeDelta("Owner-Realm", "Alchemy", 500, { name = "New" }, 2201, 2200) end
    removal(); relearn()
    assert(count(db["Owner-Realm"].professions.Alchemy) == 3, "applied while far ahead")
    serverNow = 1950
    removal(); relearn()
    local stored = db["Owner-Realm"]
    assert(stored.dropped.Alchemy == 2200 and stored.lastUpdate == 2201, "stamps rewritten")
    assert(count(stored.professions.Alchemy) == 1 and stored.professions.Alchemy.recipes[500],
        "relearn collapsed onto its drop")
end)

test("a delayed older snapshot cannot undo a newer drop already saved", function()
    -- Saved before H2 by a fast clock; left as is, so its order against older copies holds.
    playerKey = "Peer-Realm"
    db["Owner-Realm"] = entry({}, 100003, { Alchemy = 100003 })
    serverNow = 1001
    Data:MergeIncoming({ ["Owner-Realm"] = entry({ Alchemy = profession(5) }, 100001, { Alchemy = 100000 }) })
    assert(not db["Owner-Realm"].professions.Alchemy, "pre-drop recipes restored")
    assert(db["Owner-Realm"].dropped.Alchemy == 100003, "saved drop rewritten")
end)

test("clients without GetServerTime stamp with the local clock", function()
    -- Data.lua captures GetServerTime at load, so load a copy without it.
    local saved, main = GetServerTime, GuildCrafts.Data
    GetServerTime = nil
    dofile("GuildCrafts/Modules/Data.lua")
    local classic = GuildCrafts.Data
    GuildCrafts.Data, GetServerTime = main, saved
    classic.GetGuildDB, classic.GetPlayerKey = Data.GetGuildDB, Data.GetPlayerKey
    classic.ScheduleTimer, classic.db = Data.ScheduleTimer, Data.db
    now = serverNow + 1200
    db[playerKey] = entry({ Alchemy = profession(3) }, 800)
    known = { indices = { nil, 2 }, [2] = "Herbalism" }
    classic:DropProfession("alchemy")
    assert(db[playerKey].dropped.Alchemy == now, "fallback did not use time()")
    -- A fallback clock may be slow, so it never refuses a peer's stamp.
    now = serverNow - 1200
    assert(classic:MergeIncoming({ ["Other-Realm"] = entry({ Alchemy = profession(2, 0, serverNow) }, serverNow) }),
        "slow fallback clock refused a server-stamped snapshot")
end)

-- H19 (#44): a paused DR leaves its sync queue alone until the pause lifts (F29).
local versionVectorReads = 0
local readVersionVector = Data.GetVersionVector
Data.GetVersionVector = function(...)
    versionVectorReads = versionVectorReads + 1
    return readVersionVector(...)
end
local function pausedDr()
    Comms:OnInitialize()
    Comms._prefixRegistered, Comms.RegisterComm = true, function() end
    Comms:OnEnable()
    Comms.ProcessNextSyncQueue = processNextSyncQueue
    Comms.myRole = "DR"
    playerKey = "Dr-Realm"
    db = { ["Owner-Realm"] = entry({ Alchemy = profession(5) }, 500) }
    Data._onlineCache, Data._onlineCacheAt = {}, nil
    versionVectorReads = 0
    Pause:OnCombatStart()
end
local function request(sender, retry, vector)
    Comms:HandleSyncRequest({ sender = sender, retry = retry or 0, vector = vector or {} }, sender)
end
local function answered(target)
    for _, message in ipairs(sent) do
        if message.kind == "SYNC_RESPONSE" and message.target == target then return true end
    end
    return false
end
local function endCombat()
    Pause:OnCombatEnd()
    timers[#timers].fn()
end
local function restrictions()
    Enum = { AddOnRestrictionState = { Inactive = 0, Activating = 1, Active = 2 } }
    Pause._pausingTypes = { [1] = "Encounter" }
end

test("a paused DR queues sync requests without building a response", function()
    pausedDr()
    request("Alpha-Realm")
    request("Bravo-Realm")
    assert(versionVectorReads == 0, "paused DR built " .. versionVectorReads .. " version vector(s)")
    assert(#sent == 0, "paused DR sent " .. #sent .. " message(s)")
    assert(#Comms.syncQueue == 2, "queue holds " .. #Comms.syncQueue)
end)

test("a pause that starts mid-transfer holds the rest of the queue", function()
    pausedDr()
    Pause._inCombat = false
    Comms.syncProcessing = true
    request("Alpha-Realm")
    request("Bravo-Realm")
    Pause:OnCombatStart()
    -- The in-flight transfer finishes, as SendChunked's onComplete does.
    Comms.syncProcessing = false
    Comms:ProcessNextSyncQueue()
    assert(versionVectorReads == 0, "paused DR drained its queue: " .. versionVectorReads .. " vector(s)")
    assert(#Comms.syncQueue == 2, "queue holds " .. #Comms.syncQueue)
end)

test("the queue drains in order once the pause lifts", function()
    pausedDr()
    request("Alpha-Realm")
    request("Bravo-Realm")
    endCombat()
    assert(answered("Alpha-Realm") and answered("Bravo-Realm"), "queued requesters not answered")
    assert(sent[1].target == "Alpha-Realm", "queue order lost")
    assert(#Comms.syncQueue == 0, "queue holds " .. #Comms.syncQueue)
end)

test("a lifted restriction drains the queue", function()
    pausedDr()
    restrictions()
    Pause:SetRestrictionState(1, 2)
    request("Alpha-Realm")
    endCombat()
    assert(versionVectorReads == 0, "drained while the restriction was active")
    Pause:SetRestrictionState(1, 0)
    assert(answered("Alpha-Realm"), "not answered after the restriction lifted")
end)

test("a pause lifting mid-transfer waits for that transfer to finish", function()
    pausedDr()
    request("Alpha-Realm")
    Comms.syncProcessing = true
    endCombat()
    assert(versionVectorReads == 0, "started a second transfer while one was in flight")
    Comms.syncProcessing = false
    Comms:ProcessNextSyncQueue()
    assert(answered("Alpha-Realm"), "queued requester not answered after the transfer")
end)

test("resume waits for the last pause condition to clear", function()
    pausedDr()
    Pause:OnZoneEnter(nil, false)
    request("Alpha-Realm")
    endCombat()
    assert(versionVectorReads == 0, "drained while still in a zone transition")
    timers[1].fn()
    assert(answered("Alpha-Realm"), "not answered after the transition cleared")
end)

test("a requester who logged off while queued is skipped", function()
    pausedDr()
    request("Alpha-Realm")
    request("Bravo-Realm")
    now = now + 1
    Data._onlineCache, Data._onlineCacheAt = { ["Alpha-Realm"] = false }, now
    endCombat()
    assert(not answered("Alpha-Realm"), "whispered an offline requester")
    assert(answered("Bravo-Realm"), "online requester not answered")
end)

test("a roster snapshot older than the request doesn't drop it", function()
    pausedDr()
    Data._onlineCache, Data._onlineCacheAt = { ["Alpha-Realm"] = false }, now
    now = now + 1
    request("Alpha-Realm")
    endCombat()
    assert(answered("Alpha-Realm"), "dropped a requester who reconnected after the roster read")
end)

test("a repeat request from a queued peer replaces its entry", function()
    pausedDr()
    request("Alpha-Realm", 0, { ["Owner-Realm"] = 100 })
    request("Bravo-Realm")
    request("Alpha-Realm", 1, { ["Owner-Realm"] = 500 })
    assert(#Comms.syncQueue == 2, "queue holds " .. #Comms.syncQueue)
    assert(Comms.syncQueue[1].requester == "Alpha-Realm", "repeat request moved in the queue")
    assert(Comms.syncQueue[1].vector["Owner-Realm"] == 500, "kept the older vector")
end)

test("a DR demoted during the pause answers only what its new role allows", function()
    pausedDr()
    request("Alpha-Realm", 0)
    request("Bravo-Realm", 1)
    Comms.myRole = "BDR"
    endCombat()
    assert(not answered("Alpha-Realm"), "former DR answered a retry=0 request")
    assert(answered("Bravo-Realm"), "BDR skipped a retry=1 request")
    assert(#Comms.syncQueue == 0, "queue holds " .. #Comms.syncQueue)
end)

test("a request older than the requester's sync timeout is dropped", function()
    pausedDr()
    request("Alpha-Realm")
    now = now + 121
    request("Bravo-Realm")
    endCombat()
    assert(not answered("Alpha-Realm"), "answered a request its sender gave up on")
    assert(answered("Bravo-Realm"), "fresh request not answered")
end)

test("the queue is bounded", function()
    pausedDr()
    for i = 1, Comms.SYNC_QUEUE_MAX + 5 do request("Peer" .. i .. "-Realm") end
    assert(#Comms.syncQueue == Comms.SYNC_QUEUE_MAX, "queue holds " .. #Comms.syncQueue)
    assert(Comms.syncQueue[1].requester == "Peer1-Realm", "dropped an earlier requester")
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
assert(failed == 0, failed .. " profession regression(s) failed")
print(#tests .. " profession regressions passed")
