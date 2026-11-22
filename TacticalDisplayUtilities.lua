TacticalDisplay = TacticalDisplay or {}
TacticalDisplay.Utilities = TacticalDisplay.Utilities or {}
local _Utilities = TacticalDisplay.Utilities

-------------------------------------------------------------------------------
-- Basics
-------------------------------------------------------------------------------

function _Utilities.ClearTable(tbl)
    for key in pairs(tbl) do
        tbl[key] = nil
    end
end

function _Utilities.CountTable(table)
    local count = 0
    for _ in pairs(table) do
        count = count + 1
    end
    return count
end

-------------------------------------------------------------------------------
-- Logging
-------------------------------------------------------------------------------

function _Utilities.LogDebug(message)
    d("[TacticalDisplay] |cCCCCCC" .. message .. "|r")
end

function _Utilities.LogError(message)
    d("[TacticalDisplay] |cFF3030" .. message .. "|r")
end
