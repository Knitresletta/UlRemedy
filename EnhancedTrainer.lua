-- Enhanced Trainer: adds a "Train All" button to the profession trainer frame
-- that trains every available skill you can afford, in one click.
--
-- Note: the trainer service list refreshes asynchronously after a purchase, so
-- we do a SINGLE forward pass (never re-scan mid-loop) and track spendable money
-- locally to decide affordability — mirroring how the list behaves in-game.

function UlRemedy.TrainAllAvailable()
    local money = GetMoney()
    local trained, spent, leftover = 0, 0, false
    for i = 1, GetNumTrainerServices() do
        local _, _, category = GetTrainerServiceInfo(i)
        if category == "available" then
            local cost = GetTrainerServiceCost(i) or 0
            if cost <= money then
                BuyTrainerService(i)
                money = money - cost
                spent = spent + cost
                trained = trained + 1
            else
                leftover = true
            end
        end
    end
    return trained, spent, leftover
end

local function OnTrainAllClick()
    if not UlRemedy.enabled.trainer then return end
    local trained, spent, leftover = UlRemedy.TrainAllAvailable()
    if trained > 0 then
        print(UlRemedy.name .. ": Trained " .. trained .. " skill(s) for " .. UlRemedy.MoneyText(spent) .. ".")
    elseif not leftover then
        print(UlRemedy.name .. ": Nothing available to train.")
    end
    if leftover then
        print(UlRemedy.name .. ": Not enough gold to train everything.")
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
