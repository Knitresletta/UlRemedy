local function HasGuildRepairAccess()
    if not CanGuildBankRepair or not CanGuildBankRepair() then
        return false
    end
    if not GetGuildBankWithdrawMoney then
        return false
    end
    local limit = GetGuildBankWithdrawMoney()
    return limit == -1 or limit > 0
end

local function Repair()
    if not UlRemedy.enabled.repair then return end
    if not CanMerchantRepair() then return end
    local cost, canRepair = GetRepairAllCost()
    if not canRepair or not cost or cost <= 0 then return end

    local useGuild = HasGuildRepairAccess()
    local moneyBefore = GetMoney()

    if not useGuild and moneyBefore < cost then
        print(UlRemedy.name .. ": Not enough money to repair. Need " .. UlRemedy.MoneyText(cost) .. ".")
        return
    end

    RepairAllItems(useGuild)

    local spentPersonal = moneyBefore - GetMoney()
    local spentGuild = cost - spentPersonal

    if spentGuild >= cost then
        print(UlRemedy.name .. ": Repaired with guild funds for " .. UlRemedy.MoneyText(cost) .. ".")
    elseif spentGuild > 0 then
        print(UlRemedy.name .. ": Repaired — guild " .. UlRemedy.MoneyText(spentGuild) .. ", personal " .. UlRemedy.MoneyText(spentPersonal) .. ".")
    elseif spentPersonal > 0 then
        print(UlRemedy.name .. ": Repaired with personal gold for " .. UlRemedy.MoneyText(spentPersonal) .. ".")
    end
end

local frame = CreateFrame("Frame", "UlRemedyRepairFrame")
frame:RegisterEvent("MERCHANT_SHOW")
frame:SetScript("OnEvent", Repair)
