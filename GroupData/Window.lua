local _, addon = ...
local L = addon.L

local groupData = addon.GroupData

local WINDOW_WIDTH = 760
local WINDOW_HEIGHT = 320
local TABLE_INSET = 16
local HEADER_HEIGHT = 19
local TRINKET_COLUMN_WIDTH = 72
local COUNT_COLUMN_WIDTH = 72
local ADDON_COLUMN_WIDTH = 72
local TIME_COLUMN_WIDTH = 140
local WAR_MODE_COLUMN_WIDTH = 56
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

local frame

local function GetBooleanDisplay(value)
	return value and "+" or "-"
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
		local chromieTimeID = data.unit and UnitChromieTimeID(data.unit) or nil
		rows[index] = {
			index = index,
			name = data.displayName or data.name or L.UNKNOWN,
			oozeEquipped = data.hasSync and GetBooleanDisplay(data.oozeEquipped) or UNKNOWN_VALUE,
			uttsCount = data.hasSync and tostring(data.uttsCount or 0) or UNKNOWN_VALUE,
			dragonlingEquipped = data.hasSync and GetBooleanDisplay(data.dragonlingEquipped) or UNKNOWN_VALUE,
			addonVersion = data.hasSync and (data.addonVersion or "v?") or UNKNOWN_VALUE,
			timeText = data.unit and groupData.GetChromieTimeTextFromID(chromieTimeID or 0) or UNKNOWN_VALUE,
			warModeEnabled = data.hasSync and GetBooleanDisplay(data.warModeEnabled) or UNKNOWN_VALUE,
			isPlayer = data.name == playerKey,
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

	tableBuilder:AddUnsortableFillColumn(
		0,
		1.0,
		PLAYER_LEFT_CELL_PADDING,
		0,
		L.GROUP_DATA_HEADER_PLAYER,
		"Level20GroupDataCellTemplate",
		"name",
		"LEFT",
		"GameFontNormal"
	)

	AddStatusColumn(tableBuilder, ADDON_COLUMN_WIDTH, L.GROUP_DATA_HEADER_ADDON, "addonVersion")
	AddStatusColumn(tableBuilder, TIME_COLUMN_WIDTH, L.GROUP_DATA_HEADER_TIME, "timeText")
	AddStatusColumn(tableBuilder, WAR_MODE_COLUMN_WIDTH, L.GROUP_DATA_HEADER_WAR_MODE, "warModeEnabled")
	AddStatusColumn(tableBuilder, TRINKET_COLUMN_WIDTH, L.GROUP_DATA_HEADER_OOZE, "oozeEquipped")
	AddStatusColumn(tableBuilder, TRINKET_COLUMN_WIDTH, L.GROUP_DATA_HEADER_DRAGONLING, "dragonlingEquipped")
	AddStatusColumn(tableBuilder, COUNT_COLUMN_WIDTH, L.GROUP_DATA_HEADER_UTTS, "uttsCount")

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
	bodyFrame:SetPoint("BOTTOMRIGHT", tableFrame, "BOTTOMRIGHT", -22, 0)

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
