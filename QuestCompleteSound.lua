local f = CreateFrame("Frame")

local fullyCompleted = {}

f:RegisterEvent("QUEST_LOG_UPDATE")

f:SetScript("OnEvent", function(self, event, ...)
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
                    -- Play sound when ALL objectives are done
                    PlaySound(6199, "Master")
                    print("Quest ready to turn in: " .. (info.title or info.questID))
                end
            end
        end
    end
end)
