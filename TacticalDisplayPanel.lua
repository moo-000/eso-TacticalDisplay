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

local MIN_WIDTH = 240
local MIN_HEIGHT = 100
local CONTENT_PADDING = 8
local LABEL_SPACE = 4

local MAX_VISIBLE_OPPONENTS = 12
local OPPONENT_ROW_HEIGHT = 23
local OPPONENT_NAME_WIDTH = 120
local OPPONENT_ICON_MARGIN_L = 8
local OPPONENT_ICON_MARGIN_R = 6
local OPPONENT_ICON_SIZE = 20
local OPPONENT_DETAILS_OFFSET = OPPONENT_NAME_WIDTH
    + OPPONENT_ICON_MARGIN_L + OPPONENT_ICON_SIZE + OPPONENT_ICON_MARGIN_R

local _visibleOpponentEntries = {} -- [index] = { opponent, isActive }

local _isPanelEnabled = false
local _fragment
local _window
local _contentArea
local _opponentRows = {}

-------------------------------------------------------------------------------
-- Create UI
-------------------------------------------------------------------------------

local function OnMouseDown(control, button)
    if button == MOUSE_BUTTON_INDEX_LEFT then
        control:SetMovable(true)
        control:StartMoving()
    end
end

local function OnMouseUp(control, button)
    control:SetMovable(false)
    if button == MOUSE_BUTTON_INDEX_LEFT and _window and _config then
        control:StopMovingOrResizing()
        local left, top = _window:GetLeft(), _window:GetTop()
        if left and top then
            _config.offsetX = left
            _config.offsetY = top
        end
    end
end

local function UpdateContentSize(width, height)
    local panelWidth = math.max(MIN_WIDTH, (width or 0) + CONTENT_PADDING * 2)
    local panelHeight = math.max(MIN_HEIGHT, (height or 0) + CONTENT_PADDING * 2)
    _window:SetDimensions(panelWidth, panelHeight)
end

local function CreateUI()
    _window = WINDOW_MANAGER:CreateTopLevelWindow("TacticalDisplayWindow")
    _window:SetDimensions(MIN_WIDTH, MIN_HEIGHT)
    _window:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, _defaults.offsetX, _defaults.offsetY)
    _window:SetDrawTier(DT_LOW)
    _window:SetDrawLayer(DL_OVERLAY)
    _window:SetClampedToScreen(true)
    _window:SetMouseEnabled(true)
    _window:SetMovable(false)
    _window:SetHidden(false)
    _window:SetHandler("OnMouseDown", function(_, button) OnMouseDown(_window, button) end)
    _window:SetHandler("OnMouseUp", function(_, button) OnMouseUp(_window, button) end)

    local _backdrop = WINDOW_MANAGER:CreateControl(nil, _window, CT_BACKDROP)
    _backdrop:SetAnchorFill(_window)
    _backdrop:SetCenterColor(0, 0, 0, 0.16)
    _backdrop:SetEdgeColor(0.65, 0.75, 0.9, 0.55)
    _backdrop:SetEdgeTexture("EsoUI/Art/Tooltips/UI-Border.dds", CONTENT_PADDING, CONTENT_PADDING, 2, 0)
    _backdrop:SetMouseEnabled(false)

    _contentArea = WINDOW_MANAGER:CreateControl("TacticalDisplayContent", _window, CT_CONTROL)
    _contentArea:SetAnchor(TOPLEFT, _window, TOPLEFT, CONTENT_PADDING, CONTENT_PADDING)
    _contentArea:SetAnchor(BOTTOMRIGHT, _window, BOTTOMRIGHT, -CONTENT_PADDING, -CONTENT_PADDING)
    _contentArea:SetMouseEnabled(false)

    for index = 1, MAX_VISIBLE_OPPONENTS do
        local rowControl = WINDOW_MANAGER:CreateControl(nil, _contentArea, CT_CONTROL)
        rowControl:SetAnchor(TOPLEFT, _contentArea, TOPLEFT, 0, 0)
        rowControl:SetDimensions(MIN_WIDTH, OPPONENT_ROW_HEIGHT)
        rowControl:SetMouseEnabled(false)

        local nameLabel = WINDOW_MANAGER:CreateControl(nil, rowControl, CT_LABEL)
        nameLabel:SetFont("ZoFontGame")
        nameLabel:SetColor(0.95, 0.95, 1, 1)
        nameLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        nameLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        nameLabel:SetWrapMode(TEXT_WRAP_MODE_TRUNCATE)
        nameLabel:SetAnchor(TOPLEFT, rowControl, TOPLEFT, 0, 0)
        nameLabel:SetDimensions(OPPONENT_NAME_WIDTH, OPPONENT_ROW_HEIGHT)
        nameLabel:SetMouseEnabled(false)

        local icon = WINDOW_MANAGER:CreateControl(nil, rowControl, CT_TEXTURE)
        icon:SetAnchor(LEFT, rowControl, LEFT, OPPONENT_NAME_WIDTH + OPPONENT_ICON_MARGIN_L, 0)
        icon:SetDimensions(OPPONENT_ICON_SIZE, OPPONENT_ICON_SIZE)
        icon:SetMouseEnabled(false)
        icon:SetHidden(true)

        local detailLabel = WINDOW_MANAGER:CreateControl(nil, rowControl, CT_LABEL)
        detailLabel:SetFont("ZoFontGame")
        detailLabel:SetColor(0.95, 0.95, 1, 1)
        detailLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
        detailLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        detailLabel:SetAnchor(TOPLEFT, rowControl, TOPLEFT, OPPONENT_DETAILS_OFFSET, 0)
        detailLabel:SetDimensions(MIN_WIDTH, OPPONENT_ROW_HEIGHT)
        detailLabel:SetMouseEnabled(false)

        rowControl:SetHidden(true)
        _opponentRows[index] = {
            control = rowControl,
            nameLabel = nameLabel,
            icon = icon,
            detailLabel = detailLabel,
        }
    end

    _fragment = ZO_FadeSceneFragment:New(_window, true, 150)
    _fragment:SetConditional(function()
        return _isPanelEnabled
    end)
    SCENE_MANAGER:GetScene("hud"):AddFragment(_fragment)
    SCENE_MANAGER:GetScene("hudui"):AddFragment(_fragment)

    UpdateContentSize()
end

local function ApplyLayout()
    _window:ClearAnchors()
    _window:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT,
        _config.offsetX or _defaults.offsetX,
        _config.offsetY or _defaults.offsetY)
    UpdateContentSize()
end

-------------------------------------------------------------------------------
-- Update UI
-------------------------------------------------------------------------------

local function RenderRowContents(row, opponentEntry)
    local opponent = opponentEntry.opponent
    local rowFont = opponentEntry.isActive
        and "$(BOLD_FONT)|18|soft-shadow-thick"
        or "$(MEDIUM_FONT)|18|soft-shadow-thick"
    row.nameLabel:SetFont(rowFont)
    row.detailLabel:SetFont(rowFont)

    local markupParts = {}
    local plainParts = {}
    local attackIcon = nil

    if opponent.lastDealtAttack then
        local attack = opponent.lastDealtAttack
        attackIcon = attack.abilityIcon

        local abilityText = attack.abilityName
        local abilityMarkup = abilityText
        if attack.critical then
            abilityMarkup = "|cFFFF00" .. abilityText .. "|r"
        end
        if abilityText ~= "" then
            markupParts[#markupParts + 1] = abilityMarkup
            plainParts[#plainParts + 1] = abilityText
        end

        local damageText = (attack.damage or -1) >= 0 and tostring(attack.damage) or ""
        local damageMarkup = damageText
        if attack.blocked then
            damageMarkup = "|c7F00FF" .. damageText .. "|r"
        elseif attack.shielded then
            damageMarkup = "|c00FF00" .. damageText .. "|r"
        end

        if damageText ~= "" then
            markupParts[#markupParts + 1] = damageMarkup
            plainParts[#plainParts + 1] = damageText
        end
    end

    if (opponent.lastBaseDamage or 0) > 0 then
        markupParts[#markupParts + 1] = string.format("[%d]", opponent.lastBaseDamage)
        plainParts[#plainParts + 1] = string.format("[%d]", opponent.lastBaseDamage)
    end
    if (opponent.lastMitigation or 0) > 0 then
        markupParts[#markupParts + 1] = string.format("(%d%%)", opponent.lastMitigation)
        plainParts[#plainParts + 1] = string.format("(%d%%)", opponent.lastMitigation)
    end

    local detailText = table.concat(markupParts, "  ")
    local plainDetailText = table.concat(plainParts, "  ")
    row.nameLabel:SetText(opponent.name or "?")
    row.nameLabel:SetDimensions(OPPONENT_NAME_WIDTH, OPPONENT_ROW_HEIGHT)
    row.detailLabel:SetText(detailText)
    local showIcon = attackIcon ~= nil
    row.icon:SetHidden(not showIcon)
    if showIcon then
        row.icon:SetTexture(attackIcon)
    end
    row.control:SetHidden(false)
    local detailWidth = row.detailLabel:GetStringWidth(plainDetailText)
    row.detailLabel:SetDimensions(detailWidth + LABEL_SPACE, OPPONENT_ROW_HEIGHT)
    row.contentWidth = OPPONENT_DETAILS_OFFSET + detailWidth
    row.control:SetDimensions(row.contentWidth + LABEL_SPACE, OPPONENT_ROW_HEIGHT)
end

local function ClearRowUI(row)
    row.nameLabel:SetText("")
    row.detailLabel:SetText("")
    row.icon:SetHidden(true)
    row.control:SetHidden(true)
    row.contentWidth = 0
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
    local maxTextWidth = 0
    for index, row in ipairs(_opponentRows) do
        RenderRowUI(index, row)
        if index <= #_visibleOpponentEntries then
            maxTextWidth = math.max(maxTextWidth, row.contentWidth or 0)
        end
    end
    UpdateContentSize(maxTextWidth, #_visibleOpponentEntries * OPPONENT_ROW_HEIGHT)
end

local UPDATE_RENDER_NAME = "TacticalDisplay_Panel_Render"
local UPDATE_RENDER_DELAY_MS = 100

local _opponentRenderScheduled = false

local function ScheduleOpponentRender()
    if _opponentRenderScheduled then
        return
    end
    _opponentRenderScheduled = true

    EVENT_MANAGER:RegisterForUpdate(UPDATE_RENDER_NAME, UPDATE_RENDER_DELAY_MS, function()
        EVENT_MANAGER:UnregisterForUpdate(UPDATE_RENDER_NAME)
        _opponentRenderScheduled = false
        RenderPanelUI()
    end)
end

-------------------------------------------------------------------------------
-- Update view model
-------------------------------------------------------------------------------

local function RemoveVisibleOpponentAt(index)
    table.remove(_visibleOpponentEntries, index)
    local removedRow = table.remove(_opponentRows, index)
    table.insert(_opponentRows, removedRow)
    removedRow.needsRender = true
    removedRow.needsAnchor = false
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
    row.needsRender = true
    row.needsAnchor = true
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
        ScheduleOpponentRender()
    end
end

local OPPONENT_UPDATE_NAME = "TacticalDisplayPanel_Update"

local function OnOpponentUpdated(opponent)
    AddOrUpdateVisibleOpponent(opponent)
    ScheduleOpponentRender()
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

    ScheduleOpponentRender()
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
