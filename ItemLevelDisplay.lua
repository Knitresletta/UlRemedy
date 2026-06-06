local hookedFrames = {}
local hookedBankPanels = {}
local bankHooked = false

local function ShouldShow(itemID)
    if not itemID then return false end
    local _, _, _, _, _, classID = GetItemInfoInstant(itemID)
    return classID == Enum.ItemClass.Weapon or classID == Enum.ItemClass.Armor
end

local function GetOverlay(button)
    if not button.ulrIlvl then
        local fs = button:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
        fs:SetDrawLayer("OVERLAY", 7)
        fs:SetPoint("TOPLEFT", 1, -1)
        fs:SetTextColor(1, 1, 1)
        button.ulrIlvl = fs
    end
    return button.ulrIlvl
end

local function UpdateButton(button, bag, slot)
    local existing = button.ulrIlvl
    if not UlRemedy.enabled or not UlRemedy.enabled.ilvl then
        if existing then existing:Hide() end
        return
    end
    local info = C_Container.GetContainerItemInfo(bag, slot)
    if not info or not info.hyperlink or not ShouldShow(info.itemID) then
        if existing then existing:Hide() end
        return
    end
    local ilvl = C_Item.GetCurrentItemLevel(ItemLocation:CreateFromBagAndSlot(bag, slot))
    if not ilvl then
        if existing then existing:Hide() end
        return
    end
    local fs = GetOverlay(button)
    fs:SetText(ilvl)
    fs:Show()
end

local function UpdateContainer(frame)
    if not frame or not frame.EnumerateValidItems then return end
    for _, button in frame:EnumerateValidItems() do
        UpdateButton(button, button:GetBagID(), button:GetID())
    end
end

-- The bank panel's iterator yields a single value (the button) and the buttons
-- expose tab/slot through different methods than carried-bag buttons.
local function UpdateBankPanel(panel)
    if not panel or not panel.EnumerateValidItems then return end
    for button in panel:EnumerateValidItems() do
        UpdateButton(button, button:GetBankTabID(), button:GetContainerSlotID())
    end
end

-- Lets the /ur ilvl toggle refresh open bags/bank immediately instead of
-- waiting for the next update.
function UlRemedy.RefreshItemLevels()
    for _, frame in ipairs(hookedFrames) do
        if frame:IsShown() then UpdateContainer(frame) end
    end
    for _, panel in ipairs(hookedBankPanels) do
        if panel:IsShown() then UpdateBankPanel(panel) end
    end
end

local function SetupBagHooks()
    if ContainerFrameCombinedBags and ContainerFrameCombinedBags.UpdateItems then
        hooksecurefunc(ContainerFrameCombinedBags, "UpdateItems", UpdateContainer)
        hookedFrames[#hookedFrames + 1] = ContainerFrameCombinedBags
    end
    local container = ContainerFrameContainer or UIParent
    if container.ContainerFrames then
        for _, frame in ipairs(container.ContainerFrames) do
            if frame.UpdateItems then
                hooksecurefunc(frame, "UpdateItems", UpdateContainer)
                hookedFrames[#hookedFrames + 1] = frame
            end
        end
    end
end

local function HookBankPanel(panel)
    if not panel then return end
    if panel.GenerateItemSlotsForSelectedTab then
        hooksecurefunc(panel, "GenerateItemSlotsForSelectedTab", UpdateBankPanel)
    end
    if panel.RefreshAllItemsForSelectedTab then
        hooksecurefunc(panel, "RefreshAllItemsForSelectedTab", UpdateBankPanel)
    end
    hookedBankPanels[#hookedBankPanels + 1] = panel
end

-- Hook the bank lazily: the bank UI may be load-on-demand, so BankPanel only
-- reliably exists once the bank has been opened at least once.
local function SetupBankHooks()
    if bankHooked then return end
    if not BankPanel then return end
    HookBankPanel(BankPanel)
    HookBankPanel(AccountBankPanel) -- nil on 11.2+, where BankPanel covers warband tabs
    bankHooked = true
    UlRemedy.RefreshItemLevels()
end

local frame = CreateFrame("Frame", "UlRemedyItemLevelFrame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("BANKFRAME_OPENED")
frame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        SetupBagHooks()
        self:UnregisterEvent("PLAYER_LOGIN")
    elseif event == "BANKFRAME_OPENED" then
        SetupBankHooks()
    end
end)
