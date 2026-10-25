-- Inventory: remembers gold, bag contents and bank contents for every
-- character you log in with. Item tooltips show where you keep the item
-- and on which character; /ur inv opens a browser for all characters.
--
-- Bags are rescanned whenever they change. The bank can only be read
-- while the bank window is open, so each character's bank snapshot is
-- whatever was there on that character's last bank visit; the Warband
-- bank is one snapshot for the account. Data lives in its own saved
-- variable (UlRemedyInventoryDB) so Core's settings pruning never
-- touches it. Character keys are "Name-Realm", like Playtime's.
--
-- Two toggles: inventory (tracking and the browser) and inventorytooltip
-- (the lines added to item tooltips), so the tooltip part can be turned
-- off next to another bag addon.
--
-- Reads bags, bank and money; writes only its own saved variable. The
-- tooltip lines go through TooltipDataProcessor's post-call, which adds
-- to a tooltip after Blizzard has built it and touches nothing of theirs.
--
-- Ported from UlRemedyForever; the window uses the shared style in
-- Style.lua.

local BagIndex = Enum.BagIndex
local BankType = Enum.BankType

local DB            -- UlRemedyInventoryDB
local me            -- this character's record in DB.chars
local bankOpen = false
local window        -- the browser frame, created on first use

local ACCOUNT_KEY = "__account"
local ACCOUNT_LABEL = "Warband bank"

local function Enabled()
    return UlRemedy.enabled and UlRemedy.enabled.inventory
end

------------------------------------------------------------------------
-- Saved data
------------------------------------------------------------------------

local function InitDB()
    if not UlRemedyInventoryDB then UlRemedyInventoryDB = {} end
    DB = UlRemedyInventoryDB
    DB.version = 1
    DB.chars = DB.chars or {}
    DB.items = DB.items or {}
    DB.account = DB.account or {}
    DB.account.bank = DB.account.bank or {}
end

local function CharKey()
    local name = UnitName("player")
    local realm = GetNormalizedRealmName and GetNormalizedRealmName()
    if not realm or realm == "" then
        realm = (GetRealmName() or ""):gsub("%s+", "")
    end
    return name .. "-" .. realm, name, realm
end

local function InitCharacter()
    local key, name, realm = CharKey()
    local rec = DB.chars[key]
    if not rec then
        rec = { bags = {}, bank = {}, money = 0 }
        DB.chars[key] = rec
    end
    rec.name = name
    rec.realm = realm
    rec.class = select(2, UnitClass("player"))
    rec.faction = UnitFactionGroup("player")
    rec.level = UnitLevel("player")
    rec.bags = rec.bags or {}
    rec.bank = rec.bank or {}
    rec.money = rec.money or 0
    me = rec
end

-- Name, icon, quality and link per item ID, so the browser can show
-- items this character has never seen without waiting for the cache.
local function RememberItem(info)
    local rec = DB.items[info.itemID]
    if not rec then
        rec = {}
        DB.items[info.itemID] = rec
    end
    if info.itemName and info.itemName ~= "" then rec.name = info.itemName end
    if info.iconFileID then rec.icon = info.iconFileID end
    if info.quality then rec.quality = info.quality end
    if info.hyperlink then rec.link = info.hyperlink end
end

------------------------------------------------------------------------
-- Scanning
------------------------------------------------------------------------

local function ScanBag(bag, into)
    for slot = 1, (C_Container.GetContainerNumSlots(bag) or 0) do
        local ok, info = pcall(C_Container.GetContainerItemInfo, bag, slot)
        if ok and type(info) == "table" and info.itemID then
            into[info.itemID] = (into[info.itemID] or 0) + (tonumber(info.stackCount) or 1)
            RememberItem(info)
        end
    end
end

-- Backpack, the equipped bags and the reagent bag.
local function PlayerBagIDs()
    local ids = {}
    for bag = 0, (NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4) do
        ids[#ids + 1] = bag
    end
    return ids
end

-- Bank tabs are ordinary bag IDs. C_Bank tells us which tabs the
-- character has bought; without it, probe the fixed ID range instead.
local function BankBagIDs(bankType)
    if C_Bank and C_Bank.FetchPurchasedBankTabIDs then
        local ok, ids = pcall(C_Bank.FetchPurchasedBankTabIDs, bankType)
        if ok and type(ids) == "table" then return ids end
    end
    local first = (bankType == BankType.Character) and BagIndex.CharacterBankTab_1 or BagIndex.AccountBankTab_1
    local last = (bankType == BankType.Character) and BagIndex.CharacterBankTab_9 or BagIndex.AccountBankTab_9
    local ids = {}
    if first and last then
        for bag = first, last do
            if (C_Container.GetContainerNumSlots(bag) or 0) > 0 then ids[#ids + 1] = bag end
        end
    end
    return ids
end

local function CanViewBank(bankType)
    if not (C_Bank and C_Bank.CanViewBank) then
        return bankType == BankType.Character
    end
    local ok, can = pcall(C_Bank.CanViewBank, bankType)
    return ok and can
end

local function ScanBags()
    if not (me and Enabled()) then return end
    local fresh = {}
    for _, bag in ipairs(PlayerBagIDs()) do ScanBag(bag, fresh) end
    me.bags = fresh
    me.lastSeen = time()
end

local function ScanBank()
    if not (me and bankOpen and Enabled()) then return end
    if CanViewBank(BankType.Character) then
        local fresh = {}
        for _, bag in ipairs(BankBagIDs(BankType.Character)) do ScanBag(bag, fresh) end
        me.bank = fresh
        me.bankSeen = time()
    end
    if BankType.Account and CanViewBank(BankType.Account) then
        local fresh = {}
        for _, bag in ipairs(BankBagIDs(BankType.Account)) do ScanBag(bag, fresh) end
        DB.account.bank = fresh
        DB.account.bankSeen = time()
    end
end

local function ScanMoney()
    if not (me and Enabled()) then return end
    me.money = GetMoney() or 0
end

------------------------------------------------------------------------
-- Shared lookups
------------------------------------------------------------------------

local function ClassColor(classFile)
    local c = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
    if c then return c.r, c.g, c.b end
    return 1, 0.82, 0
end

local function ColoredName(rec)
    local r, g, b = ClassColor(rec.class)
    return string.format("|cff%02x%02x%02x%s|r",
        math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5), rec.name or "?")
end

local function ItemDisplay(itemID)
    local rec = DB.items[itemID] or {}
    local name, link, quality, icon = rec.name, rec.link, rec.quality, rec.icon
    if not name or name == "" or not icon then
        local n, l, q, _, _, _, _, _, _, i = C_Item.GetItemInfo(itemID)
        if not name or name == "" then name = n end
        link = link or l
        quality = quality or q
        icon = icon or i
    end
    return name or ("Item " .. itemID), link, quality, icon
end

local function QualityColor(quality)
    local c = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
    if c and c.color then return c.color:GetRGB() end
    if c then return c.r, c.g, c.b end
    return 1, 1, 1
end

-- Each record carries its own table key in .key so the window can
-- select it. It ends up in the saved file too, a harmless duplicate.
local function SortedChars()
    local list = {}
    for key, rec in pairs(DB.chars) do
        rec.key = key
        list[#list + 1] = rec
    end
    table.sort(list, function(a, b)
        if a.realm ~= b.realm then return (a.realm or "") < (b.realm or "") end
        return (a.name or "") < (b.name or "")
    end)
    return list
end

-- Returns rows {rec, bags, bank}, the Warband bank count and the total.
local function CountsFor(itemID)
    local rows, total = {}, 0
    for _, rec in ipairs(SortedChars()) do
        local bags = rec.bags[itemID] or 0
        local bank = rec.bank[itemID] or 0
        if bags > 0 or bank > 0 then
            rows[#rows + 1] = { rec = rec, bags = bags, bank = bank }
            total = total + bags + bank
        end
    end
    local account = DB.account.bank[itemID] or 0
    return rows, account, total + account
end

------------------------------------------------------------------------
-- Tooltip
------------------------------------------------------------------------

local function AddTooltipLines(tooltip, itemID)
    if not (DB and itemID and Enabled() and UlRemedy.enabled.inventorytooltip) then return end
    local rows, account, total = CountsFor(itemID)
    if total == 0 then return end

    tooltip:AddLine(" ")
    for _, row in ipairs(rows) do
        local detail
        if row.bags > 0 and row.bank > 0 then
            detail = string.format("%d  (bags %d, bank %d)", row.bags + row.bank, row.bags, row.bank)
        elseif row.bags > 0 then
            detail = string.format("%d  (bags)", row.bags)
        else
            detail = string.format("%d  (bank)", row.bank)
        end
        tooltip:AddDoubleLine(ColoredName(row.rec), detail, 1, 1, 1, 1, 1, 1)
    end
    if account > 0 then
        tooltip:AddDoubleLine(ACCOUNT_LABEL, tostring(account), 0.6, 0.8, 1, 1, 1, 1)
    end
    if #rows + (account > 0 and 1 or 0) > 1 then
        tooltip:AddDoubleLine("Total", tostring(total), 1, 0.82, 0, 1, 1, 1)
    end
    tooltip:Show()
end

local function ItemIDFromTooltip(tooltip)
    if tooltip.GetItem then
        local _, link = tooltip:GetItem()
        if link then return C_Item.GetItemInfoInstant(link) end
    end
end

local function HookTooltips()
    if not (TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall
            and Enum.TooltipDataType and Enum.TooltipDataType.Item) then
        return
    end
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
        if tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip then return end
        pcall(AddTooltipLines, tooltip, (data and data.id) or ItemIDFromTooltip(tooltip))
    end)
end

------------------------------------------------------------------------
-- Browser window
------------------------------------------------------------------------

local CHAR_ROW_H, ITEM_ROW_H = 34, 20
local ALL_KEY = "__all"
local WIDTH, HEIGHT = 680, 500
local CHAR_W = 190

local function TotalMoney()
    local total = 0
    for _, rec in pairs(DB.chars) do total = total + (rec.money or 0) end
    return total
end

local function BuildCharList()
    local list = SortedChars()
    local dp = CreateDataProvider()
    dp:Insert({ key = ALL_KEY, label = "All characters", money = TotalMoney() })
    for _, rec in ipairs(list) do
        dp:Insert({ key = rec.key, rec = rec, money = rec.money or 0 })
    end
    if next(DB.account.bank) then
        dp:Insert({ key = ACCOUNT_KEY, label = ACCOUNT_LABEL })
    end
    return dp
end

local function AppendItems(rows, source, where, rec, filter)
    for itemID, count in pairs(source) do
        local name, link, quality, icon = ItemDisplay(itemID)
        if not filter or name:lower():find(filter, 1, true) then
            rows[#rows + 1] = {
                itemID = itemID, name = name, link = link, quality = quality,
                icon = icon, count = count, where = where, rec = rec,
            }
        end
    end
end

-- All characters: one row per item, the counts added up, the Character
-- column naming every holder (most first). The per-character breakdown
-- is in the item's tooltip, which the tracker fills in anyway.
local function AppendMergedItems(rows, filter)
    local byItem = {}
    local function add(source, where, rec)
        for itemID, count in pairs(source) do
            local row = byItem[itemID]
            if row == nil then
                local name, link, quality, icon = ItemDisplay(itemID)
                if filter and not name:lower():find(filter, 1, true) then
                    row = false
                else
                    row = {
                        itemID = itemID, name = name, link = link, quality = quality,
                        icon = icon, count = 0, holders = {}, places = {},
                    }
                end
                byItem[itemID] = row
            end
            if row then
                row.count = row.count + count
                row.places[where] = true
                local key = rec or ACCOUNT_KEY
                local h = row.holders[key]
                if not h then
                    h = { rec = rec, count = 0 }
                    row.holders[key] = h
                end
                h.count = h.count + count
            end
        end
    end
    for _, rec in ipairs(SortedChars()) do
        add(rec.bags, "Bags", rec)
        add(rec.bank, "Bank", rec)
    end
    add(DB.account.bank, "Bank", nil)

    for _, row in pairs(byItem) do
        if row then
            local list = {}
            for _, h in pairs(row.holders) do list[#list + 1] = h end
            table.sort(list, function(a, b)
                if a.count ~= b.count then return a.count > b.count end
                return (a.rec and a.rec.name or "") < (b.rec and b.rec.name or "")
            end)
            local names = {}
            for _, h in ipairs(list) do
                names[#names + 1] = h.rec and ColoredName(h.rec) or ("|cff99ccff" .. ACCOUNT_LABEL .. "|r")
            end
            row.ownerText = table.concat(names, ", ")
            if row.places.Bags and row.places.Bank then
                row.where = "Both"
            elseif row.places.Bags then
                row.where = "Bags"
            else
                row.where = "Bank"
            end
            row.holders, row.places = nil, nil
            rows[#rows + 1] = row
        end
    end
end

local function BuildItemList(selected, filter)
    local rows = {}
    if selected == ALL_KEY then
        AppendMergedItems(rows, filter)
    elseif selected == ACCOUNT_KEY then
        AppendItems(rows, DB.account.bank, "Bank", nil, filter)
    else
        local rec = DB.chars[selected]
        if rec then
            AppendItems(rows, rec.bags, "Bags", rec, filter)
            AppendItems(rows, rec.bank, "Bank", rec, filter)
        end
    end
    table.sort(rows, function(a, b)
        if a.name ~= b.name then return a.name < b.name end
        local an = a.rec and a.rec.name or ""
        local bn = b.rec and b.rec.name or ""
        if an ~= bn then return an < bn end
        return a.where < b.where
    end)
    local dp = CreateDataProvider()
    for _, row in ipairs(rows) do dp:Insert(row) end
    return dp, #rows
end

local function RefreshWindow()
    if not (window and window:IsShown()) then return end
    local filter = strtrim(window.search:GetText() or ""):lower()
    if filter == "" then filter = nil end

    window.charBox:SetDataProvider(BuildCharList(), true)
    local dp, count = BuildItemList(window.selected, filter)
    window.itemBox:SetDataProvider(dp, true)

    local label
    if window.selected == ALL_KEY then
        label = "All characters"
    elseif window.selected == ACCOUNT_KEY then
        label = ACCOUNT_LABEL
    else
        local rec = DB.chars[window.selected]
        label = rec and ColoredName(rec) or "?"
    end
    window.status:SetText(string.format("%s: %d item%s", label, count, window.selected == ALL_KEY and "s, all characters added up" or " row(s)"))

    local rec = DB.chars[window.selected]
    local isMe = rec == me
    window.forget:SetShown(rec ~= nil and not isMe)
end

local function InitCharRow(button, data)
    local UI = UlRemedy.UI
    if not button.name then
        button.name = UI.Text(button, "GameFontNormal", UI.TEXT)
        button.name:SetPoint("TOPLEFT", 8, -4)
        button.name:SetPoint("RIGHT", -4, 0)
        button.name:SetJustifyH("LEFT")
        button.gold = UI.Text(button, "GameFontHighlightSmall", UI.MUTED)
        button.gold:SetPoint("BOTTOMLEFT", 8, 5)
        button.gold:SetPoint("RIGHT", -4, 0)
        button.gold:SetJustifyH("LEFT")
        button.sel = button:CreateTexture(nil, "BACKGROUND")
        button.sel:SetAllPoints()
        button.sel:SetTexture(UI.WHITE)
        button.sel:SetVertexColor(UI.ACCENT[1], UI.ACCENT[2], UI.ACCENT[3], 0.25)
        local hl = button:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetTexture(UI.WHITE)
        hl:SetVertexColor(1, 1, 1, 0.05)
        button:SetScript("OnClick", function(self)
            window.selected = self.data.key
            RefreshWindow()
        end)
    end
    button.data = data
    if data.rec then
        button.name:SetText(string.format("%s |cffaaaaaa(%d)|r", ColoredName(data.rec), data.rec.level or 0))
        button.gold:SetText(UlRemedy.MoneyText(data.money or 0))
    else
        button.name:SetText("|cff" .. string.format("%02x%02x%02x", 194, 161, 230) .. data.label .. "|r")
        button.gold:SetText(data.money and UlRemedy.MoneyText(data.money) or "")
    end
    button.sel:SetShown(window.selected == data.key)
end

local function InitItemRow(button, data)
    local UI = UlRemedy.UI
    if not button.icon then
        button.icon = button:CreateTexture(nil, "ARTWORK")
        button.icon:SetSize(16, 16)
        button.icon:SetPoint("LEFT", 4, 0)
        button.name = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        button.name:SetPoint("LEFT", button.icon, "RIGHT", 4, 0)
        button.name:SetPoint("RIGHT", -200, 0)
        button.name:SetJustifyH("LEFT")
        button.name:SetWordWrap(false)
        button.count = UI.Text(button, "GameFontHighlightSmall", UI.TEXT)
        button.count:SetPoint("RIGHT", -160, 0)
        button.count:SetWidth(36)
        button.count:SetJustifyH("RIGHT")
        button.where = UI.Text(button, "GameFontHighlightSmall", UI.MUTED)
        button.where:SetPoint("RIGHT", -114, 0)
        button.where:SetWidth(40)
        button.where:SetJustifyH("LEFT")
        button.owner = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        button.owner:SetPoint("RIGHT", -4, 0)
        button.owner:SetWidth(106)
        button.owner:SetJustifyH("LEFT")
        button.owner:SetWordWrap(false)
        local hl = button:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetTexture(UI.WHITE)
        hl:SetVertexColor(1, 1, 1, 0.05)
        button:RegisterForClicks("LeftButtonUp")
        button:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if self.data.link then
                GameTooltip:SetHyperlink(self.data.link)
            elseif GameTooltip.SetItemByID then
                GameTooltip:SetItemByID(self.data.itemID)
            end
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", function() GameTooltip:Hide() end)
        button:SetScript("OnClick", function(self)
            if self.data.link and HandleModifiedItemClick then
                HandleModifiedItemClick(self.data.link)
            end
        end)
    end
    button.data = data
    button.icon:SetTexture(data.icon or 134400) -- question mark when unknown
    local r, g, b = QualityColor(data.quality)
    button.name:SetText(data.name)
    button.name:SetTextColor(r, g, b)
    button.count:SetText(data.count)
    button.where:SetText(data.where)
    button.owner:SetText(data.ownerText or (data.rec and ColoredName(data.rec) or ("|cff99ccff" .. ACCOUNT_LABEL .. "|r")))
end

local function MakeScrollList(parent, rowHeight, initializer)
    local box = CreateFrame("Frame", nil, parent, "WowScrollBoxList")
    local bar = CreateFrame("EventFrame", nil, parent, "MinimalScrollBar")
    local view = CreateScrollBoxListLinearView()
    view:SetElementExtent(rowHeight)
    view:SetElementInitializer("Button", initializer)
    ScrollUtil.InitScrollBoxListWithScrollBar(box, bar, view)
    return box, bar
end

local function ForgetSelected()
    local rec = DB.chars[window.selected]
    if not rec or rec == me then return end
    local name = ColoredName(rec)
    local function doForget()
        DB.chars[window.selected] = nil
        window.selected = ALL_KEY
        RefreshWindow()
        print(UlRemedy.name .. ": forgot inventory data for " .. name .. ".")
    end
    if StaticPopup_ShowGenericConfirmation then
        StaticPopup_ShowGenericConfirmation("Forget all stored gold and item data for " .. name .. "?", doForget)
    else
        doForget()
    end
end

local function CreateWindow()
    local UI = UlRemedy.UI
    local PAD = UI.PAD
    local f = UI.Window("UlRemedyInventoryFrame", WIDTH, HEIGHT, UlRemedy.name, "Inventory")
    f.selected = ALL_KEY

    local top = -(UI.TITLE_H + PAD)
    local bottom = 44

    -- Left: characters and gold, on a card.
    local charCard = CreateFrame("Frame", nil, f, "BackdropTemplate")
    charCard:SetPoint("TOPLEFT", f, "TOPLEFT", PAD, top)
    charCard:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", PAD, bottom)
    charCard:SetWidth(CHAR_W)
    UI.Backdrop(charCard, UI.CARD, UI.CARD_BORDER)
    f.charBox, f.charBar = MakeScrollList(charCard, CHAR_ROW_H, InitCharRow)
    f.charBox:SetPoint("TOPLEFT", 4, -4)
    f.charBox:SetPoint("BOTTOMRIGHT", -18, 4)
    f.charBar:SetPoint("TOPLEFT", f.charBox, "TOPRIGHT", 2, 0)
    f.charBar:SetPoint("BOTTOMLEFT", f.charBox, "BOTTOMRIGHT", 2, 0)

    -- Right: search, column headers and the item list, on a card.
    local itemCard = CreateFrame("Frame", nil, f, "BackdropTemplate")
    itemCard:SetPoint("TOPLEFT", charCard, "TOPRIGHT", 12, 0)
    itemCard:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PAD, bottom)
    UI.Backdrop(itemCard, UI.CARD, UI.CARD_BORDER)

    f.search = CreateFrame("EditBox", nil, itemCard, "SearchBoxTemplate")
    f.search:SetSize(240, 20)
    f.search:SetPoint("TOPLEFT", itemCard, "TOPLEFT", 10, -8)
    f.search:HookScript("OnTextChanged", RefreshWindow)

    local header = CreateFrame("Frame", nil, itemCard)
    header:SetPoint("TOPLEFT", itemCard, "TOPLEFT", 4, -34)
    header:SetPoint("RIGHT", itemCard, "RIGHT", -22, 0)
    header:SetHeight(16)
    local function HeaderText(text, point, x, width, justify)
        local fs = UI.Text(header, "GameFontNormalSmall", UI.ACCENT_TEXT)
        fs:SetPoint(point, x, 0)
        if width then fs:SetWidth(width) end
        fs:SetJustifyH(justify)
        fs:SetText(text)
    end
    HeaderText("Item", "LEFT", 24, nil, "LEFT")
    HeaderText("Count", "RIGHT", -160, 36, "RIGHT")
    HeaderText("Where", "RIGHT", -114, 40, "LEFT")
    HeaderText("Character", "RIGHT", -4, 106, "LEFT")
    local line = itemCard:CreateTexture(nil, "ARTWORK")
    line:SetTexture(UI.WHITE)
    line:SetVertexColor(UI.ACCENT[1], UI.ACCENT[2], UI.ACCENT[3], 0.35)
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -1)
    line:SetPoint("RIGHT", itemCard, "RIGHT", -4, 0)

    f.itemBox, f.itemBar = MakeScrollList(itemCard, ITEM_ROW_H, InitItemRow)
    f.itemBox:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -4)
    f.itemBox:SetPoint("BOTTOMRIGHT", itemCard, "BOTTOMRIGHT", -18, 4)
    f.itemBar:SetPoint("TOPLEFT", f.itemBox, "TOPRIGHT", 2, 0)
    f.itemBar:SetPoint("BOTTOMLEFT", f.itemBox, "BOTTOMRIGHT", 2, 0)

    -- Bottom: status line and the forget button.
    f.status = UI.Text(f, "GameFontHighlightSmall", UI.MUTED)
    f.status:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", PAD, 14)
    f.status:SetJustifyH("LEFT")

    f.forget = UI.Button(f, "Forget character", 140, 24, ForgetSelected)
    f.forget:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PAD, 10)

    f:SetScript("OnShow", RefreshWindow)
    return f
end

-- Called by Core when a feature is toggled, so re-enabling picks up the
-- current bags and gold without waiting for the next bag event.
function UlRemedy.RescanInventory()
    ScanBags()
    ScanBank()
    ScanMoney()
    RefreshWindow()
end

function UlRemedy.ToggleInventoryWindow()
    if not DB then return end
    if not window then window = CreateWindow() end
    if window:IsShown() then
        window:Hide()
    else
        ScanBags()
        ScanMoney()
        window:Show()
        RefreshWindow()
    end
end

------------------------------------------------------------------------
-- Events
------------------------------------------------------------------------

local frame = CreateFrame("Frame", "UlRemedyInventoryFrameEvents")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_LEVEL_UP")
frame:RegisterEvent("PLAYER_MONEY")
frame:RegisterEvent("BAG_UPDATE_DELAYED")
frame:RegisterEvent("BANKFRAME_OPENED")
frame:RegisterEvent("BANKFRAME_CLOSED")
frame:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
for _, ev in ipairs({ "PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED", "BANK_TABS_CHANGED" }) do
    if C_EventUtils and C_EventUtils.IsEventValid and C_EventUtils.IsEventValid(ev) then
        frame:RegisterEvent(ev)
    end
end

frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == UlRemedy.name then
            InitDB()
            HookTooltips()
            self:UnregisterEvent("ADDON_LOADED")
        end
        return
    end
    if not DB then return end

    if event == "PLAYER_ENTERING_WORLD" then
        InitCharacter()
        ScanBags()
        ScanMoney()
    elseif event == "PLAYER_LEVEL_UP" then
        if me then me.level = tonumber(arg1) or UnitLevel("player") end
    elseif event == "PLAYER_MONEY" then
        ScanMoney()
    elseif event == "BAG_UPDATE_DELAYED" then
        ScanBags()
        ScanBank()
    elseif event == "BANKFRAME_OPENED" then
        bankOpen = true
        ScanBank()
    elseif event == "BANKFRAME_CLOSED" then
        bankOpen = false
    else -- bank slot or tab changes
        ScanBank()
    end
    RefreshWindow()
end)
