TacticalDisplay = TacticalDisplay or {}
TacticalDisplay.Menu = TacticalDisplay.Menu or {}
local Menu = TacticalDisplay.Menu
local Panel = TacticalDisplay.Panel

local function CreateSettings()
    if not LibAddonMenu2 then
        return
    end

    LibAddonMenu2:RegisterAddonPanel("TacticalDisplayOptions", {
        type = "panel",
        name = "Tactical Display",
        displayName = "Tactical Display",
        author = "moo",
        version = TacticalDisplay.version,
        registerForRefresh = true,
        registerForDefaults = true,
    })

    LibAddonMenu2:RegisterOptionControls("TacticalDisplayOptions", {
        {
            type = "button",
            name = "Reset panel layout",
            func = function()
                Panel.ResetLayout()
            end,
        },
    })
end

function Menu.Initialize()
    CreateSettings()
end
