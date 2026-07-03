-- Cursor Ring: a glowing ring that follows the mouse cursor.
--
-- The WoW API cannot sample screen pixels, so true dynamic contrast against
-- the background is impossible. Instead the ring is two-tone — a dark outline
-- under a bright gold core — plus an additive pulsing glow, which stays
-- visible on both light and dark backgrounds. UIParent hides during
-- cinematics, so the ring (parented to it) disappears there for free.

local RING_TEXTURE = "Interface\\Cooldown\\ping4"
local SIZE = 30

local ring = CreateFrame("Frame", "UlRemedyCursorRing", UIParent)
ring:SetFrameStrata("TOOLTIP")
ring:SetSize(SIZE, SIZE)
ring:Hide()

local shadow = ring:CreateTexture(nil, "BACKGROUND")
shadow:SetTexture(RING_TEXTURE)
shadow:SetVertexColor(0, 0, 0, 0.9)
shadow:SetPoint("CENTER")
shadow:SetSize(SIZE * 1.18, SIZE * 1.18)

local core = ring:CreateTexture(nil, "ARTWORK")
core:SetTexture(RING_TEXTURE)
core:SetVertexColor(0.55, 0.40, 0.70) -- dusty dark purple
core:SetAllPoints()

local glow = ring:CreateTexture(nil, "OVERLAY")
glow:SetTexture(RING_TEXTURE)
glow:SetBlendMode("ADD")
glow:SetVertexColor(0.85, 0.88, 0.95) -- cool silver
glow:SetPoint("CENTER")
glow:SetSize(SIZE * 1.7, SIZE * 1.7)
glow:SetAlpha(0.3)

local pulse = glow:CreateAnimationGroup()
pulse:SetLooping("BOUNCE")
local fade = pulse:CreateAnimation("Alpha")
fade:SetFromAlpha(0.15)
fade:SetToAlpha(0.55)
fade:SetDuration(0.9)
fade:SetSmoothing("IN_OUT")

ring:SetScript("OnUpdate", function(self)
    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    self:ClearAllPoints()
    self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)
end)

function UlRemedy.UpdateCursorRing()
    if UlRemedy.enabled.cursor then
        ring:Show()
        pulse:Play()
    else
        pulse:Stop()
        ring:Hide()
    end
end

local driver = CreateFrame("Frame", "UlRemedyCursorRingDriver")
driver:RegisterEvent("PLAYER_LOGIN")
driver:SetScript("OnEvent", function(self)
    UlRemedy.UpdateCursorRing()
    self:UnregisterEvent("PLAYER_LOGIN")
end)
