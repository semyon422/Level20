local _, addon = ...
local L = addon.L

local groupData = addon.GroupData

local WINDOW_WIDTH = 980
local WINDOW_HEIGHT = 320
local TABLE_INSET = 16
local HEADER_HEIGHT = 19
local LEVEL_COLUMN_WIDTH = 40
local CLASS_COLUMN_WIDTH = 40
local ROLE_COLUMN_WIDTH = 40
local TRINKET_COLUMN_WIDTH = 72
local COUNT_COLUMN_WIDTH = 72
local ADDON_COLUMN_WIDTH = 72
local INSTANCE_COLUMN_WIDTH = 52
local TIME_COLUMN_WIDTH = 172
local HEADER_LEFT_INSET = 4
local HEADER_RIGHT_INSET = 26
local HEADER_TOP_OFFSET = -1
local BODY_TOP_OFFSET = -1
local SCROLLBOX_TOP_INSET = 5
local SCROLLBOX_SIDE_INSET = 1
local SCROLLBOX_BOTTOM_INSET = 1
local SCROLLBAR_X_OFFSET = 9
local SCROLLBAR_BOTTOM_OFFSET = 4
local PLAYER_LEFT_CELL_PADDING = 12
local UNKNOWN_VALUE = "?"
local CLASS_ICON_TEXTURE = "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES"
local OFFLINE_COLOR_FALLBACK = "ff8a8a8a"

local frame

local function GetBooleanIconData(value)
	return {
		atlas = value and "common-icon-checkmark" or "common-icon-redx",
	}
end

local function GetOfflineColorString()
	return GRAY_FONT_COLOR and GRAY_FONT_COLOR.colorStr or OFFLINE_COLOR_FALLBACK
end

local function GetBooleanDisplay(value)
	return value and "+" or "-"
end

local function GetUnitLevelDisplay(unit)
	if not unit or not UnitExists(unit) then
		return UNKNOWN_VALUE
	end

	local level = UnitLevel(unit)
	if not level or level <= 0 then
		return UNKNOWN_VALUE
	end

	return tostring(level)
end

local function GetUnitClassDisplay(unit)
	if not unit or not UnitExists(unit) then
		return UNKNOWN_VALUE
	end

	local className = select(1, UnitClass(unit))
	return className or UNKNOWN_VALUE
end

local function GetUnitClassIconData(unit)
	if not unit or not UnitExists(unit) then
		return nil
	end

	local _, classFile = UnitClass(unit)
	local texCoords = classFile and CLASS_ICON_TCOORDS[classFile]
	if not texCoords then
		return nil
	end

	return {
		texture = CLASS_ICON_TEXTURE,
		texCoords = texCoords,
	}
end

local function GetUnitRoleDisplay(unit)
	if not unit or not UnitExists(unit) then
		return UNKNOWN_VALUE
	end

	local role = UnitGroupRolesAssigned(unit)
	if role == "TANK" then
		return TANK
	elseif role == "HEALER" then
		return HEALER
	elseif role == "DAMAGER" then
		return DAMAGER
	elseif role == "NONE" then
		return NONE
	end

	return UNKNOWN_VALUE
end

local function GetUnitRoleIconData(unit)
	if not unit or not UnitExists(unit) then
		return nil
	end

	local role = UnitGroupRolesAssigned(unit)
	if role == "TANK" then
		return { atlas = GetMicroIconForRoleEnum(Enum.LFGRole.Tank) }
	elseif role == "HEALER" then
		return { atlas = GetMicroIconForRoleEnum(Enum.LFGRole.Healer) }
	elseif role == "DAMAGER" then
		return { atlas = GetMicroIconForRoleEnum(Enum.LFGRole.Damage) }
	end

	return nil
end

local function GetUnitClassColorString(unit)
	if not unit or not UnitExists(unit) then
		return NORMAL_FONT_COLOR and NORMAL_FONT_COLOR.colorStr or "ffffffff"
	end

	local _, classFile = UnitClass(unit)
	local classColorTable = (CUSTOM_CLASS_COLORS and classFile and CUSTOM_CLASS_COLORS[classFile])
		or (RAID_CLASS_COLORS and classFile and RAID_CLASS_COLORS[classFile])

	if classColorTable and classColorTable.colorStr then
		return classColorTable.colorStr
	end

	if classColorTable and CreateColor then
		return CreateColor(classColorTable.r, classColorTable.g, classColorTable.b):GenerateColorString()
	end

	return NORMAL_FONT_COLOR and NORMAL_FONT_COLOR.colorStr or "ffffffff"
end

local function GetDisplayValue(data, field, formatter)
	if not data.hasSync or data[field] == nil then
		return UNKNOWN_VALUE
	end

	return formatter(data[field])
end

local function IdentityDataProvider(rowData)
	return rowData
end

local function AddStatusColumn(tableBuilder, width, headerText, field)
	tableBuilder:AddUnsortableFixedWidthColumn(
		0,
		width,
		0,
		0,
		headerText,
		"Level20GroupDataCellTemplate",
		field,
		"CENTER",
		"GameFontHighlight"
	)
end

local function AddBooleanStatusColumn(tableBuilder, width, headerText, field)
	tableBuilder:AddUnsortableFixedWidthColumn(
		0,
		width,
		0,
		0,
		headerText,
		"Level20GroupDataBooleanCellTemplate",
		field
	)
end

local function ArrangeTable()
	if not frame or not frame.tableBuilder or not frame.headerRow then
		return
	end

	frame.tableBuilder:SetTableWidth(frame.headerRow:GetWidth())
	frame.tableBuilder:Arrange()
end

local function BuildRows()
	local players = groupData.GetSortedPlayers()
	if #players == 0 then
		return {}
	end

	local playerKey = groupData.GetPlayerKey(GetUnitName("player", true))
	local rows = {}
	for index, data in ipairs(players) do
		local isOffline = data.unit and UnitExists(data.unit) and not UnitIsConnected(data.unit) or false
		local chromieTimeID = data.unit and UnitChromieTimeID(data.unit) or nil
		local baseChromieText = data.unit and groupData.GetChromieTimeTextFromID(chromieTimeID or 0) or UNKNOWN_VALUE
		local timeText = groupData.FormatChromieStatusText(baseChromieText, data.warModeEnabled, data.lorewalkingActive)
		if not data.hasSync then
			timeText = timeText .. " (?)"
		end

		local playerName = data.displayName or data.name or L.UNKNOWN
		local playerNameColor = isOffline and GetOfflineColorString() or GetUnitClassColorString(data.unit)
		rows[index] = {
			index = index,
			name = playerName,
			nameColored = WrapTextInColorCode(playerName, playerNameColor),
			level = GetUnitLevelDisplay(data.unit),
			class = GetUnitClassDisplay(data.unit),
			role = GetUnitRoleDisplay(data.unit),
			classIcon = GetUnitClassIconData(data.unit),
			roleIcon = GetUnitRoleIconData(data.unit),
			addonVersion = GetDisplayValue(data, "addonVersion", function(value)
				return value or "v?"
			end),
			inInstance = GetDisplayValue(data, "inInstance", GetBooleanIconData),
			timeText = timeText,
			oozeEquipped = GetDisplayValue(data, "oozeEquipped", GetBooleanIconData),
			dragonlingEquipped = GetDisplayValue(data, "dragonlingEquipped", GetBooleanIconData),
			uttsCount = GetDisplayValue(data, "uttsCount", function(value)
				return tostring(value or 0)
			end),
			amberOwned = GetDisplayValue(data, "amberOwned", GetBooleanIconData),
			isPlayer = data.name == playerKey,
			isOffline = isOffline,
		}
	end

	return rows
end

local function SaveWindowPosition(self)
	self:StopMovingOrSizing()

	local point, _, relativePoint, xOfs, yOfs = self:GetPoint()
	Level20DB.groupDataWindowPoint = point
	Level20DB.groupDataWindowRelativePoint = relativePoint
	Level20DB.groupDataWindowXOfs = xOfs
	Level20DB.groupDataWindowYOfs = yOfs
end

local function InitializeTable(window)
	local view = CreateScrollBoxListLinearView()
	view:SetElementInitializer("Level20GroupDataRowTemplate", function()
	end)
	ScrollUtil.InitScrollBoxListWithScrollBar(window.ScrollBox, window.scrollBar, view)

	local tableBuilder = CreateTableBuilder(nil, Level20GroupDataTableBuilderMixin)
	tableBuilder:SetDataProvider(IdentityDataProvider)
	tableBuilder:SetColumnHeaderOverlap(2)
	tableBuilder:SetHeaderContainer(window.headerRow)

	AddStatusColumn(tableBuilder, LEVEL_COLUMN_WIDTH, L.GROUP_DATA_HEADER_LEVEL, "level")
	tableBuilder:AddUnsortableFixedWidthColumn(
		0,
		CLASS_COLUMN_WIDTH,
		0,
		0,
		L.GROUP_DATA_HEADER_CLASS,
		"Level20GroupDataIconCellTemplate",
		"classIcon"
	)
	tableBuilder:AddUnsortableFixedWidthColumn(
		0,
		ROLE_COLUMN_WIDTH,
		0,
		0,
		L.GROUP_DATA_HEADER_ROLE,
		"Level20GroupDataIconCellTemplate",
		"roleIcon"
	)
	tableBuilder:AddUnsortableFillColumn(
		0,
		1.0,
		PLAYER_LEFT_CELL_PADDING,
		0,
		L.GROUP_DATA_HEADER_PLAYER,
		"Level20GroupDataCellTemplate",
		"nameColored",
		"LEFT",
		"GameFontNormal"
	)
	AddStatusColumn(tableBuilder, ADDON_COLUMN_WIDTH, L.GROUP_DATA_HEADER_ADDON, "addonVersion")
	AddBooleanStatusColumn(tableBuilder, INSTANCE_COLUMN_WIDTH, L.GROUP_DATA_HEADER_INSTANCE, "inInstance")
	AddStatusColumn(tableBuilder, TIME_COLUMN_WIDTH, L.GROUP_DATA_HEADER_TIME, "timeText")
	AddBooleanStatusColumn(tableBuilder, TRINKET_COLUMN_WIDTH, L.GROUP_DATA_HEADER_OOZE, "oozeEquipped")
	AddBooleanStatusColumn(tableBuilder, TRINKET_COLUMN_WIDTH, L.GROUP_DATA_HEADER_DRAGONLING, "dragonlingEquipped")
	AddStatusColumn(tableBuilder, COUNT_COLUMN_WIDTH, L.GROUP_DATA_HEADER_UTTS, "uttsCount")
	AddBooleanStatusColumn(tableBuilder, TRINKET_COLUMN_WIDTH, L.GROUP_DATA_HEADER_AMBER, "amberOwned")

	ScrollUtil.RegisterTableBuilder(window.ScrollBox, tableBuilder, IdentityDataProvider)
	window.tableBuilder = tableBuilder
	ArrangeTable()
end

local function CreateWindow()
	local window = CreateFrame("Frame", "Level20GroupDataFrame", UIParent, "DefaultPanelTemplate")
	window:SetSize(WINDOW_WIDTH, WINDOW_HEIGHT)
	window:SetPoint("CENTER", UIParent, "CENTER", 120, 0)
	window:SetMovable(true)
	window:SetClampedToScreen(true)
	window:EnableMouse(true)
	window:SetToplevel(true)
	window:SetFrameStrata("DIALOG")
	window:RegisterForDrag("LeftButton")
	window:SetScript("OnMouseDown", function(self)
		self:Raise()
	end)
	window:SetScript("OnDragStart", function(self)
		self:Raise()
		self:StartMoving()
	end)
	window:SetScript("OnDragStop", SaveWindowPosition)
	window:SetTitle(L.GROUP_TRINKETS_WINDOW_TITLE)
	window:Hide()
	window.CloseButton = CreateFrame("Button", nil, window, "UIPanelCloseButtonDefaultAnchors")

	local tableFrame = CreateFrame("Frame", nil, window)
	tableFrame:SetPoint("TOPLEFT", window, "TOPLEFT", TABLE_INSET, -34)
	tableFrame:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -TABLE_INSET, 14)

	local headerRow = CreateFrame("Frame", nil, tableFrame)
	headerRow:SetPoint("TOPLEFT", tableFrame, "TOPLEFT", HEADER_LEFT_INSET, HEADER_TOP_OFFSET)
	headerRow:SetPoint("TOPRIGHT", tableFrame, "TOPRIGHT", -HEADER_RIGHT_INSET, HEADER_TOP_OFFSET)
	headerRow:SetHeight(HEADER_HEIGHT)

	local bodyFrame = CreateFrame("Frame", nil, tableFrame, "InsetFrameTemplate")
	bodyFrame:SetPoint("TOPLEFT", headerRow, "BOTTOMLEFT", -1, BODY_TOP_OFFSET)
	bodyFrame:SetPoint("BOTTOMRIGHT", tableFrame, "BOTTOMRIGHT", -12, 0)

	local scrollBox = CreateFrame("Frame", nil, bodyFrame, "WowScrollBoxList")
	scrollBox:SetPoint("TOPLEFT", bodyFrame, "TOPLEFT", SCROLLBOX_SIDE_INSET, -SCROLLBOX_TOP_INSET)
	scrollBox:SetPoint("TOPRIGHT", bodyFrame, "TOPRIGHT", -SCROLLBOX_SIDE_INSET, -SCROLLBOX_TOP_INSET)
	scrollBox:SetPoint("BOTTOMLEFT", bodyFrame, "BOTTOMLEFT", SCROLLBOX_SIDE_INSET, SCROLLBOX_BOTTOM_INSET)
	scrollBox:SetPoint("BOTTOMRIGHT", bodyFrame, "BOTTOMRIGHT", -SCROLLBOX_SIDE_INSET, SCROLLBOX_BOTTOM_INSET)

	local scrollBar = CreateFrame("EventFrame", nil, tableFrame, "MinimalScrollBar")
	scrollBar:SetPoint("TOPLEFT", scrollBox, "TOPRIGHT", SCROLLBAR_X_OFFSET, 0)
	scrollBar:SetPoint("BOTTOMLEFT", scrollBox, "BOTTOMRIGHT", SCROLLBAR_X_OFFSET, SCROLLBAR_BOTTOM_OFFSET)
	scrollBar:SetHideIfUnscrollable(false)

	local emptyLabel = bodyFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	emptyLabel:SetPoint("TOP", scrollBox, "TOP", 0, -28)
	emptyLabel:SetPoint("LEFT", scrollBox, "LEFT", 24, 0)
	emptyLabel:SetPoint("RIGHT", scrollBox, "RIGHT", -24, 0)
	emptyLabel:SetText(L.GROUP_TRINKETS_EMPTY)
	emptyLabel:SetTextColor(0.75, 0.75, 0.75)

	window.emptyLabel = emptyLabel
	window.headerRow = headerRow
	window.ScrollBox = scrollBox
	window.scrollBar = scrollBar

	InitializeTable(window)

	scrollBox:SetScript("OnSizeChanged", function()
		ArrangeTable()
	end)

	window:SetScript("OnShow", function()
		window:Raise()
		ArrangeTable()
		groupData.RefreshWindow()
		groupData.RefreshAndBroadcast(true)
	end)

	if Level20DB.groupDataWindowPoint then
		window:ClearAllPoints()
		window:SetPoint(
			Level20DB.groupDataWindowPoint,
			UIParent,
			Level20DB.groupDataWindowRelativePoint or Level20DB.groupDataWindowPoint,
			Level20DB.groupDataWindowXOfs or 0,
			Level20DB.groupDataWindowYOfs or 0
		)
	end

	return window
end

function groupData.EnsureWindow()
	if not frame then
		frame = CreateWindow()
	end

	return frame
end

function groupData.RefreshWindow()
	if not frame then
		return
	end

	local rows = BuildRows()
	if #rows == 0 then
		frame.emptyLabel:Show()
		frame.ScrollBox:SetDataProvider(CreateDataProvider())
		return
	end

	frame.emptyLabel:Hide()
	frame.ScrollBox:SetDataProvider(CreateDataProvider(rows), ScrollBoxConstants.RetainScrollPosition)
	ArrangeTable()
end

function groupData.ShowWindow()
	groupData.EnsureWindow():Show()
end

function groupData.ToggleWindow()
	local window = groupData.EnsureWindow()
	if window:IsShown() then
		window:Hide()
	else
		groupData.ShowWindow()
	end
end
