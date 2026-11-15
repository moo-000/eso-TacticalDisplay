TacticalDisplay = TacticalDisplay or {}
TacticalDisplay.Base = TacticalDisplay.Base or {}
local _Base = TacticalDisplay.Base

local _HIDDEN_ABILITIES = {
    -- Status effects
    [17897] = true,  -- "Frozen Weapon"
    [18084] = true,  -- "Burning"
    [21481] = true,  -- "Chilled"
    [21487] = true,  -- "Concussed"
    [21925] = true,  -- "Diseased"
    [21929] = true,  -- "Poisoned"
    [28919] = true,  -- "Life Drain"
    [45445] = true,  -- "Forceful"
    [46746] = true,  -- "Absorb Stamina"
    [46749] = true,  -- "Decrease Health"
    [80184] = true,  -- "Direwolf Lunge"
    [80189] = true,  -- "Direwolf Gnash"
    [80190] = true,  -- "Direwolf Gnash"
    [148800] = true, -- "Sundered"
    [148801] = true, -- "Hemorrhaging"
    [148797] = true, -- "Overcharged"
    [215779] = true, -- "Diseased"
}

local _VISIBLE_DOT_ABILITIES = {
    [17879] = true,  -- "Corrosive Armor"
    [126941] = true, -- "Maarselok"
    -- [226394] = true, -- "Pyrebrand"
}

local DOT_ACTION_RESULTS = {
    [ACTION_RESULT_DOT_TICK] = true,
    [ACTION_RESULT_DOT_TICK_CRITICAL] = true,
}

local _hiddenAbilities -- [ability id] = true
local _hiddenDOTs      -- [ability id] = ability name

local _playerAbilityDamages = {
    [15435] = 0, -- "Light Attack (One Handed)"
    [16037] = 0, -- "Light Attack (Two Handed)"
    [16145] = 0, -- "Light Attack (Restoration)"
    [16165] = 0, -- "Light Attack (Inferno)"
    [16277] = 0, -- "Light Attack (Ice)"
    [16499] = 0, -- "Light Attack (Dual Wield)"
    [16688] = 0, -- "Light Attack (Bow)"
    [18350] = 0, -- "Light Attack (Lightning)"
    [21970] = 0, -- "Bash"
    [32464] = 0, -- "Light Attack (Werewolf)"
}
_Base.PlayerAbilityDamages = _playerAbilityDamages

local function ShallowCopy(source)
    local copy = {}
    for key, value in pairs(source) do
        copy[key] = value
    end
    return copy
end

function _Base.Initialize(savedVars)
    savedVars.base = savedVars.base or {}
    savedVars.base.hiddenDOTs = savedVars.base.hiddenDOTs or {}

    _hiddenAbilities = ShallowCopy(_HIDDEN_ABILITIES)
    _hiddenDOTs = savedVars.base.hiddenDOTs
    for abl, _ in pairs(_hiddenDOTs) do
        _hiddenAbilities[abl] = true
    end
end

function _Base.CheckHiddenAbility(actionResult, abilityId, abilityName)
    if _hiddenAbilities[abilityId] then
        return true
    end

    if DOT_ACTION_RESULTS[actionResult] and not _VISIBLE_DOT_ABILITIES[abilityId] then
        _hiddenAbilities[abilityId] = true
        _hiddenDOTs[abilityId] = abilityName
        return true
    end

    return false
end

function _Base.EstimateBaseDamage(abilityId, abilityActionSlotType, hitValue)

end
