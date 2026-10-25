-- Reminders: a small panel that says what you are missing.
--
-- Two kinds. Class reminders, anywhere: a Rogue without poisons, an
-- Enhancement Shaman without weapon imbues, a Hunter or Warlock without a pet, and
-- any class that has a raid buff of its own but is not wearing it.
-- Instance reminders, inside a Mythic or Mythic+ dungeon and in any
-- raid: no flask, no Well Fed, no oil or stone on the main hand.
--
-- Everything is decided from the spellbook, your own auras, the pet and
-- GetWeaponEnchantInfo, so a class only gets reminders about things it
-- can do. Spell IDs are checked against the spellbook at runtime; one
-- the client no longer has simply never matches. Flask and Well Fed are
-- recognised by aura name, so that part is English-client only, like
-- the Auto Macro lists.
--
-- The panel is drawn with the shared style, sits at the top of the
-- screen, can be dragged (position saved in UlRemedyDB.reminderPos) and
-- hides itself in combat and when nothing is missing. Entering an
-- instance also prints one chat line. Checks run on zoning, aura and
-- gear changes, pet and spec changes, when combat ends, and every half
-- minute for things that expire. Nothing of Blizzard's is hooked and
-- nothing is cast: this only looks.

local THROTTLE = 1               -- seconds between checks from events
local TICK = 30                  -- seconds between timed checks
local EXPIRY_WARN = 10 * 60      -- warn when a buff has less left than this

-- Raid buffs a class puts on itself; remind when the class knows the
-- spell and does not have the aura. The aura ID is the spell ID.
local RAID_BUFFS = {
    { spell = 1459,   label = "Arcane Intellect" },
    { spell = 21562,  label = "Power Word: Fortitude" },
    { spell = 6673,   label = "Battle Shout" },
    { spell = 1126,   label = "Mark of the Wild" },
    { spell = 462854, label = "Skyfury" },
}

-- Rogue poisons: the spell that applies one is also its aura ID.
local LETHAL_POISONS = { 315584, 2823, 8679, 381664 }      -- Instant, Deadly, Wound, Amplifying
local NONLETHAL_POISONS = { 3408, 5761, 381637 }           -- Crippling, Numbing, Atrophic

-- Shaman imbues, by spell.
local MAINHAND_IMBUES = { 33757, 318038, 382021 }          -- Windfury, Flametongue, Earthliving
local SHIELD_IMBUES = { 462757 }                            -- Thunderstrike Ward

local GRIMOIRE_OF_SACRIFICE = 108503
local PET_SPECS = { [253] = true, [255] = true }            -- Beast Mastery, Survival

local panel
local lines = {}
local lastCheck = 0
local pendingTimer
local lastSummary                 -- last chat summary, so zoning does not repeat it
local announcedInstance           -- instance the chat line was printed for

local function ClassOn()
    return UlRemedy.enabled and UlRemedy.enabled.reminders
end

local function InstanceOn()
    return UlRemedy.enabled and UlRemedy.enabled.instancereminders
end

------------------------------------------------------------------------
-- Looking
------------------------------------------------------------------------

local function SpellKnown(id)
    if C_SpellBook and C_SpellBook.IsSpellInSpellBook and Enum and Enum.SpellBookSpellBank then
        local ok, known = pcall(C_SpellBook.IsSpellInSpellBook, id, Enum.SpellBookSpellBank.Player, false)
        return ok and known or false
    end
    return IsSpellKnownOrOverridesKnown and IsSpellKnownOrOverridesKnown(id) or false
end

local function AnyKnown(list)
    for _, id in ipairs(list) do
        if SpellKnown(id) then return true end
    end
    return false
end

local function HasAura(spellID)
    if not (C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID) then return false end
    local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, spellID)
    return ok and aura ~= nil
end

local function AnyAura(list)
    for _, id in ipairs(list) do
        if HasAura(id) then return true end
    end
    return false
end

-- The first helpful aura whose name passes the test, with seconds left
-- (0 when it does not expire). Nothing on a failure.
local function FindAura(test)
    if not (AuraUtil and AuraUtil.ForEachAura) then return nil end
    local found, left
    pcall(AuraUtil.ForEachAura, "player", "HELPFUL", nil, function(aura)
        local name = aura and aura.name
        if type(name) == "string" and not (issecretvalue and issecretvalue(name)) and test(name) then
            found = name
            local exp = aura.expirationTime
            if type(exp) == "number" and exp > 0 then left = exp - GetTime() else left = 0 end
            return true
        end
    end, true)
    return found, left
end

local function SpellIcon(id)
    return C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(id) or 134400
end

local function ExpiryText(left)
    if left and left > 0 and left < EXPIRY_WARN then
        return string.format(" (expires in %d min)", math.max(1, math.floor(left / 60 + 0.5)))
    end
    return ""
end

-- Where we are: "mythic" for Mythic and Mythic+ dungeons, "raid" for any
-- raid, nil elsewhere.
local function InstanceKind()
    local _, instanceType, difficultyID = GetInstanceInfo()
    if instanceType == "raid" then return "raid" end
    if instanceType == "party" and (difficultyID == 8 or difficultyID == 23) then return "mythic" end
    return nil
end

-- A pet is dismissed while flying, on a taxi or in a vehicle, so a
-- missing pet means nothing then. The dismount triggers a new check.
local function Travelling()
    return (IsMounted and IsMounted()) or (UnitOnTaxi and UnitOnTaxi("player"))
        or (UnitInVehicle and UnitInVehicle("player")) or false
end

local function ClassReminders(out)
    local _, class = UnitClass("player")
    local specIndex = GetSpecialization and GetSpecialization()
    local specID = specIndex and GetSpecializationInfo and GetSpecializationInfo(specIndex)

    for _, b in ipairs(RAID_BUFFS) do
        if SpellKnown(b.spell) and not HasAura(b.spell) then
            out[#out + 1] = { icon = SpellIcon(b.spell), text = b.label .. " is not up" }
        end
    end

    if class == "ROGUE" then
        if AnyKnown(LETHAL_POISONS) and not AnyAura(LETHAL_POISONS) then
            out[#out + 1] = { icon = SpellIcon(LETHAL_POISONS[1]), text = "No lethal poison" }
        end
        if AnyKnown(NONLETHAL_POISONS) and not AnyAura(NONLETHAL_POISONS) then
            out[#out + 1] = { icon = SpellIcon(NONLETHAL_POISONS[1]), text = "No non-lethal poison" }
        end
    elseif class == "SHAMAN" then
        -- Imbues are temporary weapon enchants, the same slot an oil or
        -- stone uses, so they overwrite each other. Enhancement imbues
        -- both hands and never oils; Elemental and Restoration oil the
        -- main hand instead (the instance check covers that) and may
        -- ward the shield.
        local hasMain, _, _, _, hasOff = GetWeaponEnchantInfo()
        local offItem = GetInventoryItemID("player", 17)
        if specID == 263 then
            if AnyKnown(MAINHAND_IMBUES) and not hasMain then
                out[#out + 1] = { icon = SpellIcon(MAINHAND_IMBUES[1]), text = "No imbue on your main hand" }
            end
            if offItem and not hasOff and AnyKnown(MAINHAND_IMBUES) then
                out[#out + 1] = { icon = SpellIcon(318038), text = "No imbue on your off hand" }
            end
        elseif offItem and not hasOff and AnyKnown(SHIELD_IMBUES) then
            out[#out + 1] = { icon = SpellIcon(SHIELD_IMBUES[1]), text = "No imbue on your shield" }
        end
    elseif class == "HUNTER" then
        if specID and PET_SPECS[specID] and not UnitExists("pet") and not Travelling() then
            out[#out + 1] = { icon = 132160, text = "No pet out" }
        end
    elseif class == "WARLOCK" then
        if not UnitExists("pet") and not HasAura(GRIMOIRE_OF_SACRIFICE) and not Travelling() then
            out[#out + 1] = { icon = 136082, text = "No demon out" }
        end
    end
end

local function InstanceReminders(out, kind)
    local _, class = UnitClass("player")

    local flask, flaskLeft = FindAura(function(n) return n:find("^Flask") or n:find("^Phial") end)
    if not flask then
        out[#out + 1] = { icon = 134827, text = "No flask" }
    elseif flaskLeft and flaskLeft > 0 and flaskLeft < EXPIRY_WARN then
        out[#out + 1] = { icon = 134827, text = flask .. ExpiryText(flaskLeft) }
    end

    local fed, fedLeft = FindAura(function(n) return n == "Well Fed" end)
    if not fed then
        out[#out + 1] = { icon = 133971, text = "Not Well Fed" }
    elseif fedLeft and fedLeft > 0 and fedLeft < EXPIRY_WARN then
        out[#out + 1] = { icon = 133971, text = "Well Fed" .. ExpiryText(fedLeft) }
    end

    -- An Enhancement Shaman's imbues live in the slot an oil would use,
    -- and the class check already covers them. Other specs oil like
    -- everyone else.
    local specIndex = GetSpecialization and GetSpecialization()
    local specID = specIndex and GetSpecializationInfo and GetSpecializationInfo(specIndex)
    if not (class == "SHAMAN" and specID == 263) then
        local hasMain, mainLeft = GetWeaponEnchantInfo()
        if not hasMain then
            out[#out + 1] = { icon = 463543, text = "No oil or stone on your weapon" }
        elseif type(mainLeft) == "number" and mainLeft > 0 and mainLeft / 1000 < EXPIRY_WARN then
            out[#out + 1] = { icon = 463543, text = "Weapon oil" .. ExpiryText(mainLeft / 1000) }
        end
    end
end

------------------------------------------------------------------------
-- Panel
------------------------------------------------------------------------

local WIDTH, LINE_H, PAD = 280, 22, 10

local function CreatePanel()
    local UI = UlRemedy.UI
    local f = CreateFrame("Frame", "UlRemedyRemindersFrame", UIParent, "BackdropTemplate")
    f:SetSize(WIDTH, LINE_H + 2 * PAD)
    UI.Backdrop(f, UI.BG, UI.BORDER)
    f:SetFrameStrata("MEDIUM")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetClampedToScreen(true)
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        UlRemedyDB.reminderPos = { point = point, relPoint = relPoint, x = x, y = y }
    end)
    local pos = UlRemedyDB.reminderPos
    if pos and pos.point then
        f:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x or 0, pos.y or 0)
    else
        f:SetPoint("TOP", UIParent, "TOP", 0, -140)
    end

    local accent = f:CreateTexture(nil, "ARTWORK")
    accent:SetTexture(UI.WHITE)
    accent:SetVertexColor(UI.ACCENT[1], UI.ACCENT[2], UI.ACCENT[3], 0.9)
    accent:SetWidth(3)
    accent:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
    accent:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 1, 1)

    f.title = UI.Text(f, "GameFontNormalSmall", UI.ACCENT_TEXT)
    f.title:SetPoint("TOPLEFT", f, "TOPLEFT", PAD + 4, -6)
    f.title:SetText(UlRemedy.name .. " reminders")
    f:Hide()
    return f
end

local function GetLine(i)
    local row = lines[i]
    if row then return row end
    local UI = UlRemedy.UI
    row = CreateFrame("Frame", nil, panel)
    row:SetHeight(LINE_H)
    row:SetPoint("LEFT", panel, "LEFT", PAD + 4, 0)
    row:SetPoint("RIGHT", panel, "RIGHT", -PAD, 0)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(16, 16)
    row.icon:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    row.text = UI.Text(row, "GameFontHighlight", UI.TEXT)
    row.text:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
    row.text:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    row.text:SetJustifyH("LEFT")
    row.text:SetWordWrap(false)
    lines[i] = row
    return row
end

local function Show(items)
    if not panel then panel = CreatePanel() end
    local top = 6 + 14 + 6
    for i, item in ipairs(items) do
        local row = GetLine(i)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD + 4, -(top + (i - 1) * LINE_H))
        row:SetPoint("RIGHT", panel, "RIGHT", -PAD, 0)
        row.icon:SetTexture(item.icon or 134400)
        row.text:SetText(item.text)
        row:Show()
    end
    for i = #items + 1, #lines do lines[i]:Hide() end
    panel:SetHeight(top + #items * LINE_H + PAD)
    panel:Show()
end

local function Hide()
    if panel then panel:Hide() end
end

------------------------------------------------------------------------
-- Checking
------------------------------------------------------------------------

local function Check()
    lastCheck = GetTime()
    if InCombatLockdown() or UnitIsDeadOrGhost("player") then
        Hide()
        return
    end
    local items = {}
    local kind = InstanceKind()
    if ClassOn() then pcall(ClassReminders, items) end
    if InstanceOn() and kind then pcall(InstanceReminders, items, kind) end
    if #items == 0 then
        Hide()
        lastSummary = nil
        return
    end
    Show(items)

    -- One chat line per instance visit, and again if the list changes.
    if kind then
        local texts = {}
        for _, item in ipairs(items) do texts[#texts + 1] = item.text end
        local summary = table.concat(texts, ", ")
        local instanceID = select(8, GetInstanceInfo())
        if summary ~= lastSummary or instanceID ~= announcedInstance then
            print(UlRemedy.name .. ": " .. summary .. ".")
            lastSummary = summary
            announcedInstance = instanceID
        end
    end
end

local function Schedule()
    if not (ClassOn() or InstanceOn()) then
        Hide()
        return
    end
    if pendingTimer then return end
    local wait = math.max(0, THROTTLE - (GetTime() - lastCheck))
    pendingTimer = C_Timer.NewTimer(wait, function()
        pendingTimer = nil
        Check()
    end)
end

function UlRemedy.RefreshReminders()
    Schedule()
end

function UlRemedy.RemindersReport()
    local items = {}
    local kind = InstanceKind()
    pcall(ClassReminders, items)
    if kind then pcall(InstanceReminders, items, kind) end
    print(UlRemedy.name .. ": reminders, class " .. (ClassOn() and "on" or "off")
        .. ", instance " .. (InstanceOn() and "on" or "off")
        .. ", here: " .. (kind or "not a mythic dungeon or raid") .. ".")
    if #items == 0 then
        print("  nothing missing right now")
    else
        for _, item in ipairs(items) do print("  " .. item.text) end
    end
end

------------------------------------------------------------------------
-- Events
------------------------------------------------------------------------

local frame = CreateFrame("Frame", "UlRemedyRemindersEvents")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
frame:RegisterEvent("PLAYER_ALIVE")
frame:RegisterEvent("PLAYER_UNGHOST")
frame:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
frame:RegisterEvent("UNIT_ENTERED_VEHICLE")
frame:RegisterEvent("UNIT_EXITED_VEHICLE")
frame:RegisterUnitEvent("UNIT_AURA", "player")
frame:RegisterUnitEvent("UNIT_PET", "player")
frame:RegisterUnitEvent("UNIT_INVENTORY_CHANGED", "player")
frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "PLAYER_REGEN_DISABLED" then
        Hide()
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" and arg1 ~= "player" then
        return
    else
        Schedule()
    end
end)

C_Timer.NewTicker(TICK, function()
    if ClassOn() or InstanceOn() then Check() end
end)
