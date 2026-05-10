local KEYSTONE_ID = 180653
local lastReply = 0

local EVENT_TO_CHANNEL = {
    CHAT_MSG_SAY                  = "SAY",
    CHAT_MSG_PARTY                = "PARTY",
    CHAT_MSG_INSTANCE_CHAT        = "INSTANCE_CHAT",
    CHAT_MSG_INSTANCE_CHAT_LEADER = "INSTANCE_CHAT",
    CHAT_MSG_RAID                 = "RAID",
}

local function FindKeystone()
    for bag = 0, C_Container.NUM_TOTAL_EQUIPPED_BAG_SLOTS do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID == KEYSTONE_ID then
                local link = info.hyperlink
                if link and link ~= "" then
                    return link
                end
            end
        end
    end
end

local frame = CreateFrame("Frame", "UlRemedyKeyLinkFrame")
for event in pairs(EVENT_TO_CHANNEL) do
    frame:RegisterEvent(event)
end

frame:SetScript("OnEvent", function(self, event, message, sender)
    if not UlRemedy.enabled or not UlRemedy.enabled.keylink then return end
    if sender and sender:match("^([^%-]+)") == UnitName("player") then return end
    if message:lower():match("^!keys%s*$") then
        local now = GetTime()
        if now - lastReply < 5 then return end
        lastReply = now
        local link = FindKeystone()
        if link then
            SendChatMessage(link, EVENT_TO_CHANNEL[event])
        else
            SendChatMessage("No keystone found.", EVENT_TO_CHANNEL[event])
        end
    end
end)
