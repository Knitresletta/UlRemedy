local KEYSTONE_ID = 180653
local lastReply = 0

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

frame:SetScript("OnEvent", function(self, event, message)
    if not UlRemedy.enabled or not UlRemedy.enabled.keylink then return end
    if message:lower():match("^!keys%s*$") then
        local now = GetTime()
        if now - lastReply < 5 then return end
        local link = FindKeystone()
        if link then
            lastReply = now
            SendChatMessage(link, EVENT_TO_CHANNEL[event])
        end
    end
end)
