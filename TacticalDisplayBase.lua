TacticalDisplay = TacticalDisplay or {}
TacticalDisplay.Base = TacticalDisplay.Base or {}
local _Base = TacticalDisplay.Base
local _LogError = TacticalDisplay.Utilities.LogError
local _LogDebug = TacticalDisplay.Utilities.LogDebug

local _debugLog -- boolean

_Base.HIDDEN_ABILITIES = {
    [17895] = true,  -- "Fiery Weapon"
    [17897] = true,  -- "Frozen Weapon"
    [17899] = true,  -- "Charged Weapon"
    [17902] = true,  -- "Poisoned Weapon"
    [17904] = true,  -- "Befouled Weapon"
    [18084] = true,  -- "Burning"
    [20660] = true,  -- "Burning Embers"
    [21481] = true,  -- "Chilled"
    [21487] = true,  -- "Concussed"
    [21734] = true,  -- "Reflective Light" (Tick)
    [21925] = true,  -- "Diseased"
    [21929] = true,  -- "Poisoned"
    [23232] = true,  -- "Hurricane"
    [28919] = true,  -- "Life Drain"
    [31103] = true,  -- "Disintegrated Dragonfire"
    [39267] = true,  -- "Soul Shatter"
    [40252] = true,  -- "Razor Caltrops"
    [40337] = true,  -- "Prismatic Weapon"
    [44373] = true,  -- "Burning Embers"
    [44549] = true,  -- "Poison Injection"
    [45445] = true,  -- "Forceful"
    [45584] = true,  -- "Soul Shatter"
    [46743] = true,  -- "Absorb Magicka"
    [46746] = true,  -- "Absorb Stamina"
    [46749] = true,  -- "Decrease Health"
    [62529] = true,  -- "Quick Cloak"
    [62951] = true,  -- "Blockage of Frost"
    [67204] = true,  -- "Leeching Plate"
    [80170] = true,  -- "Burning Light"
    [80184] = true,  -- "Direwolf Lunge"
    [80189] = true,  -- "Direwolf Gnash"
    [80190] = true,  -- "Direwolf Gnash"
    [85432] = true,  -- "Combustion"
    [100218] = true, -- "Solar Barrage"
    [117321] = true, -- "Summon Twilight Matriarch"
    [117854] = true, -- "Avid Boneyard"
    [118746] = true, -- "Deathbolt"
    [118766] = true, -- "Detonating Siphon"
    [122774] = true, -- "Deathbolt"
    [127791] = true, -- "Unstable Core"
    [147843] = true, -- "Wrath of Elements"
    [147844] = true, -- "Wrath of Elements"
    [147846] = true, -- "Wrath of Elements"
    [147847] = true, -- "Wrath of Elements"
    [148797] = true, -- "Overcharged"
    [148800] = true, -- "Sundered"
    [148801] = true, -- "Hemorrhaging"
    [215779] = true, -- "Diseased"
    [233041] = true, -- "Shared Pain"
    [258660] = true, -- "Molten Armaments"
    [258665] = true, -- "Igneous Weapons"
}

_Base.TRACKED_DOT_ABILITIES = {
    [17879] = true,  -- "Corrosive Armor"
    [85182] = true,  -- "Thrive in Chaos"
    [126941] = true, -- "Maarselok"
    -- [226394] = true, -- "Pyrebrand"
}

-- TODO: for damage accumulation and signature check
_Base.PARENTS_OF_ABILITIES = {
    [26792] = 26792,   -- "Biting Jabs"
    [26794] = 26792,   -- "Biting Jabs"
    [26797] = 26797,   -- "Puncturing Sweep"
    [26799] = 26797,   -- "Puncturing Sweep"
    [38839] = 38839,   -- "Rending Slashes" (1st)
    [38840] = 38839,   -- "Rending Slashes" (2nd)
    [38841] = 38839,   -- "Rending Slashes" (DoT)
    [44432] = 26792,   -- "Biting Jabs"
    [44436] = 26797,   -- "Puncturing Sweep"
    [46340] = 46340,   -- "Force Shock"
    [46341] = 46340,   -- "Force Shock"
    [46343] = 46340,   -- "Force Shock"
    [46348] = 46348,   -- "Crushing Shock"
    [46350] = 46348,   -- "Crushing Shock"
    [46351] = 46348,   -- "Crushing Shock"
    [48011] = 48011,   -- "Crushing Shock"
    [85179] = 85179,   -- "Thrive in Chaos"
    [85180] = 85179,   -- "Thrive in Chaos"
    [85182] = 85179,   -- "Thrive in Chaos" (DoT)
    [182977] = 182977, -- "Escalating Runeblades"
    [182978] = 182977, -- "Escalating Runeblades"
    [182979] = 182977, -- "Escalating Runeblades"
    [185803] = 185803, -- "Writhing Runeblades"
    [185804] = 185803, -- "Writhing Runeblades"
    [188186] = 185803, -- "Writhing Runeblades"
    [188780] = 182977, -- "Escalating Runeblades"
    [188787] = 185803, -- "Writhing Runeblades"
}

-- TODO: identify opponents' builds
_Base.SIGNATURE_ABILITIES = {
    [23239] = true,  -- "Streak"
    [26792] = true,  -- "Biting Jabs"
    [26797] = true,  -- "Puncturing Sweep"
    [38687] = true,  -- "Focused Aim"
    [38839] = true,  -- "Rending Slashes"
    -- [46324] = true, -- "Crystal Fragments" (base)
    [63457] = true,  -- "Ice Comet"
    [76938] = true,  -- "Vicious Death"
    [114716] = true, -- "Crystal Fragments" (proc)
    [116991] = true, -- "Scavenging Maw"
    [117715] = true, -- "Blighted Skeletal Detonation"
    [123704] = true, -- "Venom Skull"
    [163293] = true, -- "Deadlands Demolisher"
    [183006] = true, -- "Cephaliarch's Flail"
    [185823] = true, -- "Tentacular Dread"
    [186370] = true, -- "Pragmatic Fatecarver"
    [227072] = true, -- "Corpseburster"
}

-------------------------------------------------------------------------------
-- Measure player damage abilities for calculating opponent mitigations
-------------------------------------------------------------------------------

-- Ability id to player damage value.
-- Value 0 means it needs updating.
-- Only listed abilities are considered measurable.
local _measurablePlayerDamageByAbility = {
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
    for abl, _ in pairs(_measurablePlayerDamageByAbility) do
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
        return 0
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
        end
    else
        return damage
    end
end

-------------------------------------------------------------------------------
-- Public functions
-------------------------------------------------------------------------------

function _Base.Initialize(savedVars)
    savedVars.base = savedVars.base or {}
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
