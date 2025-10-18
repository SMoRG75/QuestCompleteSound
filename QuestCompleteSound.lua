------------------------------------------------------------
-- QuestCompleteSound v1.1.1 by SMoRG75
-- Plays a sound when a quest's objectives are completed.
-- Optional auto-tracking for newly accepted quests.
------------------------------------------------------------

-- Create main frame for events
local f = CreateFrame("Frame")

------------------------------------------------------------
-- Register events
-- These tell the addon which game events to listen for
------------------------------------------------------------
f:RegisterEvent("PLAYER_LOGIN")       -- When the player logs in (initialize + splash)
f:RegisterEvent("QUEST_ACCEPTED")     -- When a new quest is accepted (for auto-tracking)
f:RegisterEvent("QUEST_LOG_UPDATE")   -- When quest objectives change (for completion detection)

------------------------------------------------------------
-- QCS Quest Objective Colorization
-- Works on both Retail and Classic clients
------------------------------------------------------------

------------------------------------------------------------
-- QCS_GetProgressColor (smooth gradient version)
-- Converts quest progress (0-1) into a smooth RGB fade
------------------------------------------------------------
local function QCS_GetProgressColor(progress)
    -- Clamp to valid range
    if progress >= 1 then
        return "|cff00ff00"  -- Fully complete = bright green
    elseif progress <= 0 then
        return "|cffff0000"  -- Not started = red
    end

    -- Smooth gradient: red → yellow → green
    -- 0.0 = red (255, 0, 0)
    -- 0.5 = yellow (255, 255, 0)
    -- 1.0 = green (0, 255, 0)
    local r, g

    if progress < 0.5 then
        -- Between red (1,0,0) and yellow (1,1,0)
        r = 1
        g = progress * 2     -- goes 0→1
    else
        -- Between yellow (1,1,0) and green (0,1,0)
        r = 1 - ((progress - 0.5) * 2) -- goes 1→0
        g = 1
    end

    local R = math.floor(r * 255)
    local G = math.floor(g * 255)
    local B = 0
    return string.format("|cff%02x%02x%02x", R, G, B)
end


-- Helper: Recolor the tracker line for a specific quest objective
local function QCS_RecolorQuestObjectives()
    if not QCS_ColorProgress then return end

    local numEntries = C_QuestLog.GetNumQuestLogEntries()
    for i = 1, numEntries do
        local info = C_QuestLog.GetInfo(i)
        if info and not info.isHeader and info.questID then
            local objectives = C_QuestLog.GetQuestObjectives(info.questID)
            if objectives then
                for _, obj in ipairs(objectives) do
                    if obj.numItems and obj.numItems > 0 then
                        local progress = obj.numFulfilled / obj.numRequired
                        local color = (obj.numRequired == 1) and "|cff00ff00" or QCS_GetProgressColor(progress)

                        local text = string.format("%s%d/%d|r %s",
                            color, obj.numFulfilled, obj.numRequired, obj.text or "")

                        -- Find the tracker block for this quest
                        local block
                        if QUEST_TRACKER_MODULE and QUEST_TRACKER_MODULE.GetBlock then
                            block = QUEST_TRACKER_MODULE:GetBlock(info.questID)
                        elseif ObjectiveTrackerBlocksFrame and ObjectiveTrackerBlocksFrame.GetBlock then
                            block = ObjectiveTrackerBlocksFrame:GetBlock(info.questID)
                        end

                        if block and block.lines then
                            for _, line in pairs(block.lines) do
                                if line.text and line.text:GetText() and obj.text and line.text:GetText():find(obj.text) then
                                    line.text:SetText(text)
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

------------------------------------------------------------
-- Hook into Blizzard's objective tracker updates
------------------------------------------------------------
if QUEST_TRACKER_MODULE and QUEST_TRACKER_MODULE.Update then
    hooksecurefunc(QUEST_TRACKER_MODULE, "Update", QCS_RecolorQuestObjectives)
elseif ObjectiveTracker_Update then
    hooksecurefunc("ObjectiveTracker_Update", QCS_RecolorQuestObjectives)
end



------------------------------------------------------------
-- QCS_CheckQuestProgress
-- Detects when all objectives of a quest are completed
------------------------------------------------------------
local fullyCompleted = {}

function QCS_CheckQuestProgress()
    local numEntries = C_QuestLog.GetNumQuestLogEntries()
    for i = 1, numEntries do
        local info = C_QuestLog.GetInfo(i)
        if info and not info.isHeader and info.questID then
            local objectives = C_QuestLog.GetQuestObjectives(info.questID)
            if objectives and #objectives > 0 then
                local allDone = true
                for _, obj in ipairs(objectives) do
                    if not obj.finished then
                        allDone = false
                        break
                    end
                end

                -- When all objectives are done, but not previously marked
                if allDone and not fullyCompleted[info.questID] then
                    fullyCompleted[info.questID] = true
                    PlaySound(6199, "Master")

                    -- Determine quest type
                    local isTask = C_QuestLog.IsQuestTask and C_QuestLog.IsQuestTask(info.questID)
                    local isWorld = C_QuestLog.IsWorldQuest and C_QuestLog.IsWorldQuest(info.questID)

                    if isTask or isWorld then
                        print("|cff33ff99QCS:|r |cffffff00" ..
                            (info.title or info.questID) .. "|r |cff00ff00is done!|r")
                    else
                        print("|cff33ff99QCS:|r |cffffff00" ..
                            (info.title or info.questID) .. "|r |cff00ff00is ready to turn in!|r")
                    end
                end
            end
        end
    end
end

------------------------------------------------------------
-- QCS_Init & Reset: Ensures all saved variables exist
------------------------------------------------------------
function QCS_Init(reset)
    if reset then
        QCS_AutoTrack = false
        QCS_DebugTrack = false
        print("|cff33ff99QCS:|r All settings have been reset to defaults.")
        return
    end

    if QCS_AutoTrack == nil then QCS_AutoTrack = false end
    if QCS_DebugTrack == nil then QCS_DebugTrack = false end
    if QCS_ShowSplash == nil then QCS_ShowSplash = true end
    if QCS_ColorProgress == nil then QCS_ColorProgress = true end
end

------------------------------------------------------------
-- QCS_GetVersion: Supports both Retail & Classic APIs
------------------------------------------------------------
local function QCS_GetVersion()
    if C_AddOns and C_AddOns.GetAddOnMetadata then
        return C_AddOns.GetAddOnMetadata("QuestCompleteSound", "Version")
    elseif GetAddOnMetadata then
        return GetAddOnMetadata("QuestCompleteSound", "Version")
    else
        return "Unknown"
    end
end

-- Helper: detect non-trackable quests (bonus/task) and world quests
local function QCS_HandleTrackableTypes(questID)
    -- Bonus objectives / task quests: don't try to add a watch (Blizzard handles these automatically)
    if C_QuestLog.IsQuestTask and C_QuestLog.IsQuestTask(questID) then
        if QCS_DebugTrack then
            print("|cff9999ff[QCS Debug]|r Skipping task/bonus objective:", questID)
        end
        return "skip"
    end

    -- World quests: use the correct API if available
    if C_QuestLog.IsWorldQuest and C_QuestLog.IsWorldQuest(questID) then
        if C_QuestLog.AddWorldQuestWatch then
            local ok = pcall(function() C_QuestLog.AddWorldQuestWatch(questID) end)
            if ok then
                if QCS_DebugTrack then
                    print("|cff9999ff[QCS Debug]|r Added world quest watch:", questID)
                end
                return "done"
            end
        end
        if QCS_DebugTrack then
            print("|cff9999ff[QCS Debug]|r Could not add world quest watch:", questID)
        end
        return "skip"
    end

    return "normal" -- regular quest, OK to track
end

-- Updated, safe autotrack
local function QCS_TryAutoTrack(questID, retries)
    if not questID then return end
    retries = retries or 0

    if retries > 5 then
        print("|cffff0000QCS:|r Failed to auto-track quest after multiple attempts:", questID)
        return
    end

    local mode = QCS_HandleTrackableTypes(questID)
    if mode == "skip" or mode == "done" then
        return
    end

    local title = C_QuestLog.GetTitleForQuestID(questID)
    if not title then
        C_Timer.After(0.5, function() QCS_TryAutoTrack(questID, retries + 1) end)
        return
    end

    -- Already tracked?
    if C_QuestLog.GetQuestWatchType and C_QuestLog.GetQuestWatchType(questID) then
        if QCS_DebugTrack then
            print("|cff9999ff[QCS Debug]|r Already tracked:", title)
        end
        return
    end

    if QCS_DebugTrack then
        print("|cff9999ff[QCS Debug]|r Attempting to track:", title)
    end

    -- Modern API: single parameter
    local success = false
    if C_QuestLog.AddQuestWatch then
        local ok = pcall(function() success = C_QuestLog.AddQuestWatch(questID) end)
        if not ok then success = false end
    end

    -- IMPORTANT: do NOT call the old global AddQuestWatch unless it actually exists
    if not success and AddQuestWatch then
        pcall(function() AddQuestWatch(questID) end)
    end

    -- Verify
    if C_QuestLog.GetQuestWatchType and C_QuestLog.GetQuestWatchType(questID) then
        print("And |cff33ff99QCS|r auto-tracked it")
    elseif QCS_DebugTrack then
        print("|cffff0000[QCS Debug]|r Could not track quest:", title)
    end
end

------------------------------------------------------------
-- QCS_Help: Displays all available slash commands
------------------------------------------------------------
local function QCS_Help()
    local version = QCS_GetVersion()
    local stateAutoTrack = QCS_AutoTrack and "|cff00ff00ON|r" or "|cffff0000OFF|r"
    local stateShowSplash = QCS_ShowSplash and "|cff00ff00ON|r" or "|cffff0000OFF|r"

    print("|cff33ff99----------------------------------------|r")
    print("|TInterface\\GossipFrame\\ActiveQuestIcon:14|t |cff33ff99QuestCompleteSound (QCS)|r |cff888888v" .. version .. "|r")
    print("|cff33ff99----------------------------------------|r")
    print("|cff00ff00/qcs autotrack on|r   |cffcccccc- Enable automatic quest tracking|r")
    print("|cff00ff00/qcs autotrack off|r  |cffcccccc- Disable automatic quest tracking|r")
    print("|cff00ff00/qcs autotrack|r      |cffcccccc- Show current autotrack state|r")
    print("|cff00ff00/qcs debug|r          |cffcccccc- List all quests and tracking state|r")
    print("|cff00ff00/qcs debugtrack|r     |cffcccccc- Toggle verbose tracking debug|r")
    print("|cff00ff00/qcs reset|r          |cffcccccc- Reset all settings to defaults|r")
    print("|cff00ff00/qcs help|r           |cffcccccc- Show this help message|r")
    print("|cff00ff00/qcs splash on|r      |cffcccccc- Enable splash screen on login|r")
    print("|cff00ff00/qcs splash off|r     |cffcccccc- Disable splash screen on login|r")
    print("|cff00ff00/qcs splash|r         |cffcccccc- Show current splash state|r")
    print("|cff00ff00/qcs color on|r       |cffcccccc- Enable progress colorization|r")
    print("|cff00ff00/qcs color off|r      |cffcccccc- Disable progress colorization|r")
    print("|cff00ff00/qcs color|r          |cffcccccc- Show current colorization state|r")
    print("|cff33ff99----------------------------------------|r")
    print("|cff33ff99AutoTrack status:|r " .. stateAutoTrack)
    print("|cff33ff99ShowSplash status:|r " .. stateShowSplash)
    print("|cff33ff99----------------------------------------|r")
end

------------------------------------------------------------
-- Slash Command Handler
------------------------------------------------------------
SLASH_QCS1 = "/qcs"
SlashCmdList["QCS"] = function(msg)
    msg = string.lower(msg or "")
    if msg == "autotrack on" then
        QCS_AutoTrack = true
        print("|cff33ff99QCS:|r Auto-tracking is now |cff00ff00ON|r.")
    elseif msg == "autotrack off" then
        QCS_AutoTrack = false
        print("|cff33ff99QCS:|r Auto-tracking is now |cffff0000OFF|r.")
    elseif msg == "autotrack" then
        local state = QCS_AutoTrack and "|cff00ff00ON|r" or "|cffff0000OFF|r"
        print("|cff33ff99QCS:|r Auto-tracking is currently " .. state)
    elseif msg == "debug" then
        print("|cff33ff99QCS Debug:|r Listing all quests...")
        local numEntries = C_QuestLog.GetNumQuestLogEntries()
        for i = 1, numEntries do
            local info = C_QuestLog.GetInfo(i)
            if info and not info.isHeader then
                local tracked = C_QuestLog.GetQuestWatchType(info.questID)
                local status = tracked and "|cff00ff00TRACKED|r" or "|cffff0000UNTRACKED|r"
                print(string.format("%s (ID: %d) - %s", info.title or "Unknown", info.questID or 0, status))
            end
        end
    elseif msg == "debugtrack" then
        QCS_DebugTrack = not QCS_DebugTrack
        local state = QCS_DebugTrack and "|cff00ff00ON|r" or "|cffff0000OFF|r"
        print("|cff33ff99QCS:|r Debug tracking is now " .. state)
    elseif msg == "reset" then
        QCS_Init(true)
        print("|cff33ff99QCS:|r Settings restored. You may need to /reload.")
    elseif msg == "splash on" then
        QCS_ShowSplash = true
        print("|cff33ff99QCS:|r Splash screen is now |cff00ff00ON|r.")
    elseif msg == "splash off" then
        QCS_ShowSplash = false
        print("|cff33ff99QCS:|r Splash screen is now |cffff0000OFF|r.")
    ------------------------------------------------------------
    -- Color progress toggle
    ------------------------------------------------------------
    elseif msg == "color on" then
        QCS_ColorProgress = true
        print("|cff33ff99QCS:|r Progress colorization is now |cff00ff00ON|r.")

        -- Show a preview
        local examples = {
            { text = "0/8 Wolves Slain", color = QCS_GetProgressColor(0.0) },
            { text = "4/8 Wolves Slain", color = QCS_GetProgressColor(0.5) },
            { text = "8/8 Wolves Slain", color = QCS_GetProgressColor(1.0) },
            { text = "0/1 Artifact Found", color = "|cff00ff00" }
        }

        print("|cff9999ff[QCS Preview]|r Example progression colors:")
        for _, ex in ipairs(examples) do
            print(ex.color .. ex.text .. "|r")
        end
    elseif msg == "color off" then
        QCS_ColorProgress = false
        print("|cff33ff99QCS:|r Progress colorization is now |cffff0000OFF|r.")
    elseif msg == "color" then
        local state = QCS_ColorProgress and "|cff00ff00ON|r" or "|cffff0000OFF|r"
        print("|cff33ff99QCS:|r Progress colorization is currently " .. state)

        -- Show mini preview only if it's ON
        if QCS_ColorProgress then
            local preview = string.format("%s4/8 Wolves Slain|r", QCS_GetProgressColor(0.5))
            print("|cff9999ff[QCS Preview]|r Example: " .. preview)
        end
    else
        QCS_Help()
    end
end

------------------------------------------------------------
-- Set event handler
-- All events funnel into this single handler
------------------------------------------------------------
f:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        QCS_Init()
        if QCS_ShowSplash then
            local version = QCS_GetVersion()
            local state = QCS_AutoTrack and "|cff00ff00ON|r" or "|cffff0000OFF|r"
            print("|cff33ff99----------------------------------------|r")
            print("|TInterface\\GossipFrame\\ActiveQuestIcon:14|t |cff33ff99QuestCompleteSound (QCS)|r |cff888888v" ..
                version .. "|r loaded.")
            print("|cff33ff99AutoTrack:|r " .. state)
            print("|cffccccccType |cff00ff00/qcs help|r for command list.|r")
            print("|cff33ff99----------------------------------------|r")
        end

    elseif event == "QUEST_ACCEPTED" then
        local arg1, arg2 = ...
        local questID = arg2 or arg1
        if QCS_AutoTrack and questID then
            QCS_TryAutoTrack(questID)
        end

    elseif event == "QUEST_LOG_UPDATE" then
        -- (din eksisterende logik til at afspille lyd og skrive besked)
        QCS_CheckQuestProgress()
    end
end)
