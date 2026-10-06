----------------------------------------------------------------------
-- GuildCrafts — Report.lua
-- /gc report: a copyable diagnostic report for testers to paste, ending
-- with the debug ring buffer that GuildCrafts:Debug feeds.
-- Forever only (Camelot TOC).
----------------------------------------------------------------------
local _, _ns = ... -- luacheck: ignore (WoW addon bootstrap)
local GuildCrafts = _G.GuildCrafts

local Report = GuildCrafts:NewModule("Report")
GuildCrafts.Report = Report

-- Both bound the per-character SavedVariables the log lives in.
Report.LOG_SIZE = 200
Report.LINE_MAX = 200

----------------------------------------------------------------------
-- Debug ring buffer
-- Saved as { next = N, lines = { "HH:MM:SS text", ... } }: strings and
-- numbers only, because booleans may not round-trip on Forever.
----------------------------------------------------------------------

local function NewLog()
    return { next = 1, lines = {} }
end

local function IsValidLog(log)
    return type(log) == "table" and type(log.lines) == "table"
        and type(log.next) == "number" and log.next >= 1 and log.next <= Report.LOG_SIZE
end

local function AddLine(log, line)
    log.lines[log.next] = line
    log.next = log.next % Report.LOG_SIZE + 1
end

local function OrderedLines(log)
    local out = {}
    if log.lines[log.next] then
        -- Full: the slot about to be overwritten holds the oldest line.
        for i = 0, Report.LOG_SIZE - 1 do
            out[#out + 1] = log.lines[(log.next - 1 + i) % Report.LOG_SIZE + 1]
        end
    else
        for i = 1, log.next - 1 do
            out[#out + 1] = log.lines[i]
        end
    end
    return out
end

function Report:OnInitialize()
    GuildCraftsCharDB = GuildCraftsCharDB or {}
    local saved = GuildCraftsCharDB.debugLog
    if not IsValidLog(saved) then saved = NewLog() end
    GuildCraftsCharDB.debugLog = saved

    -- Lines logged before SavedVariables loaded are kept in memory until now.
    local pending = self._log
    self._log = saved
    if pending and pending ~= saved then
        for _, line in ipairs(OrderedLines(pending)) do AddLine(saved, line) end
    end

    self:Append("Session start", GuildCrafts.DISPLAY_VERSION, (select(2, GetBuildInfo())))
end

--- Append one line built like print(): arguments tostring'd and space-joined.
--- A line identical to the previous one rewrites it with a count, so event
--- storms (TRADE_SKILL_LIST_UPDATE rescans) can't evict the useful history.
function Report:Append(...)
    if not self._log then self._log = NewLog() end
    local log = self._log
    local parts = {}
    for i = 1, select("#", ...) do
        parts[i] = tostring((select(i, ...)))
    end
    local text = table.concat(parts, " ")
    local stamp = date("%H:%M:%S") .. " "
    if text == log.lastText and (log.repeats or 0) > 0 then
        log.repeats = log.repeats + 1
        local previous = (log.next - 2) % Report.LOG_SIZE + 1
        log.lines[previous] = (stamp .. text):sub(1, Report.LINE_MAX - 8) .. " (x" .. log.repeats .. ")"
        return
    end
    log.lastText, log.repeats = text, 1
    AddLine(log, (stamp .. text):sub(1, Report.LINE_MAX))
end

--- Logged lines, oldest first.
function Report:GetLogLines()
    return OrderedLines(self._log or NewLog())
end

----------------------------------------------------------------------
-- Report sections
-- Each appends lines to out. Build runs each under pcall so one broken
-- section can't cost the tester the rest of the report.
----------------------------------------------------------------------

local function SortedKeys(t)
    local keys = {}
    for k in pairs(t or {}) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    return keys
end

local function CountKeys(t)
    local n = 0
    for _ in pairs(t or {}) do n = n + 1 end
    return n
end

local function Age(stamp)
    if not stamp then return "never" end
    return (time() - stamp) .. "s ago"
end

local function MemberLabel(key)
    if not key then return "none" end
    local ok, name = pcall(GuildCrafts.Data.GetMemberName, GuildCrafts.Data, key)
    return key .. " (" .. tostring(ok and name or "?") .. ")"
end

local function EnumName(enum, value)
    for name, v in pairs(enum or {}) do
        if v == value then return name end
    end
    return "?"
end

local function AddClient(out)
    out[#out + 1] = string.format("Addon: %s, protocol %d, data format %d",
        GuildCrafts.DISPLAY_VERSION, GuildCrafts.VERSION, GuildCrafts.DATA_FORMAT_VERSION)
    local build = {}
    for i = 1, select("#", GetBuildInfo()) do
        build[i] = tostring((select(i, GetBuildInfo())))
    end
    out[#out + 1] = "Client: " .. table.concat(build, " | ")
end

local function AddIdentity(out)
    local Data = GuildCrafts.Data
    out[#out + 1] = "Player: " .. MemberLabel(Data:GetPlayerKey())
    out[#out + 1] = "Guild: " .. tostring(Data:GetGuildKey() or "none")
end

local function AddProfessions(out)
    local Data = GuildCrafts.Data
    local detected = SortedKeys(Data._currentProfs)
    out[#out + 1] = "Detected professions: " .. (Data._currentProfs and table.concat(detected, ", ") or "not read yet")

    local gdb = Data:GetGuildDB()
    local entry = gdb and gdb[Data:GetPlayerKey()]
    if not entry then
        out[#out + 1] = "Own entry: none"
    else
        out[#out + 1] = "Own entry: revision " .. tostring(entry.lastUpdate)
        for _, profName in ipairs(SortedKeys(entry.professions)) do
            local prof = entry.professions[profName]
            local line = string.format("  %s: %d recipes", profName, CountKeys(prof.recipes))
            if prof.lastUpdate then line = line .. ", revision " .. prof.lastUpdate end
            out[#out + 1] = line
        end
        local drops = {}
        for _, profName in ipairs(SortedKeys(entry.dropped)) do
            drops[#drops + 1] = profName .. " at " .. tostring(entry.dropped[profName])
        end
        out[#out + 1] = "Dropped: " .. (#drops > 0 and table.concat(drops, ", ") or "none")
    end

    local members, recipes = 0, 0
    for _, member in pairs(gdb or {}) do
        if type(member) == "table" and member.professions then
            members = members + 1
            for _, prof in pairs(member.professions) do recipes = recipes + CountKeys(prof.recipes) end
        end
    end
    out[#out + 1] = string.format("Database: %d members, %d recipes", members, recipes)
end

local function AddSync(out)
    local Comms = GuildCrafts.Comms
    out[#out + 1] = string.format("Role: %s, term %s", tostring(Comms.myRole), tostring(Comms.currentTerm))
    out[#out + 1] = "DR: " .. MemberLabel(Comms.currentDR)
    out[#out + 1] = "BDR: " .. MemberLabel(Comms.currentBDR)
    out[#out + 1] = string.format("Sync: pending %s, retries %s, queue %d, last completed %s",
        tostring(Comms.syncPending), tostring(Comms.syncRetryCount), #(Comms.syncQueue or {}),
        Age(Comms.lastSyncCompletedAt))
    out[#out + 1] = string.format("Addon users: %d known, %d online, status %s",
        CountKeys(Comms.addonUsers), Comms:GetActiveAddonUserCount(), Comms:GetSyncStatus())
    local result = Comms.prefixResult
    out[#out + 1] = "Prefix registration: " .. (result == nil and "not attempted"
        or tostring(result) .. " (" .. EnumName(Enum and Enum.RegisterAddonMessagePrefixResult, result) .. ")")
    out[#out + 1] = "Last message received: " .. Age(Comms.lastMessageAt)
    out[#out + 1] = "Unresolved-sender drops: " .. tostring(Comms.unresolvedSenderDrops)
    out[#out + 1] = string.format("Sender fallbacks: accepted %s, refused %s, revoked %s",
        tostring(Comms.senderFallbacks), tostring(Comms.senderFallbackRefusals),
        tostring(Comms.senderFallbackRevocations))
    out[#out + 1] = "Delta sender refusals: " .. tostring(Comms.deltaSenderRefusals)
    out[#out + 1] = "Send failures: " .. tostring(Comms.sendFailures)
end

local function AddPause(out)
    local Pause = GuildCrafts.SyncPausePolicy
    local held = {}
    for _, restrictionType in ipairs(SortedKeys(Pause._restrictions)) do
        held[#held + 1] = tostring(Pause._pausingTypes and Pause._pausingTypes[restrictionType] or restrictionType)
    end
    out[#out + 1] = string.format("Pause: %s (combat %s, instance %s, transition %s, restrictions %s)",
        tostring(Pause:ShouldPause()), tostring(Pause._inCombat), tostring(Pause._inInstance),
        tostring(Pause._inTransition), #held > 0 and table.concat(held, ",") or "none")
    local lockdown = C_ChatInfo and C_ChatInfo.InChatMessagingLockdown
    out[#out + 1] = "Chat lockdown: " .. (lockdown and tostring(lockdown()) or "unavailable")
end

local SECTIONS = {
    { "client", AddClient },
    { "identity", AddIdentity },
    { "professions", AddProfessions },
    { "sync", AddSync },
    { "pause", AddPause },
}

--- The full report as one string.
function Report:Build()
    local out = { "GuildCrafts report " .. date("%Y-%m-%d %H:%M:%S") }
    for _, section in ipairs(SECTIONS) do
        local ok, err = pcall(section[2], out)
        if not ok then out[#out + 1] = section[1] .. " section failed: " .. tostring(err) end
    end
    local lines = self:GetLogLines()
    out[#out + 1] = string.format("Debug log (%d lines, oldest first):", #lines)
    for _, line in ipairs(lines) do out[#out + 1] = line end
    return table.concat(out, "\n")
end

----------------------------------------------------------------------
-- Copy box
----------------------------------------------------------------------

local function EnsureFrame(self)
    if self._frame then return self._frame end

    local frame = CreateFrame("Frame", "GuildCraftsReportFrame", UIParent)
    frame:SetSize(760, 520)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    table.insert(UISpecialFrames, "GuildCraftsReportFrame")

    local background = frame:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0, 0, 0, 0.92)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 12, -10)
    title:SetText("GuildCrafts report - Ctrl-A, Ctrl-C to copy")

    local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 12, -30)
    scroll:SetPoint("BOTTOMRIGHT", -32, 12)

    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetFontObject(ChatFontNormal)
    edit:SetWidth(700)
    if edit.SetMaxLetters then edit:SetMaxLetters(0) end
    if edit.SetMaxBytes then edit:SetMaxBytes(0) end
    edit:SetScript("OnEscapePressed", function() frame:Hide() end)
    scroll:SetScrollChild(edit)

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 0, 0)

    frame.edit = edit
    self._frame = frame
    return frame
end

--- Open the copy box with a fresh report.
function Report:Show()
    local frame = EnsureFrame(self)
    frame:Show()
    -- Escape pipes so color codes and links copy as typed rather than render.
    frame.edit:SetText((self:Build():gsub("|", "||")))
    frame.edit:HighlightText()
    frame.edit:SetFocus()
end
