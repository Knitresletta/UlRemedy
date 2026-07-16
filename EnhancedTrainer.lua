-- Enhanced Trainer: adds a "Train All" button to the profession trainer frame
-- that trains every available skill in one click.
--
-- Retail returns category as the SECOND value from GetTrainerServiceInfo (the
-- Classic-era rank return is gone). BuyTrainerService(0) is an undocumented
-- retail behavior: index 0 trains every available service server-side in one
-- call, which sidesteps the list re-sorting between individual purchases.

function UlRemedy.TrainAllAvailable()
    local available, cost = 0, 0
    local total = GetNumTrainerServices()
    local counts = {}
    for i = 1, total do
        local _, category = GetTrainerServiceInfo(i)
        category = category or "?"
        counts[category] = (counts[category] or 0) + 1
        if category == "available" then
            available = available + 1
            cost = cost + (GetTrainerServiceCost(i) or 0)
        end
    end
    if available == 0 then
        -- Diagnostic breakdown: shows what the scan actually saw, so a wrong
        -- category assumption or an empty list is visible straight in chat.
        local detail
        if total == 0 then
            detail = "trainer list is empty"
        else
            local parts = {}
            for cat, n in pairs(counts) do
                table.insert(parts, n .. " " .. cat)
            end
            table.sort(parts)
            detail = table.concat(parts, ", ")
        end
        return 0, 0, false, detail
    end
    local leftover = cost > GetMoney()
    BuyTrainerService(0)
    return available, cost, leftover
end

local function OnTrainAllClick()
    if not UlRemedy.enabled.trainer then return end
    local available, cost, leftover, detail = UlRemedy.TrainAllAvailable()
    if available == 0 then
        print(UlRemedy.name .. ": Nothing available to train (" .. detail .. ").")
    elseif leftover then
        print(UlRemedy.name .. ": Not enough gold for everything (" .. UlRemedy.MoneyText(cost) .. " needed) — trained what you could afford.")
    else
        print(UlRemedy.name .. ": Trained " .. available .. " skill(s) for " .. UlRemedy.MoneyText(cost) .. ".")
    end
end

local trainAllButton

local function EnsureButton()
    if trainAllButton then return trainAllButton end
    if not ClassTrainerFrame then return nil end
    local b = CreateFrame("Button", "UlRemedyTrainAllButton", ClassTrainerFrame, "UIPanelButtonTemplate")
    b:SetSize(90, 22)
    b:SetText("Train All")
    if ClassTrainerTrainButton then
        b:SetPoint("RIGHT", ClassTrainerTrainButton, "LEFT", -4, 0)
    else
        b:SetPoint("BOTTOMLEFT", ClassTrainerFrame, "BOTTOMLEFT", 20, 4)
    end
    b:SetScript("OnClick", OnTrainAllClick)
    trainAllButton = b
    return b
end

local frame = CreateFrame("Frame", "UlRemedyTrainerFrame")
frame:RegisterEvent("TRAINER_SHOW")
frame:SetScript("OnEvent", function()
    -- Blizzard_TrainerUI is load-on-demand; make sure the frame exists.
    if C_AddOns and C_AddOns.LoadAddOn then
        C_AddOns.LoadAddOn("Blizzard_TrainerUI")
    end
    if not UlRemedy.enabled.trainer then
        if trainAllButton then trainAllButton:Hide() end
        return
    end
    local b = EnsureButton()
    if b then b:Show() end
end)
