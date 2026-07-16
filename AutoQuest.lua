-- Auto Quest: accepts quest offers and turns in completed quests automatically.
-- Hold Shift while interacting with an NPC to bypass the automation.
--
-- Quests with more than one reward choice, or that cost gold/currency to
-- turn in, are left open so the player decides manually.
-- Greeting/gossip selection picks ONE quest per event and returns —
-- selecting a quest replaces the NPC panel, and the event re-fires after each
-- turn-in, so looping over the full list here would act on a stale panel.

local function Suppressed()
    return not UlRemedy.enabled.quest or IsShiftKeyDown()
end

local handlers = {}

function handlers.QUEST_GREETING()
    -- Old-style multi-quest NPCs: completed turn-ins first, then new quests.
    for i = 1, GetNumActiveQuests() do
        local _, isComplete = GetActiveTitle(i)
        if isComplete then
            SelectActiveQuest(i)
            return
        end
    end
    if GetNumAvailableQuests() > 0 then
        SelectAvailableQuest(1)
    end
end

function handlers.GOSSIP_SHOW()
    -- Quest lines offered through the gossip window. Pure gossip options are
    -- AutoGossip's job.
    for _, quest in ipairs(C_GossipInfo.GetActiveQuests()) do
        if quest.isComplete then
            C_GossipInfo.SelectActiveQuest(quest.questID)
            return
        end
    end
    local available = C_GossipInfo.GetAvailableQuests()
    if available[1] then
        C_GossipInfo.SelectAvailableQuest(available[1].questID)
    end
end

function handlers.QUEST_DETAIL()
    if QuestGetAutoAccept() then
        -- Server already accepted it; just dismiss the offer window.
        AcknowledgeAutoAcceptQuest()
    else
        AcceptQuest()
    end
end

function handlers.QUEST_PROGRESS()
    if not IsQuestCompletable() then return end
    -- Turn-ins that cost gold or currency are never automated — the panel
    -- stays open so the player decides. Required quest items are fine.
    if GetQuestMoneyToGet and (GetQuestMoneyToGet() or 0) > 0 then return end
    if GetNumQuestCurrencies and (GetNumQuestCurrencies() or 0) > 0 then return end
    CompleteQuest()
end

function handlers.QUEST_COMPLETE()
    local choices = GetNumQuestChoices()
    if choices > 1 then return end
    GetQuestReward(choices)
end

local frame = CreateFrame("Frame", "UlRemedyQuestFrame")
frame:RegisterEvent("QUEST_GREETING")
frame:RegisterEvent("GOSSIP_SHOW")
frame:RegisterEvent("QUEST_DETAIL")
frame:RegisterEvent("QUEST_PROGRESS")
frame:RegisterEvent("QUEST_COMPLETE")

frame:SetScript("OnEvent", function(_, event)
    if Suppressed() then return end
    handlers[event]()
end)
