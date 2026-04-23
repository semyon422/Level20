local addonName, addon = ...
local L = addon.L

local frame = CreateFrame("Frame", "Level20Frame", UIParent, "BasicFrameTemplateWithInset")
frame:SetSize(472, 292)
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

local dungeonTab = CreateTab(frame, L.TAB_DUNGEON)
dungeonTab:SetPoint("LEFT", waypointsTab, "RIGHT", 6, 0)

local infoPanel = CreateFrame("Frame", nil, frame)
infoPanel:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -66)
infoPanel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 20)

local settingsPanel = CreateFrame("Frame", nil, frame)
settingsPanel:SetPoint("TOPLEFT", infoPanel)
settingsPanel:SetPoint("BOTTOMRIGHT", infoPanel)

local settingsScrollFrame = CreateFrame("ScrollFrame", nil, settingsPanel, "UIPanelScrollFrameTemplate")
settingsScrollFrame:SetPoint("TOPLEFT", settingsPanel, "TOPLEFT", 4, -4)
settingsScrollFrame:SetPoint("BOTTOMRIGHT", settingsPanel, "BOTTOMRIGHT", -28, 4)

local settingsContent = CreateFrame("Frame", nil, settingsScrollFrame)
settingsContent:SetSize(1, 1)
settingsScrollFrame:SetScrollChild(settingsContent)
settingsScrollFrame:SetScript("OnSizeChanged", function(self, width)
	settingsContent:SetWidth(math.max(1, width - 24))
end)

local waypointsPanel = CreateFrame("Frame", nil, frame)
waypointsPanel:SetPoint("TOPLEFT", infoPanel)
waypointsPanel:SetPoint("BOTTOMRIGHT", infoPanel)

local dungeonPanel = CreateFrame("Frame", nil, frame)
dungeonPanel:SetPoint("TOPLEFT", infoPanel)
dungeonPanel:SetPoint("BOTTOMRIGHT", infoPanel)

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

local dungeonStatusRow = CreateInfoRow(dungeonPanel, L.DUNGEON_CHALLENGE_STATUS_LABEL)
local dungeonTimerRow = CreateInfoRow(dungeonPanel, L.DUNGEON_CHALLENGE_TIMER_LABEL, dungeonStatusRow)

local resetDungeonTimerButton = CreateFrame("Button", nil, dungeonPanel, "UIPanelButtonTemplate")
resetDungeonTimerButton:SetSize(180, 24)
resetDungeonTimerButton:SetPoint("TOPLEFT", dungeonTimerRow, "BOTTOMLEFT", 0, -12)
resetDungeonTimerButton:SetText(L.DUNGEON_CHALLENGE_RESET_TIMER)
resetDungeonTimerButton:SetScript("OnClick", function()
	addon.ResetDungeonChallengeTimer()
	addon.RefreshDungeonPanel()
end)

local function FormatDuration(seconds)
	seconds = math.max(0, math.floor(seconds or 0))
	return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

function addon.RefreshDungeonPanel()
	local isActive = addon.IsDungeonChallengeActive and addon.IsDungeonChallengeActive()
	dungeonStatusRow.value:SetText(isActive and L.STATE_ENABLED or L.STATE_DISABLED)
	dungeonTimerRow.value:SetText(FormatDuration(addon.GetDungeonChallengeElapsedTime and addon.GetDungeonChallengeElapsedTime() or 0))
	resetDungeonTimerButton:SetEnabled(isActive and not InCombatLockdown())
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
	if tab == "settings" or tab == "waypoints" or tab == "dungeon" then
		activeTab = tab
	else
		activeTab = "info"
	end

	infoPanel:SetShown(activeTab == "info")
	settingsPanel:SetShown(activeTab == "settings")
	waypointsPanel:SetShown(activeTab == "waypoints")
	dungeonPanel:SetShown(activeTab == "dungeon")
	infoTab:SetEnabled(activeTab ~= "info")
	settingsTab:SetEnabled(activeTab ~= "settings")
	waypointsTab:SetEnabled(activeTab ~= "waypoints")
	dungeonTab:SetEnabled(activeTab ~= "dungeon")

	if activeTab == "info" then
		addon.RefreshInfoPanel()
	elseif activeTab == "settings" then
		addon.RefreshWindow()
	elseif activeTab == "waypoints" then
		RefreshWaypointButtons()
	elseif activeTab == "dungeon" then
		addon.RefreshDungeonPanel()
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

dungeonTab:SetScript("OnClick", function()
	ShowTab("dungeon")
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
spellBookFilterCheckbox:SetPoint("TOPLEFT", talentFilterCheckbox, "BOTTOMLEFT", 0, -8)

local playerMarksCheckbox = CreateCheckbox(
	settingsContent,
	L.PLAYER_MARKS_LABEL,
	L.PLAYER_MARKS_TOOLTIP,
	function(checked)
		Level20DB.showPlayerMarks = checked
		addon.RefreshPlayerMarks()
	end
)
playerMarksCheckbox:SetPoint("TOPLEFT", spellBookFilterCheckbox, "BOTTOMLEFT", 0, -8)

local shadowlandsProtectionCheckbox = CreateCheckbox(
	settingsContent,
	L.SL_PROTECTION_LABEL,
	L.SL_PROTECTION_TOOLTIP,
	function(checked)
		Level20DB.shadowlandsProtection = checked
		addon.RefreshShadowlandsProtection()
	end
)
shadowlandsProtectionCheckbox:SetPoint("TOPLEFT", playerMarksCheckbox, "BOTTOMLEFT", 0, -8)

local debugModeCheckbox = CreateCheckbox(
	settingsContent,
	L.DEBUG_MODE_LABEL,
	L.DEBUG_MODE_TOOLTIP,
	function(checked)
		Level20DB.debugMode = checked
		addon.RefreshPlayerMarks()
		addon.RefreshXPWarning()
		addon.RefreshShadowlandsProtection()
	end
)

local dungeonChallengeFrameCheckbox = CreateCheckbox(
	settingsContent,
	L.DUNGEON_CHALLENGE_FRAME_LABEL,
	L.DUNGEON_CHALLENGE_FRAME_TOOLTIP,
	function(checked)
		addon.SetDungeonChallengeFrameEnabled(checked)
	end
)
dungeonChallengeFrameCheckbox:SetPoint("TOPLEFT", shadowlandsProtectionCheckbox, "BOTTOMLEFT", 0, -8)

debugModeCheckbox:SetPoint("TOPLEFT", dungeonChallengeFrameCheckbox, "BOTTOMLEFT", 0, -8)
settingsContent:SetPoint("TOPLEFT", settingsScrollFrame, "TOPLEFT", 0, 0)
settingsContent:SetHeight(220)

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
	dungeonChallengeFrameCheckbox:SetChecked(Level20DB.showDungeonChallengeFrame)
	addon.RefreshInfoPanel()
	addon.RefreshDungeonPanel()
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
