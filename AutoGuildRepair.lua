local function CanPayWithGuild(cost)
    if not CanGuildBankRepair or not CanGuildBankRepair() then
        return false
    end
    if not GetGuildBankWithdrawMoney then
        return false
    end
    local limit = GetGuildBankWithdrawMoney()
    return limit == -1 or limit >= cost
end

local function Repair()
    if not UlRemedy.enabled.repair then return end
    if not CanMerchantRepair() then return end
    local cost, canRepair = GetRepairAllCost()
    if not canRepair or not cost or cost <= 0 then return end

    if CanPayWithGuild(cost) then
        RepairAllItems(true)
        print(UlRemedy.name .. ": Repaired with guild funds for " .. UlRemedy.MoneyText(cost) .. ".")
    elseif GetMoney() >= cost then
        RepairAllItems(false)
        print(UlRemedy.name .. ": Repaired for " .. UlRemedy.MoneyText(cost) .. ".")
    else
        print(UlRemedy.name .. ": Not enough money to repair. Need " .. UlRemedy.MoneyText(cost) .. ".")
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("MERCHANT_SHOW")
frame:SetScript("OnEvent", Repair)
