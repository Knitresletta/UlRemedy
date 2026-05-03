local function SellJunk()
    if not UlRemedy.enabled.junk then return end
    local total = 0
    local sold = 0

    for bag = 0, NUM_BAG_SLOTS do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.hyperlink and info.quality == Enum.ItemQuality.Poor then
                local vendorPrice = select(11, GetItemInfo(info.hyperlink)) or 0
                if vendorPrice > 0 then
                    local quantity = info.stackCount or 1
                    C_Container.UseContainerItem(bag, slot)
                    total = total + (vendorPrice * quantity)
                    sold = sold + quantity
                end
            end
        end
    end

    if sold > 0 then
        print(UlRemedy.name .. ": Sold " .. sold .. " junk item(s) for " .. UlRemedy.MoneyText(total) .. ".")
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("MERCHANT_SHOW")
frame:SetScript("OnEvent", SellJunk)
