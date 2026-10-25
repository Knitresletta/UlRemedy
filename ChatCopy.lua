-- Chat Copy: the chat log in a window where the text can be selected and
-- copied.
--
-- The chat frame draws its lines but gives no way to select them. This
-- module keeps a small button at the chat frame's top-right corner which
-- opens a window with the same lines in an edit box: everything is
-- selected on open, so Ctrl+C copies the lot, and a drag selects part of
-- it. The lines come from the selected chat tab (ChatFrame1 when there
-- is none) through its own history: GetNumMessages and GetMessageInfo,
-- where index 1 is the oldest line kept (ScrollingMessageFrame.lua maps
-- it to the back of its buffer). Colour codes, textures and link
-- wrappers are stripped so the copy is plain text; the link's visible
-- text stays. The chat keeps as many lines as its own setting says, 128
-- by default, and the window shows what the chat still has.
--
-- Nothing of Blizzard's is written to or hooked: the button is anchored
-- to the chat frame but parented to UIParent, and the history is only
-- read, each line behind pcall in case a client hands back something
-- that cannot be read as text. /ur chat opens the window too.
--
-- Ported from UlRemedyForever; the window uses the shared style in
-- Style.lua instead of BasicFrameTemplateWithInset.

local WIDTH, HEIGHT = 640, 460

local button, window

local function Enabled()
    return UlRemedy.enabled and UlRemedy.enabled.chatcopy
end

------------------------------------------------------------------------
-- Reading the chat
------------------------------------------------------------------------

local function Plain(text)
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    text = text:gsub("|T.-|t", ""):gsub("|A.-|a", "")
    text = text:gsub("|H.-|h(.-)|h", "%1")
    return text
end

-- The chat frame whose lines to show: the selected tab when it can be
-- read, ChatFrame1 otherwise.
local function SourceFrame()
    local f = SELECTED_CHAT_FRAME
    if f and type(f.GetNumMessages) == "function" and type(f.GetMessageInfo) == "function" then return f end
    f = ChatFrame1
    if f and type(f.GetNumMessages) == "function" and type(f.GetMessageInfo) == "function" then return f end
    return nil
end

-- Returns the lines, the number that could not be read, and the frame's
-- name.
local function ChatLines()
    local f = SourceFrame()
    if not f then return {}, 0, "?" end
    local okN, n = pcall(f.GetNumMessages, f)
    if not okN or type(n) ~= "number" then return {}, 0, f:GetName() or "?" end
    local lines, unreadable = {}, 0
    for i = 1, n do
        local ok, msg = pcall(f.GetMessageInfo, f, i)
        if ok and type(msg) == "string" then
            local okP, plain = pcall(Plain, msg)
            lines[#lines + 1] = okP and plain or msg
        else
            unreadable = unreadable + 1
        end
    end
    return lines, unreadable, f:GetName() or "?"
end

------------------------------------------------------------------------
-- Window
------------------------------------------------------------------------

-- The lines go in one at a time: a line the edit box refuses (one it
-- cannot render, or a value the client keeps secret) is then the only
-- one lost, and the status line says so, with the size of what is
-- really in the box.
local function Fill()
    if not window then return end
    local lines, unreadable, name = ChatLines()
    local edit = window.edit
    edit:SetText("")
    local shown, refused = 0, 0
    for _, line in ipairs(lines) do
        local ok = pcall(edit.Insert, edit, line .. "\n")
        if ok then shown = shown + 1 else refused = refused + 1 end
    end
    local okT, text = pcall(edit.GetText, edit)
    local size = okT and type(text) == "string" and #text or -1
    local status = string.format("%d lines from %s, %d characters in the box", shown, name, size)
    if unreadable > 0 then status = status .. string.format(", %d could not be read", unreadable) end
    if refused > 0 then status = status .. string.format(", %d refused by the box", refused) end
    window.status:SetText(status)
    -- Everything selected: Ctrl+C right away copies the whole log.
    edit:SetFocus()
    edit:SetCursorPosition(0)
    edit:HighlightText()
end

local function CreateWindow()
    local UI = UlRemedy.UI
    local PAD = UI.PAD
    local f = UI.Window("UlRemedyChatCopyFrame", WIDTH, HEIGHT, UlRemedy.name, "Chat log")

    -- The text sits on a card; the scroll frame is inset so the scroll
    -- bar's arrows stay inside it.
    local card = CreateFrame("Frame", nil, f, "BackdropTemplate")
    card:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -(UI.TITLE_H + PAD))
    card:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PAD, 52)
    UI.Backdrop(card, UI.CARD, UI.CARD_BORDER)

    local scroll = CreateFrame("ScrollFrame", nil, card, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", card, "TOPLEFT", 8, -8)
    scroll:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -28, 8)

    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetFontObject(ChatFontNormal)
    edit:SetMaxLetters(0)
    edit:SetWidth(scroll:GetWidth())
    edit:SetScript("OnEscapePressed", function() f:Hide() end)
    -- Keep the text from being edited away by accident: a keypress that
    -- would change it puts the log back.
    edit:SetScript("OnTextChanged", function(self, byUser)
        if byUser then Fill() end
    end)
    scroll:SetScrollChild(edit)
    scroll:SetScript("OnSizeChanged", function(self, w) edit:SetWidth(w) end)
    f.edit = edit

    f.status = UI.Text(f, "GameFontHighlightSmall", UI.MUTED)
    f.status:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", PAD, 12)

    local refresh = UI.Button(f, "Refresh", 90, 24, Fill)
    refresh:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PAD, 14)

    local hint = UI.Text(f, "GameFontHighlightSmall", UI.MUTED)
    hint:SetPoint("RIGHT", refresh, "LEFT", -10, 0)
    hint:SetText("Everything is selected: Ctrl+C copies. Drag to select part. Esc closes.")

    f:SetScript("OnShow", Fill)
    return f
end

function UlRemedy.ToggleChatCopy()
    if not window then window = CreateWindow() end
    if window:IsShown() then window:Hide() else window:Show() end
end

------------------------------------------------------------------------
-- Button by the chat
------------------------------------------------------------------------

local function CreateButton()
    if not ChatFrame1 then return nil end
    local UI = UlRemedy.UI
    local b = UI.Button(UIParent, "Copy", 44, 18, UlRemedy.ToggleChatCopy)
    b.label:SetFontObject(GameFontNormalSmall)
    b:SetPoint("BOTTOMRIGHT", ChatFrame1, "TOPRIGHT", 0, 2)
    b:SetAlpha(0.45)
    b:SetFrameStrata("LOW")
    b:HookScript("OnEnter", function(self)
        self:SetAlpha(1)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Open the chat log in a window the text can be copied from.", 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    b:HookScript("OnLeave", function(self)
        self:SetAlpha(0.45)
        GameTooltip:Hide()
    end)
    return b
end

function UlRemedy.RefreshChatCopy()
    if Enabled() then
        if not button then button = CreateButton() end
        if button then button:Show() end
    else
        if button then button:Hide() end
        if window then window:Hide() end
    end
end

local frame = CreateFrame("Frame", "UlRemedyChatCopyEventFrame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function()
    UlRemedy.RefreshChatCopy()
end)
