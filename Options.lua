-- Options: a window with one switch per feature, opened with /ur.
--
-- Drawn flat and dark in the style of the game's Settings panel rather
-- than from the gold BasicFrameTemplate: a BackdropTemplate frame with a
-- one-pixel border, each feature group as a card, and a pill-shaped
-- toggle switch per feature in the same dusty purple as the cursor ring.
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

local PAD = 16                      -- window edge to content
local GAP = 12                      -- between columns and between cards
local COLUMN_W = 380
local WIDTH = PAD + COLUMN_W + GAP + COLUMN_W + PAD
local TITLE_H = 44
local BOTTOM_H = 70                 -- button row and hint
local CARD_PAD = 10
local HEADER_H = 22
local ROW_H = 46                    -- name plus up to two lines of description
local SWITCH_W, SWITCH_H = 38, 20

local WHITE = "Interface/Buttons/WHITE8x8"
local CIRCLE = "Interface/CharacterFrame/TempPortraitAlphaMask"

local ACCENT = { 0.55, 0.40, 0.70 }          -- same dusty purple as the cursor ring
local ACCENT_TEXT = { 0.76, 0.63, 0.90 }
local BG = { 0.07, 0.07, 0.09, 0.97 }
local TITLE_BG = { 0.10, 0.10, 0.13, 1 }
local BORDER = { 0.24, 0.24, 0.30, 1 }
local CARD = { 0.11, 0.11, 0.14, 1 }
local CARD_BORDER = { 0.18, 0.18, 0.23, 1 }
local TEXT = { 0.92, 0.92, 0.95 }
local MUTED = { 0.58, 0.58, 0.64 }
local TRACK_OFF = { 0.28, 0.28, 0.34 }
local KNOB_OFF = { 0.72, 0.72, 0.76 }

local window
local rows = {}

local function Unpack(c) return c[1], c[2], c[3], c[4] or 1 end

local function Backdrop(f, color, border)
    f:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    f:SetBackdropColor(Unpack(color))
    f:SetBackdropBorderColor(Unpack(border))
end

-- A flat texture; with round=true a circle (the square masked by a disc).
local function Texture(parent, w, h, round, layer)
    local t = parent:CreateTexture(nil, layer or "ARTWORK")
    t:SetTexture(WHITE)
    t:SetSize(w, h)
    if round then
        local m = parent:CreateMaskTexture()
        m:SetTexture(CIRCLE, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        m:SetAllPoints(t)
        t:AddMaskTexture(m)
    end
    return t
end

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
        local track = on and ACCENT or TRACK_OFF
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
    hover:SetTexture(WHITE)
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
    name:SetTextColor(Unpack(TEXT))
    name:SetText(feature.label)

    local desc = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -1)
    desc:SetPoint("RIGHT", switch, "LEFT", -10, 0)
    desc:SetJustifyH("LEFT")
    desc:SetWordWrap(true)
    desc:SetMaxLines(2)
    desc:SetTextColor(Unpack(MUTED))
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
    Backdrop(card, CARD, CARD_BORDER)

    local header = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header:SetPoint("TOPLEFT", card, "TOPLEFT", CARD_PAD + 6, -CARD_PAD)
    header:SetHeight(HEADER_H)
    header:SetJustifyV("MIDDLE")
    header:SetTextColor(Unpack(ACCENT_TEXT))
    header:SetText(g.name)

    local line = card:CreateTexture(nil, "ARTWORK")
    line:SetTexture(WHITE)
    line:SetVertexColor(ACCENT[1], ACCENT[2], ACCENT[3], 0.35)
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

-- A flat text button in the same style as the cards.
local function CreateFlatButton(parent, text, w, onClick)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(w, 26)
    Backdrop(b, CARD, BORDER)
    local label = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("CENTER")
    label:SetTextColor(Unpack(TEXT))
    label:SetText(text)
    b:SetScript("OnEnter", function(self) self:SetBackdropColor(0.16, 0.16, 0.20, 1) end)
    b:SetScript("OnLeave", function(self) self:SetBackdropColor(Unpack(CARD)) end)
    b:SetScript("OnClick", onClick)
    return b
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

-- An X drawn from two rotated bars, so no glyph or atlas is needed.
local function CreateCloseButton(parent)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(28, 28)
    local bars = {}
    for i, angle in ipairs({ 45, -45 }) do
        local t = b:CreateTexture(nil, "ARTWORK")
        t:SetTexture(WHITE)
        t:SetSize(14, 2)
        t:SetPoint("CENTER")
        t:SetRotation(math.rad(angle))
        t:SetVertexColor(Unpack(MUTED))
        bars[i] = t
    end
    b:SetScript("OnEnter", function() for _, t in ipairs(bars) do t:SetVertexColor(Unpack(TEXT)) end end)
    b:SetScript("OnLeave", function() for _, t in ipairs(bars) do t:SetVertexColor(Unpack(MUTED)) end end)
    b:SetScript("OnClick", function() parent:Hide() end)
    return b
end

local function CreateWindow()
    local groups = GroupedFeatures()
    local left, right, columnH = SplitColumns(groups)
    local height = TITLE_H + PAD + columnH + BOTTOM_H

    local f = CreateFrame("Frame", "UlRemedyOptionsFrame", UIParent, "BackdropTemplate")
    f:SetSize(WIDTH, height)
    f:SetPoint("CENTER")
    Backdrop(f, BG, BORDER)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetClampedToScreen(true)
    f:SetFrameStrata("HIGH")
    f:SetToplevel(true)
    tinsert(UISpecialFrames, "UlRemedyOptionsFrame")

    -- Title bar: a lighter band with the name, the version and a close X.
    local bar = f:CreateTexture(nil, "BACKGROUND", nil, 1)
    bar:SetTexture(WHITE)
    bar:SetVertexColor(Unpack(TITLE_BG))
    bar:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
    bar:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -1)
    bar:SetHeight(TITLE_H - 1)
    local barLine = f:CreateTexture(nil, "BACKGROUND", nil, 2)
    barLine:SetTexture(WHITE)
    barLine:SetVertexColor(Unpack(BORDER))
    barLine:SetPoint("TOPLEFT", bar, "BOTTOMLEFT")
    barLine:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT")
    barLine:SetHeight(1)

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("LEFT", bar, "LEFT", PAD, 0)
    title:SetTextColor(Unpack(TEXT))
    title:SetText(UlRemedy.name)
    local version = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    version:SetPoint("LEFT", title, "RIGHT", 8, -1)
    version:SetTextColor(Unpack(MUTED))
    version:SetText(UlRemedy.Version())
    local close = CreateCloseButton(f)
    close:SetPoint("RIGHT", bar, "RIGHT", -8, 0)

    local function FillColumn(list, x)
        local y = -(TITLE_H + PAD)
        for _, g in ipairs(list) do
            CreateCard(f, x, y, g)
            y = y - CardHeight(g) - GAP
        end
    end
    FillColumn(left, PAD)
    FillColumn(right, PAD + COLUMN_W + GAP)

    -- The one action that is not an on/off switch.
    local errors = CreateFlatButton(f, "Save Lua errors", 160, function()
        local ok, err = pcall(UlRemedy.DumpErrors, true)
        if not ok then print(UlRemedy.name .. ": could not read the error list: " .. tostring(err)) end
    end)
    errors:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", PAD, 32)

    local hint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", PAD, 12)
    hint:SetTextColor(Unpack(MUTED))
    hint:SetText("Chat works too: /ur <feature> toggles, /ur help lists every command.")

    f:SetScript("OnShow", function() if UlRemedy.RefreshOptions then UlRemedy.RefreshOptions() end end)
    -- A new frame is visible from the start; hide it so the first toggle
    -- shows it instead of hiding it.
    f:Hide()
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
