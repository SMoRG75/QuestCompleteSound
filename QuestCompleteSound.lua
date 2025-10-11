------------------------------------------------------------
-- QuestCompleteSound v1.1.1 by SMoRG75
-- Plays a sound when a quest's objectives are completed.
-- Optional auto-tracking for newly accepted quests.
------------------------------------------------------------

local f = CreateFrame("Frame")

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

------------------------------------------------------------
-- QCS_TryAutoTrack: Safely adds quest to tracker
------------------------------------------------------------
local function QCS_TryAutoTrack(questID, retries)
    if QCS_DebugTrack then
        print("|cff33ff99QCS Debug:|r Attempting to track quest ID:", questID)
    end

    if not questID then return end
    retries = retries or 0

    if retries > 5 then
        print("|cffff0000QCS:|r Failed to auto-track quest after multiple attempts:", questID)
        return
    end

    local title = C_QuestLog.GetTitleForQuestID(questID)
    if not title then
        C_Timer.After(0.5, function() QCS_TryAutoTrack(questID, retries + 1) end)
        return
    end

    if C_QuestLog.GetQuestWatchType(questID) then return end

    local success
    if Enum and Enum.QuestWatchType and Enum.QuestWatchType.Automatic then
        local ok = pcall(function()
            success = C_QuestLog.AddQuestWatch(questID, Enum.QuestWatchType.Automatic)
        end)
        if not ok then
            success = C_QuestLog.AddQuestWatch(questID)
        end
    else
        success = C_QuestLog.AddQuestWatch(questID)
    end

    if not success then AddQuestWatch(questID) end

    if C_QuestLog.GetQuestWatchType(questID) then
        print("And |cff33ff99QCS|r auto-tracked it")
    else
        print("|cffff0000QCS:|r Failed to track quest:", title)
    end
end

------------------------------------------------------------
-- Event: QUEST_LOG_UPDATE (play sound when quest ready)
------------------------------------------------------------
local fullyCompleted = {}
f:RegisterEvent("QUEST_LOG_UPDATE")

f:SetScript("OnEvent", function(self, event, ...)
    if event == "QUEST_LOG_UPDATE" then
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
                    if allDone and not fullyCompleted[info.questID] then
                        fullyCompleted[info.questID] = true
                        PlaySound(6199, "Master")
                        print("|TInterface\\GossipFrame\\ActiveQuestIcon:14|t |cff33ff99QCS:|r |cffffff00" ..
                            (info.title or info.questID) .. "|r |cff00ff00is ready to turn in!|r")
                    end
                end
            end
        end
    elseif event == "QUEST_ACCEPTED" then
        local arg1, arg2 = ...
        local questID = arg2 or arg1
        if QCS_AutoTrack and questID then
            QCS_TryAutoTrack(questID)
        end
    elseif event == "PLAYER_LOGIN" then
        QCS_Init()
        if QCS_ShowSplash then
            local version = QCS_GetVersion()
            local state  = QCS_AutoTrack and "|cff00ff00ON|r" or "|cffff0000OFF|r"
            print("|cff33ff99----------------------------------------|r")
            print("|cff33ff99QuestCompleteSound (QCS)|r |cff888888v" .. version .. "|r loaded.")
            print("|cff33ff99AutoTrack:|r " .. state)
            print("|cffccccccType |cff00ff00/qcs help|r for command list.|r")
            print("|cff33ff99----------------------------------------|r")
        end
    end

end)

------------------------------------------------------------
-- Event: QUEST_ACCEPTED (for autotrack)
------------------------------------------------------------
f:RegisterEvent("QUEST_ACCEPTED")
f:RegisterEvent("PLAYER_LOGIN")

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
    else
        QCS_Help()
    end
end
