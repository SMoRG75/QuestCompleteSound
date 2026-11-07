------------------------------------------------------------
-- QuestCompleteSound - Option list, the Settings (Interface -> AddOns) page
-- and Blizzard's addon compartment menu (the TOC names the
-- QuestCompleteSound_OnAddonCompartment* globals below).
------------------------------------------------------------

local ADDON_NAME, QCS = ...

------------------------------------------------------------
-- Option list, used by the options popup
------------------------------------------------------------
-- kind defaults to "checkbox"; "dropdown" entries list their values.
-- Section icons are Interface\Icons files that every client has.
QCS.OptionSections = {
    {
        title = "Quest sounds",
        icon = "Interface\\Icons\\INV_Misc_Note_01",
        options = {
            { key = "QuestCompleteSound", label = "Quest completion sound",
              tooltip = "Play a sound when a quest is ready to turn in (or done for bonus/world quests)." },
            { key = "QuestObjectiveSound", label = "Quest objective completion sound",
              tooltip = "Play a worker voice line when one objective is completed but the quest is not yet done." },
            { key = "QuestSoundProfile", label = "Quest sound profile", kind = "dropdown",
              tooltip = "Choose the worker voice used for objective and full quest completion.",
              values = {
                  { value = "Horde", label = QCS.SoundProfiles.Horde.label },
                  { value = "Alliance", label = QCS.SoundProfiles.Alliance.label },
              } },
        },
    },
}

-- Returns the display label of a dropdown value.
function QCS.GetOptionValueLabel(option, value)
    for _, entry in ipairs(option.values or {}) do
        if entry.value == value then
            return entry.label
        end
    end
    return tostring(value)
end

------------------------------------------------------------
-- Settings category
------------------------------------------------------------
-- The AddOns page holds only a button that opens the options window, so
-- every route ends up in the same place.
local function QCS_CreateSettingsCategory()
    if not (Settings and type(Settings.RegisterCanvasLayoutCategory) == "function") then
        return
    end

    local panel = CreateFrame("Frame")

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -16)
    title:SetText("QuestCompleteSound")

    local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    button:SetSize(240, 26)
    button:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -16)
    button:SetText("Open the options window")
    button:SetScript("OnClick", function()
        local settingsPanel = rawget(_G, "SettingsPanel")
        if settingsPanel and settingsPanel:IsShown() then
            HideUIPanel(settingsPanel)
        end
        QCS.OptionsPopup_Open()
    end)

    local category = Settings.RegisterCanvasLayoutCategory(panel, "QuestCompleteSound")
    Settings.RegisterAddOnCategory(category)
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function()
    QCS_CreateSettingsCategory()
end)

------------------------------------------------------------
-- Addon compartment (named in QuestCompleteSound.toc)
------------------------------------------------------------
function QuestCompleteSound_OnAddonCompartmentClick()
    QCS.OptionsPopup_Toggle()
end

function QuestCompleteSound_OnAddonCompartmentEnter(_, menuButton)
    GameTooltip:SetOwner(menuButton, "ANCHOR_LEFT")
    GameTooltip:AddLine("QuestCompleteSound")
    GameTooltip:AddLine("|cffeda55fLeft-click|r to open options", 0.2, 1, 0.2)
    GameTooltip:Show()
end

function QuestCompleteSound_OnAddonCompartmentLeave()
    GameTooltip:Hide()
end
