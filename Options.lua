-- Options: a window with one switch per feature, opened with /ur.
--
-- Drawn with the shared style in Style.lua (UlRemedy.UI): each feature
-- group as a card, and a pill-shaped toggle switch per feature in the
-- accent purple.
-- The list of features comes from Core (UlRemedy.FEATURES), so a new
-- module only needs a line there. Clicking a row goes through
-- UlRemedy.SetFeature, the same path as the chat command, so modules get
-- notified the same way either route is used. The window is closed by
-- Escape (UISpecialFrames) and can be dragged by its title bar.
--
-- Layout: the groups are laid out in two columns of equal width, split so
-- the columns come out as even as whole groups allow. The window's height
-- follows the taller column, so adding a feature usually does not change
-- it. When both columns fill up, the next step is scrolling or collapsible
-- groups, not a taller window.

local UI = UlRemedy.UI
local PAD, GAP = UI.PAD, 12           -- GAP: between columns and between cards
local COLUMN_W = 380
local WIDTH = PAD + COLUMN_W + GAP + COLUMN_W + PAD
local BOTTOM_H = 70                 -- button row and hint
local CARD_PAD = 10
local HEADER_H = 22
local ROW_H = 46                    -- name plus up to two lines of description
local SWITCH_W, SWITCH_H = 38, 20

local TRACK_OFF = { 0.28, 0.28, 0.34 }
local KNOB_OFF = { 0.72, 0.72, 0.76 }
local Unpack, Texture = UI.Unpack, UI.Texture

local window
local rows = {}

-- A pill-shaped on/off switch: a bar with two round ends and a knob that
-- sits left when off and right when on.
local function CreateSwitch(parent)
    local sw = CreateFrame("Frame", nil, parent)
    sw:SetSize(SWITCH_W, SWITCH_H)
    local mid = Texture(sw, SWITCH_W - SWITCH_H, SWITCH_H)
    mid:SetPoint("CENTER")
    local left = Texture(sw, SWITCH_H, SWITCH_H, true)
    left:SetPoint("LEFT")
    local right = Texture(sw, SWITCH_H, SWITCH_H, true)
    right:SetPoint("RIGHT")
    local knob = Texture(sw, SWITCH_H - 6, SWITCH_H - 6, true, "OVERLAY")
    sw.track = { mid, left, right }
    sw.knob = knob
    function sw:SetOn(on)
        local track = on and UI.ACCENT or TRACK_OFF
        for _, t in ipairs(self.track) do t:SetVertexColor(Unpack(track)) end
        self.knob:ClearAllPoints()
        if on then
            self.knob:SetVertexColor(1, 1, 1)
            self.knob:SetPoint("RIGHT", self, "RIGHT", -3, 0)
        else
            self.knob:SetVertexColor(Unpack(KNOB_OFF))
            self.knob:SetPoint("LEFT", self, "LEFT", 3, 0)
        end
    end
    sw:SetOn(false)
    return sw
end

-- One feature: the whole row is the button, the switch shows the state.
local function CreateRow(card, y, feature)
    local row = CreateFrame("Button", nil, card)
    row:SetPoint("TOPLEFT", card, "TOPLEFT", CARD_PAD, y)
    row:SetPoint("RIGHT", card, "RIGHT", -CARD_PAD, 0)
    row:SetHeight(ROW_H)
    row.key = feature.key

    local hover = row:CreateTexture(nil, "BACKGROUND")
    hover:SetTexture(UI.WHITE)
    hover:SetAllPoints()
    hover:SetVertexColor(1, 1, 1, 0.04)
    hover:Hide()
    row:SetScript("OnEnter", function() hover:Show() end)
    row:SetScript("OnLeave", function() hover:Hide() end)

    local switch = CreateSwitch(row)
    switch:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    row.switch = switch

    local name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    name:SetPoint("TOPLEFT", row, "TOPLEFT", 6, -4)
    name:SetPoint("RIGHT", switch, "LEFT", -10, 0)
    name:SetJustifyH("LEFT")
    name:SetTextColor(Unpack(UI.TEXT))
    name:SetText(feature.label)

    local desc = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -1)
    desc:SetPoint("RIGHT", switch, "LEFT", -10, 0)
    desc:SetJustifyH("LEFT")
    desc:SetWordWrap(true)
    desc:SetMaxLines(2)
    desc:SetTextColor(Unpack(UI.MUTED))
    desc:SetText(feature.desc)

    row:SetScript("OnClick", function(self)
        UlRemedy.SetFeature(self.key, not UlRemedy.enabled[self.key])
    end)
    return row
end

local function CardHeight(g)
    return CARD_PAD + HEADER_H + 4 + #g.features * ROW_H + CARD_PAD
end

-- A group as a card: slightly lighter panel, header in the accent color
-- with a thin line under it, then one row per feature.
local function CreateCard(parent, x, y, g)
    local card = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    card:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    card:SetSize(COLUMN_W, CardHeight(g))
    UI.Backdrop(card, UI.CARD, UI.CARD_BORDER)

    local header = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header:SetPoint("TOPLEFT", card, "TOPLEFT", CARD_PAD + 6, -CARD_PAD)
    header:SetHeight(HEADER_H)
    header:SetJustifyV("MIDDLE")
    header:SetTextColor(Unpack(UI.ACCENT_TEXT))
    header:SetText(g.name)

    local line = card:CreateTexture(nil, "ARTWORK")
    line:SetTexture(UI.WHITE)
    line:SetVertexColor(UI.ACCENT[1], UI.ACCENT[2], UI.ACCENT[3], 0.35)
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", card, "TOPLEFT", CARD_PAD, -(CARD_PAD + HEADER_H))
    line:SetPoint("RIGHT", card, "RIGHT", -CARD_PAD, 0)

    local rowY = -(CARD_PAD + HEADER_H + 4)
    for _, feature in ipairs(g.features) do
        rows[feature.key] = CreateRow(card, rowY, feature)
        rowY = rowY - ROW_H
    end
    return card
end

-- Features grouped in the order Core lists the groups; anything with an
-- unknown group lands under "Other" at the end.
local function GroupedFeatures()
    local groups = {}
    local byName = {}
    for _, name in ipairs(UlRemedy.FEATURE_GROUPS or {}) do
        local g = { name = name, features = {} }
        groups[#groups + 1] = g
        byName[name] = g
    end
    for _, feature in ipairs(UlRemedy.FEATURES or {}) do
        local g = byName[feature.group or "Other"]
        if not g then
            g = { name = feature.group or "Other", features = {} }
            groups[#groups + 1] = g
            byName[g.name] = g
        end
        g.features[#g.features + 1] = feature
    end
    local kept = {}
    for _, g in ipairs(groups) do
        if #g.features > 0 then kept[#kept + 1] = g end
    end
    return kept
end

-- Height of a column holding these cards, gaps between them included.
local function ColumnHeight(list)
    local h = 0
    for _, g in ipairs(list) do h = h + CardHeight(g) + GAP end
    return h > 0 and h - GAP or 0
end

-- Split the groups over two columns so the taller column is as short as
-- possible. Every way of assigning groups to the two columns is tried
-- (there are only a handful of groups); each column keeps Core's group
-- order. The window's height follows the taller column, so a new feature
-- usually changes which column a group sits in rather than the height.
local function SplitColumns(groups)
    local n = #groups
    local bestMask, bestH = 0, math.huge
    for mask = 0, (2 ^ n) - 1 do
        local left, right = {}, {}
        for i, g in ipairs(groups) do
            local bit = math.floor(mask / (2 ^ (i - 1))) % 2
            if bit == 0 then left[#left + 1] = g else right[#right + 1] = g end
        end
        local h = math.max(ColumnHeight(left), ColumnHeight(right))
        -- Prefer the lower mask on ties: earlier groups stay left.
        if h < bestH then bestH, bestMask = h, mask end
    end
    -- Swapping the columns changes nothing about the height, so make sure
    -- the first group (Vendor) is top-left.
    if bestMask % 2 == 1 then bestMask = (2 ^ n) - 1 - bestMask end
    local left, right = {}, {}
    for i, g in ipairs(groups) do
        local bit = math.floor(bestMask / (2 ^ (i - 1))) % 2
        if bit == 0 then left[#left + 1] = g else right[#right + 1] = g end
    end
    return left, right, bestH
end

local function CreateWindow()
    local groups = GroupedFeatures()
    local left, right, columnH = SplitColumns(groups)
    local height = UI.TITLE_H + PAD + columnH + BOTTOM_H

    local f = UI.Window("UlRemedyOptionsFrame", WIDTH, height, UlRemedy.name, UlRemedy.Version())

    local function FillColumn(list, x)
        local y = -(UI.TITLE_H + PAD)
        for _, g in ipairs(list) do
            CreateCard(f, x, y, g)
            y = y - CardHeight(g) - GAP
        end
    end
    FillColumn(left, PAD)
    FillColumn(right, PAD + COLUMN_W + GAP)

    -- The one action that is not an on/off switch.
    local errors = UI.Button(f, "Save Lua errors", 160, 26, function()
        local ok, err = pcall(UlRemedy.DumpErrors, true)
        if not ok then print(UlRemedy.name .. ": could not read the error list: " .. tostring(err)) end
    end)
    errors:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", PAD, 32)

    local hint = UI.Text(f, "GameFontHighlightSmall", UI.MUTED)
    hint:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", PAD, 12)
    hint:SetText("Chat works too: /ur <feature> toggles, /ur help lists every command.")

    f:SetScript("OnShow", function() if UlRemedy.RefreshOptions then UlRemedy.RefreshOptions() end end)
    return f
end

function UlRemedy.RefreshOptions()
    if not window or not window:IsShown() then return end
    for key, row in pairs(rows) do
        row.switch:SetOn(UlRemedy.enabled[key] and true or false)
    end
end

function UlRemedy.ToggleOptions()
    if not window then window = CreateWindow() end
    if window:IsShown() then
        window:Hide()
    else
        window:Show()
    end
end
