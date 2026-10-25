-- Playtime: remembers /played for every character you log in with, and
-- shows it in a window of its own: one bar per class, longest first, in
-- class colors, with the total across them. Hovering a bar lists the
-- characters of that class with level and time. /ur played opens it.
--
-- Grouped by class rather than one bar per character on purpose: a
-- retail account easily has dozens of characters, and thirteen rows at
-- most keeps the window readable. The per-character detail is one hover
-- away.
--
-- The client only tells an addon the played time when asked:
-- RequestTimePlayed() answers with TIME_PLAYED_MSG (total seconds, seconds
-- at this level), and the chat frames print the two "Time played" lines
-- on that same event. The addon asks once a few seconds after login and
-- keeps the lines out of chat for that one answer by unregistering the
-- chat frames from the event while the request is out (see below); a
-- /played typed by hand prints as usual and updates the record too.
--
-- Between answers the current character's time is the last answer plus
-- the clock since then, and at logout (also /reload) the record is moved
-- forward to that moment, so the saved value is never older than the
-- last session. Data lives in its own saved variable (UlRemedyPlayedDB)
-- so Core's settings pruning never touches it. Character keys are
-- "Name-Realm".
--
-- Ported from UlRemedyForever; the window uses the shared style in
-- Style.lua and the class grouping is new.

local LOGIN_DELAY = 5          -- seconds after login before the silent request
local SILENT_TIMEOUT = 15      -- give up suppressing if no answer comes

local DB
local me, myKey
local silent = false
local lastEvent              -- when the last answer came, for diagnostics
local requested = false
local window

local function Enabled()
    return UlRemedy.enabled and UlRemedy.enabled.playtime
end

------------------------------------------------------------------------
-- Saved data
------------------------------------------------------------------------

local function CharKey()
    local name = UnitName("player")
    local realm = GetNormalizedRealmName and GetNormalizedRealmName()
    if not realm or realm == "" then
        realm = (GetRealmName() or ""):gsub("%s+", "")
    end
    return name .. "-" .. realm, name, realm
end

local function InitDB()
    if not UlRemedyPlayedDB then UlRemedyPlayedDB = {} end
    DB = UlRemedyPlayedDB
    DB.chars = DB.chars or {}
end

local function InitCharacter()
    local key, name, realm = CharKey()
    myKey = key
    local rec = DB.chars[key]
    if not rec then
        rec = { total = 0, levelTime = 0 }
        DB.chars[key] = rec
    end
    rec.name = name
    rec.realm = realm
    rec.class = select(2, UnitClass("player"))
    rec.level = UnitLevel("player")
    me = rec
end

-- The current character's time right now: the last answer plus the clock
-- since. Other characters are not playing, so their stored total is it.
local function PlayedSeconds(rec)
    if not rec then return 0 end
    local total = rec.total or 0
    if rec == me and rec.at then
        total = total + math.max(0, time() - rec.at)
    end
    return total
end

local function LevelSeconds(rec)
    if not rec then return 0 end
    local t = rec.levelTime or 0
    if rec == me and rec.at then
        t = t + math.max(0, time() - rec.at)
    end
    return t
end

-- Moves the current character's record forward to now, so a stored value
-- read later (by another character, or after a crash) is up to date.
local function Settle()
    if me and me.at then
        me.total = PlayedSeconds(me)
        me.levelTime = LevelSeconds(me)
        me.at = time()
    end
end

------------------------------------------------------------------------
-- Asking the client
------------------------------------------------------------------------

-- Keeping one answer out of chat. The chat frames print the two lines
-- from their own TIME_PLAYED_MSG handler (ChatFrameMixin:SystemEventHandler
-- calling ChatFrameUtil.DisplayTimePlayed on 12.x). Rather than replace
-- a Blizzard function, the chat frames that have the event registered
-- are unregistered from it while our request is out, and registered
-- again once the answer has arrived (or on a timeout). Event registration
-- is a plain widget method, not protected, and nothing of ours runs
-- inside Blizzard's code.
local MAX_CHAT_FRAMES = 20     -- NUM_CHAT_WINDOWS plus temporary windows
local muted = {}               -- chat frames we unregistered

local function MuteChat()
    for i = 1, MAX_CHAT_FRAMES do
        local f = _G["ChatFrame" .. i]
        if f and f.IsEventRegistered and f:IsEventRegistered("TIME_PLAYED_MSG") then
            local ok = pcall(f.UnregisterEvent, f, "TIME_PLAYED_MSG")
            if ok then muted[#muted + 1] = f end
        end
    end
end

local function UnmuteChat()
    for _, f in ipairs(muted) do
        pcall(f.RegisterEvent, f, "TIME_PLAYED_MSG")
    end
    wipe(muted)
    silent = false
end

local function Request()
    if type(RequestTimePlayed) ~= "function" then return end
    requested = true
    silent = true
    MuteChat()
    RequestTimePlayed()
    C_Timer.After(SILENT_TIMEOUT, function()
        if silent then UnmuteChat() end
    end)
end

local RefreshWindow

local function OnTimePlayed(total, levelTime)
    lastEvent = time()
    if silent then
        -- Not during this dispatch: a frame registered now might still be
        -- handed the event we are hiding.
        C_Timer.After(0, UnmuteChat)
    end
    if not me then return end
    total, levelTime = tonumber(total), tonumber(levelTime)
    if not total then return end
    me.total = total
    me.levelTime = levelTime or me.levelTime or 0
    me.level = UnitLevel("player")
    me.at = time()
    RefreshWindow()
end

------------------------------------------------------------------------
-- Formatting
------------------------------------------------------------------------

function UlRemedy.FormatPlayed(seconds)
    seconds = math.floor(tonumber(seconds) or 0)
    local d = math.floor(seconds / 86400)
    seconds = seconds % 86400
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    if d > 0 then return string.format("%dd %dh %dm", d, h, m) end
    if h > 0 then return string.format("%dh %dm", h, m) end
    return string.format("%dm", m)
end

local function ClassColor(classFile)
    local c = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
    if c then return c.r, c.g, c.b end
    return 1, 0.82, 0
end

local function ClassName(classFile)
    local n = classFile and LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[classFile]
    return n or classFile or "Unknown"
end

local function Colored(classFile, text)
    local r, g, b = ClassColor(classFile)
    return string.format("|cff%02x%02x%02x%s|r",
        math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5), text)
end

-- Every character with an answer, grouped by class. Each group carries
-- its characters longest first and the class total; groups come longest
-- first too.
local function ClassGroups()
    local groups, byClass = {}, {}
    if not DB then return groups end
    for key, rec in pairs(DB.chars) do
        if rec.at then
            rec.key = key
            local class = rec.class or "UNKNOWN"
            local g = byClass[class]
            if not g then
                g = { class = class, chars = {}, total = 0 }
                byClass[class] = g
                groups[#groups + 1] = g
            end
            g.chars[#g.chars + 1] = rec
            g.total = g.total + PlayedSeconds(rec)
            if rec == me then g.mine = true end
        end
    end
    for _, g in ipairs(groups) do
        table.sort(g.chars, function(a, b)
            local sa, sb = PlayedSeconds(a), PlayedSeconds(b)
            if sa ~= sb then return sa > sb end
            return (a.name or "") < (b.name or "")
        end)
    end
    table.sort(groups, function(a, b)
        if a.total ~= b.total then return a.total > b.total end
        return ClassName(a.class) < ClassName(b.class)
    end)
    return groups
end

------------------------------------------------------------------------
-- Window
------------------------------------------------------------------------
-- One row per class: class name and character count on the left, a bar
-- whose length is the class's share of the longest, and the time at the
-- right. The window's height follows the number of classes. While it is
-- open a ticker redraws it every half minute so the bar of the class you
-- are on keeps growing.

local WIDTH = 480
local ROW_H = 28
local BAR_H = 14
local NAME_W = 150
local TIME_W = 110
local MIN_ROWS = 3
local MAX_ROWS = 15            -- more classes than the game has

local function RowTooltip(self)
    local g = self.group
    if not g then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(Colored(g.class, ClassName(g.class)))
    GameTooltip:AddDoubleLine("Total", UlRemedy.FormatPlayed(g.total), 1, 1, 1, 1, 1, 1)
    if self.share then
        GameTooltip:AddDoubleLine("Share of all", string.format("%d%%", self.share), 1, 1, 1, 1, 1, 1)
    end
    GameTooltip:AddLine(" ")
    for _, rec in ipairs(g.chars) do
        local left = string.format("%s |cffaaaaaa(%d) %s|r", Colored(g.class, rec.name or "?"), rec.level or 0, rec.realm or "")
        local right = UlRemedy.FormatPlayed(PlayedSeconds(rec)) .. (rec == me and " |cffaaaaaa+|r" or "")
        GameTooltip:AddDoubleLine(left, right, 1, 1, 1, 1, 1, 1)
    end
    if g.mine and me then
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine("This level", UlRemedy.FormatPlayed(LevelSeconds(me)), 0.7, 0.7, 0.7, 0.7, 0.7, 0.7)
    end
    GameTooltip:Show()
end

local function GetRow(i)
    local row = window.rows[i]
    if row then return row end
    local UI = UlRemedy.UI
    row = CreateFrame("Frame", nil, window.card)
    row:SetHeight(ROW_H)

    row.name = UI.Text(row, "GameFontNormal", UI.TEXT)
    row.name:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.name:SetWidth(NAME_W)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)

    row.track = row:CreateTexture(nil, "BACKGROUND")
    row.track:SetTexture(UI.WHITE)
    row.track:SetVertexColor(1, 1, 1, 0.06)
    row.track:SetPoint("LEFT", row, "LEFT", NAME_W + 8, 0)
    row.track:SetPoint("RIGHT", row, "RIGHT", -TIME_W - 8, 0)
    row.track:SetHeight(BAR_H)

    row.bar = row:CreateTexture(nil, "ARTWORK")
    row.bar:SetTexture(UI.WHITE)
    row.bar:SetPoint("LEFT", row.track, "LEFT", 0, 0)
    row.bar:SetHeight(BAR_H)

    row.time = UI.Text(row, "GameFontHighlight", UI.TEXT)
    row.time:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    row.time:SetWidth(TIME_W)
    row.time:SetJustifyH("RIGHT")

    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetTexture(UI.WHITE)
    hl:SetVertexColor(1, 1, 1, 0.04)
    hl:SetAllPoints()
    row:EnableMouse(true)
    row:SetScript("OnEnter", RowTooltip)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)

    window.rows[i] = row
    return row
end

local CARD_PAD = 10

RefreshWindow = function()
    if not (window and window:IsShown()) then return end
    local groups = ClassGroups()
    local total, longest, chars = 0, 0, 0
    for _, g in ipairs(groups) do
        total = total + g.total
        chars = chars + #g.chars
        if g.total > longest then longest = g.total end
    end

    local trackW = WIDTH - 2 * UlRemedy.UI.PAD - 2 * CARD_PAD - NAME_W - 8 - TIME_W - 8
    local shown = math.min(#groups, MAX_ROWS)
    for i = 1, shown do
        local g = groups[i]
        local row = GetRow(i)
        row.group = g
        row.share = total > 0 and math.floor(g.total / total * 100 + 0.5) or nil
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", window.card, "TOPLEFT", CARD_PAD, -(CARD_PAD + (i - 1) * ROW_H))
        row:SetPoint("RIGHT", window.card, "RIGHT", -CARD_PAD, 0)
        row.name:SetText(string.format("%s |cffaaaaaa(%d)|r", Colored(g.class, ClassName(g.class)), #g.chars))
        local cr, cg, cb = ClassColor(g.class)
        row.bar:SetVertexColor(cr, cg, cb, g.mine and 1 or 0.8)
        local frac = longest > 0 and g.total / longest or 0
        row.bar:SetWidth(math.max(2, trackW * frac))
        row.time:SetText(UlRemedy.FormatPlayed(g.total) .. (g.mine and " |cffaaaaaa+|r" or ""))
        row:Show()
    end
    for i = shown + 1, #window.rows do window.rows[i]:Hide() end

    if #groups == 0 then
        window.summary:SetText(requested and "Waiting for the client's answer..." or "Nothing recorded yet. Type /played once.")
    elseif chars == 1 then
        window.summary:SetText(string.format("Total %s on one character", UlRemedy.FormatPlayed(total)))
    else
        window.summary:SetText(string.format("Total |cffffffff%s|r across %d characters, %d classes", UlRemedy.FormatPlayed(total), chars, #groups))
    end
    local rows = math.max(MIN_ROWS, shown)
    window.card:SetHeight(2 * CARD_PAD + rows * ROW_H)
    window:SetHeight(window.topH + window.card:GetHeight() + window.bottomH)
end

local function CreateWindow()
    local UI = UlRemedy.UI
    local PAD = UI.PAD
    local f = UI.Window("UlRemedyPlaytimeFrame", WIDTH, 200, UlRemedy.name, "Playtime")
    f.rows = {}

    f.summary = UI.Text(f, "GameFontNormal", UI.MUTED)
    f.summary:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -(UI.TITLE_H + 12))
    f.summary:SetPoint("RIGHT", f, "RIGHT", -PAD, 0)
    f.summary:SetJustifyH("LEFT")

    f.topH = UI.TITLE_H + 12 + 16 + 10      -- title, summary line, gap
    f.card = CreateFrame("Frame", nil, f, "BackdropTemplate")
    f.card:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, -f.topH)
    f.card:SetPoint("RIGHT", f, "RIGHT", -PAD, 0)
    UI.Backdrop(f.card, UI.CARD, UI.CARD_BORDER)

    f.footer = UI.Text(f, "GameFontHighlightSmall", UI.MUTED)
    f.footer:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", PAD, 12)
    f.footer:SetPoint("RIGHT", f, "RIGHT", -PAD, 0)
    f.footer:SetJustifyH("LEFT")
    f.footer:SetText("+ counts up while you play. Hover a class for its characters.")
    f.bottomH = 12 + 14 + 12                -- gap, footer, bottom margin

    f:SetScript("OnShow", function(self)
        RefreshWindow()
        if not self.ticker then
            self.ticker = C_Timer.NewTicker(30, RefreshWindow)
        end
    end)
    f:SetScript("OnHide", function(self)
        if self.ticker then
            self.ticker:Cancel()
            self.ticker = nil
        end
    end)
    return f
end

function UlRemedy.TogglePlaytimeWindow()
    if not window then window = CreateWindow() end
    if window:IsShown() then
        window:Hide()
    else
        if me and not me.at then Request() end
        window:Show()
    end
end

function UlRemedy.PlaytimeDebug()
    local groups = ClassGroups()
    local n = 0
    for _, g in ipairs(groups) do n = n + #g.chars end
    print(UlRemedy.name .. ": playtime " .. (Enabled() and "on" or "off")
        .. ", characters with an answer " .. n .. " in " .. #groups .. " classes"
        .. ", RequestTimePlayed " .. (type(RequestTimePlayed) == "function" and "present" or "MISSING")
        .. ", last answer " .. (lastEvent and date("%H:%M:%S", lastEvent) or "none")
        .. ", chat frames muted now " .. #muted
        .. (me and me.at and (", this character " .. UlRemedy.FormatPlayed(PlayedSeconds(me))) or ", this character: no answer yet"))
end

------------------------------------------------------------------------
-- Events
------------------------------------------------------------------------

function UlRemedy.RefreshPlaytime()
    if Enabled() and me and not me.at then Request() end
    RefreshWindow()
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_LOGOUT")
frame:RegisterEvent("TIME_PLAYED_MSG")
frame:RegisterEvent("PLAYER_LEVEL_UP")
frame:SetScript("OnEvent", function(self, event, arg1, arg2)
    if event == "ADDON_LOADED" and arg1 == UlRemedy.name then
        InitDB()
        self:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_LOGIN" then
        InitCharacter()
        if Enabled() then C_Timer.After(LOGIN_DELAY, Request) end
    elseif event == "PLAYER_LOGOUT" then
        Settle()
    elseif event == "TIME_PLAYED_MSG" then
        pcall(OnTimePlayed, arg1, arg2)
    elseif event == "PLAYER_LEVEL_UP" then
        -- The level clock starts over; the next answer has the exact value.
        if me then
            Settle()
            me.levelTime = 0
            me.level = tonumber(arg1) or UnitLevel("player")
            RefreshWindow()
        end
    end
end)
