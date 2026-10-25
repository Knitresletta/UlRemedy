-- Auto Macro: six account macros that always use the best healing
-- potion, mana potion, flask, food, drink and bandage in your bags.
--
-- UR Heal, UR Mana, UR Flask, UR Food, UR Drink and UR Bandage are
-- created once in the General tab (shared by every character, rewritten
-- by whoever is logged in)
-- and then edited in place whenever the bags, talents or spec change
-- (out of combat), so they stay on your action bars. All but UR Heal are
-- "#showtooltip" plus "/use item:<id>", so the bar icon shows the item
-- and its count.
--
-- UR Heal is a chain: a castsequence that goes through the class's own
-- self-heals you know (shortest cooldown first), then a Healthstone when
-- you carry one, then the best healing potion, and starts over when
-- combat ends. One key, pressed again and again, works down the list. A
-- castsequence does not skip a step that is on cooldown, it waits on it,
-- so the chain can stall when its first step was used in the previous
-- fight; the reset on leaving combat and the short-cooldown-first order
-- keep that rare. Self-heals that only work out of combat (the Earthen
-- racial) get their own [nocombat] line above the chain. Lay on Hands
-- and other long cooldowns are left out on purpose: a panic key should
-- not burn them. A Warlock who knows Soulburn gets "/cast [combat]
-- Soulburn" above the chain when a Healthstone is in it, so the stone is
-- empowered by the same key press (it is off the global cooldown). With
-- the "stop casting" toggle on, the chain is preceded by /stopcasting.
--
-- UR Food prefers Well Fed food; without any, it eats what restores
-- health, conjured food first since it is free. UR Drink is the same for
-- mana: conjured water first, then the drink in the bags. UR Bandage uses
-- the best bandage.
--
-- "Best" comes from a ranked list of names per category, grouped in
-- tiers (current expansion first, older ones as fallbacks). Names rather
-- than item IDs because every crafting rank of a consumable has its own
-- ID; within one name the highest item level, that is the best rank,
-- wins, and within one tier the item you carry most of. A "Hearty"
-- version of a food outranks the plain one. Flasks of the same tier are
-- stat variants (haste, crit, mastery, versatility): which one is best
-- is your spec's call, so the tier is flat and the stack size decides.
-- Feasts are not food for this purpose, they are placed, not eaten.
--
-- Anything not on the list falls back to a guess from the item's
-- subclass (Potion, Flask, Food & Drink), its tooltip ("health", "mana",
-- "Well Fed") and item level. The list and the tooltip words are English;
-- on another client language only the guess works.
--
-- Reads the bags, item tooltips and the spellbook; writes account
-- macros through CreateMacro and EditMacro, which the client refuses in
-- combat, so a change during a fight waits for it to end. Nothing of
-- Blizzard's is hooked. /ur macrolist prints what each macro resolved to
-- and why.

local DEBOUNCE = 1.5          -- seconds after the last bag change
local LOGIN_DELAY = 4         -- let the item cache fill after login

local MACROS = {
    { key = "heal",  name = "UR Heal",  label = "healing potion" },
    { key = "mana",  name = "UR Mana",  label = "mana potion" },
    { key = "flask", name = "UR Flask", label = "flask" },
    { key = "food",    name = "UR Food",    label = "food" },
    { key = "drink",   name = "UR Drink",   label = "drink" },
    { key = "bandage", name = "UR Bandage", label = "bandage" },
}

local SOULBURN = 385899            -- Warlock talent, empowers the next Healthstone

-- Tiers, best first. Within a tier: best rank (item level), then count.
local LISTS = {
    heal = {
        -- Fleeting potions expire, so they go before the lasting ones.
        { "Fleeting Silvermoon Health Potion" },
        { "Concentrated Silvermoon Health Potion" },
        { "Silvermoon Health Potion", "Midnight Healing Potion" },
        { "Potent Healing Potion", "Ornate Healing Potion" },
        { "Refreshing Serum" },
        { "Amani Extract" },
        { "Fleeting Invigorating Healing Potion" },
        { "Invigorating Healing Potion" },
        { "Fleeting Algari Healing Potion" },
        { "Algari Healing Potion" },
        { "Dreamwalker's Healing Potion" },
        { "Refreshing Healing Potion" },
        { "Healing Potion" },
    },
    -- Potions that must be channelled or leave you defenceless (Potion of
    -- Devoured Dreams and the like) are not mana potions for a key press.
    mana = {
        { "Fleeting Lightfused Mana Potion" },
        { "Lightfused Mana Potion" },
        { "Refreshing Serum" },
        { "Fleeting Algari Mana Potion" },
        { "Algari Mana Potion" },
        { "Slumbering Soul Serum" },
        { "Aerated Mana Potion" },
    },
    flask = {
        { "Flask of the Blood Knights", "Flask of the Shattered Sun", "Flask of the Magisters", "Flask of Thalassian Resistance" },
        { "Vicious Thalassian Flask of Honor" },
        { "Flask of Alchemical Chaos", "Flask of Tempered Swiftness", "Flask of Tempered Aggression", "Flask of Tempered Mastery", "Flask of Tempered Versatility", "Flask of Saving Graces" },
        { "Vicious Flask of Honor" },
        { "Iced Phial of Corrupting Rage", "Phial of Elemental Chaos", "Phial of Static Empowerment", "Phial of Tepid Versatility", "Phial of Charged Isolation", "Phial of Glacial Fury" },
    },
    food = {
        { "Venom-Spiced Cutlets", "Puffer Plate", "Sweet-and-Sour Skewers" },
        { "Champion's Bento", "Flora Frenzy", "Impossibly Royal Roast", "Royal Roast" },
        { "Arcano Cutlets", "Sun-Seared Lumifin", "Tasty Smoked Tetra", "Crimson Calamari", "Fel-Kissed Filet", "Null and Void Plate",
          "Glitter Skewers", "Warped Wise Wings", "Braised Blood Hunter", "Buttered Root Crab", "Void-Kissed Fish Rolls",
          "Twilight Angler's Medley", "Spellfire Filet", "Mana-Infused Stew", "Bloom Skewers" },
        { "Sunwell Delight", "Hearthflame Supper", "Fried Bloomtail", "Felberry Figs", "Eversong Pudding", "Bloodthistle-Wrapped Cutlets",
          "Wise Tails", "Spiced Biscuits", "Silvermoon Standard", "Quick Sandwich", "Portable Snack", "Forager's Medley", "Farstrider Rations" },
        { "Beledar's Bounty", "Chippy Tea", "Deepfin Patty", "Sweet and Sour Meat Slaw", "Feast of the Divine Day", "Feast of the Midnight Masquerade",
          "Mycobloom Risotto", "Zesty Nibblers", "Sizzling Honey Roast", "Ginger Glazed Fillet", "Salt-Baked Seafood", "Hearty Cuts" },
        -- No buff food: eat to live. Conjured food is free, so it comes first.
        { "Conjured Mana Bun", "Conjured Souffle", "Conjured Cinnamon Roll", "Conjured Croissant" },
    },
    drink = {
        { "Conjured Tea", "Conjured Mana Bun" },
        { "Mana Lily Tea", "Tranquility Bloom Tea" },
    },
    bandage = {},
}

-- name -> tier number, per category.
local RANK = {}
for key, tiers in pairs(LISTS) do
    RANK[key] = {}
    for tier, names in ipairs(tiers) do
        for _, name in ipairs(names) do RANK[key][name] = tier end
    end
end

-- Self-heals worth a place in the UR Heal chain, checked against the
-- spellbook at build time so only the ones this character knows are
-- used; an ID the client no longer has simply never matches. Spell IDs
-- are facts about the game, not borrowed code. nocombat marks spells the
-- game only allows out of combat.
local SELF_HEALS = {
    { id = 109304,  note = "Exhilaration (Hunter)" },
    { id = 185311,  note = "Crimson Vial (Rogue)" },
    { id = 19236,   note = "Desperate Prayer (Priest)" },
    { id = 322101,  note = "Expel Harm (Monk)" },
    { id = 122281,  note = "Healing Elixir (Monk)" },
    { id = 108416,  note = "Dark Pact (Warlock)" },
    { id = 48743,   note = "Death Pact (Death Knight)" },
    { id = 55233,   note = "Vampiric Blood (Death Knight)" },
    { id = 12975,   note = "Last Stand (Warrior)" },
    -- Gift of the Naaru has one spell ID per class.
    { id = 28880,   note = "Gift of the Naaru" },
    { id = 59542,   note = "Gift of the Naaru" },
    { id = 59543,   note = "Gift of the Naaru" },
    { id = 59544,   note = "Gift of the Naaru" },
    { id = 59545,   note = "Gift of the Naaru" },
    { id = 59547,   note = "Gift of the Naaru" },
    { id = 59548,   note = "Gift of the Naaru" },
    { id = 121093,  note = "Gift of the Naaru" },
    { id = 370626,  note = "Gift of the Naaru" },
    { id = 416250,  note = "Gift of the Naaru" },
    { id = 461063,  note = "Quiet Contemplation (Earthen)", nocombat = true },
}

-- Healthstones, in the order they go into the chain.
local HEALTHSTONES = { 5512, 224464 }

local MACRO_LIMIT = 255        -- characters in a standard macro body

-- Consumable subclasses, for the fallback guess.
local CLASS_CONSUMABLE = 0
local SUB_POTION, SUB_FLASK, SUB_FOOD, SUB_BANDAGE = 1, 3, 5, 7

local pending = false         -- a scan is wanted (debounce or combat)
local timer
local lastReport = {}         -- key -> { item, name, why }
local fullWarned = false

local function Enabled()
    return UlRemedy.enabled and UlRemedy.enabled.macros
end

------------------------------------------------------------------------
-- Looking at the bags
------------------------------------------------------------------------

local function TooltipText(bag, slot)
    if not (C_TooltipInfo and C_TooltipInfo.GetBagItem) then return "" end
    local ok, data = pcall(C_TooltipInfo.GetBagItem, bag, slot)
    if not ok or type(data) ~= "table" or type(data.lines) ~= "table" then return "" end
    local parts = {}
    for _, line in ipairs(data.lines) do
        local t = line.leftText
        if type(t) == "string" and not (issecretvalue and issecretvalue(t)) then parts[#parts + 1] = t end
    end
    return table.concat(parts, "\n")
end

-- Which category an unlisted item would belong to, from subclass and
-- tooltip, or nil when it is none of the four.
local tooltipCache = {}      -- "bag:slot" -> lowered tooltip text, per scan

local function Guess(itemID, bag, slot)
    local _, _, _, _, _, classID, subID = C_Item.GetItemInfoInstant(itemID)
    if classID ~= CLASS_CONSUMABLE then return nil end
    local key = bag .. ":" .. slot
    local text = tooltipCache[key]
    if not text then
        text = TooltipText(bag, slot):lower()
        tooltipCache[key] = text
    end
    if subID == SUB_POTION then
        local health = text:find("health", 1, true) and text:find("restores", 1, true)
        local mana = text:find("mana", 1, true) and text:find("restores", 1, true)
        if health then return "heal" end
        if mana then return "mana" end
    elseif subID == SUB_FLASK then
        if text:find("flask", 1, true) and not text:find("finesse", 1, true) and not text:find("deftness", 1, true) then
            return "flask"
        end
    elseif subID == SUB_FOOD then
        if text:find("feast", 1, true) then return nil end
        if text:find("well fed", 1, true) then return "food", 1 end
        -- Plain food and drink: which one it is depends on what it restores.
        local health = text:find("health", 1, true)
        local mana = text:find("mana", 1, true)
        if health then return "food", 2 end
        if mana then return "drink", 2 end
    elseif subID == SUB_BANDAGE then
        return "bandage"
    end
    return nil
end

local function Bags()
    local list = { 0 }
    for i = 1, (NUM_BAG_SLOTS or 4) + (NUM_REAGENTBAG_SLOTS or 0) do list[#list + 1] = i end
    return list
end

-- One candidate per category: the best thing in the bags, with the
-- reason, or nil. Returns candidates and whether any item was still
-- uncached (then a rescan is worth doing once the data arrives).
local function Scan()
    local best = {}
    local uncached = false
    wipe(tooltipCache)
    for _, bag in ipairs(Bags()) do
        local n = C_Container.GetContainerNumSlots(bag) or 0
        for slot = 1, n do
            local ok, info = pcall(C_Container.GetContainerItemInfo, bag, slot)
            if ok and type(info) == "table" and info.itemID then
                local itemID = info.itemID
                local name, _, _, ilvl = C_Item.GetItemInfo(itemID)
                if not name then
                    uncached = true
                    if C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(itemID) end
                else
                    local count = tonumber(info.stackCount) or 1
                    local base = name:gsub("^Hearty ", "")
                    local hearty = base ~= name
                    for _, m in ipairs(MACROS) do
                        local tier = RANK[m.key][base]
                        local why
                        if tier then
                            why = "list tier " .. tier
                        else
                            local kind, extra = Guess(itemID, bag, slot)
                            if kind == m.key then
                                tier = #LISTS[m.key] + (extra or 1)
                                why = "guess from tooltip"
                            end
                        end
                        if tier then
                            -- Lower is better for tier; higher for the rest.
                            local score = { tier = tier, hearty = hearty and 1 or 0, ilvl = ilvl or 0, count = count }
                            local cur = best[m.key]
                            local better = not cur
                                or score.tier < cur.tier
                                or (score.tier == cur.tier and score.hearty > cur.hearty)
                                or (score.tier == cur.tier and score.hearty == cur.hearty and score.ilvl > cur.ilvl)
                                or (score.tier == cur.tier and score.hearty == cur.hearty and score.ilvl == cur.ilvl and score.count > cur.count)
                            if better then
                                score.itemID = itemID
                                score.name = name
                                score.link = info.hyperlink
                                score.why = why
                                best[m.key] = score
                            end
                        end
                    end
                end
            end
        end
    end
    return best, uncached
end

------------------------------------------------------------------------
-- The heal chain
------------------------------------------------------------------------

local function SpellKnown(id)
    if C_SpellBook and C_SpellBook.IsSpellInSpellBook and Enum and Enum.SpellBookSpellBank then
        local ok, known = pcall(C_SpellBook.IsSpellInSpellBook, id, Enum.SpellBookSpellBank.Player, false)
        return ok and known or false
    end
    if IsSpellKnownOrOverridesKnown then return IsSpellKnownOrOverridesKnown(id) end
    return false
end

local function SpellName(id)
    if C_Spell and C_Spell.GetSpellName then return C_Spell.GetSpellName(id) end
    return nil
end

local function SpellCooldown(id)
    if type(GetSpellBaseCooldown) ~= "function" then return 0 end
    local ok, ms = pcall(GetSpellBaseCooldown, id)
    return ok and tonumber(ms) and ms / 1000 or 0
end

-- The spells this character can use in the chain: in-combat ones sorted
-- by cooldown, shortest first, and the out-of-combat ones separately.
local function KnownSelfHeals()
    local combat, outside = {}, {}
    for _, spell in ipairs(SELF_HEALS) do
        if SpellKnown(spell.id) then
            local name = SpellName(spell.id)
            if name then
                local rec = { id = spell.id, name = name, cd = SpellCooldown(spell.id), note = spell.note }
                if spell.nocombat then outside[#outside + 1] = rec else combat[#combat + 1] = rec end
            end
        end
    end
    table.sort(combat, function(a, b)
        if a.cd ~= b.cd then return a.cd < b.cd end
        return a.name < b.name
    end)
    return combat, outside
end

local function HealthstonesInBags()
    local list = {}
    for _, id in ipairs(HEALTHSTONES) do
        local ok, n = pcall(C_Item.GetItemCount, id, false, false)
        if ok and tonumber(n) and n > 0 then list[#list + 1] = id end
    end
    return list
end

-- Builds the UR Heal body and a description of the chain for the report.
-- Spells are dropped from the end of the chain if the body would pass
-- the macro length limit; the Healthstone and the potion always stay.
local function HealBody(potionID)
    local spells, outside = KnownSelfHeals()
    local stones = HealthstonesInBags()
    local function Build(nSpells)
        local steps = {}
        for i = 1, nSpells do steps[#steps + 1] = spells[i].name end
        for _, id in ipairs(stones) do steps[#steps + 1] = "item:" .. id end
        if potionID then steps[#steps + 1] = "item:" .. potionID end
        local lines = { "#showtooltip" }
        if UlRemedy.enabled and UlRemedy.enabled.macrostopcast then
            lines[#lines + 1] = "/stopcasting"
        end
        local condition = "@player"
        if outside[1] then
            lines[#lines + 1] = "/cast [nocombat] " .. outside[1].name
            condition = "@player,combat"
        end
        -- Soulburn is off the global cooldown, so it lands in the same
        -- press as the Healthstone step it empowers. Without a Soul Shard
        -- the line simply fails and the chain goes on.
        if #stones > 0 and SpellKnown(SOULBURN) and SpellName(SOULBURN) then
            lines[#lines + 1] = "/cast [combat] " .. SpellName(SOULBURN)
        end
        if #steps == 0 then
            lines[#lines + 1] = "/run print(\"UlRemedy: no self-heal, Healthstone or healing potion available.\")"
        else
            lines[#lines + 1] = "/castsequence [" .. condition .. "] reset=combat " .. table.concat(steps, ", ")
        end
        return table.concat(lines, "\n"), steps
    end
    local body, steps
    for n = #spells, 0, -1 do
        body, steps = Build(n)
        if #body <= MACRO_LIMIT then break end
    end
    return body, steps, outside[1]
end

------------------------------------------------------------------------
-- Writing the macros
------------------------------------------------------------------------

local function Body(m, itemID)
    if m.key == "heal" then
        local body, steps, outside = HealBody(itemID)
        return body, steps, outside
    end
    if itemID then
        return "#showtooltip item:" .. itemID .. "\n/use [@player] item:" .. itemID
    end
    return "#showtooltip\n/run print(\"UlRemedy: nothing suitable in your bags for this macro.\")"
end

local function AccountMax()
    local consts = Constants and Constants.MacroConsts
    return (consts and consts.MAX_ACCOUNT_MACROS) or MAX_ACCOUNT_MACROS or 120
end

-- Returns "created", "updated", "same", or an error string, plus the
-- chain steps and the out-of-combat spell for the heal macro.
local function WriteMacro(m, itemID)
    local body, steps, outside = Body(m, itemID)
    local index = GetMacroIndexByName(m.name)
    -- Macros are indexed account ones first, then the character's own.
    -- A character macro with our name is left over from the first version
    -- of this module; it goes, and the account one takes its place.
    if index and index > AccountMax() then
        pcall(DeleteMacro, index)
        print(UlRemedy.name .. ": " .. m.name .. " moved from character to account macros; drag it to your bar again.")
        index = GetMacroIndexByName(m.name)
    end
    if index and index > 0 then
        local _, _, current = GetMacroInfo(index)
        if current == body then return "same", steps, outside end
        local ok, err = pcall(EditMacro, index, m.name, "INV_Misc_QuestionMark", body)
        return ok and "updated" or ("edit failed: " .. tostring(err)), steps, outside
    end
    local account = GetNumMacros()
    if account and account >= AccountMax() then
        return "no room: the account macro list is full", steps, outside
    end
    local ok, err = pcall(CreateMacro, m.name, "INV_Misc_QuestionMark", body, false)
    return ok and "created" or ("create failed: " .. tostring(err)), steps, outside
end

local function Apply()
    pending = false
    if not Enabled() then return end
    if InCombatLockdown() then
        pending = true
        return
    end
    local best, uncached = Scan()
    UlRemedyDB.macroTargets = UlRemedyDB.macroTargets or {}
    for _, m in ipairs(MACROS) do
        local pick = best[m.key]
        local itemID = pick and pick.itemID
        local result, steps, outside = WriteMacro(m, itemID)
        lastReport[m.key] = { pick = pick, result = result, steps = steps, outside = outside }
        if result == "created" or result == "updated" then
            local prev = UlRemedyDB.macroTargets[m.key]
            local signature = steps and table.concat(steps, ",") or tostring(itemID)
            if signature ~= prev then
                if steps then
                    print(UlRemedy.name .. ": " .. m.name .. " chain is now " .. (#steps > 0 and table.concat(steps, " > ") or "empty"))
                else
                    print(UlRemedy.name .. ": " .. m.name .. " now uses " .. (pick and (pick.link or pick.name) or "nothing (no " .. m.label .. " in bags)"))
                end
            end
            UlRemedyDB.macroTargets[m.key] = signature
        elseif result:find("no room", 1, true) then
            if not fullWarned then
                print(UlRemedy.name .. ": cannot create " .. m.name .. ", the account macro list is full (" .. AccountMax() .. ").")
                fullWarned = true
            end
        elseif result ~= "same" then
            print(UlRemedy.name .. ": " .. m.name .. " " .. result)
        end
    end
    if uncached then
        -- Item data is on its way; look again shortly.
        C_Timer.After(3, function() if not pending then Apply() end end)
    end
end

local function Schedule()
    if not Enabled() then return end
    pending = true
    if timer then timer:Cancel() end
    timer = C_Timer.NewTimer(DEBOUNCE, function()
        timer = nil
        if pending then Apply() end
    end)
end

------------------------------------------------------------------------
-- Commands
------------------------------------------------------------------------

function UlRemedy.MacroReport()
    if not Enabled() then
        print(UlRemedy.name .. ": Auto Macro is off. /ur macros turns it on.")
        return
    end
    print(UlRemedy.name .. ": auto macros (account macros, edited out of combat when the bags change):")
    for _, m in ipairs(MACROS) do
        local r = lastReport[m.key]
        if not r then
            print("  " .. m.name .. ": not written yet")
        elseif r.steps then
            print(string.format("  %s: %s (%s)", m.name, #r.steps > 0 and table.concat(r.steps, " > ") or "empty", r.result))
            if r.outside then print("    out of combat first: " .. r.outside.name) end
            if r.pick then print(string.format("    potion: %s x%d, ilvl %d, %s", r.pick.link or r.pick.name, r.pick.count, r.pick.ilvl, r.pick.why)) end
        elseif r.pick then
            print(string.format("  %s: %s x%d, ilvl %d, %s (%s)", m.name, r.pick.link or r.pick.name, r.pick.count, r.pick.ilvl, r.pick.why, r.result))
        else
            print("  " .. m.name .. ": no " .. m.label .. " in bags (" .. r.result .. ")")
        end
    end
    if pending then print("  a rescan is waiting" .. (InCombatLockdown() and " for combat to end" or "")) end
end

-- Core calls this when the feature is toggled.
function UlRemedy.RefreshAutoMacro()
    if Enabled() then Schedule() end
end

------------------------------------------------------------------------
-- Events
------------------------------------------------------------------------

local frame = CreateFrame("Frame", "UlRemedyAutoMacroFrame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("BAG_UPDATE_DELAYED")
frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
-- Talent changes teach and forget self-heals; the event only exists on
-- clients that have talent trees.
if C_EventUtils and C_EventUtils.IsEventValid and C_EventUtils.IsEventValid("TRAIT_CONFIG_UPDATED") then
    frame:RegisterEvent("TRAIT_CONFIG_UPDATED")
end
frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "PLAYER_LOGIN" then
        C_Timer.After(LOGIN_DELAY, Schedule)
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        if arg1 == "player" then Schedule() end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if pending then Schedule() end
    else
        Schedule()
    end
end)
