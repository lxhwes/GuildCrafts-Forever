-- Profession deletion regressions with stubbed WoW APIs.
-- Run from the repository root: lua5.1 tools/test-profession-sync.lua
local now = 1000
local known = {}
local db = {}
local messages = {}
local playerKey = "Owner-Realm"
local skillLines = {}

time = function() return now end
GetRealmName = function() return "Realm" end
GetSpellInfo = function() return nil end
IsSpellKnown = function() return false end
IsInGuild = function() return true end
GetProfessions = function()
    if known.error then error("profession API unavailable") end
    return unpack(known.indices or {}, 1, 5)
end
GetNumSkillLines = function() return #skillLines end
GetSkillLineInfo = function(index) return skillLines[index], false, nil, 1, nil, nil, 75 end
GetProfessionInfo = function(index)
    local prof = known[index]
    if prof then return prof, nil, 1, 75 end
end
LibStub = function() return nil end
GuildCrafts = {
    DATA_FORMAT_VERSION = 3,
    NewModule = function() return {} end,
    Debug = function() end,
    Print = function(_, text) messages[#messages + 1] = text end,
    Printf = function(_, format, ...)
        messages[#messages + 1] = string.format(format, ...)
    end,
}
dofile("GuildCrafts/Modules/Data.lua")
dofile("GuildCrafts/Modules/Comms.lua")
local Data, Comms = GuildCrafts.Data, GuildCrafts.Comms
Data.GetGuildDB = function() return db end
Data.GetPlayerKey = function() return playerKey end
Data.ScheduleTimer = function() end
Data.db = { global = {} }
Comms.TouchAddonUser = function() end
Comms.ProcessNextSyncQueue = function() end
local sent
Comms.SendMessage = function(_, kind, payload)
    sent[#sent + 1] = { kind = kind, payload = payload }
end
Comms.SendChunked = function(_, kind, data, _, _, complete)
    sent[#sent + 1] = { kind = kind, payload = { data = data } }
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
    playerKey = "Owner-Realm"
    skillLines = {}
    Data._currentProfs, Data._dropHinted, Data._detectRetries = nil, nil, nil
    Data.db.global = {}
    C_TradeSkillUI = nil
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
