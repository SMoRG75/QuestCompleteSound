------------------------------------------------------------
-- QuestCompleteSound v1.3.0 by SMoRG75
-- Plays a sound when a quest's objectives are completed.
-- Optional auto-tracking for newly accepted quests.
------------------------------------------------------------

local f = CreateFrame("Frame")

------------------------------------------------------------
-- QCS_Init & Reset: Ensures all saved variables exist
------------------------------------------------------------
function QCS_Init(reset)
    if reset then
        QCS_AutoTrack     = false
        QCS_DebugTrack    = false
        QCS_ShowSplash    = true
        QCS_ColorProgress = false
        print("|cff33ff99QCS:|r All settings have been reset to defaults.")
        return
    end

    if QCS_AutoTrack     == nil then QCS_AutoTrack     = false end
    if QCS_DebugTrack    == nil then QCS_DebugTrack    = false end
    if QCS_ShowSplash    == nil then QCS_ShowSplash    = true  end
    if QCS_ColorProgress == nil then QCS_ColorProgress = false end

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

local function QCS_GetStateStrings()
    local version = QCS_GetVersion()
    local atState = QCS_AutoTrack     and "|cff00ff00ON|r" or "|cffff0000OFF|r"
    local spState = QCS_ShowSplash    and "|cff00ff00ON|r" or "|cffff0000OFF|r"
    local coState = QCS_ColorProgress and "|cff00ff00ON|r" or "|cffff0000OFF|r"
    return version, atState, spState, coState
end

------------------------------------------------------------
-- Color utilities
------------------------------------------------------------
local function QCS_GetProgressColor(progress)
    if progress >= 1 then
        return "|cff00ff00"
    elseif progress <= 0 then
        return "|cffff0000"
    end
    local r, g
    if progress < 0.5 then
        r, g = 1, progress * 2
    else
        r, g = 1 - ((progress - 0.5) * 2), 1
    end
    local R = math.floor(r * 255)
    local G = math.floor(g * 255)
    return string.format("|cff%02x%02x%02x", R, G, 0)
end

------------------------------------------------------------
-- Colorize tracker objective lines (Retail tracker)
------------------------------------------------------------
local function QCS_RecolorQuestObjectives()
    if not QCS_ColorProgress or not C_QuestLog then return end
    local numEntries = C_QuestLog.GetNumQuestLogEntries()
    for i = 1, numEntries do
        local info = C_QuestLog.GetInfo(i)
        if info and not info.isHeader and info.questID then
            local objectives = C_QuestLog.GetQuestObjectives(info.questID)
            if objectives then
                for _, obj in ipairs(objectives) do
                    local numItems     = rawget(obj, "numItems")
                    local numRequired  = rawget(obj, "numRequired")
                    local numFulfilled = rawget(obj, "numFulfilled")
                    local objText      = rawget(obj, "text")
                    local hasCounter = (type(numItems) == "number" and numItems > 0)
                                    or (type(numRequired) == "number" and numRequired > 0)
                    if hasCounter then
                        local required  = (type(numRequired) == "number" and numRequired)
                                       or (type(numItems) == "number" and numItems)
                                       or 0
                        local fulfilled = (type(numFulfilled) == "number" and numFulfilled) or 0
                        local color
                        if required == 1 then
                            color = "|cff00ff00"
                        else
                            local progress = (required > 0) and (fulfilled / required) or 0
                            color = QCS_GetProgressColor(progress)
                        end
                        local text = string.format("%s%d/%d|r %s", color, fulfilled, required, objText or "")
                        local block = (QUEST_TRACKER_MODULE and QUEST_TRACKER_MODULE.GetBlock and QUEST_TRACKER_MODULE:GetBlock(info.questID))
                                   or (ObjectiveTrackerBlocksFrame and ObjectiveTrackerBlocksFrame.GetBlock and ObjectiveTrackerBlocksFrame:GetBlock(info.questID))
                        if block and block.lines then
                            for _, line in pairs(block.lines) do
                                local lineText = line.text and line.text:GetText()
                                if lineText and objText and lineText:find(objText, 1, true) then
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
-- Custom colored UI_INFO_MESSAGE (Retail-safe)
------------------------------------------------------------
local function QCS_EnableCustomInfoMessages()
    if UIErrorsFrame and UIErrorsFrame.UnregisterEvent then
        UIErrorsFrame:UnregisterEvent("UI_INFO_MESSAGE")
        if QCS_DebugTrack then
            print("|cff33ff99QCS:|r Disabled Blizzard UI_INFO_MESSAGE display.")
        end
    end

    if not QCS_MessageFrame then
        QCS_MessageFrame = CreateFrame("MessageFrame", "QCS_MessageFrame", UIParent)
        QCS_MessageFrame:SetPoint("TOP", UIParent, "TOP", 0, -150)
        QCS_MessageFrame:SetSize(512, 60)
        QCS_MessageFrame:SetInsertMode("TOP")
        QCS_MessageFrame:SetFading(true)
        QCS_MessageFrame:SetFadeDuration(1.5)
        QCS_MessageFrame:SetTimeVisible(2.5)
        QCS_MessageFrame:SetFontObject(GameFontNormalHuge)
    end

    if not QCS_InfoEventFrame then
        QCS_InfoEventFrame = CreateFrame("Frame", "QCS_InfoEventFrame")
        QCS_InfoEventFrame:RegisterEvent("UI_INFO_MESSAGE")
        QCS_InfoEventFrame:SetScript("OnEvent", function(_, event, messageType, message)
            if event ~= "UI_INFO_MESSAGE" or not QCS_ColorProgress then return end
            if type(message) ~= "string" then return end

            local label, cur, total = message:match("^(.+):%s*(%d+)%s*/%s*(%d+)$")
            if not (label and cur and total) then return end

            cur, total = tonumber(cur), tonumber(total)
            local progress = (total and total > 0) and math.min(1, math.max(0, cur / total)) or 0
            local colorCode = QCS_GetProgressColor(progress)

            QCS_MessageFrame:AddMessage(colorCode .. message .. "|r")

            if QCS_DebugTrack then
                print(string.format("|cff9999ff[QCS Debug]|r Custom UI_INFO_MESSAGE: %s (%d/%d, %.2f)",
                    label, cur or -1, total or -1, progress))
            end
        end)
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
-- Splash
------------------------------------------------------------
local function QCS_Splash()
    local version, atState, spState, coState = QCS_GetStateStrings()
    print("|cff33ff99----------------------------------------|r")
    print("|cff33ff99QuestCompleteSound (QCS)|r |cff33ff99v" .. version .. "|r")
    print("|cff33ff99----------------------------------------|r")
    print("|cff33ff99AutoTrack:|r " .. atState .. "  |cff33ff99Splash:|r " .. spState .. "  |cff33ff99Color:|r " .. coState)
    print("|cffccccccType |cff00ff00/qcs help|r for command list.|r")
    print("|cff33ff99----------------------------------------|r")
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

                    -- If all objectives done and not previously marked complete
                    if allDone and not fullyCompleted[info.questID] then
                        fullyCompleted[info.questID] = true
                        PlaySound(6199, "Master")

                        -- Determine quest type
                        local isTask = C_QuestLog.IsQuestTask and C_QuestLog.IsQuestTask(info.questID)
                        local isWorld = C_QuestLog.IsWorldQuest and C_QuestLog.IsWorldQuest(info.questID)

                        if isTask or isWorld then
                            -- Bonus or world quest
                            print("|cff33ff99QCS:|r |cffffff00" ..
                                (info.title or info.questID) .. "|r |cff00ff00is done!|r")
                        else
                            -- Normal quest
                            print("|cff33ff99QCS:|r |cffffff00" ..
                                (info.title or info.questID) .. "|r |cff00ff00is ready to turn in!|r")
                        end
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
            QCS_Splash()
        end
    end
end)

------------------------------------------------------------
-- Help
------------------------------------------------------------
local function QCS_Help()
    local version, atState, spState, coState = QCS_GetStateStrings()
    print("|cff33ff99----------------------------------------|r")
    print("|cff33ff99QuestCompleteSound (QCS)|r |cff00ff00v" .. version .. "|r")
    print("|cff33ff99----------------------------------------|r")
    print("|cff00ff00/qcs autotrack|r      |cffcccccc- Toggle automatic quest tracking|r")
    print("|cff00ff00/qcs color|r          |cffcccccc- Toggle progress colorization|r")
    print("|cff00ff00/qcs splash|r         |cffcccccc- Toggle splash on login|r")
    print("|cff00ff00/qcs debugtrack|r     |cffcccccc- Toggle verbose tracking debug|r")
    print("|cff00ff00/qcs reset|r          |cffcccccc- Reset all settings to defaults|r")
    print("|cff33ff99----------------------------------------|r")
    print("|cff33ff99AutoTrack:|r " .. atState .. "  |cff33ff99Splash:|r " .. spState .. "  |cff33ff99Color:|r " .. coState)
    print("|cff33ff99----------------------------------------|r")
end

------------------------------------------------------------
-- Slash commands
------------------------------------------------------------
SLASH_QCS1 = "/qcs"
SlashCmdList["QCS"] = function(msg)
    msg = string.lower(msg or "")
    if msg == "autotrack" then
        QCS_AutoTrack = not QCS_AutoTrack        
        local s = QCS_AutoTrack and "|cff00ff00ON|r" or "|cffff0000OFF|r"
        print("|cff33ff99QCS:|r Auto-track is " .. s)
    elseif msg == "color" then
        QCS_ColorProgress = not QCS_ColorProgress
        if QCS_ColorProgress then
            QCS_EnableCustomInfoMessages()
        else
            if UIErrorsFrame and UIErrorsFrame.RegisterEvent then
                UIErrorsFrame:RegisterEvent("UI_INFO_MESSAGE")
            end
        end
        local s = QCS_ColorProgress and "|cff00ff00ON|r" or "|cffff0000OFF|r"
        print("|cff33ff99QCS:|r Progress colorization is " .. s)
    elseif msg == "splash" then
        QCS_ShowSplash = not QCS_ShowSplash
        local s = QCS_ShowSplash and "|cff00ff00ON|r" or "|cffff0000OFF|r"
        print("|cff33ff99QCS:|r Splash is " .. s)
    elseif msg == "debugtrack" then
        QCS_DebugTrack = not QCS_DebugTrack
        local s = QCS_DebugTrack and "|cff00ff00ON|r" or "|cffff0000OFF|r"
        print("|cff33ff99QCS:|r Debug tracking " .. s)
    elseif msg == "reset" then
        QCS_Init(true)
    elseif msg == "help" then
        QCS_Help()
    else
        local version, at, sp, co = QCS_GetStateStrings()
        print("|cff33ff99QCS|r v" .. version .. " — Auto:" .. at .. " Splash:" .. sp .. " Color:" .. co)
        print("|cffccccccCommands:|r help for more info")
    end
end

------------------------------------------------------------
-- Events
------------------------------------------------------------
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("QUEST_ACCEPTED")
f:RegisterEvent("QUEST_LOG_UPDATE")

f:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        QCS_Init()
        if QCS_ShowSplash then
            QCS_Splash()
        end
        if QCS_ColorProgress then
            QCS_EnableCustomInfoMessages()
        end

    elseif event == "QUEST_ACCEPTED" then
        if not QCS_AutoTrack then return end
        local a1, a2 = ...
        local questIndex, questID
        if a2 then questIndex, questID = a1, a2 else questID = a1 end
        if (not questID or questID == 0) and questIndex and C_QuestLog and C_QuestLog.GetInfo then
            local info = C_QuestLog.GetInfo(questIndex)
            if info and info.questID then
                questID = info.questID
                if QCS_DebugTrack then
                    print("|cff9999ff[QCS Debug]|r Recovered questID", questID, "from questIndex", questIndex)
                end
            end
        end
        if questID then
            QCS_TryAutoTrack(questID)
        elseif QCS_DebugTrack then
            print("|cff9999ff[QCS Debug]|r Could not resolve questID on QUEST_ACCEPTED:", tostring(a1), tostring(a2))
        end

    elseif event == "QUEST_LOG_UPDATE" then
        QCS_RecolorQuestObjectives()
    end
end)
