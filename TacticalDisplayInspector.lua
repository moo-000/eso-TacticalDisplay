TacticalDisplay = TacticalDisplay or {}
TacticalDisplay.Inspector = TacticalDisplay.Inspector or {}
local _Inspector = TacticalDisplay.Inspector
local _Data = TacticalDisplay.Data
local _FillDefaults = TacticalDisplay.Utilities.FillDefaults
local _LogError = TacticalDisplay.Utilities.LogError
local _SortedKeys = TacticalDisplay.Utilities.SortedKeys
local _LibScrollList = LibScrollList

local _OpponentTable -- assigned by Initialize
local _config
local _defaults = {
    offsetX = 100,
    offsetY = 40,
    sizeW = 1800,
    sizeH = 900,
}

local OPPONENTS_DATA_TYPE = 1

local _window
local _table

local function SaveWindowPosition()
    local left, top = _window:GetLeft(), _window:GetTop()
    if left and top then
        _config.offsetX = left
        _config.offsetY = top
    end
end

local function CreateUI()
    _window = CreateControl("TacticalDisplayInspector", GuiRoot, CT_TOPLEVELCONTROL)
    _window:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, _config.offsetX, _config.offsetY)
    _window:SetDimensions(_config.sizeW, _config.sizeH)
    _window:SetDrawTier(DT_LOW)
    _window:SetDrawLayer(DL_OVERLAY)
    _window:SetMouseEnabled(true)
    _window:SetMovable(true)
    _window:SetResizeHandleSize(16)
    _window:SetHidden(false)
    _window:SetHandler("OnMoveStop", SaveWindowPosition)

    local background = CreateControlFromVirtual("$(parent)Background", _window, "ZO_DefaultBackdrop")
    background:SetExcludeFromResizeToFitExtents(true)

    local labelCellStyle = {
        SetFont = { "ZoFontGame" },
        SetVerticalAlignment = { TEXT_ALIGN_CENTER },
    }

    local textureCellStyle = {}

    local defaultHeaderStyle = {
        SetFont = { "ZoFontGameBold" },
        SetColor = { 1.0, 1.0, 1.0 },
    }

    local alignLeft = { SetHorizontalAlignment = { TEXT_ALIGN_LEFT } }
    local alignCenter = { SetHorizontalAlignment = { TEXT_ALIGN_CENTER } }
    local alignRight = { SetHorizontalAlignment = { TEXT_ALIGN_RIGHT } }

    local Table = LibScrollList.Table
    local Column = LibScrollList.Column
    local Label = LibScrollList.Label
    local Texture = LibScrollList.Texture
    local combine = LibScrollList.combine

    local header = Label(combine(defaultHeaderStyle, alignLeft))
    local columns = {
        Column("Name", 200, 0, Label(combine(labelCellStyle, alignLeft)),
            "Name", header, true),
        Column("LastSeen", 200, 0, Label(combine(labelCellStyle, alignRight)),
            "Last seen", header, true),
        Column("Damage", 70, 0, Label(combine(labelCellStyle, alignRight)),
            "Damage", header, true),
        Column("Mitigation", 70, 0, Label(combine(labelCellStyle, alignRight)),
            "Mitigation", header, true),
        Column("Sig1Icon", 30, 0, Texture(), "", header, false),
        Column("Sig1Name", 200, 0, Label(combine(labelCellStyle, alignLeft)),
            "1", header, true),
        Column("Sig2Icon", 30, 0, Texture(), "", header, false),
        Column("Sig2Name", 200, 0, Label(combine(labelCellStyle, alignLeft)),
            "2", header, true),
        Column("Sig3Icon", 30, 0, Texture(), "", header, false),
        Column("Sig3Name", 200, 0, Label(combine(labelCellStyle, alignLeft)),
            "3", header, true),
        Column("Sig4Icon", 30, 0, Texture(), "", header, false),
        Column("Sig4Name", 200, 0, Label(combine(labelCellStyle, alignLeft)),
            "4", header, true),
    }

    _table = Table(true)
    _table:AddDataType(OPPONENTS_DATA_TYPE, columns, 24)

    local scrollControl = _table:Create("Opponents", _window)
    scrollControl:SetAnchorFill(_window)
end

function _Inspector.Show()
    if _LibScrollList == nil then
        _LogError("cannot show inspector - LibScrollList not installed")
        return
    end

    if not _window then
        CreateUI()
    end

    local data = {}
    for _, name in ipairs(_SortedKeys(_OpponentTable)) do
        local opponent = _OpponentTable[name]
        local row = {
            name,
            opponent.lastSeen and os.date("%Y/%m/%d %H:%M:%S", GetTimeStamp()) or "?",
            opponent.lastBaseDamage and tostring(opponent.lastBaseDamage) or "?",
            opponent.lastMitigation and tostring(opponent.lastMitigation) .. "%" or "?",
        }
        local signature = opponent.signature or {}
        local sigKeys = _SortedKeys(signature)
        for i = 1, 4 do
            local abilityId = sigKeys[i]
            if abilityId == nil then
                row[#row + 1] = ""
                row[#row + 1] = ""
            else
                local sitem = signature[abilityId]
                row[#row + 1] = sitem.abilityIcon
                row[#row + 1] = sitem.abilityName
            end
        end
        data[#data + 1] = row
    end

    _table:Update(OPPONENTS_DATA_TYPE, data)
end

function _Inspector.Initialize(savedVars)
    savedVars.inspector = savedVars.inspector or _defaults
    _config = savedVars.inspector
    _FillDefaults(_config, _defaults)

    _OpponentTable = _Data.OpponentTable
end
