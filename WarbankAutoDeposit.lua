local hasDeposited = false

local BLACKLIST_CLASS = {
    [Enum.ItemClass.Consumable] = true,
}

local function GetEmptyAccountBankSlots()
    local slots = {}
    local tabs = C_Bank.FetchPurchasedBankTabData(Enum.BankType.Account)
    if not tabs then return slots end
    for _, tab in ipairs(tabs) do
        local bankBag = tab.ID
        local numSlots = C_Container.GetContainerNumSlots(bankBag) or 0
        for slot = 1, numSlots do
            if not C_Container.GetContainerItemInfo(bankBag, slot) then
                slots[#slots + 1] = { bag = bankBag, slot = slot }
            end
        end
    end
    return slots
end

local function GetItemClassID(info)
    if info.classID then return info.classID end
    if not info.hyperlink then return nil end
    local _, _, _, _, _, classID = GetItemInfoInstant(info.hyperlink)
    return classID
end

local function DepositFilteredItems()
    local deposited = 0
    local emptySlots = GetEmptyAccountBankSlots()
    local nextEmpty = 1
    local lastBag = NUM_TOTAL_EQUIPPED_BAG_SLOTS or 4
    for bag = 0, lastBag do
        local numSlots = C_Container.GetContainerNumSlots(bag) or 0
        for slot = 1, numSlots do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.hyperlink and not info.isLocked then
                local classID = GetItemClassID(info)
                local isJunk = info.quality == Enum.ItemQuality.Poor
                if not isJunk and not BLACKLIST_CLASS[classID] then
                    local location = ItemLocation:CreateFromBagAndSlot(bag, slot)
                    if C_Bank.IsItemAllowedInBankType(Enum.BankType.Account, location) then
                        local dest = emptySlots[nextEmpty]
                        if dest then
                            ClearCursor()
                            C_Container.PickupContainerItem(bag, slot)
                            C_Container.PickupContainerItem(dest.bag, dest.slot)
                            nextEmpty = nextEmpty + 1
                            deposited = deposited + 1
                        end
                    end
                end
            end
        end
    end
    ClearCursor()
    return deposited
end

local function TryDeposit()
    if hasDeposited then return end
    if not UlRemedy.enabled.warbank then return end
    if not C_Bank or not C_Bank.FetchPurchasedBankTabData then return end
    local tabs = C_Bank.FetchPurchasedBankTabData(Enum.BankType.Account)
    if not tabs or #tabs == 0 then return end
    hasDeposited = true
    local count = DepositFilteredItems()
    if count > 0 then
        print(UlRemedy.name .. ": Auto-deposited " .. count .. " item(s) to warband bank (consumables and junk skipped).")
    else
        print(UlRemedy.name .. ": Warband — nothing to deposit (consumables and junk skipped).")
    end
end

local frame = CreateFrame("Frame", "UlRemedyWarbankFrame")
frame:RegisterEvent("BANKFRAME_OPENED")
frame:RegisterEvent("BANKFRAME_CLOSED")
frame:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
frame:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_HIDE")

frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "BANKFRAME_CLOSED" then
        hasDeposited = false
        return
    end
    if event == "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" then
        if arg1 == Enum.PlayerInteractionType.AccountBanker then
            hasDeposited = false
        end
        return
    end
    -- Delay slightly so the bank tab data is populated.
    C_Timer.After(0.3, TryDeposit)
end)
