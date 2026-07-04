-- Auto Companion: summons a random favorite battle pet after loading screens
-- when none is out. Deliberately event-driven with no polling — dismissing
-- your pet manually should stick until the next loading screen, not be
-- fought two seconds later.
--
-- The delay gives the game's own cross-zone pet persistence a chance to act
-- first, so we don't summon over a pet that was about to reappear.

local DELAY = 5

local warnedNoFavorites = false

local function TrySummon()
    if not UlRemedy.enabled.companion then return end
    if InCombatLockdown() or UnitIsDeadOrGhost("player") or IsStealthed() then return end
    local _, instanceType = IsInInstance()
    if instanceType == "arena" or instanceType == "pvp" then return end
    if C_PetJournal.GetSummonedPetGUID() then return end
    if C_PetJournal.HasFavoritePets and not C_PetJournal.HasFavoritePets() then
        if not warnedNoFavorites then
            warnedNoFavorites = true
            print(UlRemedy.name .. ": Auto Companion needs at least one favorite pet — star one in the Pet Journal.")
        end
        return
    end
    C_PetJournal.SummonRandomPet(true)
end

local frame = CreateFrame("Frame", "UlRemedyCompanionFrame")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:SetScript("OnEvent", function()
    C_Timer.After(DELAY, TrySummon)
end)
