TacticalDisplay = TacticalDisplay or {}
TacticalDisplay.Settings = TacticalDisplay.Settings or {}
local _Settings = TacticalDisplay.Settings
local _Data = TacticalDisplay.Data
local _Panel = TacticalDisplay.Panel
local _LibAddonMenu2 = LibAddonMenu2

local _config
local _defaults = {
    enabled = true,
    panelEnabled = true,
    debugLog = false
}

local SAVED_VARS_VERSION = 2

local function ApplySettings()
    if _config.enabled then
        _Data.Enable()
    else
        _Data.Disable()
    end

    if _config.enabled and _config.panelEnabled then
        _Panel.Enable()
    else
        _Panel.Disable()
    end
end

local function UpdateParameters()
    _Data.SetLogLevel(_config.debugLog)
end

local function CreateSettingsUI()
    _LibAddonMenu2:RegisterAddonPanel("TacticalDisplayOptions", {
        type = "panel",
        name = "Tactical Display",
        displayName = "Tactical Display",
        author = "moo",
        registerForRefresh = true,
        registerForDefaults = true,
    })

    _LibAddonMenu2:RegisterOptionControls("TacticalDisplayOptions", {
        {
            type = "checkbox",
            name = "Enable Combat Tracking",
            getFunc = function()
                return _config.enabled
            end,
            setFunc = function(enabled)
                _config.enabled = enabled
                ApplySettings()
            end,
        },
        {
            type = "checkbox",
            name = "Enable Debug Logging",
            getFunc = function()
                return _config.debugLog
            end,
            setFunc = function(enabled)
                _config.debugLog = enabled
                UpdateParameters()
            end,
        },
        {
            type = "submenu",
            name = "Opponents Panel",
            disabled = function()
                return not _config.enabled
            end,
            controls = {
                {
                    type = "checkbox",
                    name = "Enable Panel",
                    getFunc = function()
                        return _config.panelEnabled
                    end,
                    setFunc = function(enabled)
                        _config.panelEnabled = enabled
                        ApplySettings()
                    end,
                },
                {
                    type = "button",
                    name = "Reset panel layout",
                    disabled = function()
                        return not _config.panelEnabled
                    end,
                    func = function()
                        _Panel.ResetLayout()
                    end,
                },
            },
        },
    })
end

function _Settings.CreateSavedVars()
    return ZO_SavedVars:NewAccountWide("TacticalDisplaySavedVariables", SAVED_VARS_VERSION, nil, {})
end

function _Settings.Initialize(savedVars)
    savedVars.settings = savedVars.settings or _defaults
    _config = savedVars.settings

    CreateSettingsUI()
    ApplySettings()
end
