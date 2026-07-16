-- Auto Marker: keeps diamond on the tank and moon on the healer in 5-man
-- dungeon groups. Marks are set when the roster or roles change; DPS and
-- manually placed marks on other players are left alone.
--
-- The independent "markerfix" toggle guards the player's OWN mark: if
-- another addon or party member puts the wrong mark on you, it is corrected
-- to your role's mark. It works with the marker toggle off — it never
-- places a mark on an unmarked player then, only corrects a wrong one.

local ROLE_MARK = {
    TANK   = 3, -- diamond
    HEALER = 5, -- moon
}

local UNITS = { "player", "party1", "party2", "party3", "party4" }

local function InFiveManDungeon()
    if not IsInGroup() or IsInRaid() then return false end
    local _, instanceType = IsInInstance()
    return instanceType == "party"
end

local function MarkUnit(unit)
    local mark = ROLE_MARK[UnitGroupRolesAssigned(unit)]
    if mark and GetRaidTargetIndex(unit) ~= mark then
        SetRaidTarget(unit, mark)
    end
end

local function MarkGroup()
    for _, unit in ipairs(UNITS) do
        if UnitExists(unit) then
            MarkUnit(unit)
        end
    end
end

-- Throttled so a competing addon that instantly re-marks the player turns
-- into a slow once-per-second tug of war instead of an event storm.
local lastFix = 0
local function FixPlayerMark()
    if not UlRemedy.enabled.markerfix then return end
    local mark = ROLE_MARK[UnitGroupRolesAssigned("player")]
    if not mark then return end
    local current = GetRaidTargetIndex("player")
    if current == mark then return end
    -- Placing the initial mark is the marker toggle's job; on its own,
    -- markerfix only corrects a wrong mark someone else has set.
    if not current and not UlRemedy.enabled.marker then return end
    local now = GetTime()
    if now - lastFix < 1 then return end
    lastFix = now
    SetRaidTarget("player", mark)
end

local frame = CreateFrame("Frame", "UlRemedyMarkerFrame")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
frame:RegisterEvent("PLAYER_ROLES_ASSIGNED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("RAID_TARGET_UPDATE")

frame:SetScript("OnEvent", function(_, event)
    if not InFiveManDungeon() then return end
    if event == "RAID_TARGET_UPDATE" then
        FixPlayerMark()
    elseif UlRemedy.enabled.marker then
        MarkGroup()
    end
end)
