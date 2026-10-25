-- Style: the shared look of the addon's own windows (options, chat log).
--
-- Flat and dark in the style of the game's Settings panel: a
-- BackdropTemplate frame with a one-pixel border, a lighter title band
-- with the name and a drawn X, cards and buttons in the same palette,
-- the dusty purple of the cursor ring as accent. Everything is drawn
-- from the white 8x8 texture, so no media files are needed; round shapes
-- come from masking it with a disc.
--
-- Loaded right after Core; the window modules call UlRemedy.UI.

local UI = {}
UlRemedy.UI = UI

UI.WHITE = "Interface/Buttons/WHITE8x8"
UI.CIRCLE = "Interface/CharacterFrame/TempPortraitAlphaMask"

UI.ACCENT = { 0.55, 0.40, 0.70 }         -- same dusty purple as the cursor ring
UI.ACCENT_TEXT = { 0.76, 0.63, 0.90 }
UI.BG = { 0.07, 0.07, 0.09, 0.97 }
UI.TITLE_BG = { 0.10, 0.10, 0.13, 1 }
UI.BORDER = { 0.24, 0.24, 0.30, 1 }
UI.CARD = { 0.11, 0.11, 0.14, 1 }
UI.CARD_HOVER = { 0.16, 0.16, 0.20, 1 }
UI.CARD_BORDER = { 0.18, 0.18, 0.23, 1 }
UI.TEXT = { 0.92, 0.92, 0.95 }
UI.MUTED = { 0.58, 0.58, 0.64 }

UI.PAD = 16                              -- window edge to content
UI.TITLE_H = 44

function UI.Unpack(c) return c[1], c[2], c[3], c[4] or 1 end

function UI.Backdrop(f, color, border)
    f:SetBackdrop({ bgFile = UI.WHITE, edgeFile = UI.WHITE, edgeSize = 1 })
    f:SetBackdropColor(UI.Unpack(color))
    f:SetBackdropBorderColor(UI.Unpack(border))
end

-- A flat texture; with round=true a circle (the square masked by a disc).
function UI.Texture(parent, w, h, round, layer)
    local t = parent:CreateTexture(nil, layer or "ARTWORK")
    t:SetTexture(UI.WHITE)
    t:SetSize(w, h)
    if round then
        local m = parent:CreateMaskTexture()
        m:SetTexture(UI.CIRCLE, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        m:SetAllPoints(t)
        t:AddMaskTexture(m)
    end
    return t
end

function UI.Text(parent, font, color)
    local s = parent:CreateFontString(nil, "OVERLAY", font)
    s:SetTextColor(UI.Unpack(color))
    return s
end

-- A flat text button in the same style as the cards.
function UI.Button(parent, text, w, h, onClick)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(w, h or 26)
    UI.Backdrop(b, UI.CARD, UI.BORDER)
    local label = UI.Text(b, "GameFontNormal", UI.TEXT)
    label:SetPoint("CENTER")
    label:SetText(text)
    b.label = label
    b:SetScript("OnEnter", function(self) self:SetBackdropColor(UI.Unpack(UI.CARD_HOVER)) end)
    b:SetScript("OnLeave", function(self) self:SetBackdropColor(UI.Unpack(UI.CARD)) end)
    b:SetScript("OnClick", onClick)
    return b
end

-- An X drawn from two rotated bars, so no glyph or atlas is needed.
function UI.CloseButton(parent, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(28, 28)
    local bars = {}
    for i, angle in ipairs({ 45, -45 }) do
        local t = UI.Texture(b, 14, 2)
        t:SetPoint("CENTER")
        t:SetRotation(math.rad(angle))
        t:SetVertexColor(UI.Unpack(UI.MUTED))
        bars[i] = t
    end
    b:SetScript("OnEnter", function() for _, t in ipairs(bars) do t:SetVertexColor(UI.Unpack(UI.TEXT)) end end)
    b:SetScript("OnLeave", function() for _, t in ipairs(bars) do t:SetVertexColor(UI.Unpack(UI.MUTED)) end end)
    b:SetScript("OnClick", onClick)
    return b
end

-- A movable window with a title band and a close X, closed by Escape as
-- well. Returns it hidden, so the caller's first toggle shows it. The
-- content area starts TITLE_H below the top.
function UI.Window(name, w, h, title, subtitle)
    local f = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
    f:SetSize(w, h)
    f:SetPoint("CENTER")
    UI.Backdrop(f, UI.BG, UI.BORDER)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetClampedToScreen(true)
    f:SetFrameStrata("HIGH")
    f:SetToplevel(true)
    tinsert(UISpecialFrames, name)

    local bar = f:CreateTexture(nil, "BACKGROUND", nil, 1)
    bar:SetTexture(UI.WHITE)
    bar:SetVertexColor(UI.Unpack(UI.TITLE_BG))
    bar:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
    bar:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -1)
    bar:SetHeight(UI.TITLE_H - 1)
    local barLine = f:CreateTexture(nil, "BACKGROUND", nil, 2)
    barLine:SetTexture(UI.WHITE)
    barLine:SetVertexColor(UI.Unpack(UI.BORDER))
    barLine:SetPoint("TOPLEFT", bar, "BOTTOMLEFT")
    barLine:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT")
    barLine:SetHeight(1)
    f.bar = bar

    f.title = UI.Text(f, "GameFontNormalLarge", UI.TEXT)
    f.title:SetPoint("LEFT", bar, "LEFT", UI.PAD, 0)
    f.title:SetText(title)
    f.subtitle = UI.Text(f, "GameFontHighlightSmall", UI.MUTED)
    f.subtitle:SetPoint("LEFT", f.title, "RIGHT", 8, -1)
    f.subtitle:SetText(subtitle or "")

    f.close = UI.CloseButton(f, function() f:Hide() end)
    f.close:SetPoint("RIGHT", bar, "RIGHT", -8, 0)

    f:Hide()
    return f
end
