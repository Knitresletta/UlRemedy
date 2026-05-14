local hasDeposited = false

local BLACKLIST_CLASS = {
    [Enum.ItemClass.Consumable] = true,
}

local function FindEmptyAccountBankSlot()
    local tabs = C_Bank.FetchPurchasedBankTabData(Enum.BankType.Account)
    if not tabs then return nil end
    for _, tab in ipairs(tabs) do
        local bankBag = tab.ID
        local numSlots = C_Container.GetContainerNumSlots(bankBag) or 0
        for slot = 1, numSlots do
            if not C_Container.GetContainerItemInfo(bankBag, slot) then
                return bankBag, slot
            end
        end
    end
end

local function DepositFilteredItems()
    local deposited = 0
    for bag = 0, C_Container.NUM_TOTAL_EQUIPPED_BAG_SLOTS do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.hyperlink and not info.isLocked and not BLACKLIST_CLASS[info.classID] then
                local location = ItemLocation:CreateFromBagAndSlot(bag, slot)
                if C_Bank.IsItemAllowedInBankType(location, Enum.BankType.Account) then
                    local destBag, destSlot = FindEmptyAccountBankSlot()
                    if destBag then
                        ClearCursor()
                        C_Container.PickupContainerItem(bag, slot)
                        C_Container.PickupContainerItem(destBag, destSlot)
                        deposited = deposited + 1
                    end
                end
            end
        end
    end
    ClearCursor()
    return deposited
end

local frame = CreateFrame("Frame", "UlRemedyWarbankFrame")
frame:RegisterEvent("BANKFRAME_OPENED")
frame:RegisterEvent("BANKFRAME_CLOSED")
frame:RegisterEvent("PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED")

frame:SetScript("OnEvent", function(self, event)
    if event == "BANKFRAME_CLOSED" then
        hasDeposited = false
        return
    end
    if event == "BANKFRAME_OPENED" then
        return
    end
    if hasDeposited then return end
    if not UlRemedy.enabled.warbank then return end
    if not C_Bank.CanUseBank(Enum.BankType.Account) then return end
    hasDeposited = true
    local count = DepositFilteredItems()
    if count > 0 then
        print(UlRemedy.name .. ": Auto-deposited " .. count .. " item(s) to warband bank (consumables skipped).")
    end
end)
