-- Tooltip index rebuild scheduling regressions (Modules/Tooltip.lua, F9) with stubbed WoW APIs.
-- Run from the repository root: lua5.1 tools/test-tooltip-index.lua
-- C_Timer.After returns nothing, so the module can't hold a handle to its pending timer.
local now = 0
local timers = {}
local inCombat = false
local rebuilds = 0

GetTime = function() return now end
InCombatLockdown = function() return inCombat end
GetItemInfo = function() return nil end
C_Timer = {
    After = function(delay, fn)
        timers[#timers + 1] = { at = now + delay, fn = fn }
    end,
}
GuildCrafts = {
    NewModule = function() return {} end,
    Data = {
        GetGuildDB = function()
            rebuilds = rebuilds + 1
            return { ["Player-1-AA"] = { professions = { Alchemy = { recipes = { [101] = { name = "Elixir" } } } } } }
        end,
        GetLocalizedRecipeName = function(_, _, name) return name end,
    },
}
dofile("GuildCrafts/Modules/Tooltip.lua")
local Tooltip = GuildCrafts.Tooltip

-- Advance the clock to `target`, firing due timers in order.
local function advance(target)
    while true do
        table.sort(timers, function(a, b) return a.at < b.at end)
        local nextTimer = timers[1]
        if not nextTimer or nextTimer.at > target then break end
        table.remove(timers, 1)
        now = nextTimer.at
        nextTimer.fn()
    end
    now = target
end

local function reset()
    now, timers, inCombat, rebuilds = 0, {}, false, 0
    Tooltip._rebuildTimer, Tooltip._rebuildPending, Tooltip._rebuildAt = nil, nil, nil
    Tooltip:RebuildIndex()
    rebuilds = 0
end

local tests = {}
local function test(name, fn) tests[#tests + 1] = { name, fn } end

test("one invalidation rebuilds once, 2 s later", function()
    Tooltip:InvalidateIndex()
    advance(1.9)
    assert(rebuilds == 0, "rebuilt early")
    advance(10)
    assert(rebuilds == 1, "rebuilds " .. rebuilds)
end)

test("a burst of sync chunks triggers one index rebuild", function()
    local maxPending = 0
    for i = 1, 20 do
        advance(i)  -- chunks arrive 1 s apart
        Tooltip:InvalidateIndex()
        maxPending = math.max(maxPending, #timers)
    end
    assert(rebuilds == 0, "rebuilt during the burst: " .. rebuilds)
    assert(maxPending == 1, "pending timers peaked at " .. maxPending)
    advance(60)
    assert(rebuilds == 1, "rebuilds after burst " .. rebuilds)
end)

test("rebuild waits 2 s after the last change", function()
    Tooltip:InvalidateIndex()
    advance(1.5)
    Tooltip:InvalidateIndex()
    advance(3.0)
    assert(rebuilds == 0, "rebuilt 1.5 s after the last change")
    advance(3.6)
    assert(rebuilds == 1, "rebuilds " .. rebuilds)
end)

test("repeated in-combat rebuilds leave one pending retry", function()
    inCombat = true
    Tooltip:InvalidateIndex()
    for _ = 1, 5 do Tooltip:RebuildIndex() end
    assert(#timers == 1, "pending retries " .. #timers)
    advance(20)
    assert(rebuilds == 0, "rebuilt in combat")
    assert(#timers == 1, "pending retries while in combat " .. #timers)
    inCombat = false
    advance(30)
    assert(rebuilds == 1, "rebuilds after combat " .. rebuilds)
    assert(#timers == 0, "timer left after rebuild")
end)

test("a retry with nothing dirty skips the rebuild", function()
    inCombat = true
    Tooltip:RebuildIndex()
    inCombat = false
    advance(10)
    assert(rebuilds == 0, "rebuilt a clean index " .. rebuilds .. " time(s)")
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
assert(failed == 0, failed .. " tooltip index regression(s) failed")
print(#tests .. " tooltip index regressions passed")
