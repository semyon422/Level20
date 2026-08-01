local addonName, addon = ...
local L = addon.L

local frame = CreateFrame("Frame", "Level20Frame", UIParent, "DefaultPanelTemplate")
frame:SetSize(540, 292)
frame:SetPoint("CENTER")
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
frame:SetScript("OnDragStop", function(self)
	self:StopMovingOrSizing()

	local point, _, relativePoint, xOfs, yOfs = self:GetPoint()
	Level20DB.windowPoint = point
	Level20DB.windowRelativePoint = relativePoint
	Level20DB.windowXOfs = xOfs
	Level20DB.windowYOfs = yOfs
end)
frame:Hide()
frame:SetTitle(L.ADDON_TITLE)

function addon.SetMainWindowEscapeEnabled(enabled)
	local frameName = frame:GetName()
	for index = #UISpecialFrames, 1, -1 do
		if UISpecialFrames[index] == frameName then
			table.remove(UISpecialFrames, index)
		end
	end

	if enabled then
		table.insert(UISpecialFrames, frameName)
	end
end

addon.SetMainWindowEscapeEnabled(true)

frame.CloseButton = CreateFrame("Button", nil, frame, "UIPanelCloseButtonDefaultAnchors")

local activeTab
local routesTabUnlocked = false
local debugTabUnlocked = false
local spectatorWarGameTabUnlocked = false
local tabs = {}
local tabOrder = { "info", "settings", "waypoints", "dungeon", "routes", "spectatorWarGame", "debug" }
local defaultTabCount = 4

frame.tabPadding = 0
frame.minTabWidth = 64
frame.maxTabWidth = 96

local function CreateTab(parent, id, label, tabKey)
	local button = CreateFrame("Button", parent:GetName() .. "Tab" .. id, parent, "PanelTabButtonTemplate")
	button:SetID(id)
	button:SetText(label)
	button.tabKey = tabKey
	tabs[tabKey] = button
	parent.Tabs[id] = button

	return button
end

frame.Tabs = {}

local infoTab = CreateTab(frame, 1, L.TAB_INFO, "info")
infoTab:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 18, -30)

CreateTab(frame, 2, L.TAB_SETTINGS, "settings")
CreateTab(frame, 3, L.TAB_WAYPOINTS, "waypoints")
CreateTab(frame, 4, L.TAB_DUNGEON, "dungeon")
local routesTab = CreateTab(frame, 5, L.TAB_ROUTES, "routes")
local spectatorWarGameTab = CreateTab(frame, 6, L.TAB_SPECTATOR_WARGAME, "spectatorWarGame")
local debugTab = CreateTab(frame, 7, L.TAB_DEBUG, "debug")
routesTab:Hide()
spectatorWarGameTab:Hide()
debugTab:Hide()

PanelTemplates_SetNumTabs(frame, defaultTabCount)

local infoPanel = CreateFrame("Frame", nil, frame)
infoPanel:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -40)
infoPanel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 20)

local settingsPanel = CreateFrame("Frame", nil, frame)
settingsPanel:SetPoint("TOPLEFT", infoPanel)
settingsPanel:SetPoint("BOTTOMRIGHT", infoPanel)

local settingsScrollFrame = CreateFrame("ScrollFrame", nil, settingsPanel, "ScrollFrameTemplate")
settingsScrollFrame:SetPoint("TOPLEFT", settingsPanel, "TOPLEFT", 4, -4)
settingsScrollFrame:SetPoint("BOTTOMRIGHT", settingsPanel, "BOTTOMRIGHT", -12, 4)

local settingsContent = CreateFrame("Frame", nil, settingsScrollFrame)
settingsContent:SetSize(1, 1)
settingsScrollFrame:SetScrollChild(settingsContent)
-- settingsScrollFrame.ScrollBar:SetHideIfUnscrollable(true)
settingsScrollFrame:SetScript("OnSizeChanged", function(self, width)
	settingsContent:SetWidth(math.max(1, width))
end)

local waypointsPanel = CreateFrame("Frame", nil, frame)
waypointsPanel:SetPoint("TOPLEFT", infoPanel)
waypointsPanel:SetPoint("BOTTOMRIGHT", infoPanel)

local routesPanel = CreateFrame("Frame", nil, frame)
routesPanel:SetPoint("TOPLEFT", infoPanel)
routesPanel:SetPoint("BOTTOMRIGHT", infoPanel)

local dungeonPanel = CreateFrame("Frame", nil, frame)
dungeonPanel:SetPoint("TOPLEFT", infoPanel)
dungeonPanel:SetPoint("BOTTOMRIGHT", infoPanel)

local spectatorWarGamePanel = CreateFrame("Frame", nil, frame)
spectatorWarGamePanel:SetPoint("TOPLEFT", infoPanel)
spectatorWarGamePanel:SetPoint("BOTTOMRIGHT", infoPanel)

local debugPanel = CreateFrame("Frame", nil, frame)
debugPanel:SetPoint("TOPLEFT", infoPanel)
debugPanel:SetPoint("BOTTOMRIGHT", infoPanel)

local debugScrollFrame = CreateFrame("ScrollFrame", nil, debugPanel, "ScrollFrameTemplate")
debugScrollFrame:SetPoint("TOPLEFT", debugPanel, "TOPLEFT", 4, -4)
debugScrollFrame:SetPoint("BOTTOMRIGHT", debugPanel, "BOTTOMRIGHT", -12, 4)

local debugContent = CreateFrame("Frame", nil, debugScrollFrame)
debugContent:SetSize(1, 1)
debugScrollFrame:SetScrollChild(debugContent)
debugScrollFrame:SetScript("OnSizeChanged", function(self, width)
	debugContent:SetWidth(math.max(1, width))
end)

local function ResizeScrollContentToChildren(content, bottomPadding)
	local contentTop = content:GetTop()
	if not contentTop then
		return
	end

	local height = 1
	for _, child in ipairs({ content:GetChildren() }) do
		if child:IsShown() then
			local childBottom = child:GetBottom()
			if childBottom then
				height = math.max(height, contentTop - childBottom + (bottomPadding or 0))
			end
		end
	end

	content:SetHeight(math.ceil(height))
end

local function UpdateSettingsContentHeight()
	ResizeScrollContentToChildren(settingsContent, 6)
	settingsScrollFrame.ScrollBar:Update()
end

local function UpdateDebugContentHeight()
	ResizeScrollContentToChildren(debugContent, 6)
	debugScrollFrame.ScrollBar:Update()
end

local function CreateInfoRow(parent, label, previous)
	local row = CreateFrame("Frame", nil, parent)
	row:SetSize(330, 24)

	if previous then
		row:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -8)
	else
		row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
	end

	row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	row.label:SetPoint("LEFT", row, "LEFT", 0, 0)
	row.label:SetWidth(120)
	row.label:SetJustifyH("LEFT")
	row.label:SetText(label)

	row.value = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	row.value:SetPoint("LEFT", row.label, "RIGHT", 12, 0)
	row.value:SetPoint("RIGHT", row, "RIGHT", 0, 0)
	row.value:SetJustifyH("LEFT")
	row.value:SetText(L.UNKNOWN)

	return row
end

local function CreateSectionFrame(parent, title, width, height)
	local section = CreateFrame("Frame", nil, parent, "BackdropTemplate")
	section:SetSize(width, height)
	section:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8x8",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		edgeSize = 10,
		insets = { left = 3, right = 3, top = 3, bottom = 3 },
	})
	section:SetBackdropColor(0.05, 0.05, 0.07, 0.35)
	section:SetBackdropBorderColor(0.35, 0.35, 0.4, 1)

	section.title = section:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
	section.title:SetPoint("TOP", section, "TOP", 0, -12)
	section.title:SetTextColor(1.0, 0.82, 0.0)
	section.title:SetShadowColor(0, 0, 0, 1)
	section.title:SetShadowOffset(1, -1)
	section.title:SetText(title)

	section.divider = section:CreateTexture(nil, "ARTWORK")
	section.divider:SetHeight(1)
	section.divider:SetPoint("TOPLEFT", section, "TOPLEFT", 12, -30)
	section.divider:SetPoint("TOPRIGHT", section, "TOPRIGHT", -12, -30)
	section.divider:SetColorTexture(1.0, 0.82, 0.0, 0.22)

	return section
end

local accountTypeRow = CreateInfoRow(infoPanel, L.ACCOUNT_TYPE)
local subscriptionRow = CreateInfoRow(infoPanel, L.SUBSCRIPTION, accountTypeRow)
local xpGainRow = CreateInfoRow(infoPanel, L.XP_GAIN, subscriptionRow)
local chromieTimeRow = CreateInfoRow(infoPanel, L.CHROMIE_TIME, xpGainRow)
local shadowlandsRow = CreateInfoRow(infoPanel, L.SHADOWLANDS_STATE, chromieTimeRow)

local versionStatusLabel = infoPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
versionStatusLabel:SetPoint("TOPRIGHT", infoPanel, "TOPRIGHT", 0, 0)
versionStatusLabel:SetJustifyH("RIGHT")
versionStatusLabel:SetText(L.UNKNOWN)

local groupDataButton = CreateFrame("Button", nil, infoPanel, "UIPanelButtonTemplate")
groupDataButton:SetSize(140, 24)
groupDataButton:SetPoint("TOPLEFT", shadowlandsRow, "BOTTOMLEFT", 0, -12)
groupDataButton:SetText(L.GROUP_TRINKETS_BUTTON)
groupDataButton:SetScript("OnClick", function()
	addon.GroupData.ShowWindow()
end)

local waypointData = {
	{ labelKey = "WAYPOINT_CHROMIE", faction = "Alliance", mapID = 84, x = 56.26, y = 17.32 },
	{ labelKey = "WAYPOINT_CHROMIE", faction = "Horde", mapID = 85, x = 40.82, y = 80.16 },
	{ labelKey = "WAYPOINT_XP_STOP_BEHSTEN", faction = "Alliance", mapID = 84, x = 87.70, y = 36.09 },
	{ labelKey = "WAYPOINT_XP_STOP_SLAHTZ", faction = "Horde", mapID = 85, x = 74.26, y = 44.32 },
	{ labelKey = "WAYPOINT_LOREWALKER_CHO", faction = "Alliance", mapID = 84, x = 64.23, y = 16.12 },
	{ labelKey = "WAYPOINT_LOREWALKER_CHO", faction = "Horde", mapID = 85, x = 54.25, y = 56.60 },
}

local function SetWaypoint(waypoint)
	if not C_Map.CanSetUserWaypointOnMap(waypoint.mapID) then
		print(L.CANNOT_SET_WAYPOINT)
		return
	end

	local point = UiMapPoint.CreateFromCoordinates(waypoint.mapID, waypoint.x / 100, waypoint.y / 100)
	C_Map.SetUserWaypoint(point)
	C_SuperTrack.SetSuperTrackedUserWaypoint(true)
	print(string.format(L.WAYPOINT_SET, L[waypoint.labelKey], waypoint.x, waypoint.y))
end

local function CreateWaypointButton(parent, waypoint)
	local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	button:SetSize(250, 24)

	button:SetText(L[waypoint.labelKey])
	button:SetScript("OnClick", function()
		SetWaypoint(waypoint)
	end)

	return button
end

local waypointButtons = {}
local function RefreshWaypointButtons()
	local faction = UnitFactionGroup("player")
	local row = 0

	for _, button in ipairs(waypointButtons) do
		button:Hide()
	end

	for _, waypoint in ipairs(waypointData) do
		if waypoint.faction == faction then
			row = row + 1
			local button = waypointButtons[row] or CreateWaypointButton(waypointsPanel, waypoint)
			waypointButtons[row] = button
			button:ClearAllPoints()
			button:SetPoint("TOP", waypointsPanel, "TOP", 0, -((row - 1) * 34))
			button:SetText(L[waypoint.labelKey])
			button:SetScript("OnClick", function()
				SetWaypoint(waypoint)
			end)
			button:Show()
		end
	end
end

local clearWaypointButton = CreateFrame("Button", nil, waypointsPanel, "UIPanelButtonTemplate")
clearWaypointButton:SetSize(250, 24)
clearWaypointButton:SetPoint("TOP", waypointsPanel, "TOP", 0, -114)
clearWaypointButton:SetText(L.CLEAR_WAYPOINT)
clearWaypointButton:SetScript("OnClick", function()
	C_Map.ClearUserWaypoint()
	print(L.WAYPOINT_CLEARED)
end)

local routesSection = CreateSectionFrame(routesPanel, L.ROUTE_OUTLAND, 500, 196)
routesSection:SetPoint("TOPLEFT", routesPanel, "TOPLEFT", 0, 0)

local routeFactionRow = CreateInfoRow(routesSection, L.ROUTE_FACTION_LABEL)
routeFactionRow:SetPoint("TOPLEFT", routesSection, "TOPLEFT", 12, -38)
routeFactionRow:SetWidth(470)
routeFactionRow.value:SetPoint("RIGHT", routeFactionRow, "RIGHT", 0, 0)

local routeMapRow = CreateInfoRow(routesSection, L.ROUTE_CURRENT_MAP_LABEL, routeFactionRow)
routeMapRow:SetWidth(470)
routeMapRow.value:SetPoint("RIGHT", routeMapRow, "RIGHT", 0, 0)

local routeDetectedPhaseRow = CreateInfoRow(routesSection, L.ROUTE_DETECTED_PHASE_LABEL, routeMapRow)
routeDetectedPhaseRow:SetWidth(470)
routeDetectedPhaseRow.value:SetPoint("RIGHT", routeDetectedPhaseRow, "RIGHT", 0, 0)

local routeNextStepRow = CreateInfoRow(routesSection, L.ROUTE_NEXT_STEP_LABEL, routeDetectedPhaseRow)
routeNextStepRow:SetWidth(470)
routeNextStepRow.value:SetPoint("RIGHT", routeNextStepRow, "RIGHT", 0, 0)

local routeStartButton = CreateFrame("Button", nil, routesSection, "UIPanelButtonTemplate")
routeStartButton:SetSize(220, 24)
routeStartButton:SetPoint("TOPLEFT", routeNextStepRow, "BOTTOMLEFT", 0, -10)
routeStartButton:SetText(L.ROUTE_START)

local debugRouteTaxiNodeDiffRow
local selectedRouteID = addon.Routes and addon.Routes.GetDefaultRouteID and addon.Routes.GetDefaultRouteID() or nil

routeStartButton:SetScript("OnClick", function()
	if addon.Routes and addon.Routes.Toggle then
		addon.Routes.Toggle(selectedRouteID)
	end
	addon.RefreshRoutesPanel()
end)

function addon.RefreshRoutesPanel(updateDiffBaseline)
	if not addon.Routes or not addon.Routes.GetPanelState then
		return
	end

	local routeState = addon.Routes.GetPanelState(selectedRouteID)
	routesSection.title:SetText(routeState.title or L.ROUTE_OUTLAND)
	routeFactionRow.value:SetText(routeState.faction or L.UNKNOWN)
	routeMapRow.value:SetText(routeState.mapText or L.UNKNOWN)
	routeDetectedPhaseRow.value:SetText(routeState.phaseText or L.UNKNOWN)
	routeNextStepRow.value:SetText(routeState.nextStepText or L.UNKNOWN)
	routeStartButton:SetText(routeState.active and L.ROUTE_STOP or L.ROUTE_START)
	routeStartButton:SetEnabled(routeState.active or routeState.canStart)

	if debugRouteTaxiNodeDiffRow and addon.Routes.GetDebugTaxiNodeDiff then
		debugRouteTaxiNodeDiffRow.value:SetText(addon.Routes.GetDebugTaxiNodeDiff(updateDiffBaseline))
	end
end

local spectatorWarGameControls = {}
local spectatorWarGameDropdownWidth = 330

local function CreateSpectatorWarGameRadio(rootDescription, option, isSelected, setSelected)
	local radio = rootDescription:CreateRadio(option.label, isSelected, setSelected, option.value)
	radio:AddInitializer(function(button)
		local fontString = button.fontString or button.Text
		if fontString then
			fontString:SetWidth(spectatorWarGameDropdownWidth - 32)
			fontString:SetWordWrap(false)
			fontString:SetText(option.label)
		end
	end)
	return radio
end

local function GetSpectatorWarGameLeaderLabel(value)
	return value and value ~= "" and value or L.SPECTATOR_WARGAME_SELECT_FRIEND
end

local function GetSpectatorWarGameArenaLabel(value)
	if not value or not addon.GetSpectatorWarGameArenaOptions then
		return nil
	end

	for _, option in ipairs(addon.GetSpectatorWarGameArenaOptions()) do
		if option.value == value then
			return option.label
		end
	end

	return nil
end

local function CreateSpectatorWarGameFriendDropdown(parent, label, dbKey, previous)
	local row = CreateFrame("Frame", nil, parent)
	row:SetSize(430, 30)
	if previous then
		row:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -10)
	else
		row:SetPoint("TOPLEFT", parent, "TOPLEFT", 22, -18)
	end

	row.Text = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	row.Text:SetPoint("LEFT", row, "LEFT", 0, 0)
	row.Text:SetWidth(90)
	row.Text:SetJustifyH("LEFT")
	row.Text:SetText(label)

	row.Dropdown = CreateFrame("DropdownButton", nil, row, "WowStyle1DropdownTemplate")
	row.Dropdown:SetPoint("LEFT", row.Text, "RIGHT", 8, 0)
	row.Dropdown:SetWidth(spectatorWarGameDropdownWidth)

	if row.Dropdown.SetSelectionText then
		row.Dropdown:SetSelectionText(function()
			return GetSpectatorWarGameLeaderLabel(Level20DB[dbKey])
		end)
	end

	local function IsSelected(value)
		return Level20DB[dbKey] == value
	end

	local function SetSelected(value)
		Level20DB[dbKey] = value
		addon.RefreshSpectatorWarGamePanel()
	end

	row.Dropdown:SetupMenu(function(dropdown, rootDescription)
		rootDescription:SetTag("LEVEL20_SPECTATOR_WARGAME_" .. dbKey)
		rootDescription:SetMinimumWidth(spectatorWarGameDropdownWidth)

		local options = addon.GetSpectatorWarGameBNetFriendOptions and addon.GetSpectatorWarGameBNetFriendOptions() or {}
		if #options == 0 then
			rootDescription:CreateTitle(L.SPECTATOR_WARGAME_NO_BNET_FRIENDS)
			return
		end

		for _, option in ipairs(options) do
			CreateSpectatorWarGameRadio(rootDescription, option, IsSelected, SetSelected)
		end
	end)

	function row:Refresh()
		local value = GetSpectatorWarGameLeaderLabel(Level20DB[dbKey])
		if self.Dropdown.SetDefaultText then
			self.Dropdown:SetDefaultText(value)
		end
	end

	table.insert(spectatorWarGameControls, row)
	return row
end

local function CreateSpectatorWarGameArenaDropdown(parent, previous)
	local row = CreateFrame("Frame", nil, parent)
	row:SetSize(430, 30)
	row:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -10)

	row.Text = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	row.Text:SetPoint("LEFT", row, "LEFT", 0, 0)
	row.Text:SetWidth(90)
	row.Text:SetJustifyH("LEFT")
	row.Text:SetText(L.SPECTATOR_WARGAME_ARENA)

	row.Dropdown = CreateFrame("DropdownButton", nil, row, "WowStyle1DropdownTemplate")
	row.Dropdown:SetPoint("LEFT", row.Text, "RIGHT", 8, 0)
	row.Dropdown:SetWidth(spectatorWarGameDropdownWidth)

	if row.Dropdown.SetSelectionText then
		row.Dropdown:SetSelectionText(function()
			return GetSpectatorWarGameArenaLabel(Level20DB.spectatorWarGameArenaID) or L.SPECTATOR_WARGAME_SELECT_ARENA
		end)
	end

	local function IsSelected(value)
		return Level20DB.spectatorWarGameArenaID == value
	end

	local function SetSelected(value)
		Level20DB.spectatorWarGameArenaID = value
		addon.RefreshSpectatorWarGamePanel()
	end

	row.Dropdown:SetupMenu(function(dropdown, rootDescription)
		rootDescription:SetTag("LEVEL20_SPECTATOR_WARGAME_ARENA")
		rootDescription:SetMinimumWidth(spectatorWarGameDropdownWidth)

		local options = addon.GetSpectatorWarGameArenaOptions and addon.GetSpectatorWarGameArenaOptions() or {}
		if #options == 0 then
			rootDescription:CreateTitle(L.SPECTATOR_WARGAME_NO_ARENAS)
			return
		end

		for _, option in ipairs(options) do
			CreateSpectatorWarGameRadio(rootDescription, option, IsSelected, SetSelected)
		end
	end)

	function row:Refresh()
		local value = GetSpectatorWarGameArenaLabel(Level20DB.spectatorWarGameArenaID) or L.SPECTATOR_WARGAME_SELECT_ARENA
		if self.Dropdown.Text then
			self.Dropdown.Text:SetWidth(spectatorWarGameDropdownWidth - 38)
		end
		if self.Dropdown.OverrideText then
			self.Dropdown:OverrideText(value)
		elseif self.Dropdown.SetDefaultText then
			self.Dropdown:SetDefaultText(value)
		end
	end

	table.insert(spectatorWarGameControls, row)
	return row
end

local spectatorWarGameLeaderARow = CreateSpectatorWarGameFriendDropdown(spectatorWarGamePanel, L.SPECTATOR_WARGAME_LEADER_A, "spectatorWarGameLeaderA")
local spectatorWarGameLeaderBRow = CreateSpectatorWarGameFriendDropdown(spectatorWarGamePanel, L.SPECTATOR_WARGAME_LEADER_B, "spectatorWarGameLeaderB", spectatorWarGameLeaderARow)
local spectatorWarGameArenaRow = CreateSpectatorWarGameArenaDropdown(spectatorWarGamePanel, spectatorWarGameLeaderBRow)

local spectatorWarGameStartButton = CreateFrame("Button", nil, spectatorWarGamePanel, "UIPanelButtonTemplate")
spectatorWarGameStartButton:SetSize(180, 24)
spectatorWarGameStartButton:SetPoint("TOPLEFT", spectatorWarGameArenaRow, "BOTTOMLEFT", 98, -14)
spectatorWarGameStartButton:SetText(L.SPECTATOR_WARGAME_START_MATCH)
spectatorWarGameStartButton:SetScript("OnClick", function()
	if not Level20DB.spectatorWarGameLeaderA or not Level20DB.spectatorWarGameLeaderB or not Level20DB.spectatorWarGameArenaID then
		print(L.SPECTATOR_WARGAME_SELECT_REQUIRED)
		return
	end

	addon.OpenSpectatorWarGameCommand(Level20DB.spectatorWarGameLeaderA, Level20DB.spectatorWarGameLeaderB, Level20DB.spectatorWarGameArenaID)
end)

local spectatorWarGameRefreshButton = CreateFrame("Button", nil, spectatorWarGamePanel, "UIPanelButtonTemplate")
spectatorWarGameRefreshButton:SetSize(180, 24)
spectatorWarGameRefreshButton:SetPoint("LEFT", spectatorWarGameStartButton, "RIGHT", 8, 0)
spectatorWarGameRefreshButton:SetText(L.SPECTATOR_WARGAME_REFRESH_FRIENDS)
spectatorWarGameRefreshButton:SetScript("OnClick", function()
	addon.RefreshSpectatorWarGamePanel()
end)

function addon.RefreshSpectatorWarGamePanel()
	local availableLeaders = {}
	local options = addon.GetSpectatorWarGameBNetFriendOptions and addon.GetSpectatorWarGameBNetFriendOptions() or {}
	for _, option in ipairs(options) do
		availableLeaders[option.value] = true
	end

	local availableArenas = {}
	local arenaOptions = addon.GetSpectatorWarGameArenaOptions and addon.GetSpectatorWarGameArenaOptions() or {}
	for _, option in ipairs(arenaOptions) do
		availableArenas[option.value] = true
	end
	if Level20DB.spectatorWarGameArenaID and not availableArenas[Level20DB.spectatorWarGameArenaID] then
		Level20DB.spectatorWarGameArenaID = nil
	end
	if not Level20DB.spectatorWarGameArenaID and arenaOptions[1] then
		Level20DB.spectatorWarGameArenaID = arenaOptions[1].value
	end

	for _, control in ipairs(spectatorWarGameControls) do
		if control.Refresh then
			control:Refresh()
		end
	end

	local hasBothLeaders = availableLeaders[Level20DB.spectatorWarGameLeaderA]
		and availableLeaders[Level20DB.spectatorWarGameLeaderB]
		and Level20DB.spectatorWarGameLeaderA ~= Level20DB.spectatorWarGameLeaderB
	local hasArena = Level20DB.spectatorWarGameArenaID and availableArenas[Level20DB.spectatorWarGameArenaID]
	spectatorWarGameStartButton:SetEnabled(hasBothLeaders and hasArena and true or false)
end

local spectatorWarGameEventFrame = CreateFrame("Frame")
spectatorWarGameEventFrame:RegisterEvent("BN_FRIEND_LIST_SIZE_CHANGED")
spectatorWarGameEventFrame:RegisterEvent("BN_FRIEND_INFO_CHANGED")
spectatorWarGameEventFrame:RegisterEvent("BN_FRIEND_ACCOUNT_ONLINE")
spectatorWarGameEventFrame:RegisterEvent("BN_FRIEND_ACCOUNT_OFFLINE")
spectatorWarGameEventFrame:SetScript("OnEvent", function()
	if spectatorWarGamePanel:IsShown() then
		addon.RefreshSpectatorWarGamePanel()
	end
end)

local function GetAccountTypeText()
	if IsTrialAccount() then
		return L.ACCOUNT_TRIAL
	end

	if IsVeteranTrialAccount() then
		return L.ACCOUNT_VETERAN
	end

	return L.ACCOUNT_STANDARD
end

local function GetSubscriptionText()
	if addon.GroupData and addon.GroupData.HasActiveSubscription and not addon.GroupData.HasActiveSubscription() then
		return L.SUBSCRIPTION_INACTIVE
	end

	return L.SUBSCRIPTION_ACTIVE
end

local function GetXPGainText()
	return IsXPUserDisabled() and L.XP_DISABLED or L.XP_ENABLED
end

local function GetChromieTimeText()
	local chromieText = addon.GroupData and addon.GroupData.GetChromieTimeText and addon.GroupData.GetChromieTimeText() or L.UNKNOWN
	local warModeEnabled = C_PvP and C_PvP.IsWarModeDesired and C_PvP.IsWarModeDesired() or false
	local lorewalkingActive = addon.IsLorewalkingActive and addon.IsLorewalkingActive() or false
	return addon.GroupData and addon.GroupData.FormatChromieStatusText and addon.GroupData.FormatChromieStatusText(chromieText, warModeEnabled, lorewalkingActive) or chromieText
end

function addon.RefreshInfoPanel()
	accountTypeRow.value:SetText(GetAccountTypeText())
	subscriptionRow.value:SetText(GetSubscriptionText())
	xpGainRow.value:SetText(GetXPGainText())
	chromieTimeRow.value:SetText(GetChromieTimeText())
	shadowlandsRow.value:SetText(addon.GetShadowlandsStateText())
	versionStatusLabel:SetText(addon.GetVersionStatusText and addon.GetVersionStatusText() or L.UNKNOWN)

	local red, green, blue = 1, 1, 1
	if addon.GetVersionStatusColor then
		red, green, blue = addon.GetVersionStatusColor()
	end
	versionStatusLabel:SetTextColor(red, green, blue)
end

local DUNGEON_SECTION_WIDTH = 244
local DUNGEON_SECTION_HEIGHT = 196
local DUNGEON_SECTION_GAP = 12
local DUNGEON_SECTION_INSET = 12
local DUNGEON_ROW_WIDTH = 220
local DUNGEON_BUTTON_WIDTH = 220
local DUNGEON_BUTTON_HEIGHT = 24
local DUNGEON_ROW_BUTTON_GAP = 12
local DUNGEON_BUTTON_GAP = 8

local dungeonRunSection = CreateSectionFrame(dungeonPanel, L.DUNGEON_CHALLENGE_RUN_SECTION, DUNGEON_SECTION_WIDTH, DUNGEON_SECTION_HEIGHT)
dungeonRunSection:SetPoint("TOPLEFT", dungeonPanel, "TOPLEFT", 0, 0)

local dungeonLoggingSection = CreateSectionFrame(dungeonPanel, L.DUNGEON_CHALLENGE_LOGGING_SECTION, DUNGEON_SECTION_WIDTH, DUNGEON_SECTION_HEIGHT)
dungeonLoggingSection:SetPoint("TOPLEFT", dungeonRunSection, "TOPRIGHT", DUNGEON_SECTION_GAP, 0)

local dungeonStatusRow = CreateInfoRow(dungeonRunSection, L.DUNGEON_CHALLENGE_STATUS_LABEL)
dungeonStatusRow:SetPoint("TOPLEFT", dungeonRunSection, "TOPLEFT", DUNGEON_SECTION_INSET, -34)
dungeonStatusRow:SetWidth(DUNGEON_ROW_WIDTH)
dungeonStatusRow.value:SetPoint("RIGHT", dungeonStatusRow, "RIGHT", 0, 0)

local dungeonTimerRow = CreateInfoRow(dungeonRunSection, L.DUNGEON_CHALLENGE_TIMER_LABEL, dungeonStatusRow)
dungeonTimerRow:SetWidth(DUNGEON_ROW_WIDTH)
dungeonTimerRow.value:SetPoint("RIGHT", dungeonTimerRow, "RIGHT", 0, 0)

local dungeonCombatLogRow = CreateInfoRow(dungeonLoggingSection, L.DUNGEON_CHALLENGE_COMBAT_LOG_LABEL)
dungeonCombatLogRow:SetPoint("TOPLEFT", dungeonLoggingSection, "TOPLEFT", DUNGEON_SECTION_INSET, -34)
dungeonCombatLogRow:SetWidth(DUNGEON_ROW_WIDTH)
dungeonCombatLogRow.label:SetWidth(128)
dungeonCombatLogRow.value:SetPoint("RIGHT", dungeonCombatLogRow, "RIGHT", 0, 0)

local dungeonAdvancedCombatLogRow = CreateInfoRow(dungeonLoggingSection, L.DUNGEON_CHALLENGE_ADVANCED_COMBAT_LOG_LABEL, dungeonCombatLogRow)
dungeonAdvancedCombatLogRow:SetWidth(DUNGEON_ROW_WIDTH)
dungeonAdvancedCombatLogRow.label:SetWidth(128)
dungeonAdvancedCombatLogRow.value:SetPoint("RIGHT", dungeonAdvancedCombatLogRow, "RIGHT", 0, 0)

local resetDungeonTimerButton = CreateFrame("Button", nil, dungeonRunSection, "UIPanelButtonTemplate")
resetDungeonTimerButton:SetSize(DUNGEON_BUTTON_WIDTH, DUNGEON_BUTTON_HEIGHT)
resetDungeonTimerButton:SetPoint("TOPLEFT", dungeonTimerRow, "BOTTOMLEFT", 0, -DUNGEON_ROW_BUTTON_GAP)
resetDungeonTimerButton:SetScript("OnClick", function()
	local challenge = addon.DungeonChallenge
	local isStarted = challenge and challenge.IsTimerStarted and challenge.IsTimerStarted()
	local isStopped = challenge and challenge.IsTimerStopped and challenge.IsTimerStopped()

	if not isStarted then
		challenge.startTimer()
	elseif isStopped then
		challenge.resetTimer()
	else
		challenge.completeRun()
	end

	addon.RefreshDungeonPanel()
end)

local guildStartDungeonTimerButton = CreateFrame("Button", nil, dungeonRunSection, "UIPanelButtonTemplate")
guildStartDungeonTimerButton:SetSize(DUNGEON_BUTTON_WIDTH, DUNGEON_BUTTON_HEIGHT)
guildStartDungeonTimerButton:SetPoint("TOPLEFT", resetDungeonTimerButton, "BOTTOMLEFT", 0, -DUNGEON_BUTTON_GAP)
guildStartDungeonTimerButton:SetText(L.DUNGEON_CHALLENGE_GUILD_START_SEND)
guildStartDungeonTimerButton:SetScript("OnClick", function()
	if addon.DungeonChallenge.SendGuildStartCommand() then
		print(L.DUNGEON_CHALLENGE_GUILD_START_SENT)
	else
		print(L.DUNGEON_CHALLENGE_GUILD_START_FAILED)
	end

	addon.RefreshDungeonPanel()
end)

local toggleCombatLogButton = CreateFrame("Button", nil, dungeonLoggingSection, "UIPanelButtonTemplate")
toggleCombatLogButton:SetSize(DUNGEON_BUTTON_WIDTH, DUNGEON_BUTTON_HEIGHT)
toggleCombatLogButton:SetPoint("TOPLEFT", dungeonAdvancedCombatLogRow, "BOTTOMLEFT", 0, -DUNGEON_ROW_BUTTON_GAP)

local toggleAdvancedCombatLogButton = CreateFrame("Button", nil, dungeonLoggingSection, "UIPanelButtonTemplate")
toggleAdvancedCombatLogButton:SetSize(DUNGEON_BUTTON_WIDTH, DUNGEON_BUTTON_HEIGHT)
toggleAdvancedCombatLogButton:SetPoint("TOPLEFT", toggleCombatLogButton, "BOTTOMLEFT", 0, -DUNGEON_BUTTON_GAP)

local function FormatDuration(seconds)
	seconds = math.max(0, math.floor(seconds or 0))
	return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

function addon.RefreshDungeonPanel()
	local challenge = addon.DungeonChallenge
	local isActive = challenge and challenge.ShouldUse and challenge.ShouldUse()
	local isStarted = challenge and challenge.IsTimerStarted and challenge.IsTimerStarted()
	local isStopped = challenge and challenge.IsTimerStopped and challenge.IsTimerStopped()

	dungeonStatusRow.value:SetText(isActive and L.STATE_ENABLED or L.STATE_DISABLED)
	dungeonTimerRow.value:SetText(FormatDuration(challenge and challenge.GetElapsedTime and challenge.GetElapsedTime() or 0))
	dungeonCombatLogRow.value:SetText(challenge and challenge.GetCombatLogStatusText and challenge.GetCombatLogStatusText() or L.UNKNOWN)
	dungeonAdvancedCombatLogRow.value:SetText(challenge and challenge.GetAdvancedCombatLogStatusText and challenge.GetAdvancedCombatLogStatusText() or L.UNKNOWN)
	if not isStarted then
		resetDungeonTimerButton:SetText(L.DUNGEON_CHALLENGE_START_RUN)
	elseif isStopped then
		resetDungeonTimerButton:SetText(L.DUNGEON_CHALLENGE_RESET_TIMER)
	else
		resetDungeonTimerButton:SetText(L.DUNGEON_CHALLENGE_COMPLETE_RUN)
	end
	resetDungeonTimerButton:SetEnabled(isActive and not InCombatLockdown())
	guildStartDungeonTimerButton:SetEnabled(not InCombatLockdown() and IsInGuild())
	toggleCombatLogButton:SetText(challenge and challenge.GetCombatLogToggleLabel and challenge.GetCombatLogToggleLabel() or L.DUNGEON_CHALLENGE_COMBAT_LOG_START)
	toggleCombatLogButton:SetEnabled(challenge and challenge.CanControlCombatLog and challenge.CanControlCombatLog())
	toggleAdvancedCombatLogButton:SetText(challenge and challenge.GetAdvancedCombatLogToggleLabel and challenge.GetAdvancedCombatLogToggleLabel() or L.DUNGEON_CHALLENGE_ADVANCED_COMBAT_LOG_START)
	toggleAdvancedCombatLogButton:SetEnabled(challenge and challenge.CanControlAdvancedCombatLog and challenge.CanControlAdvancedCombatLog())
end

local dungeonPanelRefreshElapsed = 0
dungeonPanel:SetScript("OnUpdate", function(_, elapsed)
	if activeTab ~= "dungeon" then
		return
	end

	dungeonPanelRefreshElapsed = dungeonPanelRefreshElapsed + elapsed
	if dungeonPanelRefreshElapsed >= 1 then
		dungeonPanelRefreshElapsed = 0
		addon.RefreshDungeonPanel()
	end
end)

local function ShowTab(tab)
	if tabs[tab]
		and (tab ~= "routes" or routesTabUnlocked)
		and (tab ~= "debug" or debugTabUnlocked)
		and (tab ~= "spectatorWarGame" or spectatorWarGameTabUnlocked)
	then
		activeTab = tab
	else
		activeTab = "info"
	end

	PanelTemplates_SetTab(frame, tabs[activeTab]:GetID())

	infoPanel:SetShown(activeTab == "info")
	settingsPanel:SetShown(activeTab == "settings")
	waypointsPanel:SetShown(activeTab == "waypoints")
	routesPanel:SetShown(activeTab == "routes")
	dungeonPanel:SetShown(activeTab == "dungeon")
	spectatorWarGamePanel:SetShown(activeTab == "spectatorWarGame")
	debugPanel:SetShown(activeTab == "debug")

	if activeTab == "info" then
		addon.RefreshInfoPanel()
	elseif activeTab == "settings" then
		addon.RefreshWindow()
		UpdateSettingsContentHeight()
	elseif activeTab == "waypoints" then
		RefreshWaypointButtons()
	elseif activeTab == "routes" then
		addon.RefreshRoutesPanel()
	elseif activeTab == "dungeon" then
		addon.RefreshDungeonPanel()
	elseif activeTab == "spectatorWarGame" then
		addon.RefreshSpectatorWarGamePanel()
	elseif activeTab == "debug" then
		addon.RefreshWindow()
		UpdateDebugContentHeight()
	end
end

local function RefreshHiddenTabCount()
	local count = defaultTabCount
	if routesTabUnlocked then
		count = math.max(count, routesTab:GetID())
	end
	if spectatorWarGameTabUnlocked then
		count = math.max(count, spectatorWarGameTab:GetID())
	end
	if debugTabUnlocked then
		count = math.max(count, debugTab:GetID())
	end
	PanelTemplates_SetNumTabs(frame, count)
end

local function LockRoutesTab()
	routesTabUnlocked = false
	routesTab:Hide()
	RefreshHiddenTabCount()
end

local function LockDebugTab()
	debugTabUnlocked = false
	debugTab:Hide()
	RefreshHiddenTabCount()
end

local function LockSpectatorWarGameTab()
	spectatorWarGameTabUnlocked = false
	spectatorWarGameTab:Hide()
	RefreshHiddenTabCount()
end

frame:HookScript("OnHide", function()
	LockRoutesTab()
	LockDebugTab()
	LockSpectatorWarGameTab()
end)

for _, tabKey in ipairs(tabOrder) do
	tabs[tabKey]:SetScript("OnClick", function(self)
		ShowTab(self.tabKey)
		PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
	end)
end

local function ReportCompletionBannerResult(ok, err)
	if ok then
		print(L.DUNGEON_CHALLENGE_COMPLETION_COMMAND)
	else
		print(L.DUNGEON_CHALLENGE_COMPLETION_ERROR:format(tostring(err or "unknown error")))
	end
end

local function CreateCheckbox(parent, label, tooltip, onClick)
	local checkbox = CreateFrame("CheckButton", nil, parent, "MinimalCheckboxTemplate")
	checkbox:SetHitRectInsets(0, -340, 0, 0)

	checkbox.Text = checkbox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	checkbox.Text:SetPoint("LEFT", checkbox, "RIGHT", 4, 0)
	checkbox.Text:SetText(label)
	checkbox.Text:SetJustifyH("LEFT")

	checkbox:SetScript("OnClick", function(self)
		onClick(self:GetChecked())
		addon.RefreshWindow()
	end)
	checkbox:SetScript("OnEnter", function(self)
		if tooltip then
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(label, 1, 1, 1)
			GameTooltip_AddNormalLine(GameTooltip, tooltip)
			GameTooltip:Show()
		end
	end)
	checkbox:SetScript("OnLeave", GameTooltip_Hide)

	return checkbox
end

local enemyForcesModeOptions = {
	{
		mode = addon.ENEMY_FORCES_MODE_DISABLED,
		label = L.DUNGEON_CHALLENGE_ENEMY_FORCES_MODE_DISABLED,
	},
	{
		mode = addon.ENEMY_FORCES_MODE_REQUIRED,
		label = L.DUNGEON_CHALLENGE_ENEMY_FORCES_MODE_REQUIRED,
	},
	{
		mode = addon.ENEMY_FORCES_MODE_UNLIMITED,
		label = L.DUNGEON_CHALLENGE_ENEMY_FORCES_MODE_UNLIMITED,
	},
}

local function GetEnemyForcesModeLabel(mode)
	for _, option in ipairs(enemyForcesModeOptions) do
		if option.mode == mode then
			return option.label
		end
	end

	return L.DUNGEON_CHALLENGE_ENEMY_FORCES_MODE_DISABLED
end

local function NormalizeEnemyForcesMode(mode)
	if mode == addon.ENEMY_FORCES_MODE_REQUIRED or mode == addon.ENEMY_FORCES_MODE_UNLIMITED then
		return mode
	end

	return addon.ENEMY_FORCES_MODE_DISABLED
end

local function GetSelectedEnemyForcesMode()
	return NormalizeEnemyForcesMode(Level20DB.enemyForcesMode)
end

local function SetSelectedEnemyForcesMode(mode)
	Level20DB.enemyForcesMode = NormalizeEnemyForcesMode(mode)
	if addon.DungeonChallenge and addon.DungeonChallenge.refresh then
		addon.DungeonChallenge.refresh(Level20DB.showDungeonChallengeFrame)
	end
end

local function CreateEnemyForcesModeDropdown(parent)
	local row = CreateFrame("Frame", nil, parent)
	row:SetSize(430, 26)

	row.Text = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	row.Text:SetPoint("LEFT", row, "LEFT", 0, 0)
	row.Text:SetWidth(170)
	row.Text:SetJustifyH("LEFT")
	row.Text:SetText(L.DUNGEON_CHALLENGE_ENEMY_FORCES_SETTING_LABEL)

	row.Dropdown = CreateFrame("DropdownButton", nil, row, "WowStyle1DropdownTemplate")
	row.Dropdown:SetPoint("LEFT", row.Text, "RIGHT", 8, 0)
	row.Dropdown:SetWidth(180)

	if row.Dropdown.SetSelectionText then
		row.Dropdown:SetSelectionText(function()
			return GetEnemyForcesModeLabel(GetSelectedEnemyForcesMode())
		end)
	end

	local function IsSelected(mode)
		return GetSelectedEnemyForcesMode() == mode
	end

	local function SetSelected(mode)
		SetSelectedEnemyForcesMode(mode)
		addon.RefreshWindow()
	end

	row.Dropdown:SetupMenu(function(dropdown, rootDescription)
		rootDescription:SetTag("LEVEL20_ENEMY_FORCES_MODE")

		for _, option in ipairs(enemyForcesModeOptions) do
			rootDescription:CreateRadio(option.label, IsSelected, SetSelected, option.mode)
		end
	end)

	row:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(L.DUNGEON_CHALLENGE_ENEMY_FORCES_SETTING_LABEL, 1, 1, 1)
		GameTooltip_AddNormalLine(GameTooltip, L.DUNGEON_CHALLENGE_ENEMY_FORCES_SETTING_TOOLTIP)
		GameTooltip:Show()
	end)
	row:SetScript("OnLeave", GameTooltip_Hide)
	row.Dropdown:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(L.DUNGEON_CHALLENGE_ENEMY_FORCES_SETTING_LABEL, 1, 1, 1)
		GameTooltip_AddNormalLine(GameTooltip, L.DUNGEON_CHALLENGE_ENEMY_FORCES_SETTING_TOOLTIP)
		GameTooltip:Show()
	end)
	row.Dropdown:SetScript("OnLeave", GameTooltip_Hide)

	function row:Refresh()
		local label = GetEnemyForcesModeLabel(GetSelectedEnemyForcesMode())
		if self.Dropdown.SetDefaultText then
			self.Dropdown:SetDefaultText(label)
		end
	end

	return row
end

toggleCombatLogButton:SetScript("OnClick", function()
	addon.DungeonChallenge.ToggleCombatLog()
	addon.RefreshDungeonPanel()
	if addon.RefreshCombatLogWarning then
		addon.RefreshCombatLogWarning()
	end
end)

toggleAdvancedCombatLogButton:SetScript("OnClick", function()
	addon.DungeonChallenge.ToggleAdvancedCombatLog()
	addon.RefreshDungeonPanel()
	if addon.RefreshCombatLogWarning then
		addon.RefreshCombatLogWarning()
	end
end)

local function CreateSlider(parent, name, label, minValue, maxValue, valueStep)
	local slider = CreateFrame("Frame", name, parent, "MinimalSliderWithSteppersTemplate")
	slider:SetWidth(250)

	local steps = (maxValue - minValue) / valueStep
	local formatters = {
		[MinimalSliderWithSteppersMixin.Label.Top] = CreateMinimalSliderFormatter(MinimalSliderWithSteppersMixin.Label.Top, label),
		[MinimalSliderWithSteppersMixin.Label.Min] = CreateMinimalSliderFormatter(MinimalSliderWithSteppersMixin.Label.Min, tostring(minValue)),
		[MinimalSliderWithSteppersMixin.Label.Max] = CreateMinimalSliderFormatter(MinimalSliderWithSteppersMixin.Label.Max, tostring(maxValue)),
	}
	slider:Init(minValue, minValue, maxValue, steps, formatters)

	function slider:SetOnValueChanged(callback)
		self.Slider:SetScript("OnValueChanged", function(_, value)
			self:FormatValue(value)
			callback(self, value)
		end)
	end

	function slider:GetValue()
		return self.Slider:GetValue()
	end

	return slider
end

local talentFilterCheckbox = CreateCheckbox(
	settingsContent,
	L.TALENT_FILTER_LABEL,
	L.TALENT_FILTER_TOOLTIP,
	function(checked)
		addon.SetTalentFilterEnabled(checked)
	end
)
talentFilterCheckbox:SetPoint("TOPLEFT", settingsContent, "TOPLEFT", 0, 0)

local spellBookFilterCheckbox = CreateCheckbox(
	settingsContent,
	L.SPELLBOOK_FILTER_LABEL,
	L.SPELLBOOK_FILTER_TOOLTIP,
	function(checked)
		addon.SetSpellBookFilterEnabled(checked)
	end
)
spellBookFilterCheckbox:SetPoint("TOPLEFT", talentFilterCheckbox, "BOTTOMLEFT", 0, -4)
spellBookFilterCheckbox:SetShown(not addon.SPELLBOOK_FILTER_DISABLED)

local playerMarksCheckbox = CreateCheckbox(
	settingsContent,
	L.PLAYER_MARKS_LABEL,
	L.PLAYER_MARKS_TOOLTIP,
	function(checked)
		Level20DB.showPlayerMarks = checked
		addon.RefreshPlayerMarks()
	end
)
if addon.SPELLBOOK_FILTER_DISABLED then
	playerMarksCheckbox:SetPoint("TOPLEFT", talentFilterCheckbox, "BOTTOMLEFT", 0, -4)
else
	playerMarksCheckbox:SetPoint("TOPLEFT", spellBookFilterCheckbox, "BOTTOMLEFT", 0, -4)
end

local shadowlandsProtectionCheckbox = CreateCheckbox(
	settingsContent,
	L.SL_PROTECTION_LABEL,
	L.SL_PROTECTION_TOOLTIP,
	function(checked)
		Level20DB.shadowlandsProtection = checked
		addon.RefreshShadowlandsProtection()
	end
)
shadowlandsProtectionCheckbox:SetPoint("TOPLEFT", playerMarksCheckbox, "BOTTOMLEFT", 0, -4)

local dungeonChallengeFrameCheckbox = CreateCheckbox(
	settingsContent,
	L.DUNGEON_CHALLENGE_FRAME_LABEL,
	L.DUNGEON_CHALLENGE_FRAME_TOOLTIP,
	function(checked)
		addon.DungeonChallenge.setEnabled(checked)
	end
)
dungeonChallengeFrameCheckbox:SetPoint("TOPLEFT", shadowlandsProtectionCheckbox, "BOTTOMLEFT", 0, -4)

local enemyForcesModeDropdown = CreateEnemyForcesModeDropdown(settingsContent)
enemyForcesModeDropdown:SetPoint("TOPLEFT", dungeonChallengeFrameCheckbox, "BOTTOMLEFT", 0, -4)

local scoreCriteriaCheckbox = CreateCheckbox(
	settingsContent,
	L.DUNGEON_CHALLENGE_SCORE_CRITERIA_LABEL,
	L.DUNGEON_CHALLENGE_SCORE_CRITERIA_TOOLTIP,
	function(checked)
		addon.DungeonChallenge.SetScoreCriteriaEnabled(checked)
	end
)
scoreCriteriaCheckbox:SetPoint("TOPLEFT", enemyForcesModeDropdown, "BOTTOMLEFT", 0, -4)

local combatLogManagementCheckbox = CreateCheckbox(
	settingsContent,
	L.DUNGEON_CHALLENGE_COMBAT_LOG_MANAGEMENT_LABEL,
	L.DUNGEON_CHALLENGE_COMBAT_LOG_MANAGEMENT_TOOLTIP,
	function(checked)
		addon.DungeonChallenge.SetCombatLogManagementEnabled(checked)
	end
)
combatLogManagementCheckbox:SetPoint("TOPLEFT", scoreCriteriaCheckbox, "BOTTOMLEFT", 0, -4)

local guildChallengeStartCheckbox = CreateCheckbox(
	settingsContent,
	L.DUNGEON_CHALLENGE_GUILD_START_LABEL,
	L.DUNGEON_CHALLENGE_GUILD_START_TOOLTIP,
	function(checked)
		addon.DungeonChallenge.SetGuildStartEnabled(checked)
	end
)
guildChallengeStartCheckbox:SetPoint("TOPLEFT", combatLogManagementCheckbox, "BOTTOMLEFT", 0, -4)

local bagFoldersCheckbox = CreateCheckbox(
	settingsContent,
	L.BAG_FOLDERS_SETTING_LABEL,
	L.BAG_FOLDERS_SETTING_TOOLTIP,
	function(checked)
		addon.SetBagFoldersEnabled(checked)
	end
)
bagFoldersCheckbox:SetPoint("TOPLEFT", guildChallengeStartCheckbox, "BOTTOMLEFT", 0, -4)

local smallMinimapButtonCheckbox = CreateCheckbox(
	settingsContent,
	L.MINIMAP_SMALL_BUTTON_LABEL,
	L.MINIMAP_SMALL_BUTTON_TOOLTIP,
	function(checked)
		addon.SetSmallMinimapButtonEnabled(checked)
	end
)
smallMinimapButtonCheckbox:SetPoint("TOPLEFT", bagFoldersCheckbox, "BOTTOMLEFT", 0, -4)

settingsContent:SetPoint("TOPLEFT", settingsScrollFrame, "TOPLEFT", 0, 0)
UpdateSettingsContentHeight()

local debugXPWarningCheckbox = CreateCheckbox(
	debugContent,
	L.DEBUG_XP_WARNING_LABEL,
	L.DEBUG_XP_WARNING_TOOLTIP,
	function(checked)
		Level20DB.debugXPWarning = checked
		addon.RefreshXPWarning()
	end
)
debugXPWarningCheckbox:SetPoint("TOPLEFT", debugContent, "TOPLEFT", 0, 0)

local debugCovenantWarningCheckbox = CreateCheckbox(
	debugContent,
	L.DEBUG_COVENANT_WARNING_LABEL,
	L.DEBUG_COVENANT_WARNING_TOOLTIP,
	function(checked)
		Level20DB.debugCovenantWarning = checked
		addon.RefreshShadowlandsProtection()
	end
)
debugCovenantWarningCheckbox:SetPoint("TOPLEFT", debugXPWarningCheckbox, "BOTTOMLEFT", 0, -4)

local debugPlayerMarksCheckbox = CreateCheckbox(
	debugContent,
	L.DEBUG_PLAYER_MARKS_LABEL,
	L.DEBUG_PLAYER_MARKS_TOOLTIP,
	function(checked)
		Level20DB.debugPlayerMarks = checked
		addon.RefreshPlayerMarks()
	end
)
debugPlayerMarksCheckbox:SetPoint("TOPLEFT", debugCovenantWarningCheckbox, "BOTTOMLEFT", 0, -4)

local debugUnitTooltipValuesCheckbox = CreateCheckbox(
	debugContent,
	L.DEBUG_UNIT_TOOLTIP_VALUES_LABEL,
	L.DEBUG_UNIT_TOOLTIP_VALUES_TOOLTIP,
	function(checked)
		Level20DB.debugUnitTooltipValues = checked and true or false
	end
)
debugUnitTooltipValuesCheckbox:SetPoint("TOPLEFT", debugPlayerMarksCheckbox, "BOTTOMLEFT", 0, -4)

debugRouteTaxiNodeDiffRow = CreateInfoRow(debugContent, L.ROUTE_CHANGED_NODES_LABEL, debugUnitTooltipValuesCheckbox)
debugRouteTaxiNodeDiffRow:SetWidth(430)
debugRouteTaxiNodeDiffRow.label:SetWidth(130)
debugRouteTaxiNodeDiffRow.value:SetPoint("LEFT", debugRouteTaxiNodeDiffRow.label, "RIGHT", 12, 0)
debugRouteTaxiNodeDiffRow.value:SetPoint("RIGHT", debugRouteTaxiNodeDiffRow, "RIGHT", 0, 0)
debugRouteTaxiNodeDiffRow.value:SetWordWrap(false)

local debugRouteBaselineButton = CreateFrame("Button", nil, debugContent, "UIPanelButtonTemplate")
debugRouteBaselineButton:SetSize(220, 24)
debugRouteBaselineButton:SetPoint("TOPLEFT", debugRouteTaxiNodeDiffRow, "BOTTOMLEFT", 0, -8)
debugRouteBaselineButton:SetText(L.ROUTE_REFRESH_PHASE)
debugRouteBaselineButton:SetScript("OnClick", function()
	addon.RefreshRoutesPanel(true)
end)

local completionBannerPlayerCountSlider = CreateSlider(
	debugContent,
	"Level20CompletionBannerPlayerCountSlider",
	L.DEBUG_COMPLETION_BANNER_PLAYERS_LABEL,
	1,
	40,
	1
)
completionBannerPlayerCountSlider:SetPoint("TOPLEFT", debugRouteBaselineButton, "BOTTOMLEFT", 4, -28)

local completionBannerPlayerCountValue = debugContent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
completionBannerPlayerCountValue:SetPoint("LEFT", completionBannerPlayerCountSlider, "RIGHT", 12, 0)

completionBannerPlayerCountSlider:SetOnValueChanged(function(self, value)
	local playerCount = math.floor(value + 0.5)
	if self:GetValue() ~= playerCount then
		self:SetValue(playerCount)
	end

	Level20DB.debugCompletionBannerPlayerCount = playerCount
	completionBannerPlayerCountValue:SetText(tostring(playerCount))
end)

local showTestCompletionBannerButton = CreateFrame("Button", nil, debugContent, "UIPanelButtonTemplate")
showTestCompletionBannerButton:SetSize(220, 24)
showTestCompletionBannerButton:SetPoint("TOPLEFT", completionBannerPlayerCountSlider, "BOTTOMLEFT", -4, -24)
showTestCompletionBannerButton:SetText(L.DEBUG_SHOW_COMPLETION_BANNER)
showTestCompletionBannerButton:SetScript("OnClick", function()
	local playerCount = math.floor(completionBannerPlayerCountSlider:GetValue() + 0.5)
	ReportCompletionBannerResult(addon.DungeonChallenge.ShowTestCompletionBanner(playerCount))
end)

debugContent:SetPoint("TOPLEFT", debugScrollFrame, "TOPLEFT", 0, 0)
UpdateDebugContentHeight()

function addon.RestoreWindowPosition()
	if not Level20DB.windowPoint then
		return
	end

	frame:ClearAllPoints()
	frame:SetPoint(
		Level20DB.windowPoint,
		UIParent,
		Level20DB.windowRelativePoint or Level20DB.windowPoint,
		Level20DB.windowXOfs or 0,
		Level20DB.windowYOfs or 0
	)
end

function addon.RefreshWindow()
	talentFilterCheckbox:SetChecked(Level20DB.hideHighLevelTalents)
	if not addon.SPELLBOOK_FILTER_DISABLED then
		spellBookFilterCheckbox:SetChecked(Level20DB.hideHighLevelSpells)
	end
	playerMarksCheckbox:SetChecked(Level20DB.showPlayerMarks)
	shadowlandsProtectionCheckbox:SetChecked(Level20DB.shadowlandsProtection)
	dungeonChallengeFrameCheckbox:SetChecked(Level20DB.showDungeonChallengeFrame)
	scoreCriteriaCheckbox:SetChecked(Level20DB.showDungeonChallengeScoreCriteria)
	enemyForcesModeDropdown:Refresh()
	combatLogManagementCheckbox:SetChecked(Level20DB.manageCombatLog)
	guildChallengeStartCheckbox:SetChecked(Level20DB.allowGuildChallengeStart)
	bagFoldersCheckbox:SetChecked(Level20DB.bagFolders and Level20DB.bagFolders.enabled)
	smallMinimapButtonCheckbox:SetChecked(Level20DB.smallMinimapButton)
	debugXPWarningCheckbox:SetChecked(Level20DB.debugXPWarning)
	debugCovenantWarningCheckbox:SetChecked(Level20DB.debugCovenantWarning)
	debugPlayerMarksCheckbox:SetChecked(Level20DB.debugPlayerMarks)
	debugUnitTooltipValuesCheckbox:SetChecked(Level20DB.debugUnitTooltipValues)
	completionBannerPlayerCountSlider:SetValue(Level20DB.debugCompletionBannerPlayerCount or 5)
	UpdateSettingsContentHeight()
	UpdateDebugContentHeight()
	addon.RefreshInfoPanel()
	addon.RefreshRoutesPanel()
	addon.RefreshDungeonPanel()
	addon.RefreshSpectatorWarGamePanel()
end

function addon.ShowWindow()
	LockRoutesTab()
	LockDebugTab()
	LockSpectatorWarGameTab()
	addon.RefreshWindow()
	ShowTab("info")
	frame:Show()
end

function addon.ShowHiddenTabsWindow()
	if not routesTabUnlocked then
		routesTabUnlocked = true
		routesTab:Show()
	end

	if not spectatorWarGameTabUnlocked then
		spectatorWarGameTabUnlocked = true
		spectatorWarGameTab:Show()
	end

	if not debugTabUnlocked then
		debugTabUnlocked = true
		debugTab:Show()
	end

	RefreshHiddenTabCount()
	addon.RefreshWindow()
	ShowTab("spectatorWarGame")
	frame:Show()
end

function addon.ToggleWindow()
	if frame:IsShown() then
		frame:Hide()
	else
		addon.ShowWindow()
	end
end

function addon.IsWindowShown()
	return frame:IsShown()
end
