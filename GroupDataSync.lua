local addonName, addon = ...
local L = addon.L

local COMM_PREFIX = "L20TRK"
local MESSAGE_VERSION = "4"
local OOZE_TRINKET_ITEM_ID = 178769
local UTTS_ITEM_ID = 158379
local DRAGONLING_TRINKET_ITEM_ID = 77530
local WINDOW_WIDTH = 760
local WINDOW_HEIGHT = 320
local TABLE_INSET = 16
local HEADER_HEIGHT = 19
local ROW_HEIGHT = 20
local TRINKET_COLUMN_WIDTH = 72
local COUNT_COLUMN_WIDTH = 72
local ADDON_COLUMN_WIDTH = 72
local TIME_COLUMN_WIDTH = 140
local WAR_MODE_COLUMN_WIDTH = 56
local HEADER_LEFT_INSET = 4
local HEADER_RIGHT_INSET = 26
local HEADER_TOP_OFFSET = -1
local BODY_TOP_OFFSET = -1
local SCROLL_BOTTOM_OFFSET = 3
local SCROLLBOX_TOP_INSET = 5
local SCROLLBOX_SIDE_INSET = 1
local SCROLLBOX_BOTTOM_INSET = 1
local SCROLLBAR_X_OFFSET = 9
local SCROLLBAR_BOTTOM_OFFSET = 4
local PLAYER_LEFT_CELL_PADDING = 12
local BOOL_TRUE = "1"
local BOOL_FALSE = "0"
local UNKNOWN_VALUE = "?"

local state = {
	initialized = false,
	players = {},
	lastBroadcastMessage = nil,
	lastLocalMessage = nil,
}

local groupDataFrame
local RefreshAndBroadcastLocalGroupData

local function GetChromieTimeTextFromID(chromieTimeID)
	if chromieTimeID == 0 then
		return L.CHROMIE_TIME_PRESENT
	end

	if not chromieTimeID or chromieTimeID < 0 then
		return L.UNKNOWN
	end

	local options = C_ChromieTime and C_ChromieTime.GetChromieTimeExpansionOptions and C_ChromieTime.GetChromieTimeExpansionOptions()
	if type(options) ~= "table" then
		return L.UNKNOWN
	end

	for _, option in ipairs(options) do
		if option.id == chromieTimeID then
			return option.name or L.UNKNOWN
		end
	end

	return L.UNKNOWN
end

function addon.GetChromieTimeText()
	if not C_PlayerInfo or not C_PlayerInfo.IsPlayerInChromieTime or not C_PlayerInfo.IsPlayerInChromieTime() then
		return L.CHROMIE_TIME_PRESENT
	end

	local chromieTimeID = UnitChromieTimeID("player")
	if not chromieTimeID then
		return L.UNKNOWN
	end

	return GetChromieTimeTextFromID(chromieTimeID)
end

local function GetChromieTimeSyncValue()
	if not C_PlayerInfo or not C_PlayerInfo.IsPlayerInChromieTime or not C_PlayerInfo.IsPlayerInChromieTime() then
		return 0
	end

	local chromieTimeID = UnitChromieTimeID("player")
	return chromieTimeID or -1
end

local function IsWarModeEnabled()
	return C_PvP and C_PvP.IsWarModeDesired and C_PvP.IsWarModeDesired() or false
end

local function IsTrackedTrinketEquipped(itemID)
	if not itemID then
		return false
	end

	return GetInventoryItemID("player", INVSLOT_TRINKET1) == itemID
		or GetInventoryItemID("player", INVSLOT_TRINKET2) == itemID
end

local function EncodeBoolean(value)
	return value and BOOL_TRUE or BOOL_FALSE
end

local function DecodeBoolean(value)
	return value == BOOL_TRUE
end

local function GetBooleanDisplay(value)
	return value and "+" or "-"
end

local function GetPlayerKey(name)
	if not name or name == "" then
		return nil
	end

	return Ambiguate(name, "none")
end

local function IsOwnSender(sender)
	local playerName = GetUnitName("player", true)
	return playerName and sender and Ambiguate(sender, "none") == Ambiguate(playerName, "none")
end

local function GetGroupDistribution()
	if IsInRaid(LE_PARTY_CATEGORY_INSTANCE) then
		return "INSTANCE_CHAT"
	end

	if IsInRaid() then
		return "RAID"
	end

	if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
		return "INSTANCE_CHAT"
	end

	if IsInGroup() then
		return "PARTY"
	end
end

local function GetTrackedItemCount(itemID)
	if not itemID then
		return 0
	end

	return GetItemCount(itemID, false, false) or 0
end

local function BuildRosterOrder()
	local players = {}

	if UnitExists("player") then
		players[#players + 1] = {
			key = GetPlayerKey(GetUnitName("player", true)),
			displayName = GetUnitName("player", false),
		}
	end

	if IsInRaid() then
		for index = 1, GetNumGroupMembers() do
			local unit = "raid" .. index
			if UnitExists(unit) and UnitIsPlayer(unit) and not UnitIsUnit(unit, "player") then
				players[#players + 1] = {
					key = GetPlayerKey(GetUnitName(unit, true)),
					displayName = GetUnitName(unit, false),
				}
			end
		end
	elseif IsInGroup() then
		for index = 1, GetNumSubgroupMembers() do
			local unit = "party" .. index
			if UnitExists(unit) and UnitIsPlayer(unit) then
				players[#players + 1] = {
					key = GetPlayerKey(GetUnitName(unit, true)),
					displayName = GetUnitName(unit, false),
				}
			end
		end
	end

	return players
end

local function GetSortedSyncedPlayers()
	local rosterOrder = BuildRosterOrder()
	local indexed = {}

	for orderIndex, rosterEntry in ipairs(rosterOrder) do
		if rosterEntry and rosterEntry.key then
			indexed[rosterEntry.key] = orderIndex
		end
	end

	local results = {}
	for _, rosterEntry in ipairs(rosterOrder) do
		local data = rosterEntry.key and state.players[rosterEntry.key] or nil
		results[#results + 1] = data or {
			name = rosterEntry.key,
			displayName = rosterEntry.displayName,
		}
	end

	table.sort(results, function(left, right)
		local leftOrder = indexed[left.name]
		local rightOrder = indexed[right.name]
		if leftOrder and rightOrder and leftOrder ~= rightOrder then
			return leftOrder < rightOrder
		end
		return (left.displayName or left.name or "") < (right.displayName or right.name or "")
	end)

	return results
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

local function ArrangeGroupDataTable()
	if not groupDataFrame or not groupDataFrame.tableBuilder or not groupDataFrame.headerRow then
		return
	end

	groupDataFrame.tableBuilder:SetTableWidth(groupDataFrame.headerRow:GetWidth())
	groupDataFrame.tableBuilder:Arrange()
end

local function RefreshGroupDataWindow()
	if not groupDataFrame then
		return
	end

	local players = GetSortedSyncedPlayers()
	if #players == 0 then
		groupDataFrame.emptyLabel:Show()
		groupDataFrame.ScrollBox:SetDataProvider(CreateDataProvider())
		return
	end

	groupDataFrame.emptyLabel:Hide()

	local playerKey = GetPlayerKey(GetUnitName("player", true))
	local rows = {}
	for index, data in ipairs(players) do
		rows[index] = {
			index = index,
			name = data.displayName or data.name or L.UNKNOWN,
			oozeEquipped = data.hasSync and GetBooleanDisplay(data.oozeEquipped) or UNKNOWN_VALUE,
			uttsCount = data.hasSync and tostring(data.uttsCount or 0) or UNKNOWN_VALUE,
			dragonlingEquipped = data.hasSync and GetBooleanDisplay(data.dragonlingEquipped) or UNKNOWN_VALUE,
			addonInstalled = data.hasSync and GetBooleanDisplay(data.addonInstalled) or "-",
			timeText = data.hasSync and GetChromieTimeTextFromID(data.chromieTimeID) or UNKNOWN_VALUE,
			warModeEnabled = data.hasSync and GetBooleanDisplay(data.warModeEnabled) or UNKNOWN_VALUE,
			isPlayer = data.name == playerKey,
		}
	end

	groupDataFrame.ScrollBox:SetDataProvider(CreateDataProvider(rows), ScrollBoxConstants.RetainScrollPosition)
	ArrangeGroupDataTable()
end

local function SaveGroupDataWindowPosition(self)
	self:StopMovingOrSizing()

	local point, _, relativePoint, xOfs, yOfs = self:GetPoint()
	Level20DB.groupDataWindowPoint = point
	Level20DB.groupDataWindowRelativePoint = relativePoint
	Level20DB.groupDataWindowXOfs = xOfs
	Level20DB.groupDataWindowYOfs = yOfs
end

local function InitializeGroupDataTable(frame)
	local view = CreateScrollBoxListLinearView()
	view:SetElementInitializer("Level20GroupDataRowTemplate", function()
	end)
	ScrollUtil.InitScrollBoxListWithScrollBar(frame.ScrollBox, frame.scrollBar, view)

	local tableBuilder = CreateTableBuilder(nil, Level20GroupDataTableBuilderMixin)
	tableBuilder:SetDataProvider(IdentityDataProvider)
	tableBuilder:SetColumnHeaderOverlap(2)
	tableBuilder:SetHeaderContainer(frame.headerRow)

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

	AddStatusColumn(tableBuilder, ADDON_COLUMN_WIDTH, L.GROUP_DATA_HEADER_ADDON, "addonInstalled")
	AddStatusColumn(tableBuilder, TIME_COLUMN_WIDTH, L.GROUP_DATA_HEADER_TIME, "timeText")
	AddStatusColumn(tableBuilder, WAR_MODE_COLUMN_WIDTH, L.GROUP_DATA_HEADER_WAR_MODE, "warModeEnabled")
	AddStatusColumn(tableBuilder, TRINKET_COLUMN_WIDTH, L.GROUP_DATA_HEADER_OOZE, "oozeEquipped")
	AddStatusColumn(tableBuilder, TRINKET_COLUMN_WIDTH, L.GROUP_DATA_HEADER_DRAGONLING, "dragonlingEquipped")
	AddStatusColumn(tableBuilder, COUNT_COLUMN_WIDTH, L.GROUP_DATA_HEADER_UTTS, "uttsCount")

	ScrollUtil.RegisterTableBuilder(frame.ScrollBox, tableBuilder, IdentityDataProvider)
	frame.tableBuilder = tableBuilder
	ArrangeGroupDataTable()
end

local function EnsureGroupDataWindow()
	if groupDataFrame then
		return groupDataFrame
	end

	local frame = CreateFrame("Frame", "Level20GroupDataFrame", UIParent, "DefaultPanelTemplate")
	frame:SetSize(WINDOW_WIDTH, WINDOW_HEIGHT)
	frame:SetPoint("CENTER", UIParent, "CENTER", 120, 0)
	frame:SetMovable(true)
	frame:SetClampedToScreen(true)
	frame:EnableMouse(true)
	frame:SetToplevel(true)
	frame:SetFrameStrata("DIALOG")
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnMouseDown", function(self)
		self:Raise()
	end)
	frame:SetScript("OnDragStart", function(self)
		self:Raise()
		self:StartMoving()
	end)
	frame:SetScript("OnDragStop", SaveGroupDataWindowPosition)
	frame:SetTitle(L.GROUP_TRINKETS_WINDOW_TITLE)
	frame:Hide()
	frame.CloseButton = CreateFrame("Button", nil, frame, "UIPanelCloseButtonDefaultAnchors")

	local refreshButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	refreshButton:SetSize(100, 22)
	refreshButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -32, -32)
	refreshButton:SetText(REFRESH)
	refreshButton:SetScript("OnClick", function()
		RefreshAndBroadcastLocalGroupData(true)
	end)

	local tableFrame = CreateFrame("Frame", nil, frame)
	tableFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", TABLE_INSET, -58)
	tableFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -TABLE_INSET, 14)

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

	frame.emptyLabel = emptyLabel
	frame.tableFrame = tableFrame
	frame.bodyFrame = bodyFrame
	frame.headerRow = headerRow
	frame.ScrollBox = scrollBox
	frame.scrollBar = scrollBar

	InitializeGroupDataTable(frame)

	scrollBox:SetScript("OnSizeChanged", function()
		ArrangeGroupDataTable()
	end)

	frame:SetScript("OnShow", function()
		frame:Raise()
		ArrangeGroupDataTable()
		addon.RefreshGroupDataWindow()
		RefreshAndBroadcastLocalGroupData(true)
	end)

	if Level20DB.groupDataWindowPoint then
		frame:ClearAllPoints()
		frame:SetPoint(
			Level20DB.groupDataWindowPoint,
			UIParent,
			Level20DB.groupDataWindowRelativePoint or Level20DB.groupDataWindowPoint,
			Level20DB.groupDataWindowXOfs or 0,
			Level20DB.groupDataWindowYOfs or 0
		)
	end

	groupDataFrame = frame
	return groupDataFrame
end

local function BuildMessage()
	return table.concat({
		MESSAGE_VERSION,
		EncodeBoolean(IsTrackedTrinketEquipped(OOZE_TRINKET_ITEM_ID)),
		tostring(GetTrackedItemCount(UTTS_ITEM_ID)),
		EncodeBoolean(IsTrackedTrinketEquipped(DRAGONLING_TRINKET_ITEM_ID)),
		BOOL_TRUE,
		tostring(GetChromieTimeSyncValue()),
		EncodeBoolean(IsWarModeEnabled()),
	}, "\t")
end

RefreshAndBroadcastLocalGroupData = function(force)
	local message = addon.UpdateLocalGroupData()
	if not force and message == state.lastLocalMessage then
		return
	end

	state.lastLocalMessage = message
	addon.BroadcastGroupData(force)
end

local function UpdatePlayerData(fullName, oozeEquipped, uttsCount, dragonlingEquipped, addonInstalled, chromieTimeID, warModeEnabled)
	local playerKey = GetPlayerKey(fullName)
	if not playerKey then
		return
	end

	state.players[playerKey] = {
		name = playerKey,
		displayName = Ambiguate(fullName, "short"),
		hasSync = true,
		oozeEquipped = DecodeBoolean(oozeEquipped),
		uttsCount = tonumber(uttsCount) or 0,
		dragonlingEquipped = DecodeBoolean(dragonlingEquipped),
		addonInstalled = DecodeBoolean(addonInstalled),
		chromieTimeID = tonumber(chromieTimeID) or -1,
		warModeEnabled = DecodeBoolean(warModeEnabled),
	}

	addon.RefreshGroupDataWindow()
end

function addon.InitializeGroupDataSync()
	if state.initialized then
		return
	end

	if not C_ChatInfo or not C_ChatInfo.RegisterAddonMessagePrefix or not C_ChatInfo.SendAddonMessage then
		return
	end

	C_ChatInfo.RegisterAddonMessagePrefix(COMM_PREFIX)
	state.initialized = true
	state.syncTicker = C_Timer.NewTicker(1, function()
		RefreshAndBroadcastLocalGroupData()
	end)
end

function addon.UpdateLocalGroupData()
	local message = BuildMessage()
	local _, oozeEquipped, uttsCount, dragonlingEquipped, addonInstalled, chromieTimeID, warModeEnabled = strsplit("\t", message, 7)
	UpdatePlayerData(GetUnitName("player", true), oozeEquipped, uttsCount, dragonlingEquipped, addonInstalled, chromieTimeID, warModeEnabled)
	return message
end

function addon.BroadcastGroupData(force)
	if not state.initialized then
		return
	end

	local distribution = GetGroupDistribution()
	if distribution then
		local message = addon.UpdateLocalGroupData()
		if not force and message == state.lastBroadcastMessage then
			return
		end

		state.lastBroadcastMessage = message
		C_ChatInfo.SendAddonMessage(COMM_PREFIX, message, distribution)
	end
end

function addon.OnGroupDataMessage(prefix, message, _, sender)
	if prefix ~= COMM_PREFIX or not sender or IsOwnSender(sender) then
		return
	end

	local version, oozeEquipped, uttsCount, dragonlingEquipped, addonInstalled, chromieTimeID, warModeEnabled = strsplit("\t", message or "", 7)
	if version ~= MESSAGE_VERSION then
		return
	end

	UpdatePlayerData(sender, oozeEquipped, uttsCount, dragonlingEquipped, addonInstalled, chromieTimeID, warModeEnabled)
end

function addon.RefreshGroupDataWindow()
	RefreshGroupDataWindow()
end

function addon.ShowGroupDataWindow()
	EnsureGroupDataWindow():Show()
end

function addon.ToggleGroupDataWindow()
	local frame = EnsureGroupDataWindow()
	if frame:IsShown() then
		frame:Hide()
	else
		addon.ShowGroupDataWindow()
	end
end
