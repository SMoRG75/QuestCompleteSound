------------------------------------------------------------
-- QuestCompleteSound by SMoRG75 (Retail and WoW Forever).
-- Plays a worker voice line when a quest objective is completed and another
-- when the whole quest is done. Sounds only: every other feature moved to
-- SMoRG's QoL, which plays the same sounds.
------------------------------------------------------------

local ADDON_NAME, QCS = ...          -- addon namespace table (shared across files)
local f = CreateFrame("Frame")

QCS.SoundProfiles = {
    Horde = {
        label = "Horde (Peon)",
        objective = 6197, -- B_PeonYes3: "Work, work."
        complete = 6199,  -- B_PeonBuildingComplete1: "Work complete."
    },
    Alliance = {
        label = "Alliance (Human worker)",
        objective = 6288, -- B_PeasantWhat3: "More work?"
        complete = "Interface\\AddOns\\QuestCompleteSound\\Sounds\\Peasant_job_done.mp3",
    },
}

------------------------------------------------------------
-- Defaults
------------------------------------------------------------
QCS.defaults = {
    QuestCompleteSound = true,
    QuestObjectiveSound = true,
    QuestSoundProfile = "Horde",
}

local QCS_REMOVED_SETTINGS = {
    "AutoTrack", "DebugTrack", "ShowSplash", "ColorProgress", "HideDoneAchievements", "SoundOnly",
}

------------------------------------------------------------
-- QCS_Init & Reset: ensure saved variables exist
------------------------------------------------------------
function QCS.Init(reset)
    -- Ensure SavedVariables table exists
    if reset or type(QCS_DB) ~= "table" then
        QCS_DB = {}
    end

    -- Drop settings left behind by the features removed in 2.0.0
    for _, k in ipairs(QCS_REMOVED_SETTINGS) do
        QCS_DB[k] = nil
    end

    -- Apply defaults into QCS_DB without clobbering user values
    for k, v in pairs(QCS.defaults) do
        if QCS_DB[k] == nil then
            QCS_DB[k] = v
        end
    end

    if not QCS.SoundProfiles[QCS_DB.QuestSoundProfile] then
        QCS_DB.QuestSoundProfile = QCS.defaults.QuestSoundProfile
    end

    -- Bind runtime DB reference
    QCS.DB = QCS_DB
end

------------------------------------------------------------
-- Client helpers
-- WoW Forever reports its own interface version, so look the APIs up instead
-- of assuming the ones Retail has.
------------------------------------------------------------
function QCS.GetVersion()
    local getMetadata = C_AddOns and C_AddOns.GetAddOnMetadata or rawget(_G, "GetAddOnMetadata")
    return type(getMetadata) == "function" and getMetadata(ADDON_NAME, "Version") or "?"
end

-- SMoRG's QoL plays the same sounds, so stay quiet instead of playing them twice.
function QCS.IsSMoRGsQoLLoaded()
    local isLoaded = C_AddOns and C_AddOns.IsAddOnLoaded or rawget(_G, "IsAddOnLoaded")
    return type(isLoaded) == "function" and isLoaded("SMoRGsQoL") and true or false
end

local function QCS_HasModernQuestLog()
    return C_QuestLog and type(C_QuestLog.GetNumQuestLogEntries) == "function"
        and type(C_QuestLog.GetInfo) == "function"
end

local function QCS_GetNumQuestLogEntries()
    local query = QCS_HasModernQuestLog() and C_QuestLog.GetNumQuestLogEntries
        or rawget(_G, "GetNumQuestLogEntries")
    if type(query) ~= "function" then return 0 end
    local ok, numEntries = pcall(query)
    return (ok and type(numEntries) == "number") and numEntries or 0
end

-- Quest ID at a log index, nil for headers and empty entries.
local function QCS_GetQuestIDAtIndex(index)
    if QCS_HasModernQuestLog() then
        local ok, info = pcall(C_QuestLog.GetInfo, index)
        return ok and info and not info.isHeader and info.questID or nil
    end

    local getTitle = rawget(_G, "GetQuestLogTitle")
    if type(getTitle) ~= "function" then return nil end
    local ok, title, _, _, isHeader, _, _, _, questID = pcall(getTitle, index)
    if not ok or not title or isHeader then return nil end
    return (type(questID) == "number" and questID > 0) and questID or nil
end

local function QCS_GetQuestObjectives(questID)
    if not C_QuestLog or type(C_QuestLog.GetQuestObjectives) ~= "function" then return nil end
    local ok, objectives = pcall(C_QuestLog.GetQuestObjectives, questID)
    return ok and type(objectives) == "table" and objectives or nil
end

------------------------------------------------------------
-- Quest progress (play sounds for objective and quest completion)
------------------------------------------------------------
QCS.fullyCompleted = {}
QCS.questObjectiveStates = {}
QCS._seenQuests = {}
QCS._checkPending = false
QCS._needsBaseline = true
local QCS_SCAN_DELAY = 0.20
local QCS_HANDLED_TTL = 10

local function QCS_ShouldWatchQuests()
    return QCS.DB
        and (QCS.DB.QuestCompleteSound or QCS.DB.QuestObjectiveSound)
        and not QCS.IsSMoRGsQoLLoaded()
end

local function QCS_PlayQuestSound(soundType)
    local profile = QCS.SoundProfiles[QCS.DB.QuestSoundProfile] or QCS.SoundProfiles.Horde
    local sound = profile[soundType]

    if type(sound) == "number" then
        PlaySound(sound, "Master")
    elseif type(sound) == "string" then
        PlaySoundFile(sound, "Master")
    end
end

local function QCS_CheckQuestProgress()
    if not QCS_ShouldWatchQuests() then return end

    -- The first scan after login only records state: quests that are already
    -- done should stay silent.
    local suppressAlerts = QCS._needsBaseline
    local seenQuests = QCS._seenQuests
    wipe(seenQuests)

    for i = 1, QCS_GetNumQuestLogEntries() do
        local questID = QCS_GetQuestIDAtIndex(i)
        if questID then
            seenQuests[questID] = true
            local objectives = QCS_GetQuestObjectives(questID)
            if objectives and #objectives > 0 then
                local allDone = true
                local objectiveCompleted = false
                local previous = QCS.questObjectiveStates[questID]
                local current = {}

                for objectiveIndex, obj in ipairs(objectives) do
                    local finished = not not obj.finished
                    if previous and previous[objectiveIndex] == false and finished then
                        objectiveCompleted = true
                    end
                    if not finished then
                        allDone = false
                    end
                    current[objectiveIndex] = finished
                end

                QCS.questObjectiveStates[questID] = current

                -- If all objectives done and not previously marked complete
                if allDone and not QCS.fullyCompleted[questID] then
                    QCS.fullyCompleted[questID] = true
                    if not suppressAlerts and QCS.DB.QuestCompleteSound then
                        QCS_PlayQuestSound("complete")
                    end
                elseif not allDone and objectiveCompleted
                    and not suppressAlerts and QCS.DB.QuestObjectiveSound then
                    QCS_PlayQuestSound("objective")
                end
            else
                QCS.questObjectiveStates[questID] = nil
            end
        end
    end

    for questID in pairs(QCS.questObjectiveStates) do
        if not seenQuests[questID] then
            QCS.questObjectiveStates[questID] = nil
        end
    end

    QCS._needsBaseline = false
end

-- QUEST_LOG_UPDATE fires in bursts, so scan once shortly after the last change.
local function QCS_ScheduleQuestProgressCheck()
    if QCS._checkPending or not QCS_ShouldWatchQuests() then return end

    QCS._checkPending = true
    C_Timer.After(QCS_SCAN_DELAY, function()
        QCS._checkPending = false
        QCS_CheckQuestProgress()
    end)
end

-- A short-lived marker suppresses delayed QUEST_LOG_UPDATE events during a
-- turn-in/removal, without keeping the quest marked for the whole session.
local function QCS_MarkQuestHandledTemporarily(questID)
    if not questID then return end

    local marker = {}
    QCS.fullyCompleted[questID] = marker
    QCS.questObjectiveStates[questID] = nil
    C_Timer.After(QCS_HANDLED_TTL, function()
        if QCS.fullyCompleted[questID] == marker then
            QCS.fullyCompleted[questID] = nil
        end
    end)
end

-- With both sounds off nothing is scanned, so the next scan starts over silently.
local function QCS_RefreshQuestWatching()
    if not QCS.DB.QuestCompleteSound and not QCS.DB.QuestObjectiveSound then
        wipe(QCS.questObjectiveStates)
        wipe(QCS.fullyCompleted)
        wipe(QCS._seenQuests)
        QCS._needsBaseline = true
    else
        if next(QCS.questObjectiveStates) == nil then
            QCS._needsBaseline = true
        end
        QCS_ScheduleQuestProgressCheck()
    end
end

------------------------------------------------------------
-- Public option helper (used by the options window and slash commands)
------------------------------------------------------------
function QCS.SetOption(key, value)
    QCS.DB[key] = value
    if key == "QuestCompleteSound" or key == "QuestObjectiveSound" then
        QCS_RefreshQuestWatching()
    end
    QCS.OptionsPopup_Refresh()
end

------------------------------------------------------------
-- Help
------------------------------------------------------------
local function QCS_OnOff(value)
    return value and "|cff00ff00ON|r" or "|cffff0000OFF|r"
end

local function QCS_PrintStatus()
    local profile = QCS.SoundProfiles[QCS.DB.QuestSoundProfile]
    print("|cff33ff99QCS|r v" .. QCS.GetVersion()
        .. " — |cff33ff99Quest sound:|r " .. QCS_OnOff(QCS.DB.QuestCompleteSound)
        .. "  |cff33ff99Objective sound:|r " .. QCS_OnOff(QCS.DB.QuestObjectiveSound)
        .. "  |cff33ff99Profile:|r " .. profile.label)
    if QCS.IsSMoRGsQoLLoaded() then
        print("|cff33ff99QCS:|r SMoRG's QoL is loaded and plays the quest sounds, so QCS stays silent.")
    end
end

local function QCS_Help()
    print("|cff33ff99-----------------------------------|r")
    print("|cff33ff99QuestCompleteSound (QCS)|r |cffffffffv" .. QCS.GetVersion() .. "|r")
    print("|cff33ff99-----------------------------------|r")
    print("|cff00ff00/qcs questsound|r      |cffcccccc- Toggle the quest completion sound|r")
    print("|cff00ff00/qcs qs|r              |cffcccccc- Shorthand for questsound|r")
    print("|cff00ff00/qcs objectivesound|r  |cffcccccc- Toggle the objective completion sound|r")
    print("|cff00ff00/qcs os|r              |cffcccccc- Shorthand for objectivesound|r")
    print("|cff00ff00/qcs soundprofile|r    |cffcccccc- Switch between the Horde and Alliance sounds|r")
    print("|cff00ff00/qcs config|r          |cffcccccc- Open the options window|r")
    print("|cff00ff00/qcs reset|r           |cffcccccc- Reset all settings to defaults|r")
    print("|cff33ff99-----------------------------------|r")
    QCS_PrintStatus()
end

------------------------------------------------------------
-- Slash commands
------------------------------------------------------------
SLASH_QCS1 = "/qcs"
SlashCmdList["QCS"] = function(msg)
    msg = string.lower(msg or "")

    local function toggle(key, label)
        QCS.SetOption(key, not QCS.DB[key])
        print("|cff33ff99QCS:|r " .. label .. " " .. QCS_OnOff(QCS.DB[key]))
    end

    if msg == "questsound" or msg == "qs" then
        toggle("QuestCompleteSound", "Quest completion sound is")

    elseif msg == "objectivesound" or msg == "os" then
        toggle("QuestObjectiveSound", "Objective completion sound is")

    elseif msg == "soundprofile" or msg == "soundset" then
        QCS.SetOption("QuestSoundProfile", QCS.DB.QuestSoundProfile == "Alliance" and "Horde" or "Alliance")
        print("|cff33ff99QCS:|r Sound profile is " .. QCS.SoundProfiles[QCS.DB.QuestSoundProfile].label)

    elseif msg == "config" or msg == "options" then
        QCS.OptionsPopup_Toggle()

    elseif msg == "reset" then
        QCS.Init(true)
        print("|cff33ff99QCS:|r All settings have been reset to defaults.")
        QCS_RefreshQuestWatching()
        QCS.OptionsPopup_Refresh()

    elseif msg == "help" then
        QCS_Help()

    else
        QCS_PrintStatus()
        print("|cffccccccCommands:|r help for more info")
    end
end

------------------------------------------------------------
-- Events
------------------------------------------------------------
-- Registering an event the client doesn't know errors and would stop the rest
-- of this file from loading.
local function QCS_RegisterOptionalEvent(event)
    pcall(f.RegisterEvent, f, event)
end

f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("QUEST_ACCEPTED")
f:RegisterEvent("QUEST_LOG_UPDATE")
QCS_RegisterOptionalEvent("QUEST_WATCH_UPDATE")
QCS_RegisterOptionalEvent("QUEST_CRITERIA_UPDATE")
QCS_RegisterOptionalEvent("QUEST_TURNED_IN")
QCS_RegisterOptionalEvent("QUEST_REMOVED")

f:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == ADDON_NAME then
            QCS.Init()
            f:UnregisterEvent("ADDON_LOADED")
        end

    elseif event == "QUEST_ACCEPTED" then
        local a1, a2 = ...
        local questIndex, questID
        if a2 then questIndex, questID = a1, a2 else questID = a1 end
        if (not questID or questID == 0) and questIndex then
            questID = QCS_GetQuestIDAtIndex(questIndex)
        end
        if questID then
            QCS.fullyCompleted[questID] = nil
            QCS.questObjectiveStates[questID] = nil
        end

    elseif event == "QUEST_TURNED_IN" or event == "QUEST_REMOVED" then
        QCS_MarkQuestHandledTemporarily((...))

    elseif event == "QUEST_LOG_UPDATE" or event == "QUEST_WATCH_UPDATE"
        or event == "QUEST_CRITERIA_UPDATE" then
        QCS_ScheduleQuestProgressCheck()
    end
end)
