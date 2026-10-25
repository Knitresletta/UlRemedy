-- Loot Helper: says when someone in your group got a piece you want, and
-- when you got a piece someone else wants.
--
-- Personal loot only. When a boss drops loot, ENCOUNTER_LOOT_RECEIVED
-- fires once per item for everyone in the group, with the item, the
-- receiver and their class. Items that went through a loot roll are
-- ignored: their item IDs are remembered from START_LOOT_ROLL. (The
-- loot method reported by GetLootMethod is not "personalloot" in a
-- 12.1.5 dungeon, so it is not used as a gate; the roll memory is.)
--
-- Two questions per item. Is it an upgrade for me: it has to suit my
-- class and spec (armor type, and C_Item.GetItemSpecInfo), and its item
-- level has to beat what I wear in that slot (the lower of two rings or
-- trinkets). Is my drop an upgrade for someone else: the same test with
-- their spec and their worn item level, which needs an inspect. Group
-- members are inspected one at a time, out of combat and in range, when
-- the roster changes and after each boss, and the result is cached by
-- GUID for the run.
--
-- Whether another player's item is tradable only their own tooltip
-- knows, so the message says to ask. Output is a small card in the
-- shared style with the item's icon, up to three stacked, each gone
-- after half a minute or a click on its X; the cards can be dragged and
-- the spot is saved in UlRemedyDB.lootPos. Nothing is whispered and
-- nothing is traded. /ur loot prints what the module knows about the
-- group.

local ROLL_MEMORY = 10 * 60       -- seconds a rolled item stays on the ignore list
local INSPECT_GAP = 2             -- seconds between inspect requests
local INSPECT_TTL = 15 * 60       -- seconds an inspect result is trusted

local ARMOR_FOR_CLASS = {
    MAGE = 1, PRIEST = 1, WARLOCK = 1,
    ROGUE = 2, DRUID = 2, MONK = 2, DEMONHUNTER = 2,
    HUNTER = 3, SHAMAN = 3, EVOKER = 3,
    WARRIOR = 4, PALADIN = 4, DEATHKNIGHT = 4,
}

-- Equip location to the inventory slots it competes with.
local SLOTS = {
    INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 },
    INVTYPE_CHEST = { 5 }, INVTYPE_ROBE = { 5 }, INVTYPE_WAIST = { 6 },
    INVTYPE_LEGS = { 7 }, INVTYPE_FEET = { 8 }, INVTYPE_WRIST = { 9 },
    INVTYPE_HAND = { 10 }, INVTYPE_FINGER = { 11, 12 }, INVTYPE_TRINKET = { 13, 14 },
    INVTYPE_CLOAK = { 15 }, INVTYPE_WEAPON = { 16, 17 }, INVTYPE_SHIELD = { 17 },
    INVTYPE_2HWEAPON = { 16 }, INVTYPE_WEAPONMAINHAND = { 16 }, INVTYPE_WEAPONOFFHAND = { 17 },
    INVTYPE_HOLDABLE = { 17 }, INVTYPE_RANGED = { 16 }, INVTYPE_RANGEDRIGHT = { 16 },
}
local SLOT_NAMES = {
    [1] = "head", [2] = "neck", [3] = "shoulders", [5] = "chest", [6] = "waist", [7] = "legs",
    [8] = "feet", [9] = "wrists", [10] = "hands", [11] = "ring", [12] = "ring", [13] = "trinket",
    [14] = "trinket", [15] = "back", [16] = "main hand", [17] = "off hand",
}

local rolled = {}        -- itemID -> time it went to a roll
local inspected = {}     -- guid -> { name, class, spec, slots = { [slot] = ilvl }, at }
local queue = {}         -- unit tokens waiting for an inspect
local inspecting         -- { unit, guid, at } while a request is out

local function Enabled()
    return UlRemedy.enabled and UlRemedy.enabled.loothelper
end

local function Plain(v)
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end

------------------------------------------------------------------------
-- Items
------------------------------------------------------------------------

local function ItemLevel(link)
    local ok, ilvl = pcall(C_Item.GetDetailedItemLevelInfo, link)
    return ok and tonumber(Plain(ilvl)) or nil
end

-- Where the item goes, or nil when it is not gear worth comparing.
local function ItemSlots(link)
    local ok, itemID, _, _, equipLoc, _, classID, subClassID = pcall(C_Item.GetItemInfoInstant, link)
    if not ok or not itemID then return nil end
    local slots = SLOTS[equipLoc]
    if not slots then return nil end
    return slots, classID, subClassID
end

-- Does the item suit this class and spec. Armor must be the class's
-- type unless it is generic (neck, rings, trinkets, cloaks); then the
-- spec list, when the item has one, must name the spec.
local function Suits(link, class, specID, classID, subClassID)
    if classID == 4 and subClassID and subClassID >= 1 and subClassID <= 4 then
        if ARMOR_FOR_CLASS[class] and ARMOR_FOR_CLASS[class] ~= subClassID then return false end
    end
    if not specID then return true end
    local ok, specs = pcall(C_Item.GetItemSpecInfo, link)
    if not ok or type(specs) ~= "table" or #specs == 0 then return true end
    for _, id in ipairs(specs) do
        if id == specID then return true end
    end
    return false
end

-- The lowest item level worn in the slots the item competes with, and
-- that slot. Missing or unreadable gear counts as 0.
local function WornLevel(slotLevels, slots)
    local lowest, which = math.huge, slots[1]
    for _, slot in ipairs(slots) do
        local lvl = slotLevels[slot] or 0
        if lvl < lowest then lowest, which = lvl, slot end
    end
    return lowest == math.huge and 0 or lowest, which
end

local function MySlotLevels()
    local levels = {}
    for slot = 1, 17 do
        local link = GetInventoryItemLink("player", slot)
        levels[slot] = link and ItemLevel(link) or 0
    end
    return levels
end

local function MySpec()
    local index = GetSpecialization and GetSpecialization()
    return index and GetSpecializationInfo and GetSpecializationInfo(index) or nil
end

------------------------------------------------------------------------
-- Inspecting the group
------------------------------------------------------------------------

local function GroupUnits()
    local units = {}
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do units[#units + 1] = "raid" .. i end
    elseif IsInGroup() then
        for i = 1, GetNumSubgroupMembers() do units[#units + 1] = "party" .. i end
    end
    return units
end

local function NextInspect()
    if inspecting or InCombatLockdown() then return end
    while #queue > 0 do
        local unit = table.remove(queue, 1)
        local guid = UnitGUID(unit)
        local rec = guid and inspected[guid]
        local fresh = rec and (GetTime() - rec.at) < INSPECT_TTL
        if guid and not fresh and not UnitIsUnit(unit, "player") and UnitIsConnected(unit) and CanInspect(unit) then
            inspecting = { unit = unit, guid = guid, at = GetTime() }
            local ok = pcall(NotifyInspect, unit)
            if ok then
                -- No answer within ten seconds means out of range; move on.
                C_Timer.After(10, function()
                    if inspecting and inspecting.guid == guid then
                        inspecting = nil
                        NextInspect()
                    end
                end)
                return
            end
            inspecting = nil
        end
    end
end

local function QueueInspects()
    if not Enabled() then return end
    wipe(queue)
    for _, unit in ipairs(GroupUnits()) do queue[#queue + 1] = unit end
    C_Timer.After(INSPECT_GAP, NextInspect)
end

-- INSPECT_READY arrives before the client has every item cached, so
-- links are missing or give the unscaled base level on the first read.
-- Read three times over three seconds, keeping the best value per slot
-- and asking for the item data in between, then let the inspect go.
local READ_DELAYS = { 0, 1, 2.5 }

local function ReadInspectSlots(unit, rec)
    local read = 0
    for slot = 1, 17 do
        local okL, link = pcall(GetInventoryItemLink, unit, slot)
        link = okL and Plain(link) or nil
        if link then
            local lvl = ItemLevel(link)
            if lvl and lvl > (rec.slots[slot] or 0) then rec.slots[slot] = lvl end
            if not lvl or lvl < 100 then
                local id = C_Item.GetItemInfoInstant(link)
                if id and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end
            end
            read = read + 1
        end
    end
    rec.linksSeen = math.max(rec.linksSeen or 0, read)
end

local function OnInspectReady(guid)
    if not inspecting or inspecting.guid ~= guid then return end
    local unit = inspecting.unit
    local rec = { name = UnitName(unit), class = select(2, UnitClass(unit)), slots = {}, at = GetTime() }
    local ok, spec = pcall(GetInspectSpecialization, unit)
    rec.spec = ok and tonumber(Plain(spec)) or nil
    if rec.spec == 0 then rec.spec = nil end
    local okA, avg = pcall(C_PaperDollInfo and C_PaperDollInfo.GetInspectItemLevel or function() end, unit)
    rec.average = okA and tonumber(Plain(avg)) or nil
    for slot = 1, 17 do rec.slots[slot] = 0 end
    inspected[guid] = rec

    for i, delay in ipairs(READ_DELAYS) do
        C_Timer.After(delay, function()
            if inspecting and inspecting.guid == guid and UnitGUID(unit) == guid then
                pcall(ReadInspectSlots, unit, rec)
            end
            if i == #READ_DELAYS then
                if inspecting and inspecting.guid == guid then inspecting = nil end
                if ClearInspectPlayer then pcall(ClearInspectPlayer) end
                C_Timer.After(INSPECT_GAP, NextInspect)
            end
        end)
    end
end

------------------------------------------------------------------------
-- Cards
------------------------------------------------------------------------

local CARD_W, CARD_PAD, CARD_LIFE, MAX_CARDS = 340, 10, 30, 3
local cards = {}          -- shown cards, newest last
local anchor              -- invisible frame the cards hang from

local function GetAnchor()
    if anchor then return anchor end
    anchor = CreateFrame("Frame", "UlRemedyLootAnchor", UIParent)
    anchor:SetSize(CARD_W, 1)
    local pos = UlRemedyDB.lootPos
    if pos and pos.point then
        anchor:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x or 0, pos.y or 0)
    else
        anchor:SetPoint("TOP", UIParent, "TOP", 0, -230)
    end
    return anchor
end

local function LayoutCards()
    local prev
    for _, card in ipairs(cards) do
        card:ClearAllPoints()
        if prev then
            card:SetPoint("TOP", prev, "BOTTOM", 0, -6)
        else
            card:SetPoint("TOP", GetAnchor(), "TOP", 0, 0)
        end
        prev = card
    end
end

local function DismissCard(card)
    for i, c in ipairs(cards) do
        if c == card then table.remove(cards, i) break end
    end
    card:Hide()
    LayoutCards()
end

local pool = {}

local function AcquireCard()
    local card = table.remove(pool)
    if card then return card end
    local UI = UlRemedy.UI
    card = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    card:SetWidth(CARD_W)
    UI.Backdrop(card, UI.BG, UI.BORDER)
    card:SetFrameStrata("HIGH")
    card:EnableMouse(true)
    card:SetMovable(true)
    card:RegisterForDrag("LeftButton")
    card:SetClampedToScreen(true)
    -- Dragging any card moves the anchor, so the stack moves together.
    card:SetScript("OnDragStart", function(self)
        local a = GetAnchor()
        a:SetMovable(true)
        a:StartMoving()
        self.movingAnchor = true
    end)
    card:SetScript("OnDragStop", function(self)
        local a = GetAnchor()
        a:StopMovingOrSizing()
        local point, _, relPoint, x, y = a:GetPoint()
        UlRemedyDB.lootPos = { point = point, relPoint = relPoint, x = x, y = y }
        self.movingAnchor = nil
    end)
    card:SetHyperlinksEnabled(true)
    card:SetScript("OnHyperlinkClick", function(self, link, text, mouseButton)
        if HandleModifiedItemClick and IsModifiedClick("CHATLINK") then
            HandleModifiedItemClick(text)
        else
            SetItemRef(link, text, mouseButton, self)
        end
    end)
    card:SetScript("OnHyperlinkEnter", function(self, link)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink(link)
        GameTooltip:Show()
    end)
    card:SetScript("OnHyperlinkLeave", function() GameTooltip:Hide() end)

    local accent = card:CreateTexture(nil, "ARTWORK")
    accent:SetTexture(UI.WHITE)
    accent:SetVertexColor(UI.ACCENT[1], UI.ACCENT[2], UI.ACCENT[3], 0.9)
    accent:SetWidth(3)
    accent:SetPoint("TOPLEFT", card, "TOPLEFT", 1, -1)
    accent:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 1, 1)

    card.icon = card:CreateTexture(nil, "ARTWORK")
    card.icon:SetSize(36, 36)
    card.icon:SetPoint("TOPLEFT", card, "TOPLEFT", CARD_PAD + 4, -CARD_PAD)
    card.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    card.close = UI.CloseButton(card, function() DismissCard(card) end)
    card.close:SetSize(22, 22)
    card.close:SetPoint("TOPRIGHT", card, "TOPRIGHT", -2, -2)

    card.title = UI.Text(card, "GameFontNormal", UI.ACCENT_TEXT)
    card.title:SetPoint("TOPLEFT", card.icon, "TOPRIGHT", 10, -1)
    card.title:SetPoint("RIGHT", card.close, "LEFT", -4, 0)
    card.title:SetJustifyH("LEFT")

    card.body = UI.Text(card, "GameFontHighlightSmall", UI.TEXT)
    card.body:SetPoint("TOPLEFT", card.title, "BOTTOMLEFT", 0, -3)
    card.body:SetPoint("RIGHT", card, "RIGHT", -CARD_PAD, 0)
    card.body:SetJustifyH("LEFT")
    card.body:SetWordWrap(true)
    card.body:SetSpacing(2)

    -- Hovering pauses the timer, so a card is not lost while reading.
    card:SetScript("OnUpdate", function(self, elapsed)
        if self:IsMouseOver() then return end
        self.left = (self.left or CARD_LIFE) - elapsed
        if self.left <= 0 then DismissCard(self) end
    end)
    return card
end

local function ShowCard(icon, title, body)
    while #cards >= MAX_CARDS do DismissCard(cards[1]) end
    local card = AcquireCard()
    card.icon:SetTexture(icon or 134400)
    card.title:SetText(title)
    card.body:SetText(body)
    card.left = CARD_LIFE
    local h = CARD_PAD + math.max(36, 16 + card.body:GetStringHeight() + 6) + CARD_PAD
    card:SetHeight(h)
    cards[#cards + 1] = card
    card:Show()
    LayoutCards()
    if PlaySound and SOUNDKIT and SOUNDKIT.UI_GARRISON_TOAST then
        pcall(PlaySound, SOUNDKIT.UI_GARRISON_TOAST)
    end
end

local function ItemIcon(link)
    local ok, _, _, _, _, icon = pcall(C_Item.GetItemInfoInstant, link)
    return ok and icon or nil
end

------------------------------------------------------------------------
-- Judging a drop
------------------------------------------------------------------------

local function LootMethod()
    local ok, method = pcall(GetLootMethod)
    return ok and tostring(Plain(method)) or "?"
end

local function OnLoot(itemLink, receiverName, receiverClass)
    if not Enabled() then return end
    if not itemLink or not receiverName then return end
    local itemID = C_Item.GetItemInfoInstant(itemLink)
    if itemID and rolled[itemID] and (GetTime() - rolled[itemID]) < ROLL_MEMORY then return end
    local slots, classID, subClassID = ItemSlots(itemLink)
    if not slots then return end
    local ilvl = ItemLevel(itemLink)
    if not ilvl then return end

    local myName = UnitName("player")
    local shortReceiver = Ambiguate(receiverName, "short")
    local mine = shortReceiver == myName

    if not mine then
        -- Someone else's drop: do I want it?
        local me = select(2, UnitClass("player"))
        if not Suits(itemLink, me, MySpec(), classID, subClassID) then return end
        local worn, slot = WornLevel(MySlotLevels(), slots)
        if ilvl > worn then
            ShowCard(ItemIcon(itemLink), shortReceiver .. " got an upgrade for you",
                string.format("%s (ilvl %d) beats your %s (ilvl %d). Ask whether it can be traded.",
                    itemLink, ilvl, SLOT_NAMES[slot] or "slot", worn))
        end
        return
    end

    -- My drop: is it an upgrade for me, and if not, for whom?
    local me = select(2, UnitClass("player"))
    local worn = select(1, WornLevel(MySlotLevels(), slots))
    if Suits(itemLink, me, MySpec(), classID, subClassID) and ilvl > worn then return end

    local wants = {}
    for _, unit in ipairs(GroupUnits()) do
        local guid = UnitGUID(unit)
        local rec = guid and inspected[guid]
        if rec and not UnitIsUnit(unit, "player") then
            if Suits(itemLink, rec.class, rec.spec, classID, subClassID) then
                local theirs = WornLevel(rec.slots, slots)
                if ilvl > theirs then
                    wants[#wants + 1] = string.format("%s (ilvl %d there)", rec.name or unit, theirs)
                end
            end
        end
    end
    if #wants > 0 then
        ShowCard(ItemIcon(itemLink), "Your drop would help someone",
            string.format("%s (ilvl %d) is not an upgrade for you. It would be for %s.",
                itemLink, ilvl, table.concat(wants, ", ")))
    end
end

------------------------------------------------------------------------
-- Commands and events
------------------------------------------------------------------------

function UlRemedy.LootHelperReport()
    print(UlRemedy.name .. ": loot helper " .. (Enabled() and "on" or "off")
        .. ", loot method " .. LootMethod() .. " (not used as a gate)"
        .. ", inspect " .. (inspecting and ("waiting on " .. inspecting.unit) or "idle") .. ", queue " .. #queue .. ".")
    for _, unit in ipairs(GroupUnits()) do
        local guid = UnitGUID(unit)
        local rec = guid and inspected[guid]
        if rec then
            local n, sum = 0, 0
            for slot, lvl in pairs(rec.slots) do
                if slot ~= 4 and lvl > 0 then n = n + 1; sum = sum + lvl end
            end
            print(string.format("  %s: spec %s, %d links seen, %d levels read, average of those %d, client average %s, %d min ago",
                rec.name or unit, tostring(rec.spec or "?"), rec.linksSeen or 0, n, n > 0 and math.floor(sum / n + 0.5) or 0,
                rec.average and string.format("%.0f", rec.average) or "?", math.floor((GetTime() - rec.at) / 60)))
        else
            print("  " .. (UnitName(unit) or unit) .. ": not inspected yet")
        end
    end
end

-- /ur loottest: a sample card, to see where it lands and move it.
function UlRemedy.LootHelperTest()
    local link = GetInventoryItemLink("player", 16) or GetInventoryItemLink("player", 1) or "item"
    ShowCard(ItemIcon(link), "Someone got an upgrade for you",
        string.format("%s (ilvl 999) beats your main hand (ilvl 1). Ask whether it can be traded.", link))
end

function UlRemedy.RefreshLootHelper()
    if Enabled() then QueueInspects() end
end

local frame = CreateFrame("Frame", "UlRemedyLootHelperEvents")
frame:RegisterEvent("ENCOUNTER_LOOT_RECEIVED")
frame:RegisterEvent("START_LOOT_ROLL")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
frame:RegisterEvent("ENCOUNTER_END")
frame:RegisterEvent("INSPECT_READY")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ENCOUNTER_LOOT_RECEIVED" then
        local _, _, itemLink, _, playerName, className = ...
        pcall(OnLoot, Plain(itemLink), Plain(playerName), Plain(className))
    elseif event == "START_LOOT_ROLL" then
        local rollID = ...
        local ok, link = pcall(GetLootRollItemLink, rollID)
        local itemID = ok and Plain(link) and C_Item.GetItemInfoInstant(link)
        if itemID then rolled[itemID] = GetTime() end
    elseif event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
        if not IsInGroup() then wipe(inspected) end
        QueueInspects()
    elseif event == "ENCOUNTER_END" then
        C_Timer.After(5, QueueInspects)
    elseif event == "INSPECT_READY" then
        local guid = ...
        pcall(OnInspectReady, guid)
    elseif event == "PLAYER_REGEN_ENABLED" then
        NextInspect()
    end
end)
