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
}

-- Persistent data tables (not toggles) that the prune below must leave alone.
local DATA_KEYS = {
    seenCinematics = true,
    errors = true,
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

local FEATURES = {
    { key = "keylink",     label = "KeyLink" },
    { key = "repair",      label = "Auto Repair" },
    { key = "junk",        label = "Junk Seller" },
    { key = "warbank",     label = "Warband Auto Deposit" },
    { key = "groupinvite", label = "Group Invite" },
    { key = "trainer",     label = "Enhanced Trainer" },
    { key = "ilvl",        label = "Item Level Display" },
    { key = "quest",       label = "Auto Quest" },
    { key = "cinematic",   label = "Cinematic Skip" },
    { key = "gossip",      label = "Auto Gossip" },
    { key = "cursor",      label = "Cursor Ring" },
    { key = "companion",   label = "Auto Companion" },
    { key = "marker",      label = "Auto Marker" },
    { key = "markerfix",   label = "Correct Marker on Player" },
}

local function PrintHelp()
    print("|cffffcc00" .. UlRemedy.name .. "|r — commands:")
    for _, f in ipairs(FEATURES) do
        local state = UlRemedy.enabled[f.key] and "|cff00ff00on|r" or "|cffff4444off|r"
        print("  /ur " .. f.key .. " — " .. f.label .. " (" .. state .. ")")
    end
    print("  /ur errors — save this session's Lua errors, warnings and blocked actions to the saved variables, print the last five")
end

local function Toggle(key, label)
    UlRemedy.enabled[key] = not UlRemedy.enabled[key]
    local state = UlRemedy.enabled[key] and "|cff00ff00enabled|r" or "|cffff4444disabled|r"
    print(UlRemedy.name .. ": " .. label .. " " .. state .. ".")
    if UlRemedy.RefreshItemLevels then UlRemedy.RefreshItemLevels() end
    if UlRemedy.UpdateCursorRing then UlRemedy.UpdateCursorRing() end
end

SLASH_ULREMEDY1 = "/ur"
SLASH_ULREMEDY2 = "/ulremedy"
SlashCmdList["ULREMEDY"] = function(msg)
    local cmd = strtrim(msg):lower()
    if cmd == "errors" then
        local ok, err = pcall(UlRemedy.DumpErrors, true)
        if not ok then print(UlRemedy.name .. ": could not read the error list: " .. tostring(err)) end
        return
    end
    local matched = false
    for _, f in ipairs(FEATURES) do
        if cmd == f.key then
            Toggle(f.key, f.label)
            matched = true
            break
        end
    end
    if not matched then PrintHelp() end
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
