TacticalDisplay = TacticalDisplay or {}
TacticalDisplay.Panel = TacticalDisplay.Panel or {}
local _Panel = TacticalDisplay.Panel
local _OnOpponentUpdated = TacticalDisplay.Data.OnOpponentUpdated

local _config
local _defaults = {
    offsetX = 40,
    offsetY = 240,
}

local _opponentActiveDuration = 2
local _opponentVisibleDuration = 30

local FONT_BOLD = "$(BOLD_FONT)|18|soft-shadow-thick"
local FONT_NORMAL = "$(MEDIUM_FONT)|18|soft-shadow-thick"

local MIN_WIDTH = 240
local MIN_HEIGHT = 100
local CONTENT_PADDING = 8

local MAX_VISIBLE_OPPONENTS = 12
local OPPONENT_ROW_HEIGHT = 23
local OPPONENT_NAME_WIDTH = 120
local OPPONENT_DD_LABEL_WIDTH = 50
local OPPONENT_TANK_LABEL_WIDTH = 40
local OPPONENT_ATTACK_ICON_MARGIN = 6
local OPPONENT_ATTACK_ICON_SIZE = 20

local _visibleOpponentEntries = {} -- [index] = { opponent, isActive }

local _isPanelEnabled = false
local _fragment
local _window
local _reserve
local _contentArea
local _opponentRows = {}

-------------------------------------------------------------------------------
-- Create UI
-------------------------------------------------------------------------------

local function SaveWindowPosition()
    if _window and _config then
        local left, top = _window:GetLeft(), _window:GetTop()
        if left and top then
            _config.offsetX = left
            _config.offsetY = top
        end
    end
end

local function CreateUI()
    _window = WINDOW_MANAGER:CreateTopLevelWindow("TacticalDisplayWindow")
    _window:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, _defaults.offsetX, _defaults.offsetY)
    _window:SetResizeToFitDescendents(true)
    _window:SetResizeToFitConstrains(ANCHOR_CONSTRAINS_XY)
    _window:SetResizeToFitPadding(CONTENT_PADDING * 2, CONTENT_PADDING * 2)
    _window:SetDrawTier(DT_LOW)
    _window:SetDrawLayer(DL_OVERLAY)
    _window:SetClampedToScreen(true)
    _window:SetMouseEnabled(true)
    _window:SetMovable(true)
    _window:SetHidden(false)
    _window:SetHandler("OnMoveStop", SaveWindowPosition)

    _reserve = WINDOW_MANAGER:CreateControl(nil, _window, CT_CONTROL)
    _reserve:SetAnchor(TOPLEFT, _window, TOPLEFT, 0, 0)
    _reserve:SetDimensions(MIN_WIDTH, MIN_HEIGHT)
    _reserve:SetMouseEnabled(false)

    local _reserveTitle = WINDOW_MANAGER:CreateControl(nil, _reserve, CT_LABEL)
    _reserveTitle:SetFont(FONT_BOLD)
    _reserveTitle:SetColor(0.95, 0.95, 1, 1)
    _reserveTitle:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    _reserveTitle:SetAnchor(TOPLEFT, _reserve, TOPLEFT, CONTENT_PADDING, CONTENT_PADDING)
    _reserveTitle:SetText("Tactical Display")
    _reserveTitle:SetColor(1.0, 0.8, 0, 0.75)
    _reserveTitle:SetHidden(false)

    local _backdrop = WINDOW_MANAGER:CreateControl(nil, _window, CT_BACKDROP)
    _backdrop:SetAnchorFill(_window)
    _backdrop:SetExcludeFromResizeToFitExtents(true)
    _backdrop:SetCenterColor(0.4, 0.2, 0, 0.2)

    _backdrop:SetEdgeColor(1.0, 1.0, 1.0, 0.5)
    _backdrop:SetEdgeTexture("EsoUI/Art/Tooltips/UI-Border.dds", CONTENT_PADDING, CONTENT_PADDING, 2, 0)
    _backdrop:SetMouseEnabled(false)

    _contentArea = WINDOW_MANAGER:CreateControl("TacticalDisplayContent", _window, CT_CONTROL)
    _contentArea:SetAnchor(TOPLEFT, _window, TOPLEFT, CONTENT_PADDING, CONTENT_PADDING)
    _contentArea:SetResizeToFitDescendents(true)
    _contentArea:SetResizeToFitConstrains(ANCHOR_CONSTRAINS_XY)
    _contentArea:SetMouseEnabled(false)

    for index = 1, MAX_VISIBLE_OPPONENTS do
        local rowControl = WINDOW_MANAGER:CreateControl(nil, _contentArea, CT_CONTROL)
        rowControl:SetAnchor(TOPLEFT, _contentArea, TOPLEFT, 0, 0)
        rowControl:SetDimensions(MIN_WIDTH, OPPONENT_ROW_HEIGHT)
        rowControl:SetResizeToFitDescendents(true)
        rowControl:SetResizeToFitConstrains(ANCHOR_CONSTRAINS_X)
        rowControl:SetMouseEnabled(false)

        local timeline = ANIMATION_MANAGER:CreateTimeline()

        local scaleAnim = timeline:InsertAnimation(ANIMATION_SCALE, rowControl, 0)
        scaleAnim:SetScaleValues(1.1, 1.0)
        scaleAnim:SetDuration(100)
        -- scaleAnim:SetScaleFromCenter(true)
        scaleAnim:SetEasingFunction(ZO_EaseOutQuadratic)

        local fadeOutAnim = timeline:InsertAnimation(ANIMATION_ALPHA, rowControl, 0)
        fadeOutAnim:SetAlphaValues(1, 0.5)
        fadeOutAnim:SetDuration(_opponentVisibleDuration * 1000 / 2)

        local nameLabel = WINDOW_MANAGER:CreateControl(nil, rowControl, CT_LABEL)
        nameLabel:SetFont(FONT_NORMAL)
        nameLabel:SetColor(0.95, 0.95, 1, 1)
        nameLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        nameLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        nameLabel:SetWrapMode(TEXT_WRAP_MODE_TRUNCATE)
        nameLabel:SetAnchor(TOPLEFT, rowControl, TOPLEFT, 0, 0)
        nameLabel:SetDimensions(OPPONENT_NAME_WIDTH, OPPONENT_ROW_HEIGHT)
        nameLabel:SetMouseEnabled(false)

        local ddLabel = WINDOW_MANAGER:CreateControl(nil, rowControl, CT_LABEL)
        ddLabel:SetFont(FONT_NORMAL)
        ddLabel:SetColor(0.95, 0.95, 1, 1)
        ddLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        ddLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        ddLabel:SetWrapMode(TEXT_WRAP_MODE_TRUNCATE)
        ddLabel:SetAnchor(LEFT, nameLabel, RIGHT, 0, 0)
        ddLabel:SetDimensions(OPPONENT_DD_LABEL_WIDTH, OPPONENT_ROW_HEIGHT)
        ddLabel:SetMouseEnabled(false)

        local tankLabel = WINDOW_MANAGER:CreateControl(nil, rowControl, CT_LABEL)
        tankLabel:SetFont(FONT_NORMAL)
        tankLabel:SetColor(0.95, 0.95, 1, 1)
        tankLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        tankLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        tankLabel:SetWrapMode(TEXT_WRAP_MODE_TRUNCATE)
        tankLabel:SetAnchor(LEFT, ddLabel, RIGHT, 0, 0)
        tankLabel:SetDimensions(OPPONENT_TANK_LABEL_WIDTH, OPPONENT_ROW_HEIGHT)
        tankLabel:SetMouseEnabled(false)

        local attackIcon = WINDOW_MANAGER:CreateControl(nil, rowControl, CT_TEXTURE)
        attackIcon:SetAnchor(LEFT, tankLabel, RIGHT, OPPONENT_ATTACK_ICON_MARGIN, 0)
        attackIcon:SetDimensions(OPPONENT_ATTACK_ICON_SIZE, OPPONENT_ATTACK_ICON_SIZE)
        attackIcon:SetMouseEnabled(false)
        attackIcon:SetAlpha(0)

        local attackLabel = WINDOW_MANAGER:CreateControl(nil, rowControl, CT_LABEL)
        attackLabel:SetFont(FONT_NORMAL)
        attackLabel:SetColor(0.95, 0.95, 1, 1)
        attackLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
        attackLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        attackLabel:SetAnchor(LEFT, attackIcon, RIGHT, OPPONENT_ATTACK_ICON_MARGIN, 0)
        attackLabel:SetMouseEnabled(false)

        rowControl:SetHidden(true)
        _opponentRows[index] = {
            control = rowControl,
            timeline = timeline,
            nameLabel = nameLabel,
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

local function ApplyLayout()
    _window:ClearAnchors()
    _window:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT,
        _config.offsetX or _defaults.offsetX,
        _config.offsetY or _defaults.offsetY)
end

-------------------------------------------------------------------------------
-- Update UI
-------------------------------------------------------------------------------

local function RenderRowContents(row, opponentEntry)
    local opponent = opponentEntry.opponent
    local rowFont = opponentEntry.isActive and FONT_BOLD or FONT_NORMAL

    row.nameLabel:SetFont(rowFont)
    row.nameLabel:SetText(opponent.name or "?")

    if (opponent.lastBaseDamage or 0) > 0 then
        row.ddLabel:SetText(string.format("%d ||", opponent.lastBaseDamage))
    else
        row.ddLabel:SetText("||")
    end
    if (opponent.lastMitigation or 0) > 0 then
        local m = opponent.lastMitigation
        if m > 99 then
            m = 99
        end
        row.tankLabel:SetText(string.format("%d%%", m))
    else
        row.tankLabel:SetText("?%")
    end

    local attackIcon = nil
    local attackMarkupParts = {}

    if opponent.lastDealtAttack then
        local attack = opponent.lastDealtAttack
        attackIcon = attack.abilityIcon

        local abilityText = attack.abilityName
        local abilityMarkup = abilityText
        if attack.critical then
            abilityMarkup = "|cFFFF00" .. abilityText .. "|r"
        end
        if abilityText ~= "" then
            attackMarkupParts[#attackMarkupParts + 1] = abilityMarkup
        end

        local damageText = (attack.damage or -1) >= 0 and tostring(attack.damage) or ""
        local damageMarkup = damageText
        if attack.blocked then
            damageMarkup = "|c7F00FF" .. damageText .. "|r"
        elseif attack.shielded then
            damageMarkup = "|c00FF00" .. damageText .. "|r"
        end

        if damageText ~= "" then
            attackMarkupParts[#attackMarkupParts + 1] = damageMarkup
        end
    end

    row.attackIcon:SetAlpha(1)
    row.attackIcon:SetTexture(attackIcon)

    row.attackLabel:SetFont(rowFont)
    local attackText = table.concat(attackMarkupParts, "  ")
    row.attackLabel:SetText(attackText)

    row.control:SetHidden(false)
    row.timeline:PlayFromStart()
end

local function ClearRowUI(row)
    row.nameLabel:SetText("")
    row.attackIcon:SetTexture(nil)
    row.attackLabel:SetText("")
    row.control:SetHidden(true)
    row.contentWidth = 0
    row.timeline:Stop()
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
        row.control:ClearAnchors()
        row.control:SetAnchor(TOPLEFT, _contentArea, TOPLEFT, 0, (index - 1) * OPPONENT_ROW_HEIGHT)
        row.needsAnchor = false
    end
    if row.needsRender then
        RenderRowContents(row, entry)
        row.control:SetHidden(false)
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

local function InsertVisibleOpponentAtTop(opponent)
    if #_visibleOpponentEntries >= MAX_VISIBLE_OPPONENTS then
        RemoveVisibleOpponentAt(#_visibleOpponentEntries)
    end

    table.insert(_visibleOpponentEntries, 1, {
        opponent = opponent,
        isActive = true,
    })
    local row = table.remove(_opponentRows, #_visibleOpponentEntries)
    table.insert(_opponentRows, 1, row)
    row.needsAnchor = true
    row.needsRender = true
    for index = 2, #_visibleOpponentEntries do
        _opponentRows[index].needsAnchor = true
    end
end

local function AddOrUpdateVisibleOpponent(opponent)
    for index, entry in ipairs(_visibleOpponentEntries) do
        if entry.opponent == opponent then
            entry.isActive = true
            _opponentRows[index].needsRender = true
            return index
        end
    end

    InsertVisibleOpponentAtTop(opponent)
end

-------------------------------------------------------------------------------
-- Trigger: scheduled cleanup and opponent update events
-------------------------------------------------------------------------------

local UPDATE_CLEANUP_NAME = "TacticalDisplay_Panel_Cleanup"
local UPDATE_CLEANUP_INTERVAL_MS = 1000

local function CleanupOpponentEntries()
    local now = GetTimeStamp()
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
            local isActive = now - opponent.lastSeen <= _opponentActiveDuration
            if opponentEntry.isActive ~= isActive then
                opponentEntry.isActive = isActive
                _opponentRows[index].needsRender = true
                changed = true
            end
        end
    end
    if changed then
        ScheduleRenderTask()
    end
end

local OPPONENT_UPDATE_NAME = "TacticalDisplayPanel_Update"

local function OnOpponentUpdated(opponent)
    AddOrUpdateVisibleOpponent(opponent)
    ScheduleRenderTask()
end

-------------------------------------------------------------------------------
-- Public functions
-------------------------------------------------------------------------------

function _Panel.Initialize(savedVars)
    savedVars.panel = savedVars.panel or _defaults
    _config = savedVars.panel

    CreateUI()
    ApplyLayout()
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
    ApplyLayout()
end
