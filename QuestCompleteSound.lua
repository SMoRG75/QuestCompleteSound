------------------------------------------------------------
-- QuestCompleteSound v1.3.1 by SMoRG75
-- Retail-only. Plays a sound when a quest's objectives are completed.
-- Optional auto-tracking for newly accepted quests.
-- Now with throttled updates, QCS/QCS_DB table structure, and richer debug.
------------------------------------------------------------

local QCS = {}          -- addon namespace table
local f = CreateFrame("Frame")

------------------------------------------------------------
-- Defaults
------------------------------------------------------------
QCS.defaults = {
    AutoTrack     = false,
    DebugTrack    = false,
    ShowSplash    = true,
    ColorProgress = false,
    HideDoneAchievements = false
}

------------------------------------------------------------
-- Internal utils
------------------------------------------------------------
local function dprint(...)
    if QCS.DB.DebugTrack then
        print("|cff9999ff[QCS Debug]|r", ...)
    end
end

local function safe_pcall(fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok and QCS.DB.DebugTrack then
        dprint("pcall error:", err)
    end
    return ok
end

local function clamp01(x)
    if x ~= x then return 0 end
    if x < 0 then return 0 end
    if x > 1 then return 1 end
    return x
end

------------------------------------------------------------
-- Apply the achievement filter according to saved setting
------------------------------------------------------------
local function QCS_ApplyAchievementFilter()
    if not C_AddOns.IsAddOnLoaded("Blizzard_AchievementUI") then return end

    local filter = QCS.DB.HideDoneAchievements and ACHIEVEMENT_FILTER_INCOMPLETE or ACHIEVEMENT_FILTER_ALL

    if AchievementFrame and AchievementFrame_SetFilter then
        AchievementFrame_SetFilter(filter)

        -- Update dropdown UI
        if AchievementFrame.Header and AchievementFrame.Header.FilterDropDown then
            UIDropDownMenu_SetSelectedValue(AchievementFrame.Header.FilterDropDown, filter)
        end

        -- Refresh category tree so change is visible immediately
        if AchievementFrameCategories_Update then
            AchievementFrameCategories_Update()
        end
    end
end

------------------------------------------------------------
-- QCS_Init & Reset: ensure saved variables exist
------------------------------------------------------------
function QCS.Init(reset)
    -- Ensure SavedVariables table exists
    if reset or type(QCS_DB) ~= "table" then
        QCS_DB = {}
    end

    -- Apply defaults into QCS_DB without clobbering user values
    for k, v in pairs(QCS.defaults) do
        if QCS_DB[k] == nil then
            QCS_DB[k] = v
        end
    end

    -- Bind runtime DB reference
    QCS.DB = QCS_DB

    if reset then
        print("|cff33ff99QCS:|r All settings have been reset to defaults.")

        -- 🟢 Apply Achievement filter after reset
        if not C_AddOns.IsAddOnLoaded("Blizzard_AchievementUI") then
            C_AddOns.LoadAddOn("Blizzard_AchievementUI")
        end
        C_Timer.After(0.1, function()
            QCS_ApplyAchievementFilter()
            print("|cff33ff99QCS:|r Achievement filter reset to show all achievements.")
        end)
    end
end

------------------------------------------------------------
-- Get version (Retail APIs)
------------------------------------------------------------
local function QCS_GetVersion()
    return C_AddOns.GetAddOnMetadata("QuestCompleteSound", "Version")
end

local function QCS_GetStateStrings()
    local version = QCS_GetVersion()
    local atState = QCS.DB.AutoTrack     and "|cff00ff00ON|r" or "|cffff0000OFF|r"
    local spState = QCS.DB.ShowSplash    and "|cff00ff00ON|r" or "|cffff0000OFF|r"
    local coState = QCS.DB.ColorProgress and "|cff00ff00ON|r" or "|cffff0000OFF|r"
    local loState = QCS.DB.HideDoneAchievements and "|cff00ff00ON|r" or "|cffff0000OFF|r"
    return version, atState, spState, coState, loState
end

------------------------------------------------------------
-- Color utilities
------------------------------------------------------------
local function QCS_GetProgressColor(progress)
    progress = clamp01(progress or 0)
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
    local R = math.floor(r * 255 + 0.5)
    local G = math.floor(g * 255 + 0.5)
    return string.format("|cff%02x%02x%02x", R, G, 0)
end

------------------------------------------------------------
-- Colorize tracker objective lines (Retail tracker)
-- Throttled to avoid excess work during rapid updates.
------------------------------------------------------------
QCS._recolorPending = false
QCS._lastRecolorAt  = 0

local function QCS_RecolorQuestObjectives_Impl()
    if not QCS.DB.ColorProgress then return end
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
                        local block = ObjectiveTrackerBlocksFrame and ObjectiveTrackerBlocksFrame:GetBlock(info.questID)
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

local function QCS_RecolorQuestObjectives_Throttle()
    if QCS._recolorPending then return end
    QCS._recolorPending = true
    C_Timer.After(0.2, function()
        QCS_RecolorQuestObjectives_Impl()
        QCS._recolorPending = false
        QCS._lastRecolorAt = GetTimePreciseSec()
    end)
end

------------------------------------------------------------
-- Custom colored UI_INFO_MESSAGE (Retail-safe)
------------------------------------------------------------
local function QCS_EnableCustomInfoMessages()
    if UIErrorsFrame and UIErrorsFrame.UnregisterEvent then
        UIErrorsFrame:UnregisterEvent("UI_INFO_MESSAGE")
        dprint("Disabled Blizzard UI_INFO_MESSAGE display.")
    end

    if not QCS.MessageFrame then
        QCS.MessageFrame = CreateFrame("MessageFrame", "QCS_MessageFrame", UIParent)
        QCS.MessageFrame:SetPoint("TOP", UIParent, "TOP", 0, -150)
        QCS.MessageFrame:SetSize(512, 60)
        QCS.MessageFrame:SetInsertMode("TOP")
        QCS.MessageFrame:SetFading(true)
        QCS.MessageFrame:SetFadeDuration(1.5)
        QCS.MessageFrame:SetTimeVisible(2.5)
        -- Use explicit font to avoid dependency on UI object availability
        QCS.MessageFrame:SetFont("Fonts\\FRIZQT__.TTF", 24, "OUTLINE")
    end

    if not QCS.InfoEventFrame then
        QCS.InfoEventFrame = CreateFrame("Frame", "QCS_InfoEventFrame")
        QCS.InfoEventFrame:RegisterEvent("UI_INFO_MESSAGE")
        QCS.InfoEventFrame:SetScript("OnEvent", function(_, event, messageType, message)
            if event ~= "UI_INFO_MESSAGE" or not QCS.DB.ColorProgress then return end
            if type(message) ~= "string" then return end

            local label, cur, total = message:match("^(.+):%s*(%d+)%s*/%s*(%d+)$")
            if not (label and cur and total) then return end

            cur, total = tonumber(cur), tonumber(total)
            local progress = (total and total > 0) and clamp01(cur / total) or 0
            local colorCode = QCS_GetProgressColor(progress)

            QCS.MessageFrame:AddMessage(colorCode .. message .. "|r")

            dprint(string.format("Custom UI_INFO_MESSAGE: %s (%d/%d, %.2f)",
                label, cur or -1, total or -1, progress))
        end)
    end
end

------------------------------------------------------------
-- Helpers: trackable types
------------------------------------------------------------
local function QCS_HandleTrackableTypes(questID)
    -- Bonus objectives / task quests: don't try to add a watch (Blizzard handles these automatically)
    if C_QuestLog.IsQuestTask(questID) then
        dprint("Skipping task/bonus objective:", questID)
        return "skip"
    end

    -- World quests: use the correct API if available
    if C_QuestLog.IsWorldQuest(questID) then
        if C_QuestLog.AddWorldQuestWatch then
            local ok = safe_pcall(function() C_QuestLog.AddWorldQuestWatch(questID) end)
            if ok then
                dprint("Added world quest watch:", questID)
                return "done"
            end
        end
        dprint("Could not add world quest watch:", questID)
        return "skip"
    end

    return "normal" -- regular quest, OK to track
end

------------------------------------------------------------
-- Auto-track
------------------------------------------------------------
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
    if C_QuestLog.GetQuestWatchType(questID) then
        dprint("Already tracked:", title)
        return
    end

    dprint("Attempting to track:", title)

    C_QuestLog.AddQuestWatch(questID)
    print("And |cff33ff99QCS|r auto-tracked it")

end

------------------------------------------------------------
-- Splash
------------------------------------------------------------
local function QCS_Splash()
    local version, atState, spState, coState, loState = QCS_GetStateStrings()
    print("|cff33ff99-----------------------------------|r")
    print("|cff33ff99QuestCompleteSound (QCS)|r |cffffffffv" .. version .. "|r")
    print("|cff33ff99------------------------------------------------------------------------------|r")
    print("|cff33ff99AutoTrack:|r " .. atState .. "  |cff33ff99Splash:|r " .. spState .. "  |cff33ff99ColorProgress:|r " .. coState .. "  |cff33ff99HideDoneAchievements:|r " .. loState)
    print("|cffccccccType |cff00ff00/qcs help|r for command list.|r")
    print("|cff33ff99------------------------------------------------------------------------------|r")
end

------------------------------------------------------------
-- Event: QUEST_LOG_UPDATE (play sound when quest ready)
------------------------------------------------------------
QCS.fullyCompleted = {}

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

                -- If all objectives done and not previously marked complete
                if allDone and not QCS.fullyCompleted[info.questID] then
                    QCS.fullyCompleted[info.questID] = true
                    PlaySound(6199, "Master")

                    -- Determine quest type
                    local isTask = C_QuestLog.IsQuestTask(info.questID)
                    local isWorld = C_QuestLog.IsWorldQuest(info.questID)

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
end

------------------------------------------------------------
-- Help
------------------------------------------------------------
local function QCS_Help()
    local version, atState, spState, coState, loState = QCS_GetStateStrings()
    print("|cff33ff99-----------------------------------|r")
    print("|cff33ff99QuestCompleteSound (QCS)|r |cffffffffv" .. version .. "|r")
    print("|cff33ff99-----------------------------------|r")
    print("|cff00ff00/qcs autotrack|r   |cffcccccc- Toggle automatic quest tracking|r")
    print("|cff00ff00/qcs at|r          |cffcccccc- Shorthand for autotrack|r")
    print("|cff00ff00/qcs color|r       |cffcccccc- Toggle progress colorization|r")
    print("|cff00ff00/qcs col|r         |cffcccccc- Shorthand for color|r")
    print("|cff00ff00/qcs hideach|r     |cffcccccc- Toggle hiding completed achievements|r")
    print("|cff00ff00/qcs ha|r          |cffcccccc- Shorthand for hideach|r")
    print("|cff00ff00/qcs splash|r      |cffcccccc- Toggle splash on login|r")
    print("|cff00ff00/qcs debugtrack|r  |cffcccccc- Toggle verbose tracking debug|r")
    print("|cff00ff00/qcs dbg|r         |cffcccccc- Shorthand for debugtrack|r")
    print("|cff00ff00/qcs reset|r       |cffcccccc- Reset all settings to defaults|r")
    print("|cff33ff99------------------------------------------------------------------------------|r")
    print("|cff33ff99AutoTrack:|r " .. atState .. "  |cff33ff99Splash:|r " .. spState .. "  |cff33ff99ColorProgress:|r " .. coState .. "  |cff33ff99HideDoneAchievements:|r " .. loState)
    print("|cff33ff99------------------------------------------------------------------------------|r")
end

------------------------------------------------------------
-- Slash commands
------------------------------------------------------------
SLASH_QCS1 = "/qcs"
SlashCmdList["QCS"] = function(msg)
    msg = string.lower(msg or "")

    local function toggle(key, label)
        QCS.DB[key] = not QCS.DB[key]
        local s = QCS.DB[key] and "|cff00ff00ON|r" or "|cffff0000OFF|r"
        print("|cff33ff99QCS:|r " .. label .. " " .. s)
    end

    if msg == "autotrack" or msg == "at" then
        toggle("AutoTrack", "Auto-track is")

    elseif msg == "color" or msg == "col" then
        toggle("ColorProgress", "Progress colorization is")
        if QCS.DB.ColorProgress then
            QCS_EnableCustomInfoMessages()
        else
            if UIErrorsFrame and UIErrorsFrame.RegisterEvent then
                UIErrorsFrame:RegisterEvent("UI_INFO_MESSAGE")
            end
        end

    elseif msg == "splash" then
        toggle("ShowSplash", "Splash is")

    elseif msg == "debugtrack" or msg == "dbg" then
        toggle("DebugTrack", "Debug tracking")

    elseif msg == "hideach" or msg == "ha" then
        QCS.DB.HideDoneAchievements = not QCS.DB.HideDoneAchievements
        local s = QCS.DB.HideDoneAchievements and "|cff00ff00ON|r" or "|cffff0000OFF|r"
        print("|cff33ff99QCS:|r Hide completed achievements is " .. s)

        if not C_AddOns.IsAddOnLoaded("Blizzard_AchievementUI") then
            C_AddOns.LoadAddOn("Blizzard_AchievementUI")
        end

        QCS_ApplyAchievementFilter()

    elseif msg == "reset" then
        QCS.Init(true)

    elseif msg == "help" then
        QCS_Help()

    else
        local version, at, sp, co, lo = QCS_GetStateStrings()
        print("|cff33ff99QCS|r v" .. version .. " — AutoTrackQuests:" .. at .. " Splash:" .. sp .. " ColorProgress:" .. co .. " HideDoneAchievements:" .. lo)
        print("|cffccccccCommands:|r help for more info")
    end
end

------------------------------------------------------------
-- Events
------------------------------------------------------------
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("QUEST_ACCEPTED")
f:RegisterEvent("QUEST_LOG_UPDATE")
f:RegisterEvent("ADDON_LOADED")

f:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        QCS.Init()
        if QCS.DB.ShowSplash then
            QCS_Splash()
        end

        if QCS.DB.ColorProgress then
            QCS_EnableCustomInfoMessages()
        end

        -- Apply saved preference when logging in (only if already loaded)
        QCS_ApplyAchievementFilter()

     elseif event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == "Blizzard_AchievementUI" then
            C_Timer.After(0.1, QCS_ApplyAchievementFilter)
        end

    elseif event == "QUEST_ACCEPTED" then
        if not QCS.DB.AutoTrack then return end
        local a1, a2 = ...
        local questIndex, questID
        if a2 then questIndex, questID = a1, a2 else questID = a1 end
        if (not questID or questID == 0) and questIndex then
            local info = C_QuestLog.GetInfo(questIndex)
            if info and info.questID then
                questID = info.questID
                dprint("Recovered questID", questID, "from questIndex", questIndex)
            end
        end
        if questID then
            QCS_TryAutoTrack(questID)
        else
            dprint("Could not resolve questID on QUEST_ACCEPTED:", tostring(a1), tostring(a2))
        end

    elseif event == "QUEST_LOG_UPDATE" then
        QCS_CheckQuestProgress()
        QCS_RecolorQuestObjectives_Throttle()
    end
end)
