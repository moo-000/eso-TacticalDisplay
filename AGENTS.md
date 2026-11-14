# Tactical Display (ESO addon)

Source: https://github.com/moo-000/eso-TacticalDisplay

## Build

Run `_pack.bat` to create a zip file of this addon.

## Module Dependencies

Modules may depend on each other, and dependencies are made clear by declaring local references on top, e.g.

```lua
TacticalDisplay = TacticalDisplay or {}
TacticalDisplay.Settings = TacticalDisplay.Settings or {}
local _Settings = TacticalDisplay.Settings  -- current module
local _Data = TacticalDisplay.Data          -- dependency
local _Panel = TacticalDisplay.Panel        -- dependency
```

## Module Saved Variables

### Internal Variables

Internal variables not exposed on the Addon menu are managed by each module itself, by exposing an `Initialize(savedVars)` function to manage its internal settings, e.g.

```lua
local _config

function _Panel.Initialize(savedVars)
    savedVars.panel = savedVars.panel or {}
    _config = savedVars.panel
    _config.x = 123
    _config.y = 500
end
```

### Configurations

Configurations for the Addon menu are centralized in [TacticalDisplaySettings](TacticalDisplaySettings.lua).