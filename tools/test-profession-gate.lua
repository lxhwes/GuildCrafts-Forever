-- Profession-gate regressions (Data:ApplyClientProfessionGate) with stubbed skill lines.
-- Run from the repository root: lua5.1 tools/test-profession-gate.lua
-- Data.lua prunes at load, so each case loads a fresh copy.
local function load(level, lines)
    GetClassicExpansionLevel = function() return level end
    GetSpellInfo = function() return nil end
    time = function() return 1 end
    GuildCrafts = {
        NewModule = function() return { ScheduleTimer = function() end } end,
        Print = function() end,
        Printf = function() end,
        Debug = function() end,
    }
    local names = { [171] = "Alchemy", [755] = "Jewelcrafting", [164] = "Blacksmithing" }
    C_TradeSkillUI = lines and {
        GetAllProfessionTradeSkillLines = function() return lines end,
        GetProfessionInfoBySkillLineID = function(id) return { professionName = names[id] } end,
    } or nil
    dofile("GuildCrafts/Modules/Data.lua")
    GuildCrafts.Data:OnEnable()
    local tracked = {}
    for _, name in ipairs(GuildCrafts.Data:GetTrackedProfessions()) do tracked[name] = true end
    return tracked
end

local tests = {}
local function test(name, fn) tests[#tests + 1] = { name, fn } end

test("raised expansion level without a JC skill line drops JC only", function()
    local t = load(1, { 171, 164 })
    assert(not t.Jewelcrafting and t.Alchemy)
end)

test("JC skill line present keeps JC", function()
    assert(load(1, { 171, 755 }).Jewelcrafting)
end)

test("empty skill-line list leaves the expansion check in charge", function()
    assert(load(1, {}).Jewelcrafting)
end)

test("missing C_TradeSkillUI leaves the expansion check in charge", function()
    assert(load(1, nil).Jewelcrafting)
end)

test("expansion level 0 keeps the vanilla set", function()
    local t = load(0, { 171 })
    assert(not t.Jewelcrafting and not t.Inscription and t.Blacksmithing)
end)

local failed = 0
for _, case in ipairs(tests) do
    local ok, err = pcall(case[2])
    if ok then
        print("PASS " .. case[1])
    else
        failed = failed + 1
        print("FAIL " .. case[1] .. ": " .. tostring(err))
    end
end
assert(failed == 0, failed .. " profession-gate regression(s) failed")
print(#tests .. " profession-gate regressions passed")
