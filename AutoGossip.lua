-- Auto Gossip: clicks through NPC dialog automatically, but only in the
-- safest case — exactly one option, plain chat-bubble icon, no quests on the
-- NPC, and never inside an instance (dialog there can start boss encounters).
-- Hold Shift to leave the dialog open.

-- Interface/GossipFrame/GossipGossipIcon — the plain "just talk" bubble.
-- Vendor, taxi, binder etc. use different icons, so this guard keeps the
-- automation away from anything with side effects.
local GOSSIP_BUBBLE_ICON = 132053

local frame = CreateFrame("Frame", "UlRemedyGossipFrame")
frame:RegisterEvent("GOSSIP_SHOW")

frame:SetScript("OnEvent", function()
    if not UlRemedy.enabled.gossip then return end
    if IsShiftKeyDown() then return end
    if IsInInstance() then return end
    if #C_GossipInfo.GetAvailableQuests() > 0 then return end
    if #C_GossipInfo.GetActiveQuests() > 0 then return end

    local options = C_GossipInfo.GetOptions()
    if #options ~= 1 then return end

    local opt = options[1]
    if not opt.gossipOptionID then return end
    if (opt.icon or GOSSIP_BUBBLE_ICON) ~= GOSSIP_BUBBLE_ICON then return end
    if opt.status and opt.status ~= 0 then return end -- locked/unavailable

    C_GossipInfo.SelectOption(opt.gossipOptionID)
end)
