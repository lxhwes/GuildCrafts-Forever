-- How does a current (v3, main) client treat candidate N2 opt-out markers?
-- Run from the repository root: lua5.1 spec/later/research/optout-v3-compat.lua
local now = 2000
local db = {}
local roster = {}
time = function() return now end
GetRealmName = function() return "Realm" end
GetSpellInfo = function() return nil end
IsSpellKnown = function() return false end
IsInGuild = function() return true end
GetNumGuildMembers = function() return #roster end
GetGuildRosterInfo = function(i) local r = roster[i]; if r then return r, nil,nil,nil,nil,nil,nil,nil,true,nil,nil,nil,nil,nil,nil,nil,r end end
LibStub = function() return nil end
GuildCrafts = { DATA_FORMAT_VERSION = 3, NewModule = function() return {} end, Debug = function() end, Print = function() end, Printf = function() end }
dofile("GuildCrafts/Modules/Data.lua")
local Data = GuildCrafts.Data
Data.GetGuildDB = function() return db end
Data.GetPlayerKey = function() return "Me-Realm" end
Data.db = { global = {} }

local function live(rev)
  return { lastUpdate = rev, dataFormat = 3, professions = { Alchemy = { lastUpdate = rev, recipes = { [1] = {name="A"}, [2] = {name="B"} } } } }
end
local function count(e) local n=0; for _,p in pairs(e and e.professions or {}) do for _ in pairs(p.recipes or {}) do n=n+1 end end; return n end
local function show(label) local e = db["Alt-Realm"]; print(string.format("  %-44s entry=%s tomb=%s optout=%s recipes=%d", label, tostring(e ~= nil), tostring(e and e._tombstone), tostring(e and e._optout), count(e))) end

print("A) plain marker { _optout=1, lastUpdate=1500, no professions }")
db = { ["Alt-Realm"] = live(1000) }
Data:MergeIncoming({ ["Alt-Realm"] = { _optout = 1, lastUpdate = 1500, dataFormat = 4 } })
show("after merge (old client had live@1000)")
print("  relayed as:", (function() local s = Data:StripSyncFields(db["Alt-Realm"]); return "lastUpdate="..s.lastUpdate.." recipes="..count(s).." optout="..tostring(s._optout) end)())

print("B) tombstone-shaped marker { _tombstone=true, _optout=1, lastUpdate=1500 }")
db = { ["Alt-Realm"] = live(1000) }
Data:MergeIncoming({ ["Alt-Realm"] = { _tombstone = true, _optout = 1, lastUpdate = 1500 } })
show("after merge (old client had live@1000)")
print("  relayed as:", (function() local s = Data:StripSyncFields(db["Alt-Realm"]); local k={} for x in pairs(s) do k[#k+1]=x end table.sort(k) return table.concat(k, ",") end)())
roster = { "Alt-Realm", "Me-Realm", "Other-Realm" }
Data:PruneRoster()
show("after PruneRoster (Alt still in roster)")
Data:MergeIncoming({ ["Alt-Realm"] = live(1000) })
show("after stale live@1000 from another old peer")
Data:MergeIncoming({ ["Alt-Realm"] = { _tombstone = true, _optout = 1, lastUpdate = 1500 } })
show("after marker again from a new DR")
