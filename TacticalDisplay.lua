TacticalDisplay = TacticalDisplay or {}

local ADDON_NAME = "TacticalDisplay"
local LOAD_EVENT_NAME = "TacticalDisplay_Loaded"

local function OnAddonLoaded(_, addonName)
    if addonName ~= ADDON_NAME then
        return
    end

    EVENT_MANAGER:UnregisterForEvent(LOAD_EVENT_NAME, EVENT_ADD_ON_LOADED)

    local savedVars = ZO_SavedVars:NewAccountWide("TacticalDisplaySavedVariables", 1, nil,
        { enabled = true })
    savedVars.enabled = true

    TacticalDisplay.Data.Initialize(savedVars)
    TacticalDisplay.Panel.Initialize(savedVars)
    TacticalDisplay.Menu.Initialize(savedVars)

    TacticalDisplay.Data.ApplySettings(savedVars.enabled, TacticalDisplay.Panel.OnOpponentUpdated)
    TacticalDisplay.Panel.ApplySettings(savedVars.enabled)
end

EVENT_MANAGER:RegisterForEvent(LOAD_EVENT_NAME, EVENT_ADD_ON_LOADED, OnAddonLoaded)
