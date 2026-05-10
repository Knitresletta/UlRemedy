local hasDeposited = false

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
    -- PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED: warband bank tab data is loaded
    if hasDeposited then return end
    if not UlRemedy.enabled.warbank then return end
    if not C_Bank.CanUseBank(Enum.BankType.Account) then return end
    hasDeposited = true
    C_Bank.AutoDepositItemsIntoBank(Enum.BankType.Account)
    print(UlRemedy.name .. ": Auto-deposited items to warband bank.")
end)
