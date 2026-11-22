TacticalDisplay = TacticalDisplay or {}
TacticalDisplay.Base = TacticalDisplay.Base or {}
local _Base = TacticalDisplay.Base
local _ClearTable = TacticalDisplay.Utilities.ClearTable
local _CountTable = TacticalDisplay.Utilities.CountTable
local _LogError = TacticalDisplay.Utilities.LogError
local _LogDebug = TacticalDisplay.Utilities.LogDebug

local _debugLog -- boolean

-- Hidden from current attack report and "recent" update.
-- Can still be tracked if they're also signature abilities.
-- DoTs are listed, though no effect for now (see TRACKED_DOT_ABILITIES).
local HIDDEN_ABILITY_NAMES = {
    ["Absorb Magicka"] = true,
    ["Absorb Stamina"] = true,
    ["Atronach Lightning Storm"] = true,
    ["Avid Boneyard"] = true,
    ["Befouled Weapon"] = true,
    ["Blockade of Frost"] = true,
    ["Blockade of Storms"] = true,
    ["Burning Embers"] = true,
    ["Burning Light"] = true,
    ["Burning"] = true,
    ["Charged Weapon"] = true,
    ["Chilled"] = true,
    ["Combustion"] = true,
    ["Concussed"] = true,
    ["Corrosive Drain"] = true,
    ["Deathbolt"] = true,
    ["Decrease Health"] = true,
    ["Detonating Siphon"] = true,
    ["Direwolf Gnash"] = true,
    ["Direwolf Lunge"] = true,
    ["Diseased"] = true,
    ["Disintegrated Dragonfire"] = true,
    ["Fiery Weapon"] = true,
    ["Forceful"] = true,
    ["Frozen Weapon"] = true,
    ["Hemorrhaging"] = true,
    ["Hurricane"] = true,
    ["Igneous Weapons"] = true,
    ["Leeching Plate"] = true,
    ["Life Drain"] = true,
    ["Molten Armaments"] = true,
    ["Overcharged"] = true,
    ["Poison Injection"] = true,
    ["Poisoned Weapon"] = true,
    ["Poisoned"] = true,
    ["Prismatic Weapon"] = true,
    ["Quick Cloak"] = true,
    ["Razor Caltrops"] = true,
    ["Shared Pain"] = true,
    ["Solar Barrage"] = true,
    ["Soul Shatter"] = true,
    ["Summon Twilight Matriarch"] = true,
    ["Sundered"] = true,
    ["Unstable Clannfear"] = true,
    ["Unstable Core"] = true,
    ["Volatile Familiar"] = true,
}
local _HIDDEN_ABILITIES

-- DoT abilities to register for combat events explicitly
-- Because there are very few DoTs to track for now.
-- This might change in future to rely on HIDDEN_ABILITIES.
local TRACKED_DOT_ABILITY_NAMES = {
    ["Corrosive Armor"] = true,
    ["Maarselok"] = true,
    ["Pyrebrand"] = true,
    ["Thrive in Chaos"] = true,
}
local _TRACKED_DOT_ABILITIES

-- To identify opponents' builds
local SIGNATURE_ABILITY_NAMES = {
    ["Ballista"] = true,
    ["Biting Jabs"] = true,
    ["Blood for Blood"] = true,
    ["Bound Armaments"] = true,
    ["Cephaliarch's Flail"] = true,
    ["Corpseburster"] = true,
    ["Corrosive Armor"] = true,
    ["Crystal Fragments"] = true,
    ["Crystal Weapon"] = true,
    ["Daedric Prey"] = true,
    ["Deadlands Demolisher"] = true,
    ["Deep Fissure"] = true,
    ["Dizzying Swing"] = true,
    ["Exhausting Fatecarver"] = true,
    ["Flame Lash"] = true,
    ["Focused Aim"] = true,
    ["Glacial Colossus"] = true,
    ["Gorethief"] = true,
    ["Hrothgar's Chill"] = true,
    ["Ice Comet"] = true,
    ["Lava Whip"] = true,
    ["Lethal Arrow"] = true,
    ["Maarselok"] = true,
    ["Merciless Resolve"] = true,
    ["Molten Whip"] = true,
    ["Onslaught"] = true,
    ["Pestilent Colossus"] = true,
    ["Power Slam"] = true,
    ["Pragmatic Fatecarver"] = true,
    ["Puncturing Sweep"] = true,
    ["Pyrebrand"] = true,
    ["Rend"] = true,
    ["Relentless Focus"] = true,
    ["Radiant Glory"] = true,
    ["Radiant Oppression"] = true,
    ["Rending Slashes"] = true,
    ["Reverberating Bash"] = true,
    ["Scavenging Maw"] = true,
    ["Streak"] = true,
    ["Subterranean Assault"] = true,
    ["Tentacular Dread"] = true,
    ["The Tide King's Gaze"] = true,
    ["Thrive in Chaos"] = true,
    ["Toxic Barrage"] = true,
    ["Venom Skull"] = true,
    ["Vicious Death"] = true,
    ["Wrath of Elements"] = true,
    ["Wrecking Blow"] = true,
}
local _SIGNATURE_ABILITIES

-- For mitigation measurement, id to player tooltip damage
local MEASURABLE_PLAYER_ABILITY_NAMES = {
    ["Bash"] = true,
    ["Light Attack (Bow)"] = true,
    ["Light Attack (Dual Wield)"] = true,
    ["Light Attack (Ice)"] = true,
    ["Light Attack (Inferno)"] = true,
    ["Light Attack (Lightning)"] = true,
    ["Light Attack (One Handed)"] = true,
    ["Light Attack (Restoration)"] = true,
    ["Light Attack (Two Handed)"] = true,
    ["Light Attack (Werewolf)"] = true,
}
local _MEASURABLE_PLAYER_ABILITIES

local DEAD_ICON_PATH = "/esoui/art/icons/ability_mage_065.dds"

local function IsRealAbility(abilityId)
    if not DoesAbilityExist(abilityId) then
        return false
    end

    local icon = GetAbilityIcon(abilityId) or ""
    if icon == DEAD_ICON_PATH then
        return false
    end

    return true
end

local function BuildAbilityNameMap()
    local nameMap = {}
    local numAbilities = 0
    local lastAbilityId = 0
    local lastAbilityName = ""
    for abilityId = 1, 400000 do
        if IsRealAbility(abilityId) then
            local abilityName = GetAbilityName(abilityId, nil)
            local idList = nameMap[abilityName] or {}
            idList[#idList + 1] = abilityId
            nameMap[abilityName] = idList
            numAbilities = numAbilities + 1
            lastAbilityId = abilityId
            lastAbilityName = abilityName
        end
    end
    if _debugLog then
        _LogDebug(string.format("found %d abilities and %d names , last ability is %d %s",
            numAbilities, _CountTable(nameMap), lastAbilityId, lastAbilityName))
    end
    return nameMap
end

local function RebuildAbilityMaps()
    local nameToIdList = BuildAbilityNameMap()

    _ClearTable(_HIDDEN_ABILITIES)
    for abilityName, _ in pairs(HIDDEN_ABILITY_NAMES) do
        local idList = nameToIdList[abilityName] or {}
        for _, abilityId in ipairs(idList) do
            _HIDDEN_ABILITIES[abilityId] = abilityName
        end
    end
    if _debugLog then
        _LogDebug(string.format("rebuilt hidden ability map: %d",
            _CountTable(_HIDDEN_ABILITIES)))
    end

    _ClearTable(_TRACKED_DOT_ABILITIES)
    for abilityName, _ in pairs(TRACKED_DOT_ABILITY_NAMES) do
        local idList = nameToIdList[abilityName] or {}
        for _, abilityId in ipairs(idList) do
            _TRACKED_DOT_ABILITIES[abilityId] = abilityName
        end
    end
    if _debugLog then
        _LogDebug(string.format("rebuilt DoT ability map: %d",
            _CountTable(_TRACKED_DOT_ABILITIES)))
    end

    _ClearTable(_SIGNATURE_ABILITIES)
    for abilityName, _ in pairs(SIGNATURE_ABILITY_NAMES) do
        local idList = nameToIdList[abilityName] or {}
        for _, abilityId in ipairs(idList) do
            _SIGNATURE_ABILITIES[abilityId] = abilityName
        end
    end
    if _debugLog then
        _LogDebug(string.format("rebuilt signature ability map: %d",
            _CountTable(_SIGNATURE_ABILITIES)))
    end

    _ClearTable(_MEASURABLE_PLAYER_ABILITIES)
    for abilityName, _ in pairs(MEASURABLE_PLAYER_ABILITY_NAMES) do
        local idList = nameToIdList[abilityName] or {}
        for _, abilityId in ipairs(idList) do
            if GetAbilityDescription(abilityId, nil, "player") ~= "" then
                _MEASURABLE_PLAYER_ABILITIES[abilityId] = abilityName
            end
        end
    end
    if _debugLog then
        _LogDebug(string.format("rebuilt measurable player ability map: %d",
            _CountTable(_MEASURABLE_PLAYER_ABILITIES)))
    end
end

-------------------------------------------------------------------------------
-- Measure player damage abilities for calculating opponent mitigations
-------------------------------------------------------------------------------

-- Ability id to player damage value.
-- Value 0 means it needs updating.
-- Only listed abilities are considered measurable.
local _measurablePlayerDamageByAbility = {}

local function ExtractDamageFromAbilityDescription(description)
    if description == nil then
        return nil
    end

    local numberText = description:match("%d+")
    if numberText == nil then
        return nil
    end

    return tonumber(numberText)
end

local function ResetMeasurablePlayerDamage()
    _ClearTable(_measurablePlayerDamageByAbility)
    for abl, _ in pairs(_MEASURABLE_PLAYER_ABILITIES) do
        _measurablePlayerDamageByAbility[abl] = 0
    end
end

local REG_PLAYER_ACTIVATED = "TacticalDisplay_Base_PlayerActivated"
local REG_BAR_SWAPPED = "TacticalDisplay_Base_BarSwapped"

local function RegisterPlayerUpdate()
    EVENT_MANAGER:RegisterForEvent(REG_PLAYER_ACTIVATED, EVENT_PLAYER_ACTIVATED, ResetMeasurablePlayerDamage)
    EVENT_MANAGER:RegisterForEvent(REG_BAR_SWAPPED, EVENT_ACTIVE_WEAPON_PAIR_CHANGED, ResetMeasurablePlayerDamage)
end

local function UnregisterPlayerUpdate()
    EVENT_MANAGER:UnregisterForEvent(REG_PLAYER_ACTIVATED, EVENT_PLAYER_ACTIVATED)
    EVENT_MANAGER:UnregisterForEvent(REG_BAR_SWAPPED, EVENT_ACTIVE_WEAPON_PAIR_CHANGED)
end

function _Base.GetMeasurablePlayerDamage(abilityId, abilityName)
    local damage = _measurablePlayerDamageByAbility[abilityId]
    if damage == nil then
        return nil
    elseif damage == 0 then
        local descr = GetAbilityDescription(abilityId, nil, "player")
        local newDamage = ExtractDamageFromAbilityDescription(descr)
        if newDamage ~= nil and newDamage > 0 then
            _measurablePlayerDamageByAbility[abilityId] = newDamage
            if _debugLog then
                _LogDebug(string.format("Refresh player ability %d %s = %d from: %s",
                    abilityId, abilityName, newDamage, descr))
            end
            return newDamage
        else
            _LogError(string.format("Failed to refresh player ability %d %s from: %s",
                abilityId, abilityName, descr))
            return nil
        end
    else
        return damage
    end
end

-------------------------------------------------------------------------------
-- Public functions
-------------------------------------------------------------------------------

function _Base.Initialize(savedVars)
    local serverName = GetWorldName()
    savedVars.base = savedVars.base or {}
    savedVars.base[serverName] = savedVars.base[serverName] or {}
    local db = savedVars.base[serverName]

    db.HIDDEN_ABILITIES = db.HIDDEN_ABILITIES or {}
    _HIDDEN_ABILITIES = db.HIDDEN_ABILITIES
    _Base.HIDDEN_ABILITIES = db.HIDDEN_ABILITIES

    db.TRACKED_DOT_ABILITIES = db.TRACKED_DOT_ABILITIES or {}
    _TRACKED_DOT_ABILITIES = db.TRACKED_DOT_ABILITIES
    _Base.TRACKED_DOT_ABILITIES = db.TRACKED_DOT_ABILITIES

    db.SIGNATURE_ABILITIES = db.SIGNATURE_ABILITIES or {}
    _SIGNATURE_ABILITIES = db.SIGNATURE_ABILITIES
    _Base.SIGNATURE_ABILITIES = db.SIGNATURE_ABILITIES

    db.MEASURABLE_PLAYER_ABILITIES = db.MEASURABLE_PLAYER_ABILITIES or {}
    _MEASURABLE_PLAYER_ABILITIES = db.MEASURABLE_PLAYER_ABILITIES
    _Base.MEASURABLE_PLAYER_ABILITIES = db.MEASURABLE_PLAYER_ABILITIES
end

local _enabled = false

function _Base.Enable()
    if _enabled then
        return
    end
    RegisterPlayerUpdate()
    _enabled = true
end

function _Base.Disable()
    if not _enabled then
        return
    end
    UnregisterPlayerUpdate()
    _enabled = false
end

function _Base.UpdateParameters(debug)
    _debugLog = debug
end

function _Base.RebuildDB()
    RebuildAbilityMaps()
    ResetMeasurablePlayerDamage()
end
