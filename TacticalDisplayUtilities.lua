TacticalDisplay = TacticalDisplay or {}
TacticalDisplay.Utilities = TacticalDisplay.Utilities or {}
local _Utilities = TacticalDisplay.Utilities

-------------------------------------------------------------------------------
-- Logging
-------------------------------------------------------------------------------

function _Utilities.LogDebug(message)
    d("[TacticalDisplay] |cCCCCCC" .. message .. "|r")
end

function _Utilities.LogError(message)
    d("[TacticalDisplay] |cFF3030" .. message .. "|r")
end
