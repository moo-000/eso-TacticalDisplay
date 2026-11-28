TacticalDisplay = TacticalDisplay or {}
TacticalDisplay.Panel = TacticalDisplay.Panel or {}
local _Panel = TacticalDisplay.Panel
local _DoOpponentTimeTick = TacticalDisplay.Data.DoOpponentTimeTick
local _OnOpponentUpdated = TacticalDisplay.Data.OnOpponentUpdated
local _ResetOpponentProcs = TacticalDisplay.Data.ResetOpponentProcs
local _FillDefaults = TacticalDisplay.Utilities.FillDefaults
local _SortedKeys = TacticalDisplay.Utilities.SortedKeys
---@diagnostic disable-next-line: undefined-global
local _AbilityTooltip = AbilityTooltip

local _config
local _defaults = {
    offsetX = 40,
    offsetY = 240,
}

local _opponentActiveDuration = 2
local _opponentVisibleDuration = 30

local FONT_BOLD = "EsoUI/Common/Fonts/FTN87.otf|18|soft-shadow-thick"
local FONT_NORMAL = "EsoUI/Common/Fonts/FTN57.otf|18|soft-shadow-thick"

local MIN_WIDTH = 240
local MIN_HEIGHT = 100
local CONTENT_PADDING_W = 12
local CONTENT_PADDING_H = 8

local MAX_VISIBLE_OPPONENTS = 12
local OPPONENT_ROW_HEIGHT = 23
local OPPONENT_SIGNATURE_CAP = 4
local OPPONENT_MAX_NAME_LABEL_WIDTH = 200
local OPPONENT_DD_LABEL_WIDTH = 45
local OPPONENT_TANK_LABEL_WIDTH = 25
local OPPONENT_ATTACK_ICON_MARGIN = 6
local OPPONENT_ATTACK_ICON_SIZE = 20

local ROW_HIGHLIGHT_DEFAULT = { 0.0, 0.0, 0.0, 0.5 }
local ROW_HIGHLIGHT_MAP = {
    ["Corrosive Armor"] = { 0.2, 0.8, 0.2, 0.5 },
    ["Onslaught"] = { 0.8, 0.4, 0.0, 0.5 },
}

local _visibleOpponentEntries = {} -- [index] = { opponent, isActive }

local _isPanelEnabled = false
local _fragment
local _window
local _reserve
local _contentAreaLeft
local _contentAreaRight

-- Row UIs are pre-created to MAX_VISIBLE_OPPONENTS;
-- The top rows in _opponentRows match _visibleOpponentEntries, while the rest
-- are hidden until new opponents need to be displayed.
-- Once a row is linked to a visible opponent, the link stays until the
-- opponent expires - if positions should change, rows in _opponentRows are
-- merely swapped and their anchors updated.
-- Expiring a previously-linked row involves moving it to the bottom (both in
-- the table and on the UI, though hidden).
local _opponentRows = {}

-------------------------------------------------------------------------------
-- Create UI
-------------------------------------------------------------------------------

local function WindowOnMoveStop()
    local left, top = _window:GetLeft(), _window:GetTop()
    if left and top then
        _config.offsetX = left
        _config.offsetY = top
    end
end

local function CreateRowAnimation(parent)
    local timeline = ANIMATION_MANAGER:CreateTimeline()

    local scaleAnim = timeline:InsertAnimation(ANIMATION_SCALE, parent, 0)
    scaleAnim:SetScaleValues(1.1, 1.0)
    scaleAnim:SetDuration(300)
    scaleAnim:SetEasingFunction(ZO_EaseOutQuadratic)

    local fadeOutAnim = timeline:InsertAnimation(ANIMATION_ALPHA, parent, 0)
    fadeOutAnim:SetAlphaValues(1, 0.33)
    fadeOutAnim:SetDuration(_opponentVisibleDuration * 1000 / 3 * 2)

    return timeline
end

local function HighlightTimelineOnStop(timeline, _)
    local highlight = timeline.tdParent
    highlight:SetAlpha(0.0)
    highlight:SetCenterColor(unpack(ROW_HIGHLIGHT_DEFAULT))
end

local function SignatureIconOnMouseEnter(self)
    if not self.abilityId or self.abilityId == 0 then
        return
    end
    InitializeTooltip(_AbilityTooltip, self, BOTTOM, 0, -4)
    _AbilityTooltip:SetAbilityId(self.abilityId)
end

local function SignatureIconOnMouseExit()
    ClearTooltip(_AbilityTooltip)
end

local function CreateUI()
    _window = WINDOW_MANAGER:CreateTopLevelWindow("TacticalDisplayPanel")
    _window:SetResizeToFitDescendents(true)
    _window:SetResizeToFitConstrains(ANCHOR_CONSTRAINS_XY)
    _window:SetResizeToFitPadding(CONTENT_PADDING_W * 2, CONTENT_PADDING_H * 2)
    _window:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, _config.offsetX, _config.offsetY)
    _window:SetDrawTier(DT_LOW)
    _window:SetDrawLayer(DL_OVERLAY) -- to input, or can't be dragged
    _window:SetClampedToScreen(true)
    _window:SetMouseEnabled(true)
    _window:SetMovable(true)
    _window:SetHidden(false)
    _window:SetHandler("OnMoveStop", WindowOnMoveStop)

    _reserve = WINDOW_MANAGER:CreateControl(nil, _window, CT_CONTROL)
    _reserve:SetDimensions(MIN_WIDTH, MIN_HEIGHT)
    _reserve:SetAnchor(TOPLEFT, _window, TOPLEFT, 0, 0)
    _reserve:SetMouseEnabled(false)

    local _reserveTitle = WINDOW_MANAGER:CreateControl(nil, _reserve, CT_LABEL)
    _reserveTitle:SetAnchor(TOPLEFT, _reserve, TOPLEFT, CONTENT_PADDING_W, CONTENT_PADDING_H)
    _reserveTitle:SetFont(FONT_BOLD)
    _reserveTitle:SetColor(1.0, 0.8, 0, 0.75)
    _reserveTitle:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    _reserveTitle:SetText("Tactical Display")
    _reserveTitle:SetHidden(false)

    local _backdrop = WINDOW_MANAGER:CreateControl(nil, _window, CT_BACKDROP)
    _backdrop:SetExcludeFromResizeToFitExtents(true)
    _backdrop:SetAnchorFill(_window)
    _backdrop:SetDrawLayer(DL_BACKGROUND)
    _backdrop:SetCenterColor(0.3, 0.3, 0.3, 0.3)
    _backdrop:SetEdgeColor(1.0, 1.0, 1.0, 0.5)
    _backdrop:SetEdgeTexture("EsoUI/Art/Tooltips/UI-Border.dds", 8, 8, 2, 0)
    _backdrop:SetMouseEnabled(false)

    _contentAreaLeft = WINDOW_MANAGER:CreateControl("TacticalDisplayContentLeft", _window, CT_CONTROL)
    _contentAreaLeft:SetResizeToFitDescendents(true)
    _contentAreaLeft:SetResizeToFitConstrains(ANCHOR_CONSTRAINS_XY)
    _contentAreaLeft:SetAnchor(TOPLEFT, _window, TOPLEFT, CONTENT_PADDING_W, CONTENT_PADDING_H)
    _contentAreaLeft:SetMouseEnabled(false)

    _contentAreaRight = WINDOW_MANAGER:CreateControl("TacticalDisplayContentRight", _window, CT_CONTROL)
    _contentAreaRight:SetResizeToFitDescendents(true)
    _contentAreaRight:SetResizeToFitConstrains(ANCHOR_CONSTRAINS_XY)
    _contentAreaRight:SetAnchor(TOPLEFT, _contentAreaLeft, TOPRIGHT, CONTENT_PADDING_W / 2, 0)
    _contentAreaRight:SetMouseEnabled(false)

    for index = 1, MAX_VISIBLE_OPPONENTS do
        local groupLeft = WINDOW_MANAGER:CreateControl(nil, _contentAreaLeft, CT_CONTROL)
        groupLeft:SetDimensions(0, OPPONENT_ROW_HEIGHT)
        groupLeft:SetResizeToFitDescendents(true)
        groupLeft:SetResizeToFitConstrains(ANCHOR_CONSTRAINS_X)
        groupLeft:SetAnchor(TOPRIGHT, _contentAreaLeft, TOPRIGHT, 0, 0)
        groupLeft:SetMouseEnabled(false)
        groupLeft.tdTimeline = CreateRowAnimation(groupLeft)

        local nameLabel = WINDOW_MANAGER:CreateControl(nil, groupLeft, CT_LABEL)
        nameLabel:SetDimensionConstraints(0, 0, OPPONENT_MAX_NAME_LABEL_WIDTH, 0)
        nameLabel:SetAnchor(TOPRIGHT, groupLeft, TOPRIGHT, 0, 0)
        nameLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        nameLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        nameLabel:SetWrapMode(TEXT_WRAP_MODE_TRUNCATE)
        nameLabel:SetFont(FONT_NORMAL)
        nameLabel:SetColor(1, 1, 1, 1)
        nameLabel:SetMouseEnabled(false)

        local groupRight = WINDOW_MANAGER:CreateControl(nil, _contentAreaRight, CT_CONTROL)
        groupRight:SetDimensions(0, OPPONENT_ROW_HEIGHT)
        groupRight:SetResizeToFitDescendents(true)
        groupRight:SetResizeToFitConstrains(ANCHOR_CONSTRAINS_X)
        groupRight:SetAnchor(TOPLEFT, _contentAreaRight, TOPLEFT, 0, 0)
        groupRight:SetMouseEnabled(false)
        groupRight.tdTimeline = CreateRowAnimation(groupRight)

        local highlight = WINDOW_MANAGER:CreateControl(nil, _window, CT_BACKDROP)
        highlight:SetDimensions(0, OPPONENT_ROW_HEIGHT)
        highlight:SetExcludeFromResizeToFitExtents(true)
        highlight:SetAnchor(TOPLEFT, _contentAreaLeft, TOPLEFT, 0, 0)
        highlight:SetAnchor(TOPRIGHT, _contentAreaRight, TOPRIGHT, 0, 0)
        highlight:SetDrawLayer(DL_BACKGROUND)
        highlight:SetAlpha(0.0)
        highlight:SetCenterColor(unpack(ROW_HIGHLIGHT_DEFAULT))
        highlight:SetEdgeColor(0.0, 0.0, 0.0, 0.0)
        highlight.tdTimeline = ANIMATION_MANAGER:CreateTimeline()
        highlight.tdTimeline:SetHandler("OnStop", HighlightTimelineOnStop)
        highlight.tdTimeline.tdParent = highlight
        highlight.tdAnimation = highlight.tdTimeline:InsertAnimation(ANIMATION_ALPHA, highlight, 0)

        local signatureIcons = {}
        local signatureAuras = {}
        local signatureBadges = {}
        local iconMargin = (OPPONENT_ROW_HEIGHT - OPPONENT_ATTACK_ICON_SIZE) / 2
        for i = 1, OPPONENT_SIGNATURE_CAP do
            local icon = WINDOW_MANAGER:CreateControl(nil, groupRight, CT_TEXTURE)
            icon:SetDimensions(OPPONENT_ATTACK_ICON_SIZE, OPPONENT_ATTACK_ICON_SIZE)
            if i == 1 then
                icon:SetAnchor(TOPLEFT, groupRight, TOPLEFT, iconMargin, iconMargin)
            else
                icon:SetAnchor(TOPLEFT, signatureIcons[i - 1], TOPRIGHT, iconMargin, 0)
            end
            icon:SetDrawLayer(DL_OVERLAY) -- to receive input before _window, or tooltip cannot show
            icon:SetMouseEnabled(true)
            icon:SetHandler("OnMouseEnter", SignatureIconOnMouseEnter)
            icon:SetHandler("OnMouseExit", SignatureIconOnMouseExit)
            icon:SetHidden(true)
            signatureIcons[i] = icon

            local aura = WINDOW_MANAGER:CreateControl(nil, icon, CT_TEXTURE)
            aura:SetAnchor(TOPLEFT, icon, TOPLEFT, -2, -2)
            aura:SetAnchor(BOTTOMRIGHT, icon, BOTTOMRIGHT, 2, 2)
            aura:SetDrawLayer(DL_OVERLAY)
            aura:SetTexture("EsoUI/Art/ActionBar/abilityHighlight_mage_med.dds")
            aura:SetBlendMode(TEX_BLEND_MODE_ADD)
            aura:SetColor(1.0, 0.6, 0.0, 0.8)
            aura.tdTimeline = ANIMATION_MANAGER:CreateTimeline()
            local anim = aura.tdTimeline:InsertAnimation(ANIMATION_TEXTURE, aura)
            anim:SetImageData(64, 1)
            anim:SetFramerate(16)
            aura.tdTimeline:SetPlaybackType(ANIMATION_PLAYBACK_LOOP, LOOP_INDEFINITELY)
            signatureAuras[i] = aura

            local badge = WINDOW_MANAGER:CreateControl(nil, groupRight, CT_LABEL)
            badge:SetAnchor(BOTTOMRIGHT, icon, BOTTOMRIGHT, -1, 2)
            badge:SetDrawLayer(DL_OVERLAY)
            badge:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
            badge:SetVerticalAlignment(TEXT_ALIGN_BOTTOM)
            badge:SetWrapMode(TEXT_WRAP_MODE_TRUNCATE)
            badge:SetFont(FONT_BOLD)
            badge:SetColor(1, 1, 0, 1)
            badge:SetMouseEnabled(false)
            signatureBadges[i] = badge
        end

        local ddLabel = WINDOW_MANAGER:CreateControl(nil, groupRight, CT_LABEL)
        ddLabel:SetDimensions(OPPONENT_DD_LABEL_WIDTH, OPPONENT_ROW_HEIGHT)
        ddLabel:SetAnchor(TOPLEFT, signatureIcons[OPPONENT_SIGNATURE_CAP], TOPRIGHT, 0, 0)
        ddLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        ddLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        ddLabel:SetWrapMode(TEXT_WRAP_MODE_TRUNCATE)
        ddLabel:SetFont(FONT_NORMAL)
        ddLabel:SetColor(1, 1, 1, 1)
        ddLabel:SetMouseEnabled(false)

        local tankLabel = WINDOW_MANAGER:CreateControl(nil, groupRight, CT_LABEL)
        tankLabel:SetDimensions(OPPONENT_TANK_LABEL_WIDTH, OPPONENT_ROW_HEIGHT)
        tankLabel:SetAnchor(LEFT, ddLabel, RIGHT, 0, 0)
        tankLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        tankLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        tankLabel:SetWrapMode(TEXT_WRAP_MODE_TRUNCATE)
        tankLabel:SetFont(FONT_NORMAL)
        tankLabel:SetColor(1, 1, 1, 1)
        tankLabel:SetMouseEnabled(false)

        local attackIcon = WINDOW_MANAGER:CreateControl(nil, groupRight, CT_TEXTURE)
        attackIcon:SetDimensions(OPPONENT_ATTACK_ICON_SIZE, OPPONENT_ATTACK_ICON_SIZE)
        attackIcon:SetAnchor(LEFT, tankLabel, RIGHT, OPPONENT_ATTACK_ICON_MARGIN, 0)
        attackIcon:SetMouseEnabled(false)
        attackIcon:SetHidden(true)

        local attackLabel = WINDOW_MANAGER:CreateControl(nil, groupRight, CT_LABEL)
        attackLabel:SetAnchor(LEFT, attackIcon, RIGHT, OPPONENT_ATTACK_ICON_MARGIN, 0)
        attackLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
        attackLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        attackLabel:SetWrapMode(TEXT_WRAP_MODE_TRUNCATE)
        attackLabel:SetFont(FONT_NORMAL)
        attackLabel:SetColor(1, 1, 1, 1)
        attackLabel:SetMouseEnabled(false)

        groupLeft:SetHidden(true)
        groupRight:SetHidden(true)
        highlight:SetHidden(true)

        _opponentRows[index] = {
            groupLeft = groupLeft,
            groupRight = groupRight,
            highlight = highlight,
            nameLabel = nameLabel,
            signatureIcons = signatureIcons,
            signatureAuras = signatureAuras,
            signatureBadges = signatureBadges,
            ddLabel = ddLabel,
            tankLabel = tankLabel,
            attackIcon = attackIcon,
            attackLabel = attackLabel,
        }
    end

    _fragment = ZO_FadeSceneFragment:New(_window, true, 150)
    _fragment:SetConditional(function()
        return _isPanelEnabled
    end)
    SCENE_MANAGER:GetScene("hud"):AddFragment(_fragment)
    SCENE_MANAGER:GetScene("hudui"):AddFragment(_fragment)
end

-------------------------------------------------------------------------------
-- Update UI
-------------------------------------------------------------------------------

local function ClearRowSignature(row, index)
    local icon = row.signatureIcons[index]
    icon.abilityId = 0
    icon:SetTexture(nil)
    icon:SetHidden(true)
    local aura = row.signatureAuras[index]
    aura:SetHidden(true)
    aura.tdTimeline:Stop()
    local badge = row.signatureBadges[index]
    badge:SetHidden(true)
end

local function RenderRowContents(row, opponentEntry)
    local timeMs = GetGameTimeMilliseconds()
    local opponent = opponentEntry.opponent
    local rowFont = opponentEntry.isActive and FONT_BOLD or FONT_NORMAL

    row.nameLabel:SetFont(rowFont)
    row.nameLabel:SetText(opponent.name or "?")

    local signature = opponent.signature or {}
    local numSig = 1
    for _, abilityId in ipairs(_SortedKeys(signature)) do
        local sitem = signature[abilityId]
        local icon = row.signatureIcons[numSig]
        if not icon then
            -- currently limited to pre-allocated N icons
            break
        end
        icon.abilityId = abilityId
        icon:SetTexture(sitem.abilityIcon)
        icon:SetHidden(false)

        local proc = opponent.procs[sitem.abilityName]
        local badge = row.signatureBadges[numSig]
        local animate = false
        if proc then
            local n = zo_floor(proc.numProc)
            badge:SetText(tostring(n))
            badge:SetHidden(false)
            animate = n > 0
        else
            badge:SetText("")
            badge:SetHidden(true)
        end

        local aura = row.signatureAuras[numSig]
        if animate then
            aura:SetHidden(false)
            if not aura.tdTimeline:IsPlaying() then
                aura.tdTimeline:PlayFromStart()
            end
        else
            aura:SetHidden(true)
            aura.tdTimeline:Stop()
        end

        numSig = numSig + 1
    end

    for i = numSig, #row.signatureIcons do
        ClearRowSignature(row, i)
    end

    if (opponent.lastBaseDamage or 0) > 0 then
        row.ddLabel:SetText(string.format("%d||", opponent.lastBaseDamage))
        row.ddLabel:SetColor(1, 1, 1, 1.0)
    else
        row.ddLabel:SetText("0000||")
        row.ddLabel:SetColor(1, 1, 1, 0.25)
    end
    if (opponent.lastMitigation or 0) > 0 then
        local m = opponent.lastMitigation
        if m > 99 then
            m = 99
        end
        row.tankLabel:SetText(string.format("%d%%", m))
        row.tankLabel:SetColor(1, 1, 1, 1.0)
    else
        row.tankLabel:SetText("??%")
        row.tankLabel:SetColor(1, 1, 1, 0.25)
    end

    local attackIcon = nil
    local abilityName = nil
    local attackMarkupParts = {}

    if opponent.lastDealtAttack then
        local attack = opponent.lastDealtAttack
        attackIcon = attack.abilityIcon
        abilityName = attack.abilityName

        local abilityMarkup
        if attack.isCritical then
            abilityMarkup = "|cFFFF00" .. abilityName .. "|r"
        else
            abilityMarkup = abilityName
        end
        attackMarkupParts[#attackMarkupParts + 1] = abilityMarkup

        local damageText = tostring(attack.damage)
        local damageMarkup
        if attack.isBlocked then
            damageMarkup = "|c7F00FF" .. damageText .. "|r"
        elseif attack.isShielded then
            damageMarkup = "|c00FF00" .. damageText .. "|r"
        else
            damageMarkup = damageText
        end
        attackMarkupParts[#attackMarkupParts + 1] = damageMarkup
    end

    row.attackIcon:SetTexture(attackIcon)
    row.attackIcon:SetHidden(attackIcon == nil)

    row.attackLabel:SetFont(rowFont)
    row.attackLabel:SetText(table.concat(attackMarkupParts, "  "))

    row.groupLeft:SetHidden(false)
    row.groupRight:SetHidden(false)
    row.highlight:SetHidden(false)
    if row.needsNotice then
        row.groupLeft.tdTimeline:PlayFromStart()
        row.groupRight.tdTimeline:PlayFromStart()
        row.needsNotice = false
    end

    for buffName, buff in pairs(opponent.buffs) do
        local hlColor = ROW_HIGHLIGHT_MAP[buffName]
        -- only support one buff for now and no overlap
        if hlColor and not row.highlight.tdTimeline:IsPlaying() then
            row.highlight:SetCenterColor(unpack(hlColor))
            row.highlight.tdAnimation:SetAlphaValues(1, 0.5)
            row.highlight.tdAnimation:SetDuration(buff.activeEndMs - buff.activeStartMs)
            row.highlight.tdTimeline:PlayFromStart(timeMs - buff.activeStartMs)
            break
        end
    end
end

local function ClearRowUI(row)
    row.groupLeft.tdTimeline:Stop()
    row.groupRight.tdTimeline:Stop()
    row.highlight.tdTimeline:Stop()
    row.needsNotice = false

    row.nameLabel:SetText("")
    for i = 1, #row.signatureIcons do
        ClearRowSignature(row, i)
    end
    row.attackIcon:SetTexture(nil)
    row.attackIcon:SetHidden(true)
    row.attackLabel:SetText("")
    row.groupLeft:SetHidden(true)
    row.groupRight:SetHidden(true)
    row.highlight:SetHidden(true)
end

local function RenderRowUI(index, row)
    local entry = _visibleOpponentEntries[index]
    if not entry then
        if row.needsRender then
            ClearRowUI(row)
            row.needsRender = false
        end
        return
    end

    if row.needsAnchor then
        row.groupLeft:ClearAnchors()
        row.groupLeft:SetAnchor(TOPRIGHT, _contentAreaLeft, TOPRIGHT, 0, (index - 1) * OPPONENT_ROW_HEIGHT)
        row.groupRight:ClearAnchors()
        row.groupRight:SetAnchor(TOPLEFT, _contentAreaRight, TOPLEFT, 0, (index - 1) * OPPONENT_ROW_HEIGHT)
        row.highlight:ClearAnchors()
        row.highlight:SetAnchor(TOPLEFT, _contentAreaLeft, TOPLEFT, 0, (index - 1) * OPPONENT_ROW_HEIGHT)
        row.highlight:SetAnchor(TOPRIGHT, _contentAreaRight, TOPRIGHT, 0, (index - 1) * OPPONENT_ROW_HEIGHT)
        row.needsAnchor = false
    end
    if row.needsRender then
        RenderRowContents(row, entry)
        row.needsRender = false
    end
end

local function RenderPanelUI()
    _reserve:SetHidden(#_visibleOpponentEntries > 0)

    for index, row in ipairs(_opponentRows) do
        RenderRowUI(index, row)
    end
end

local UPDATE_RENDER_NAME = "TacticalDisplay_Panel_Render"
local UPDATE_RENDER_DELAY_MS = 100

local _renderTaskScheduled = false

local function DoRenderTask()
    EVENT_MANAGER:UnregisterForUpdate(UPDATE_RENDER_NAME)
    _renderTaskScheduled = false
    RenderPanelUI()
end

local function ScheduleRenderTask()
    if _renderTaskScheduled then
        return
    end
    _renderTaskScheduled = true

    EVENT_MANAGER:RegisterForUpdate(UPDATE_RENDER_NAME, UPDATE_RENDER_DELAY_MS, DoRenderTask)
end

-------------------------------------------------------------------------------
-- Update view model
-------------------------------------------------------------------------------

local function RemoveVisibleOpponentAt(index)
    table.remove(_visibleOpponentEntries, index)
    local removedRow = table.remove(_opponentRows, index)
    table.insert(_opponentRows, removedRow)
    removedRow.needsAnchor = false
    removedRow.needsRender = true
    for rowIndex = index, #_visibleOpponentEntries do
        _opponentRows[rowIndex].needsAnchor = true
    end
end

local function InsertVisibleOpponentAtTop(opponent, activate)
    if #_visibleOpponentEntries >= MAX_VISIBLE_OPPONENTS then
        RemoveVisibleOpponentAt(#_visibleOpponentEntries)
    end

    table.insert(_visibleOpponentEntries, 1, {
        opponent = opponent,
        isActive = activate,
    })
    local row = table.remove(_opponentRows, #_visibleOpponentEntries)
    table.insert(_opponentRows, 1, row)
    row.needsAnchor = true
    row.needsRender = true
    row.needsNotice = activate
    for index = 2, #_visibleOpponentEntries do
        _opponentRows[index].needsAnchor = true
    end
end

local function AddOrUpdateVisibleOpponent(opponent, activate)
    for index, entry in ipairs(_visibleOpponentEntries) do
        if entry.opponent == opponent then
            entry.isActive = activate
            _opponentRows[index].needsRender = true
            _opponentRows[index].needsNotice = activate
            return index
        end
    end

    _ResetOpponentProcs(opponent)
    InsertVisibleOpponentAtTop(opponent)
end

-------------------------------------------------------------------------------
-- Trigger: scheduled cleanup and opponent update events
-------------------------------------------------------------------------------

local UPDATE_CLEANUP_NAME = "TacticalDisplay_Panel_Cleanup"
local UPDATE_CLEANUP_INTERVAL_MS = 250

local function CleanupOpponentEntries()
    local now = GetTimeStamp()
    local nowMs = GetGameTimeMilliseconds()
    local changed = false
    for index = #_visibleOpponentEntries, 1, -1 do
        local opponentEntry = _visibleOpponentEntries[index]
        local opponent = opponentEntry and opponentEntry.opponent
        if not opponent
            or not opponent.lastSeen
            or now - opponent.lastSeen >= _opponentVisibleDuration then
            RemoveVisibleOpponentAt(index)
            changed = true
        else
            local row = _opponentRows[index]
            local isActive = false
            if opponent.lastSeen > (opponent.lastDied or 0)
                and (now - opponent.lastSeen) <= _opponentActiveDuration then
                isActive = true
            end
            if opponentEntry.isActive ~= isActive then
                opponentEntry.isActive = isActive
                row.needsRender = true
                changed = true
            end
            if _DoOpponentTimeTick(opponent, nowMs) then
                row.needsRender = true
                changed = true
            end
        end
    end
    if changed then
        ScheduleRenderTask()
    end
end

local OPPONENT_UPDATE_NAME = "TacticalDisplayPanel_Update"

local function OnOpponentUpdated(opponent, activate)
    AddOrUpdateVisibleOpponent(opponent, activate)
    ScheduleRenderTask()
end

-------------------------------------------------------------------------------
-- Public functions
-------------------------------------------------------------------------------

function _Panel.Initialize(savedVars)
    savedVars.panel = savedVars.panel or _defaults
    _config = savedVars.panel
    _FillDefaults(_config, _defaults)

    CreateUI()
end

function _Panel.Enable()
    if _isPanelEnabled then
        return
    end

    _OnOpponentUpdated[OPPONENT_UPDATE_NAME] = OnOpponentUpdated
    EVENT_MANAGER:RegisterForUpdate(UPDATE_CLEANUP_NAME, UPDATE_CLEANUP_INTERVAL_MS, CleanupOpponentEntries)

    _isPanelEnabled = true
    _fragment:Refresh()

    ScheduleRenderTask()
end

function _Panel.Disable()
    if not _isPanelEnabled then
        return
    end

    EVENT_MANAGER:UnregisterForUpdate(UPDATE_CLEANUP_NAME)
    _OnOpponentUpdated[OPPONENT_UPDATE_NAME] = nil

    _isPanelEnabled = false
    _fragment:Refresh()
end

function _Panel.UpdateParameters(activeDuration, visibleDuration)
    _opponentActiveDuration = activeDuration or 1
    _opponentVisibleDuration = visibleDuration or 1
end

function _Panel.ResetLayout()
    _config.offsetX = _defaults.offsetX
    _config.offsetY = _defaults.offsetY
    _window:ClearAnchors()
    _window:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, _config.offsetX, _config.offsetY)
end
