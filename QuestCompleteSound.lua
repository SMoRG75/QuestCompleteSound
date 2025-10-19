------------------------------------------------------------
-- QuestCompleteSound (QCS)
-- Plays a sound when a quest's objectives are completed.
-- Optional: auto-track new quests, splash toggle, progress colorization.
-- Works across Retail & Classic clients.
------------------------------------------------------------

-- Main event frame
local f = CreateFrame("Frame")

------------------------------------------------------------
-- Saved variables init/reset
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
    if QCS_ColorProgress == nil then QCS_ColorProgress = false  end
end

------------------------------------------------------------
-- Version helper (Retail + Classic compatible)
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
-- Helper: Get current QCS states (formatted strings)
------------------------------------------------------------
local function QCS_GetStateStrings()
    local version = QCS_GetVersion()
    local atState = QCS_AutoTrack     and "|cff00ff00ON|r" or "|cffff0000OFF|r"
    local spState = QCS_ShowSplash    and "|cff00ff00ON|r" or "|cffff0000OFF|r"
    local coState = QCS_ColorProgress and "|cff00ff00ON|r" or "|cffff0000OFF|r"

    return version, atState, spState, coState
end

------------------------------------------------------------
-- Auto-track newly accepted quests (robust across clients)
------------------------------------------------------------
local function QCS_HandleTrackableTypes(questID)
    -- Skip bonus/task objectives: Blizzard handles visibility automatically
    if C_QuestLog.IsQuestTask and C_QuestLog.IsQuestTask(questID) then
        if QCS_DebugTrack then
            print("|cff9999ff[QCS Debug]|r Skipping task/bonus objective:", questID)
        end
        return "skip"
    end

    -- World quests: use dedicated API where available
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

    return "normal"
end

local function QCS_TryAutoTrack(questID, retries)
    if not questID then return end
    retries = retries or 0

    if retries > 5 then
        print("|cffff0000QCS:|r Failed to auto-track quest:", questID)
        return
    end

    local mode = QCS_HandleTrackableTypes(questID)
    if mode ~= "normal" then return end

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

    local success = false
    if C_QuestLog.AddQuestWatch then
        local ok = pcall(function() success = C_QuestLog.AddQuestWatch(questID) end)
        if not ok then success = false end
    end
    -- Classic fallback only if global exists
    if not success and AddQuestWatch then
        pcall(function() AddQuestWatch(questID) end)
    end

    if C_QuestLog.GetQuestWatchType and C_QuestLog.GetQuestWatchType(questID) then
        print("And |cff33ff99QCS|r auto-tracked it")
    elseif QCS_DebugTrack then
        print("|cffff0000[QCS Debug]|r Could not track quest:", title or questID)
    end
end

------------------------------------------------------------
-- Smooth progress color (red -> yellow -> green)
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
-- Recolor quest tracker objective lines (safe, lint-clean)
------------------------------------------------------------
local function QCS_RecolorQuestObjectives()
    if not QCS_ColorProgress then return end

    local numEntries = C_QuestLog.GetNumQuestLogEntries()
    for i = 1, numEntries do
        local info = C_QuestLog.GetInfo(i)
        if info and not info.isHeader and info.questID then
            local objectives = C_QuestLog.GetQuestObjectives(info.questID)
            if objectives then
                for _, obj in ipairs(objectives) do
                    -- Safe reads (avoid VS Code 'undefined-field' warnings)
                    local numItems     = rawget(obj, "numItems")
                    local numRequired  = rawget(obj, "numRequired")
                    local numFulfilled = rawget(obj, "numFulfilled")
                    local objText      = rawget(obj, "text")

                    -- Determine if this objective has a numeric counter
                    local hasCounter = (type(numItems) == "number" and numItems > 0)
                                    or (type(numRequired) == "number" and numRequired > 0)

                    if hasCounter then
                        -- Pick a valid counter and progress
                        local required  = (type(numRequired) == "number" and numRequired)
                                       or (type(numItems) == "number" and numItems)
                                       or 0
                        local fulfilled = (type(numFulfilled) == "number" and numFulfilled) or 0

                        local color
                        if required == 1 then
                            color = "|cff00ff00" -- single-step -> green immediately
                        else
                            local progress = (required > 0) and (fulfilled / required) or 0
                            color = QCS_GetProgressColor(progress)
                        end

                        local text = string.format("%s%d/%d|r %s", color, fulfilled, required, objText or "")

                        -- Locate quest tracker block for this quest
                        local block = (QUEST_TRACKER_MODULE and QUEST_TRACKER_MODULE.GetBlock and QUEST_TRACKER_MODULE:GetBlock(info.questID))
                                   or (ObjectiveTrackerBlocksFrame and ObjectiveTrackerBlocksFrame.GetBlock and ObjectiveTrackerBlocksFrame:GetBlock(info.questID))

                        -- Update matching line text safely
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
-- Hook tracker updates (Retail & Classic safe)
------------------------------------------------------------
local function QCS_HookTracker()
    -- Retail style
    if QUEST_TRACKER_MODULE and QUEST_TRACKER_MODULE.Update then
        hooksecurefunc(QUEST_TRACKER_MODULE, "Update", QCS_RecolorQuestObjectives)
    end
    -- Classic / fallback
    if ObjectiveTracker_Update then
        hooksecurefunc("ObjectiveTracker_Update", QCS_RecolorQuestObjectives)
    end
end

------------------------------------------------------------
-- Update colors also on quest log updates
------------------------------------------------------------
local function QCS_OnQuestLogUpdate()
    QCS_RecolorQuestObjectives()
end

-- Register our color-refresh hook once player is in-game
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:HookScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        QCS_HookTracker()
    elseif event == "QUEST_LOG_UPDATE" then
        QCS_OnQuestLogUpdate()
    end
end)

------------------------------------------------------------
-- Quest completion sound + message formatting
------------------------------------------------------------
local fullyCompleted = {}

local function QCS_CheckQuestProgress()
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

                    local isTask = C_QuestLog.IsQuestTask and C_QuestLog.IsQuestTask(info.questID)
                    local isWorld = C_QuestLog.IsWorldQuest and C_QuestLog.IsWorldQuest(info.questID)
                    local title = info.title or tostring(info.questID)

                    if isTask or isWorld then
                        print("|cff33ff99QCS:|r |cffffff00" ..
                              title .. "|r |cff00ff00is done!|r")
                    else
                        print("|cff33ff99QCS:|r |cffffff00" ..
                              title .. "|r |cff00ff00is ready to turn in!|r")
                    end
                end
            end
        end
    end
end

------------------------------------------------------------
-- Help
------------------------------------------------------------
local function QCS_Help()
    local version, atState, spState, coState = QCS_GetStateStrings()    
    
    print("|cff33ff99----------------------------------------|r")
    print("|TInterface\\GossipFrame\\ActiveQuestIcon:14|t |cff33ff99QuestCompleteSound (QCS)|r |cff888888v" .. version .. "|r")
    print("|cff33ff99----------------------------------------|r")
    print("|cff00ff00/qcs autotrack on|r   |cffcccccc- Enable automatic quest tracking|r")
    print("|cff00ff00/qcs autotrack off|r  |cffcccccc- Disable automatic quest tracking|r")
    print("|cff00ff00/qcs autotrack|r      |cffcccccc- Show current autotrack state|r")
    print("|cff00ff00/qcs color on|r       |cffcccccc- Enable progress colorization|r")
    print("|cff00ff00/qcs color off|r      |cffcccccc- Disable progress colorization|r")
    print("|cff00ff00/qcs color|r          |cffcccccc- Show current colorization state|r")
    print("|cff00ff00/qcs splash on|r      |cffcccccc- Show splash on login|r")
    print("|cff00ff00/qcs splash off|r     |cffcccccc- Hide splash on login|r")
    print("|cff00ff00/qcs splash|r         |cffcccccc- Show current splash state|r")
    print("|cff00ff00/qcs debug|r          |cffcccccc- List quests + watch state|r")
    print("|cff00ff00/qcs debugtrack|r     |cffcccccc- Toggle verbose tracking debug|r")
    print("|cff00ff00/qcs reset|r          |cffcccccc- Reset all settings to defaults|r")
    print("|cff33ff99----------------------------------------|r")
    print("|cff33ff99AutoTrack:|r " .. atState .. "  |cff33ff99Splash:|r " .. spState .. "  |cff33ff99Color:|r " .. coState)
    if QCS_ColorProgress then
        local preview = string.format("%s4/8 Wolves Slain|r", QCS_GetProgressColor(0.5))
        print("|cff9999ff[QCS Preview]|r Example progression: " .. preview)
    else
        print("|cff9999ff[QCS Preview]|r Progress colorization is currently disabled.")
    end
    print("|cff33ff99----------------------------------------|r")
end

------------------------------------------------------------
-- QCS: Retail-safe custom display for UI_INFO_MESSAGE
-- Suppress Blizzard UIErrorsFrame and show colorized progress
------------------------------------------------------------
local function QCS_EnableCustomInfoMessages()
    -- Disable Blizzard's default UI_INFO_MESSAGE on UIErrorsFrame (so it won't show yellow lines)
    if UIErrorsFrame and UIErrorsFrame.UnregisterEvent then
        UIErrorsFrame:UnregisterEvent("UI_INFO_MESSAGE")
        if QCS_DebugTrack then
            print("|cff33ff99QCS:|r Disabled Blizzard UI_INFO_MESSAGE display.")
        end
    end

    -- Create (or reuse) our own message frame
    if not QCS_MessageFrame then
        QCS_MessageFrame = CreateFrame("MessageFrame", "QCS_MessageFrame", UIParent)
        QCS_MessageFrame:SetPoint("TOP", UIParent, "TOP", 0, -200)
        QCS_MessageFrame:SetSize(512, 60)
        QCS_MessageFrame:SetInsertMode("TOP")
        QCS_MessageFrame:SetFading(true)
        QCS_MessageFrame:SetFadeDuration(1.5)
        QCS_MessageFrame:SetTimeVisible(2.5)
        QCS_MessageFrame:SetFontObject(GameFontNormalHuge)
    end

    -- Event frame to listen for UI_INFO_MESSAGE and show our colored text
    if not QCS_InfoEventFrame then
        QCS_InfoEventFrame = CreateFrame("Frame", "QCS_InfoEventFrame")
        QCS_InfoEventFrame:RegisterEvent("UI_INFO_MESSAGE")
        QCS_InfoEventFrame:SetScript("OnEvent", function(_, event, messageType, message)
            if event ~= "UI_INFO_MESSAGE" or not QCS_ColorProgress then return end
            if type(message) ~= "string" then return end

            -- Match messages like: "Boars slain: 4/8"
            local label, cur, total = message:match("^(.+):%s*(%d+)%s*/%s*(%d+)$")
            if not (label and cur and total) then return end

            cur, total = tonumber(cur), tonumber(total)
            local progress = (total and total > 0) and math.min(1, math.max(0, cur / total)) or 0
            local colorCode = QCS_GetProgressColor(progress)

            -- Show colored message on our own frame
            QCS_MessageFrame:AddMessage(colorCode .. message .. "|r")

            if QCS_DebugTrack then
                print(string.format("|cff9999ff[QCS Debug]|r Custom UI_INFO_MESSAGE: %s (%d/%d, %.2f)",
                    label, cur or -1, total or -1, progress))
            end
        end)
    end
end

------------------------------------------------------------
-- Slash command
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
        local s = QCS_AutoTrack and "|cff00ff00ON|r" or "|cffff0000OFF|r"
        print("|cff33ff99QCS:|r Auto-tracking is currently " .. s)

    elseif msg == "color on" then
        QCS_ColorProgress = true
        QCS_EnableCustomInfoMessages()
        print("|cff33ff99QCS:|r Progress colorization is now |cff00ff00ON|r.")
        print("|cff9999ff[QCS Preview]|r Example progression colors:")
        print(QCS_GetProgressColor(0.0) .. "0/8 Wolves Slain|r")
        print(QCS_GetProgressColor(0.5) .. "4/8 Wolves Slain|r")
        print(QCS_GetProgressColor(1.0) .. "8/8 Wolves Slain|r")
        print("|cff00ff00" .. "1/1 Artifact Found|r")
    elseif msg == "color off" then
        UIErrorsFrame:RegisterEvent("UI_INFO_MESSAGE")
        QCS_ColorProgress = false
        print("|cff33ff99QCS:|r Progress colorization is now |cffff0000OFF|r.")
    elseif msg == "color" then
        local s = QCS_ColorProgress and "|cff00ff00ON|r" or "|cffff0000OFF|r"
        print("|cff33ff99QCS:|r Progress colorization is currently " .. s)
        if QCS_ColorProgress then
            print("|cff9999ff[QCS Preview]|r Example: " .. QCS_GetProgressColor(0.5) .. "4/8 Wolves Slain|r")
        end

    elseif msg == "splash on" then
        QCS_ShowSplash = true
        print("|cff33ff99QCS:|r Splash screen is now |cff00ff00ON|r.")
    elseif msg == "splash off" then
        QCS_ShowSplash = false
        print("|cff33ff99QCS:|r Splash screen is now |cffff0000OFF|r.")
    elseif msg == "splash" then
        local s = QCS_ShowSplash and "|cff00ff00ON|r" or "|cffff0000OFF|r"
        print("|cff33ff99QCS:|r Splash screen is currently " .. s)

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
        local s = QCS_DebugTrack and "|cff00ff00ON|r" or "|cffff0000OFF|r"
        print("|cff33ff99QCS:|r Debug tracking is now " .. s)

    elseif msg == "reset" then
        QCS_Init(true)
        print("|cff33ff99QCS:|r Settings restored.")
    else
        QCS_Help()
    end
end

------------------------------------------------------------
-- Event registration & handler
------------------------------------------------------------
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("QUEST_ACCEPTED")
f:RegisterEvent("QUEST_LOG_UPDATE")

f:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        QCS_Init()
        if QCS_ShowSplash then
            local version, atState, spState, coState = QCS_GetStateStrings()
            print("|cff33ff99----------------------------------------|r")
            print("|cff33ff99QuestCompleteSound (QCS)|r |cff888888v" .. version .. "|r loaded.")
            print("|cff33ff99AutoTrack:|r " .. atState .. "  |cff33ff99Splash:|r " .. spState .. "  |cff33ff99Color:|r " .. coState)
            print("|cffccccccType |cff00ff00/qcs help|r for command list.|r")
            print("|cff33ff99----------------------------------------|r")
        end

elseif event == "QUEST_ACCEPTED" then
    local arg1, arg2 = ...
    local questIndex, questID = arg1, arg2

    if QCS_AutoTrack then
        -- Detect Classic environment: no C_TaskQuest or missing C_QuestLog.GetTitleForQuestID
        local isClassic = (not C_TaskQuest) or (not C_QuestLog or not C_QuestLog.GetTitleForQuestID)

        if not isClassic and questID and C_QuestLog then
            ------------------------------------------------------------
            -- Modern / Retail clients
            ------------------------------------------------------------
            QCS_TryAutoTrack(questID)

        elseif questIndex and AddQuestWatch then
            ------------------------------------------------------------
            -- Classic / SoD / Hardcore clients
            ------------------------------------------------------------
            local function doTrack()
                local title, _, _, isHeader = GetQuestLogTitle(questIndex)
                if not isHeader then
                    AddQuestWatch(questIndex)

                    -- Force the watch frame / tracker to refresh
                    if QuestWatch_Update then
                        QuestWatch_Update()
                    elseif WatchFrame_Update then
                        WatchFrame_Update()
                    elseif ObjectiveTracker_Update then
                        ObjectiveTracker_Update()
                    end

                    if QCS_DebugTrack then
                        print(string.format("|cff9999ff[QCS Debug]|r Classic auto-tracked and refreshed: %s (index %d)", title or "Unknown quest", questIndex))
                    else
                        print("And |cff33ff99QCS|r auto-tracked it")
                    end
                elseif QCS_DebugTrack then
                    print(string.format("|cff9999ff[QCS Debug]|r Skipped header entry at index %d", questIndex))
                end
            end

            -- Delay a bit so quest appears in log first
            if C_Timer and C_Timer.After then
                C_Timer.After(0.3, doTrack)
            else
                local delayFrame = CreateFrame("Frame")
                local t0 = GetTime()
                delayFrame:SetScript("OnUpdate", function(self)
                    if GetTime() - t0 > 0.3 then
                        doTrack()
                        self:SetScript("OnUpdate", nil)
                    end
                end)
            end
        elseif QCS_DebugTrack then
            print("|cff9999ff[QCS Debug]|r Could not auto-track quest; no valid API for this client.")
        end
    end


    elseif event == "QUEST_LOG_UPDATE" then
        QCS_CheckQuestProgress()
    end
end)

------------------------------------------------------------
-- UIErrorsFrame quest progress colorization (Retail safe)
------------------------------------------------------------
do
    local orig_UIErrorsFrame_OnEvent = UIErrorsFrame_OnEvent

    -- Helper: normalize objective text
    local function NormalizeLabel(text)
        if not text or text == "" then return nil end
        text = text:lower():gsub("^%s+", ""):gsub("%s+$", "")
        text = text:gsub("[:%.,;!%s]+$", "")
        return text
    end

    -- Check if label matches any active quest objective
    local function IsQuestObjectiveLabel(label)
        if not label then return false end
        local wanted = NormalizeLabel(label)
        if not wanted then return false end
        local numEntries = C_QuestLog.GetNumQuestLogEntries()
        for i = 1, numEntries do
            local info = C_QuestLog.GetInfo(i)
            if info and not info.isHeader and info.questID then
                local objectives = C_QuestLog.GetQuestObjectives(info.questID)
                if objectives then
                    for _, obj in ipairs(objectives) do
                        local txt = rawget(obj, "text")
                        if type(txt) == "string" then
                            local norm = NormalizeLabel(txt)
                            if norm and (norm == wanted or norm:find(wanted, 1, true) or wanted:find(norm, 1, true)) then                                
                                return true
                            end
                        end
                    end
                end
            end
        end
        return false
    end

    UIErrorsFrame_OnEvent = function(frame, event, ...)
        if event == "UI_INFO_MESSAGE" and QCS_ColorProgress then
            local message, chatType, holdTime = ...
            local label, cur, total = tostring(message):match("^(.+):%s*(%d+)%s*/%s*(%d+)$")
            if label and cur and total then
                cur, total = tonumber(cur), tonumber(total)
                if IsQuestObjectiveLabel(label) then
                    local progress = math.min(1, math.max(0, cur / total))
                    local color = QCS_GetProgressColor(progress)
                    if QCS_DebugTrack then
                        print(string.format("|cff9999ff[QCS Debug]|r Colorized quest progress: %s (%d/%d, %.2f)",
                            label, cur, total, progress))
                    end
                    message = color .. message .. "|r"
                    return orig_UIErrorsFrame_OnEvent(frame, event, message, chatType, holdTime)
                end
            end
        end
        return orig_UIErrorsFrame_OnEvent(frame, event, ...)
    end
end

------------------------------------------------------------
-- QCS: Retail-safe custom display for UI_INFO_MESSAGE
-- Suppress Blizzard UIErrorsFrame and show colorized progress
------------------------------------------------------------
local function QCS_EnableCustomInfoMessages()
    -- Disable Blizzard's default UI_INFO_MESSAGE on UIErrorsFrame (so it won't show yellow lines)
    if UIErrorsFrame and UIErrorsFrame.UnregisterEvent then
        UIErrorsFrame:UnregisterEvent("UI_INFO_MESSAGE")
        if QCS_DebugTrack then
            print("|cff33ff99QCS:|r Disabled Blizzard UI_INFO_MESSAGE display.")
        end
    end

    -- Create (or reuse) our own message frame
    if not QCS_MessageFrame then
        QCS_MessageFrame = CreateFrame("MessageFrame", "QCS_MessageFrame", UIParent)
        QCS_MessageFrame:SetPoint("TOP", UIParent, "TOP", 0, -200)
        QCS_MessageFrame:SetSize(512, 60)
        QCS_MessageFrame:SetInsertMode("TOP")
        QCS_MessageFrame:SetFading(true)
        QCS_MessageFrame:SetFadeDuration(1.5)
        QCS_MessageFrame:SetTimeVisible(2.5)
        QCS_MessageFrame:SetFontObject(GameFontNormalHuge)
    end

    -- Event frame to listen for UI_INFO_MESSAGE and show our colored text
    if not QCS_InfoEventFrame then
        QCS_InfoEventFrame = CreateFrame("Frame", "QCS_InfoEventFrame")
        QCS_InfoEventFrame:RegisterEvent("UI_INFO_MESSAGE")
        QCS_InfoEventFrame:SetScript("OnEvent", function(_, event, messageType, message)
            if event ~= "UI_INFO_MESSAGE" or not QCS_ColorProgress then return end
            if type(message) ~= "string" then return end

            -- Match messages like: "Boars slain: 4/8"
            local label, cur, total = message:match("^(.+):%s*(%d+)%s*/%s*(%d+)$")
            if not (label and cur and total) then return end

            cur, total = tonumber(cur), tonumber(total)
            local progress = (total and total > 0) and math.min(1, math.max(0, cur / total)) or 0
            local colorCode = QCS_GetProgressColor(progress)

            -- Show colored message on our own frame
            QCS_MessageFrame:AddMessage(colorCode .. message .. "|r")

            if QCS_DebugTrack then
                print(string.format("|cff9999ff[QCS Debug]|r Custom UI_INFO_MESSAGE: %s (%d/%d, %.2f)",
                    label, cur or -1, total or -1, progress))
            end
        end)
    end
end

-- Ensure UI is ready before changing Blizzard frames
local QCS_InfoInit = CreateFrame("Frame")
QCS_InfoInit:RegisterEvent("PLAYER_LOGIN")
QCS_InfoInit:SetScript("OnEvent", function()
    if QCS_ColorProgress then
        QCS_EnableCustomInfoMessages()
    end
end)
