UlRemedy = { name = "UlRemedy", enabled = {} }

local DEFAULTS = {
    keylink     = true,
    repair      = true,
    junk        = true,
    warbank     = false,
    groupinvite = true,
    trainer     = true,
    ilvl        = true,
    quest       = true,
    cinematic   = true,
    gossip      = true,
    cursor      = true,
    companion   = true,
    marker      = false,
    markerfix   = false,
    chatcopy    = true,
    playtime    = true,
    macros      = true,
    macrostopcast = false,
    inventory   = true,
    inventorytooltip = true,
}

-- Persistent data tables (not toggles) that the prune below must leave alone.
local DATA_KEYS = {
    seenCinematics = true,
    errors = true,
    macroTargets = true,
}

local function InitDB()
    if not UlRemedyDB then UlRemedyDB = {} end
    for k, v in pairs(DEFAULTS) do
        if UlRemedyDB[k] == nil then UlRemedyDB[k] = v end
    end
    for k in pairs(UlRemedyDB) do
        if DEFAULTS[k] == nil and not DATA_KEYS[k] then UlRemedyDB[k] = nil end
    end
    UlRemedy.enabled = UlRemedyDB
end

function UlRemedy.Version()
    local v = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(UlRemedy.name, "Version")
    return v or "?"
end

------------------------------------------------------------------------
-- Lua error log
------------------------------------------------------------------------
-- The client keeps every Lua error and warning of the session in
-- ScriptErrorsFrame.errorData (message, count, time, stack, locals; see
-- Blizzard_ScriptErrorsFrame.lua), whether or not the scriptErrors CVar
-- shows them, and forgets them on reload. Warnings such as "exceeded
-- execution limit" never pass through the error handler, so reading that
-- table is the only way to see everything. It is copied into the saved
-- variables at logout and reload, and on /ur errors, so the log can be
-- read from WTF/.../SavedVariables/UlRemedy.lua afterwards. Strings that
-- are secret values are replaced with a marker rather than touched.
local MAX_LOGGED_ERRORS = 40

local function PlainString(v)
    if v == nil then return nil end
    if issecretvalue and issecretvalue(v) then return "<secret>" end
    if type(v) ~= "string" then return tostring(v) end
    return v
end

local function Clip(text, n)
    text = PlainString(text)
    if not text then return nil end
    text = text:gsub("Interface[/\\]AddOns[/\\]", "")
    if #text > n then text = text:sub(1, n) .. "..." end
    return text
end

-- Blocked actions are a separate thing from Lua errors: the client refuses
-- a protected call made from tainted code, fires ADDON_ACTION_BLOCKED (or
-- _FORBIDDEN) with the addon and function name, and the AddOns list shows
-- an alert icon with the count. Nothing reaches the error frame. Keep a
-- count per function and the stack of the first time each was seen; the
-- event fires inside the refused call, so the stack names our call site.
local blocked = {}        -- functionName -> { count, kind, stack, last }

local function NoteBlocked(kind, addonName, functionName)
    if addonName ~= UlRemedy.name then return end
    local key = tostring(functionName or "?")
    local rec = blocked[key]
    if not rec then
        rec = { count = 0, kind = kind, stack = Clip(debugstack(3, 12, 0), 1200) }
        blocked[key] = rec
    end
    rec.count = rec.count + 1
    rec.last = date("%H:%M:%S")
end

function UlRemedy.DumpErrors(announce)
    local frameData = ScriptErrorsFrame and ScriptErrorsFrame.errorData
    local list = {}
    if type(frameData) == "table" then
        local n = #frameData
        for i = math.max(1, n - MAX_LOGGED_ERRORS + 1), n do
            local e = frameData[i]
            local ok, rec = pcall(function()
                return {
                    kind = e.messageType == 1 and "warning" or "error",
                    count = tonumber(PlainString(e.count)) or 0,
                    time = PlainString(e.time),
                    message = Clip(e.message, 400),
                    stack = Clip(e.stack, 1200),
                }
            end)
            list[#list + 1] = ok and rec or { kind = "unreadable", message = tostring(rec) }
        end
    end
    local blockedList, blockedTotal = {}, 0
    for fn, rec in pairs(blocked) do
        blockedList[#blockedList + 1] = { func = fn, count = rec.count, kind = rec.kind, last = rec.last, stack = rec.stack }
        blockedTotal = blockedTotal + rec.count
    end
    table.sort(blockedList, function(a, b) return a.count > b.count end)
    UlRemedyDB.errors = {
        at = date("%Y-%m-%d %H:%M:%S"),
        version = UlRemedy.Version(),
        total = type(frameData) == "table" and #frameData or 0,
        blocked = blockedList,
        blockedTotal = blockedTotal,
        -- Tells a missing frame apart from a clean session.
        source = ScriptErrorsFrame and (type(frameData) == "table" and "ScriptErrorsFrame.errorData" or "frame without errorData") or "no ScriptErrorsFrame",
        list = list,
    }
    if announce then
        print(UlRemedy.name .. ": saved " .. #list .. " of " .. UlRemedyDB.errors.total
            .. " Lua errors and warnings from this session (" .. UlRemedyDB.errors.source
            .. ") to the saved variables, written on reload or logout.")
        for i = math.max(1, #list - 4), #list do
            local e = list[i]
            print("  " .. (e.count or 0) .. "x " .. (e.kind or "?") .. ": " .. (e.message or "?"))
        end
        print("  blocked actions this session: " .. blockedTotal .. (blockedTotal > 0 and ":" or "."))
        for i = 1, math.min(5, #blockedList) do
            local b = blockedList[i]
            print("    " .. b.count .. "x " .. b.func .. " (" .. b.kind .. ", last " .. (b.last or "?") .. ")")
        end
    end
end

function UlRemedy.MoneyText(amount)
    if C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString then
        return C_CurrencyInfo.GetCoinTextureString(amount)
    end
    return tostring(amount) .. " copper"
end

-- Every toggleable feature. Options.lua draws one checkbox per entry;
-- /ur <key> toggles it from chat. desc is the one-line explanation shown
-- next to the checkbox and in /ur help.
local FEATURES = {
    { key = "repair",      group = "Vendor",    label = "Auto Repair",              desc = "Repairs your gear at vendors, guild funds first when they cover it." },
    { key = "junk",        group = "Vendor",    label = "Junk Seller",              desc = "Sells all grey items when a vendor opens." },
    { key = "warbank",     group = "Vendor",    label = "Warband Auto Deposit",     desc = "Deposits warbound items when the Warband Bank opens. Off by default." },
    { key = "keylink",     group = "Group",     label = "KeyLink",                  desc = "Links your Mythic Keystone when anyone types !key or !keys." },
    { key = "groupinvite", group = "Group",     label = "Group Invite",             desc = "Auto-accepts group invites from friends and guildmates." },
    { key = "marker",      group = "Group",     label = "Auto Marker",              desc = "Diamond on the tank, moon on the healer in 5-man groups. Off by default." },
    { key = "markerfix",   group = "Group",     label = "Correct Marker on Player", desc = "Fixes your own mark if someone sets the wrong one on you." },
    { key = "quest",       group = "Quests",    label = "Auto Quest",               desc = "Accepts quests and hands them in. Reward choices are left to you." },
    { key = "gossip",      group = "Quests",    label = "Auto Gossip",              desc = "Clicks through single-option NPC dialogs, never vendors or taxis." },
    { key = "cinematic",   group = "Quests",    label = "Cinematic Skip",           desc = "Skips movies and cutscenes any of your characters has seen." },
    { key = "trainer",     group = "Interface", label = "Enhanced Trainer",         desc = "Adds a Train All button to profession trainers." },
    { key = "ilvl",        group = "Interface", label = "Item Level Display",       desc = "Shows item level on equippable gear in bags and bank." },
    { key = "cursor",      group = "Interface", label = "Cursor Ring",              desc = "A purple ring that follows your mouse cursor." },
    { key = "companion",   group = "Interface", label = "Auto Companion",           desc = "Summons a random favorite battle pet after loading screens." },
    { key = "chatcopy",    group = "Interface", label = "Chat Copy",                desc = "A Copy button above the chat opens the log in a window the text can be copied from." },
    { key = "playtime",    group = "Interface", label = "Playtime",                 desc = "Remembers /played for every character. /ur played shows a bar per class, characters on hover." },
    { key = "macros",      group = "Vendor",    label = "Auto Macro",               desc = "UR Heal chains your self-heals, Healthstone and best potion; UR Mana, Flask, Food, Drink and Bandage use the best in your bags." },
    { key = "macrostopcast", group = "Vendor",  label = "UR Heal Stops Casting",    desc = "Puts /stopcasting first in UR Heal, so a caster's heal is not delayed by the spell in progress. Off by default." },
    { key = "inventory",   group = "Items",     label = "Inventory",                desc = "Remembers gold, bags and bank for all your characters. /ur inv opens the browser." },
    { key = "inventorytooltip", group = "Items", label = "Inventory in Tooltips",  desc = "Item tooltips list which characters have the item, where, and the total." },
}
UlRemedy.FEATURE_GROUPS = { "Vendor", "Group", "Quests", "Interface", "Items" }
UlRemedy.FEATURES = FEATURES

local function PrintHelp()
    print("|cffffcc00" .. UlRemedy.name .. "|r: /ur opens the options window. Chat commands:")
    for _, f in ipairs(FEATURES) do
        local state = UlRemedy.enabled[f.key] and "|cff00ff00on|r" or "|cffff4444off|r"
        print("  /ur " .. f.key .. ": " .. f.label .. " (" .. state .. "): " .. f.desc)
    end
    print("  /ur chat: open the chat log in a window the text can be copied from")
    print("  /ur played: open the playtime window (a bar per class, characters on hover, total across them)")
    print("  /ur pt: print playtime diagnostics")
    print("  /ur inv: open the inventory browser (all characters, gold and items)")
    print("  /ur macrolist: print what the six UR macros use right now, and why")
    print("  /ur errors: save this session's Lua errors, warnings and blocked actions to the saved variables, print the last five")
    print("  /ur help: this list")
end

-- Modules that need a nudge when a feature changes state.
local function NotifyModules()
    if UlRemedy.RefreshItemLevels then UlRemedy.RefreshItemLevels() end
    if UlRemedy.UpdateCursorRing then UlRemedy.UpdateCursorRing() end
    if UlRemedy.RefreshChatCopy then UlRemedy.RefreshChatCopy() end
    if UlRemedy.RefreshPlaytime then UlRemedy.RefreshPlaytime() end
    if UlRemedy.RefreshAutoMacro then UlRemedy.RefreshAutoMacro() end
    if UlRemedy.RescanInventory then UlRemedy.RescanInventory() end
    if UlRemedy.RefreshOptions then UlRemedy.RefreshOptions() end
end

-- Shared by the chat command and the options window, so modules are
-- notified the same way whichever route is used.
function UlRemedy.SetFeature(key, enabled)
    local feature
    for _, f in ipairs(FEATURES) do
        if f.key == key then feature = f end
    end
    if not feature then return end
    UlRemedy.enabled[key] = enabled and true or false
    local state = UlRemedy.enabled[key] and "|cff00ff00enabled|r" or "|cffff4444disabled|r"
    print(UlRemedy.name .. ": " .. feature.label .. " " .. state .. ".")
    NotifyModules()
end

SLASH_ULREMEDY1 = "/ur"
SLASH_ULREMEDY2 = "/ulremedy"
SlashCmdList["ULREMEDY"] = function(msg)
    local cmd = strtrim(msg):lower()
    if cmd == "" then
        if UlRemedy.ToggleOptions then UlRemedy.ToggleOptions() else PrintHelp() end
        return
    end
    if cmd == "help" then
        PrintHelp()
        return
    end
    if cmd == "chat" then
        if UlRemedy.ToggleChatCopy then UlRemedy.ToggleChatCopy() end
        return
    end
    if cmd == "played" then
        if UlRemedy.TogglePlaytimeWindow then UlRemedy.TogglePlaytimeWindow() end
        return
    end
    if cmd == "pt" then
        if UlRemedy.PlaytimeDebug then UlRemedy.PlaytimeDebug() end
        return
    end
    if cmd == "inv" or cmd == "bags" then
        if UlRemedy.ToggleInventoryWindow then UlRemedy.ToggleInventoryWindow() end
        return
    end
    if cmd == "macrolist" then
        if UlRemedy.MacroReport then UlRemedy.MacroReport() end
        return
    end
    if cmd == "errors" then
        local ok, err = pcall(UlRemedy.DumpErrors, true)
        if not ok then print(UlRemedy.name .. ": could not read the error list: " .. tostring(err)) end
        return
    end
    for _, f in ipairs(FEATURES) do
        if cmd == f.key then
            UlRemedy.SetFeature(f.key, not UlRemedy.enabled[f.key])
            return
        end
    end
    PrintHelp()
end

local frame = CreateFrame("Frame", "UlRemedyCoreFrame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_LOGOUT")
frame:RegisterEvent("ADDON_ACTION_BLOCKED")
frame:RegisterEvent("ADDON_ACTION_FORBIDDEN")

frame:SetScript("OnEvent", function(self, event, arg1, arg2)
    if event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
        pcall(NoteBlocked, event == "ADDON_ACTION_BLOCKED" and "blocked" or "forbidden", arg1, arg2)
        return
    end
    if event == "ADDON_LOADED" and arg1 == UlRemedy.name then
        InitDB()
        self:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_LOGOUT" then
        -- Also fires on /reload: the error list is about to be lost.
        pcall(UlRemedy.DumpErrors, false)
    elseif event == "PLAYER_LOGIN" then
        print(UlRemedy.name .. " " .. UlRemedy.Version() .. " loaded. Type |cffffcc00/ur|r to see commands.")
        self:UnregisterEvent("PLAYER_LOGIN")
    end
end)
