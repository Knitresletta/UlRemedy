local KEYSTONE_ID = 180653

local EVENT_TO_CHANNEL = {
    CHAT_MSG_SAY                  = "SAY",
    CHAT_MSG_PARTY                = "PARTY",
    CHAT_MSG_PARTY_LEADER         = "PARTY",
    CHAT_MSG_INSTANCE_CHAT        = "INSTANCE_CHAT",
    CHAT_MSG_INSTANCE_CHAT_LEADER = "INSTANCE_CHAT",
    CHAT_MSG_RAID                 = "RAID",
    CHAT_MSG_RAID_LEADER          = "RAID",
}

local function FindKeystone()
    for bag = 0, NUM_BAG_SLOTS do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID == KEYSTONE_ID then
                return info.hyperlink
            end
        end
    end
end

local frame = CreateFrame("Frame")
for event in pairs(EVENT_TO_CHANNEL) do
    frame:RegisterEvent(event)
end

frame:SetScript("OnEvent", function(self, event, message)
    if not UlRemedy.enabled.keylink then return end
    if message == "!keys" then
        local link = FindKeystone()
        if link then
            SendChatMessage(link, EVENT_TO_CHANNEL[event])
        end
    end
end)
