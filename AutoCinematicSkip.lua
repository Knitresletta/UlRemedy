-- Auto Cinematic Skip: skips movies and in-game cutscenes you have already
-- seen on any character (UlRemedyDB is account-wide). Hold Shift as one starts
-- to watch it again.
--
-- Pre-rendered movies (PLAY_MOVIE) carry a reliable movie ID. In-game
-- cutscenes (CINEMATIC_START) have no ID, so they are keyed by zone + subzone
-- — best effort, but distinct cutscenes rarely share a spot.

local function GetDB()
    UlRemedyDB.seenCinematics = UlRemedyDB.seenCinematics or {}
    local db = UlRemedyDB.seenCinematics
    db.movies = db.movies or {}
    db.scenes = db.scenes or {}
    return db
end

local function SceneKey()
    return (GetRealZoneText() or "?") .. ":" .. (GetSubZoneText() or "")
end

local function AnnounceSkip()
    print(UlRemedy.name .. ": Skipped a cinematic you've already seen (hold Shift to watch again).")
end

local frame = CreateFrame("Frame", "UlRemedyCinematicFrame")
frame:RegisterEvent("PLAY_MOVIE")
frame:RegisterEvent("CINEMATIC_START")

frame:SetScript("OnEvent", function(_, event, movieID)
    if not UlRemedy.enabled.cinematic then return end
    local db = GetDB()

    if event == "PLAY_MOVIE" then
        local seen = db.movies[movieID]
        db.movies[movieID] = true
        if seen and not IsShiftKeyDown() then
            -- Defer one frame so Blizzard's own handler has shown MovieFrame;
            -- hiding it stops playback via its OnHide.
            C_Timer.After(0, function()
                if MovieFrame and MovieFrame:IsShown() then
                    MovieFrame:Hide()
                    AnnounceSkip()
                end
            end)
        end
    else -- CINEMATIC_START
        local key = SceneKey()
        local seen = db.scenes[key]
        db.scenes[key] = true
        if seen and not IsShiftKeyDown() then
            C_Timer.After(0, function()
                if CinematicFrame and CinematicFrame:IsShown() then
                    if CinematicFrame_CancelCinematic then
                        CinematicFrame_CancelCinematic()
                    else
                        StopCinematic()
                    end
                    AnnounceSkip()
                end
            end)
        end
    end
end)
