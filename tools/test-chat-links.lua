-- Chat link and whisper regressions (UI/MainFrame.lua, F25) with stubbed WoW APIs.
-- Run from the repository root: lua5.1 tools/test-chat-links.lua
-- Forever defines ChatFrameUtil.InsertLink/OpenChat; ChatEdit_InsertLink and ChatFrame_OpenChat
-- are only aliases in Blizzard_DeprecatedChatInfo (Deprecated_ChatFrame.lua:43, :74 at 9a789c0).
local calls
local printed

local function record(name)
    return function(...)
        calls[#calls + 1] = { name = name, args = { ... } }
        return true
    end
end

C_Item = {
    GetItemInfo = function(id) return "Item " .. id, "|Hitem:" .. id .. "|h[Item " .. id .. "]|h" end,
}
C_Spell = {
    GetSpellLink = function(id) return "|Hspell:" .. id .. "|h[Spell " .. id .. "]|h" end,
}
GuildCrafts = {
    Data = { GetWhisperTarget = function(_, key) return key end },
    Print = function(_, msg) printed[#printed + 1] = msg end,
}
dofile("GuildCrafts/UI/MainFrame.lua")
local UI = GuildCrafts.UI

local function reset()
    calls, printed = {}, {}
    ChatFrameUtil = nil
    ChatEdit_InsertLink = nil
    ChatFrame_OpenChat = nil
end

local function only(name)
    assert(#calls == 1, "expected one call to " .. name .. ", got " .. #calls)
    assert(calls[1].name == name, "called " .. calls[1].name .. ", not " .. name)
    return calls[1].args
end

local tests = {}
local function test(name, fn) tests[#tests + 1] = { name, fn } end

test("shift-click link goes through ChatFrameUtil.InsertLink", function()
    ChatFrameUtil = { InsertLink = record("ChatFrameUtil.InsertLink") }
    ChatEdit_InsertLink = record("ChatEdit_InsertLink")
    UI:LinkRecipeToChat(101)
    local args = only("ChatFrameUtil.InsertLink")
    assert(args[1] == "|Hitem:101|h[Item 101]|h", "link " .. tostring(args[1]))
end)

test("spell recipes link through ChatFrameUtil.InsertLink", function()
    ChatFrameUtil = { InsertLink = record("ChatFrameUtil.InsertLink") }
    UI:LinkRecipeToChat(-7)
    local args = only("ChatFrameUtil.InsertLink")
    assert(args[1] == "|Hspell:7|h[Spell 7]|h", "link " .. tostring(args[1]))
end)

test("shift-click falls back to ChatEdit_InsertLink without ChatFrameUtil", function()
    ChatEdit_InsertLink = record("ChatEdit_InsertLink")
    UI:LinkRecipeToChat(101)
    only("ChatEdit_InsertLink")
end)

test("shift-click falls back when ChatFrameUtil lacks InsertLink", function()
    ChatFrameUtil = {}
    ChatEdit_InsertLink = record("ChatEdit_InsertLink")
    UI:LinkRecipeToChat(101)
    only("ChatEdit_InsertLink")
end)

test("shift-click with no chat API says so instead of erroring", function()
    UI:LinkRecipeToChat(101)
    assert(#printed == 1, "printed " .. #printed .. " message(s)")
end)

-- An edit box that records its tell target and chat type, like ChatFrameEditBoxBaseMixin.
local function editBoxStub()
    local box = { chatFrame = { name = "ChatFrame1" } }
    function box:SetTellTarget(target) self.tellTarget = target end
    function box:SetChatType(chatType) self.chatType = chatType end
    return box
end

test("[W] sets a two-word name as the tell target (F20)", function()
    local box = editBoxStub()
    ChatFrameUtil = {
        ChooseBoxForSend = function() return box end,
        OpenChat = record("ChatFrameUtil.OpenChat"),
    }
    ChatFrame_OpenChat = record("ChatFrame_OpenChat")
    UI:OpenWhisper("Geo Prizm", "Elixir")
    assert(box.tellTarget == "Geo Prizm", "tell target " .. tostring(box.tellTarget))
    assert(box.chatType == "WHISPER", "chat type " .. tostring(box.chatType))
    local args = only("ChatFrameUtil.OpenChat")
    assert(args[1] == "Can you craft Elixir for me?", "text " .. tostring(args[1]))
    -- With no frame, OpenChat hands plain text to a chat focus override such as the Communities
    -- box (ChatFrameUtil.lua:434-438, CommunitiesChatFrame.lua:492 at 9a789c0).
    assert(args[2] == box.chatFrame, "OpenChat not given the whisper box's chat frame")
end)

test("[W] types /w when the edit box has no chat frame", function()
    local box = editBoxStub()
    box.chatFrame = nil
    ChatFrameUtil = {
        ChooseBoxForSend = function() return box end,
        OpenChat = record("ChatFrameUtil.OpenChat"),
    }
    UI:OpenWhisper("Geo", "Elixir")
    local args = only("ChatFrameUtil.OpenChat")
    assert(args[1] == "/w Geo Can you craft Elixir for me?", "text " .. tostring(args[1]))
    assert(box.tellTarget == nil, "set a tell target it couldn't open")
end)

test("[W] types /w through ChatFrameUtil.OpenChat without ChooseBoxForSend", function()
    ChatFrameUtil = { OpenChat = record("ChatFrameUtil.OpenChat") }
    ChatFrame_OpenChat = record("ChatFrame_OpenChat")
    UI:OpenWhisper("Geo", "Elixir")
    local args = only("ChatFrameUtil.OpenChat")
    assert(args[1] == "/w Geo Can you craft Elixir for me?", "text " .. tostring(args[1]))
end)

test("[W] falls back to ChatFrame_OpenChat without ChatFrameUtil", function()
    ChatFrame_OpenChat = record("ChatFrame_OpenChat")
    UI:OpenWhisper("Geo", "Elixir")
    local args = only("ChatFrame_OpenChat")
    assert(args[1] == "/w Geo Can you craft Elixir for me?", "text " .. tostring(args[1]))
end)

test("[W] with no chat API says so instead of erroring", function()
    UI:OpenWhisper("Geo", "Elixir")
    assert(#printed == 1, "printed " .. #printed .. " message(s)")
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
assert(failed == 0, failed .. " chat link regression(s) failed")
print(#tests .. " chat link regressions passed")
