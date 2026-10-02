----------------------------------------------------------------------
-- GuildCrafts — ForeverIdentity.lua
-- Member keys for WoW Forever. Loaded only from GuildCrafts_Camelot.toc,
-- after Modules\Data.lua, and replaces Data's key and name helpers.
--
-- Forever characters have a first name and a surname and no realm.
-- UnitFullName returns the surname as its second value, the guild roster
-- and addon-message senders both read "First Surname", and one guild can
-- span several servers. So members are keyed by GUID
-- ("Player-4619-012F81BC"); names are for display and whispers only and
-- come from the guild roster. Verified in game on 2026-10-02 (ME, GR and
-- SND probes in docs/ingame-commands.md).
----------------------------------------------------------------------
local _, _ns = ... -- luacheck: ignore (WoW addon bootstrap)
local GuildCrafts = _G.GuildCrafts
local Data = GuildCrafts.Data

local ROSTER_RESCAN_INTERVAL = 5  -- seconds between roster rescans after a lookup miss

local nameToGuid = {}
local guidToName = {}
local lastRescan = 0

local function IsSecret(value)
    return issecretvalue ~= nil and issecretvalue(value)
end

local function IsPlayerGUID(value)
    return type(value) == "string" and not IsSecret(value)
        and value:match("^Player%-%d+%-%x+$") ~= nil
end

local function Remember(name, guid)
    if type(name) ~= "string" or name == "" or IsSecret(name) or not IsPlayerGUID(guid) then
        return false
    end
    nameToGuid[name] = guid
    guidToName[guid] = name
    return true
end

-- Rebuild the name/GUID maps from the roster, at most every few seconds.
local function RescanRoster()
    local now = GetTime()
    if now - lastRescan < ROSTER_RESCAN_INTERVAL then return end
    lastRescan = now
    if not (IsInGuild() and GetNumGuildMembers and GetGuildRosterInfo) then return end
    for i = 1, GetNumGuildMembers() do
        local name, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, guid = GetGuildRosterInfo(i)
        Remember(name, guid)
    end
end

-- "First Surname" for the local player, as the roster and senders spell it.
local function PlayerDisplayName()
    local getName = UnitNameUnmodified or UnitName
    local first, surname = getName("player")
    if type(first) ~= "string" or IsSecret(first) then return nil end
    if type(surname) == "string" and surname ~= "" and not IsSecret(surname) then
        return first .. " " .. surname
    end
    return first
end

-- Spellings a name may arrive in: as-is, a pre-GUID beta key ("First-Surname"),
-- or with a trailing "-Realm" suffix.
local function NameCandidates(name)
    local spaced = name:gsub("%-", " ", 1)
    local stripped = name:match("^(.*)%-[^%-]*$")
    return { name, spaced, stripped }
end

local function ResolveName(name)
    local candidates = NameCandidates(name)
    for _, candidate in ipairs(candidates) do
        if candidate and nameToGuid[candidate] then return nameToGuid[candidate] end
    end
    RescanRoster()
    for _, candidate in ipairs(candidates) do
        if candidate and nameToGuid[candidate] then return nameToGuid[candidate] end
    end
    return nil
end

----------------------------------------------------------------------
-- Data overrides
----------------------------------------------------------------------

function Data:GetPlayerKey()
    if self._playerKey then return self._playerKey end
    local guid = UnitGUID("player")
    if not IsPlayerGUID(guid) then
        GuildCrafts:Debug("ForeverIdentity: UnitGUID(\"player\") unavailable — no player key yet")
        return nil
    end
    self._playerKey = guid
    local name = PlayerDisplayName()
    if name then Remember(name, guid) end
    return guid
end

--- GUIDs pass through; names resolve to a GUID through the guild roster.
--- Returns nil for a name that isn't in the roster.
function Data:NormalizeMemberKey(key)
    if type(key) ~= "string" or key == "" or IsSecret(key) then return nil end
    if IsPlayerGUID(key) then return key end
    return ResolveName(key)
end

function Data:RosterMemberKey(name, guid)
    if Remember(name, guid) then return guid end
    return nil
end

function Data:GetMemberName(key)
    local name = guidToName[key]
    if not name and key == self._playerKey then name = PlayerDisplayName() end
    if not name and IsPlayerGUID(key) then
        RescanRoster()
        name = guidToName[key]
    end
    return name or key
end

function Data:GetWhisperTarget(key)
    local name = self:GetMemberName(key)
    if name == key and IsPlayerGUID(key) then return nil end
    return name
end

-- Move the local player's pre-GUID beta entry ("First-Surname") onto the GUID key
-- before the generic key normalisation runs. Other members' old entries resolve
-- through NormalizeMemberKey when the roster is loaded, or age out via PruneRoster.
local baseMergeRealmlessKeys = Data.MergeRealmlessKeys
function Data:MergeRealmlessKeys(gdb)
    local guid = self:GetPlayerKey()
    local first, surname = UnitFullName("player")
    if gdb and guid and type(first) == "string" and type(surname) == "string" then
        local legacyKey = first .. "-" .. surname:gsub("[%s%-']", "")
        if gdb[legacyKey] and not gdb[guid] then
            gdb[guid] = gdb[legacyKey]
            gdb[legacyKey] = nil
            GuildCrafts:Debug("ForeverIdentity: moved", legacyKey, "to", guid)
        end
    end
    return baseMergeRealmlessKeys(self, gdb)
end
