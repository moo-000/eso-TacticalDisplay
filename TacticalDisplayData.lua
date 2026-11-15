TacticalDisplay = TacticalDisplay or {}
TacticalDisplay.Data = TacticalDisplay.Data or {}
local _Data = TacticalDisplay.Data
local _CheckHiddenAbility = TacticalDisplay.Base.CheckHiddenAbility
local _GetMeasurablePlayerDamage = TacticalDisplay.Base.GetMeasurablePlayerDamage
local _LogError = TacticalDisplay.Utilities.LogError
local _LogDebug = TacticalDisplay.Utilities.LogDebug

local _debugLog               -- boolean
local _opponentTable          -- [source_or_target] = opponent data, see GetOrCreateOpponent()
local _onOpponentUpdated = {} -- [caller_id] = func callback(opponent)
_Data.OnOpponentUpdated = _onOpponentUpdated

local INCLUDED_ACTION_RESULTS = {
    ACTION_RESULT_DAMAGE,
    ACTION_RESULT_CRITICAL_DAMAGE,
    ACTION_RESULT_DOT_TICK,
    ACTION_RESULT_DOT_TICK_CRITICAL,
    -- ACTION_RESULT_REFLECTED_DAMAGE, -- can't include as it'd mess up profile.
    ACTION_RESULT_BLOCKED_DAMAGE,
    ACTION_RESULT_DAMAGE_SHIELDED,
}

local BLOCKED_ACTION_RESULTS = {
    [ACTION_RESULT_BLOCKED_DAMAGE] = true,
}

local CRITICAL_ACTION_RESULTS = {
    [ACTION_RESULT_CRITICAL_DAMAGE] = true,
    [ACTION_RESULT_DOT_TICK_CRITICAL] = true,
}

local function GetOrCreateOpponent(key)
    local opponent = _opponentTable[key]
    if not opponent then
        opponent = {
            name = key,
            lastSeen = 0,
            lastDealtAttack = nil,
            -- {
            --     abilityId = 123,
            --     abilityIcon = nil,
            --     abilityName = "Bash",
            --     damage = 100,
            --     critical = true,
            --     blocked = false,
            -- },
            lastBaseDamage = 0,
            lastMitigation = 0,
        }
        _opponentTable[key] = opponent
    end
    return opponent
end

local function InvokeOnOpponentUpdated(opponent)
    for _, callback in pairs(_onOpponentUpdated) do
        if callback then
            callback(opponent)
        end
    end
end

local function OnIncomingCombatEvent(
    eventCode,
    result,
    isError,
    abilityName,
    abilityGraphic,
    abilityActionSlotType,
    sourceName,
    sourceType,
    targetName,
    targetType,
    hitValue,
    powerType,
    damageType,
    log,
    sourceUnitId,
    targetUnitId,
    abilityId,
    overflow
)
    if not hitValue or hitValue <= 0
        or not sourceName or sourceName == ""
        or not abilityName or abilityName == ""
        or _CheckHiddenAbility(result, abilityId, abilityName) then
        return
    end

    -- ignore environment damage
    if targetType == COMBAT_UNIT_TYPE_PLAYER and sourceType == COMBAT_UNIT_TYPE_PLAYER then
        return
    end

    local blocked = BLOCKED_ACTION_RESULTS[result]
    local critical = CRITICAL_ACTION_RESULTS[result]
    local damage = hitValue + overflow

    local opponentKey = zo_strformat(SI_UNIT_NAME, sourceName)
    local opponent = GetOrCreateOpponent(opponentKey)
    opponent.lastSeen = GetTimeStamp()
    opponent.lastDealtAttack = {
        abilityId = abilityId,
        abilityName = abilityName,
        abilityIcon = abilityId and GetAbilityIcon(abilityId) or nil,
        damage = damage,
        critical = critical,
        blocked = blocked
    }

    if not blocked and not critical
        and abilityActionSlotType == ACTION_SLOT_TYPE_LIGHT_ATTACK
        and overflow == 0 then
        opponent.lastBaseDamage = damage
    end

    if _debugLog then
        _LogDebug(string.format("Incoming from [%s]: %d %s, %d+%d %s(base %d)",
            opponentKey, abilityId, abilityName,
            hitValue, overflow, (critical and "C" or "") .. (blocked and "B" or ""),
            opponent.lastBaseDamage))
    end

    InvokeOnOpponentUpdated(opponent)
end

local function OnOutgoingCombatEvent(
    eventCode,
    result,
    isError,
    abilityName,
    abilityGraphic,
    abilityActionSlotType,
    sourceName,
    sourceType,
    targetName,
    targetType,
    hitValue,
    powerType,
    damageType,
    log,
    sourceUnitId,
    targetUnitId,
    abilityId,
    overflow
)
    if isError or not hitValue or hitValue <= 0
        or not targetName or targetName == ""
        or not abilityName or abilityName == ""
        or _CheckHiddenAbility(result, abilityId, abilityName) then
        return
    end

    -- ignore environment damage
    if targetType == COMBAT_UNIT_TYPE_PLAYER and sourceType == COMBAT_UNIT_TYPE_PLAYER then
        return
    end

    local blocked = BLOCKED_ACTION_RESULTS[result]
    local critical = CRITICAL_ACTION_RESULTS[result]

    local opponentKey = zo_strformat(SI_UNIT_NAME, targetName)
    local opponent = GetOrCreateOpponent(opponentKey)
    opponent.lastSeen = GetTimeStamp()

    if not blocked and not critical and overflow == 0 then
        local castedDamage = _GetMeasurablePlayerDamage(abilityId)
        if castedDamage > 0 then
            local receivedDamage = hitValue
            local mitigation = math.floor((1 - receivedDamage / castedDamage) * 100 + 0.5)
            if mitigation >= 0 then
                opponent.lastMitigation = mitigation
                if _debugLog then
                    _LogDebug(string.format("Update mitigation %d %s %d => %s %d, mitigated %d%%",
                        abilityId, abilityName, castedDamage,
                        opponentKey, receivedDamage, mitigation))
                end
            end
        end
    end

    if _debugLog then
        _LogDebug(string.format("Outgoing to [%s]: %d %s, %d+%d %s(%d%%)",
            opponentKey, abilityId, abilityName,
            hitValue, overflow, (critical and "C" or "") .. (blocked and "B" or ""),
            opponent.lastMitigation))
    end

    InvokeOnOpponentUpdated(opponent)
end

local INCOMING_COMBAT_EVENT_PREFIX = "TacticalDisplay_Data_Combat_In_"
local OUTGOING_COMBAT_EVENT_PREFIX = "TacticalDisplay_Data_Combat_Out_"

local function RegisterCombatEvent()
    for _, actionResult in ipairs(INCLUDED_ACTION_RESULTS) do
        local incomingCombatEvent = INCOMING_COMBAT_EVENT_PREFIX .. tostring(actionResult)
        EVENT_MANAGER:RegisterForEvent(incomingCombatEvent, EVENT_COMBAT_EVENT, OnIncomingCombatEvent)
        if not EVENT_MANAGER:AddFilterForEvent(
                incomingCombatEvent,
                EVENT_COMBAT_EVENT,
                REGISTER_FILTER_IS_ERROR, false,
                ---@diagnostic disable-next-line: redundant-parameter
                REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER,
                ---@diagnostic disable-next-line: redundant-parameter
                REGISTER_FILTER_COMBAT_RESULT, actionResult
            ) then
            _LogError(string.format("Failed to apply filter for %s", incomingCombatEvent))
        end

        local outgoingCombatEvent = OUTGOING_COMBAT_EVENT_PREFIX .. tostring(actionResult)
        EVENT_MANAGER:RegisterForEvent(outgoingCombatEvent, EVENT_COMBAT_EVENT, OnOutgoingCombatEvent)
        if not EVENT_MANAGER:AddFilterForEvent(
                outgoingCombatEvent,
                EVENT_COMBAT_EVENT,
                REGISTER_FILTER_IS_ERROR, false,
                ---@diagnostic disable-next-line: redundant-parameter
                REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER,
                ---@diagnostic disable-next-line: redundant-parameter
                REGISTER_FILTER_COMBAT_RESULT, actionResult
            ) then
            _LogError(string.format("Failed to apply filter for %s", outgoingCombatEvent))
        end
    end
end

local function UnregisterCombatEvent()
    for _, actionResult in ipairs(INCLUDED_ACTION_RESULTS) do
        EVENT_MANAGER:UnregisterForEvent(INCOMING_COMBAT_EVENT_PREFIX .. tostring(actionResult), EVENT_COMBAT_EVENT)
        EVENT_MANAGER:UnregisterForEvent(OUTGOING_COMBAT_EVENT_PREFIX .. tostring(actionResult), EVENT_COMBAT_EVENT)
    end
end

function _Data.Initialize(savedVars)
    local serverName = GetWorldName()
    savedVars.data = savedVars.data or {}
    savedVars.data[serverName] = savedVars.data[serverName] or {}
    savedVars.data[serverName].opponentTable = savedVars.data[serverName].opponentTable or {}

    _opponentTable = savedVars.data[serverName].opponentTable
end

local _enabled = false

function _Data.Enable()
    if _enabled then
        return
    end
    RegisterCombatEvent()
    _enabled = true
end

function _Data.Disable()
    if not _enabled then
        return
    end
    UnregisterCombatEvent()
    _enabled = false
end

function _Data.SetLogLevel(debug)
    _debugLog = debug
end
