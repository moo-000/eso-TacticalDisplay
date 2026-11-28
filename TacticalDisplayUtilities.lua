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

function _Utilities.CopyTable(orig)
    local copy = {}
    for k, v in pairs(orig) do
        copy[k] = v
    end
    return copy
end

function _Utilities.CountTable(tbl)
    local count = 0
    for _ in pairs(tbl) do
        count = count + 1
    end
    return count
end

function _Utilities.FillDefaults(tbl, defaults)
    for key, value in pairs(defaults) do
        if tbl[key] == nil then
            tbl[key] = value
        end
    end
end

function _Utilities.SortedKeys(tbl)
    local keyTable = {}
    for key in pairs(tbl) do
        keyTable[#keyTable + 1] = key
    end
    table.sort(keyTable)
    return keyTable
end

-------------------------------------------------------------------------------
-- Basics
-------------------------------------------------------------------------------

local _abilityIconCache = {}

function _Utilities.GetAbilityIconCached(abilityId)
    if not abilityId or abilityId == 0 then
        return nil
    end

    local icon = _abilityIconCache[abilityId]
    if icon == nil then
        icon = GetAbilityIcon(abilityId) or false
        _abilityIconCache[abilityId] = icon
    end
    return icon or nil
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
