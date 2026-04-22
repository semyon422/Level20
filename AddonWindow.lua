local addonName, addon = ...
local L = addon.L

local frame = CreateFrame("Frame", "Level20Frame", UIParent, "BasicFrameTemplateWithInset")
frame:SetSize(420, 292)
frame:SetPoint("CENTER")
frame:SetMovable(true)
frame:SetClampedToScreen(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", function(self)
	self:StopMovingOrSizing()

	local point, _, relativePoint, xOfs, yOfs = self:GetPoint()
	Level20DB.windowPoint = point
	Level20DB.windowRelativePoint = relativePoint
	Level20DB.windowXOfs = xOfs
	Level20DB.windowYOfs = yOfs
end)
frame:Hide()

frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
frame.title:SetPoint("LEFT", frame.TitleBg, "LEFT", 8, 0)
frame.title:SetText(L.ADDON_TITLE)

local activeTab

local function CreateTab(parent, label)
	local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	button:SetSize(92, 24)
	button:SetText(label)
	return button
end

local infoTab = CreateTab(frame, L.TAB_INFO)
infoTab:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -31)

local settingsTab = CreateTab(frame, L.TAB_SETTINGS)
settingsTab:SetPoint("LEFT", infoTab, "RIGHT", 6, 0)

local waypointsTab = CreateTab(frame, L.TAB_WAYPOINTS)
waypointsTab:SetPoint("LEFT", settingsTab, "RIGHT", 6, 0)

local infoPanel = CreateFrame("Frame", nil, frame)
infoPanel:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -66)
infoPanel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 20)

local settingsPanel = CreateFrame("Frame", nil, frame)
settingsPanel:SetPoint("TOPLEFT", infoPanel)
settingsPanel:SetPoint("BOTTOMRIGHT", infoPanel)

local waypointsPanel = CreateFrame("Frame", nil, frame)
waypointsPanel:SetPoint("TOPLEFT", infoPanel)
waypointsPanel:SetPoint("BOTTOMRIGHT", infoPanel)

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

local accountTypeRow = CreateInfoRow(infoPanel, L.ACCOUNT_TYPE)
local subscriptionRow = CreateInfoRow(infoPanel, L.SUBSCRIPTION, accountTypeRow)
local xpGainRow = CreateInfoRow(infoPanel, L.XP_GAIN, subscriptionRow)
local chromieTimeRow = CreateInfoRow(infoPanel, L.CHROMIE_TIME, xpGainRow)
local shadowlandsRow = CreateInfoRow(infoPanel, L.SHADOWLANDS_STATE, chromieTimeRow)

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
	local levelCap = GetRestrictedAccountData()
	if levelCap == addon.LEVEL_CAP then
		return L.SUBSCRIPTION_INACTIVE
	end

	return L.SUBSCRIPTION_ACTIVE
end

local function GetXPGainText()
	return IsXPUserDisabled() and L.XP_DISABLED or L.XP_ENABLED
end

local function GetChromieTimeText()
	if not C_PlayerInfo.IsPlayerInChromieTime() then
		return L.CHROMIE_TIME_PRESENT
	end

	local chromieTimeID = UnitChromieTimeID("player")
	if not chromieTimeID then
		return L.UNKNOWN
	end

	local options = C_ChromieTime.GetChromieTimeExpansionOptions()
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

function addon.RefreshInfoPanel()
	accountTypeRow.value:SetText(GetAccountTypeText())
	subscriptionRow.value:SetText(GetSubscriptionText())
	xpGainRow.value:SetText(GetXPGainText())
	chromieTimeRow.value:SetText(GetChromieTimeText())
	shadowlandsRow.value:SetText(addon.GetShadowlandsStateText())
end

local function ShowTab(tab)
	if tab == "settings" or tab == "waypoints" then
		activeTab = tab
	else
		activeTab = "info"
	end

	infoPanel:SetShown(activeTab == "info")
	settingsPanel:SetShown(activeTab == "settings")
	waypointsPanel:SetShown(activeTab == "waypoints")
	infoTab:SetEnabled(activeTab ~= "info")
	settingsTab:SetEnabled(activeTab ~= "settings")
	waypointsTab:SetEnabled(activeTab ~= "waypoints")

	if activeTab == "info" then
		addon.RefreshInfoPanel()
	elseif activeTab == "settings" then
		addon.RefreshWindow()
	elseif activeTab == "waypoints" then
		RefreshWaypointButtons()
	end
end

infoTab:SetScript("OnClick", function()
	ShowTab("info")
end)

settingsTab:SetScript("OnClick", function()
	ShowTab("settings")
end)

waypointsTab:SetScript("OnClick", function()
	ShowTab("waypoints")
end)

local function CreateCheckbox(parent, label, tooltip, onClick)
	local checkbox = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	checkbox.Text:SetText(label)
	checkbox.tooltipText = tooltip
	checkbox:SetScript("OnClick", function(self)
		onClick(self:GetChecked())
		addon.RefreshWindow()
	end)

	return checkbox
end

local talentFilterCheckbox = CreateCheckbox(
	settingsPanel,
	L.TALENT_FILTER_LABEL,
	L.TALENT_FILTER_TOOLTIP,
	function(checked)
		addon.SetTalentFilterEnabled(checked)
	end
)
talentFilterCheckbox:SetPoint("TOPLEFT", settingsPanel, "TOPLEFT", 0, 0)

local spellBookFilterCheckbox = CreateCheckbox(
	settingsPanel,
	L.SPELLBOOK_FILTER_LABEL,
	L.SPELLBOOK_FILTER_TOOLTIP,
	function(checked)
		addon.SetSpellBookFilterEnabled(checked)
	end
)
spellBookFilterCheckbox:SetPoint("TOPLEFT", talentFilterCheckbox, "BOTTOMLEFT", 0, -8)

local playerMarksCheckbox = CreateCheckbox(
	settingsPanel,
	L.PLAYER_MARKS_LABEL,
	L.PLAYER_MARKS_TOOLTIP,
	function(checked)
		Level20DB.showPlayerMarks = checked
		addon.RefreshPlayerMarks()
	end
)
playerMarksCheckbox:SetPoint("TOPLEFT", spellBookFilterCheckbox, "BOTTOMLEFT", 0, -8)

local shadowlandsProtectionCheckbox = CreateCheckbox(
	settingsPanel,
	L.SL_PROTECTION_LABEL,
	L.SL_PROTECTION_TOOLTIP,
	function(checked)
		Level20DB.shadowlandsProtection = checked
		addon.RefreshShadowlandsProtection()
	end
)
shadowlandsProtectionCheckbox:SetPoint("TOPLEFT", playerMarksCheckbox, "BOTTOMLEFT", 0, -8)

local debugModeCheckbox = CreateCheckbox(
	settingsPanel,
	L.DEBUG_MODE_LABEL,
	L.DEBUG_MODE_TOOLTIP,
	function(checked)
		Level20DB.debugMode = checked
		addon.RefreshPlayerMarks()
		addon.RefreshXPWarning()
		addon.RefreshShadowlandsProtection()
	end
)
debugModeCheckbox:SetPoint("TOPLEFT", shadowlandsProtectionCheckbox, "BOTTOMLEFT", 0, -8)

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
	spellBookFilterCheckbox:SetChecked(Level20DB.hideHighLevelSpells)
	playerMarksCheckbox:SetChecked(Level20DB.showPlayerMarks)
	shadowlandsProtectionCheckbox:SetChecked(Level20DB.shadowlandsProtection)
	debugModeCheckbox:SetChecked(Level20DB.debugMode)
	addon.RefreshInfoPanel()
end

function addon.ShowWindow()
	addon.RefreshWindow()
	ShowTab("info")
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
