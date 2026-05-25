local addonName, addon = ...
local L = addon.L

local frame = CreateFrame("Frame", "Level20Frame", UIParent, "DefaultPanelTemplate")
frame:SetSize(540, 292)
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
frame:SetTitle(L.ADDON_TITLE)

frame.CloseButton = CreateFrame("Button", nil, frame, "UIPanelCloseButtonDefaultAnchors")

local activeTab
local tabs = {}
local tabOrder = { "info", "settings", "waypoints", "dungeon", "debug" }

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
CreateTab(frame, 5, L.TAB_DEBUG, "debug")

PanelTemplates_SetNumTabs(frame, #tabOrder)

local infoPanel = CreateFrame("Frame", nil, frame)
infoPanel:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -40)
infoPanel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 20)

local settingsPanel = CreateFrame("Frame", nil, frame)
settingsPanel:SetPoint("TOPLEFT", infoPanel)
settingsPanel:SetPoint("BOTTOMRIGHT", infoPanel)

local settingsScrollFrame = CreateFrame("ScrollFrame", nil, settingsPanel, "ScrollFrameTemplate")
settingsScrollFrame:SetPoint("TOPLEFT", settingsPanel, "TOPLEFT", 4, -4)
settingsScrollFrame:SetPoint("BOTTOMRIGHT", settingsPanel, "BOTTOMRIGHT", -28, 4)

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

local dungeonPanel = CreateFrame("Frame", nil, frame)
dungeonPanel:SetPoint("TOPLEFT", infoPanel)
dungeonPanel:SetPoint("BOTTOMRIGHT", infoPanel)

local debugPanel = CreateFrame("Frame", nil, frame)
debugPanel:SetPoint("TOPLEFT", infoPanel)
debugPanel:SetPoint("BOTTOMRIGHT", infoPanel)

local debugScrollFrame = CreateFrame("ScrollFrame", nil, debugPanel, "ScrollFrameTemplate")
debugScrollFrame:SetPoint("TOPLEFT", debugPanel, "TOPLEFT", 4, -4)
debugScrollFrame:SetPoint("BOTTOMRIGHT", debugPanel, "BOTTOMRIGHT", -28, 4)

local debugContent = CreateFrame("Frame", nil, debugScrollFrame)
debugContent:SetSize(1, 1)
debugScrollFrame:SetScrollChild(debugContent)
debugScrollFrame:SetScript("OnSizeChanged", function(self, width)
	debugContent:SetWidth(math.max(1, width))
end)

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

local versionStatusLabel = infoPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
versionStatusLabel:SetPoint("TOPRIGHT", infoPanel, "TOPRIGHT", 0, 0)
versionStatusLabel:SetJustifyH("RIGHT")
versionStatusLabel:SetText(L.UNKNOWN)

local groupDataButton = CreateFrame("Button", nil, infoPanel, "UIPanelButtonTemplate")
groupDataButton:SetSize(140, 24)
groupDataButton:SetPoint("TOPLEFT", shadowlandsRow, "BOTTOMLEFT", 0, -12)
groupDataButton:SetText(L.GROUP_TRINKETS_BUTTON)
groupDataButton:SetScript("OnClick", function()
	addon.ShowGroupDataWindow()
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
	return addon.GetChromieTimeText and addon.GetChromieTimeText() or L.UNKNOWN
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

local dungeonStatusRow = CreateInfoRow(dungeonPanel, L.DUNGEON_CHALLENGE_STATUS_LABEL)
local dungeonTimerRow = CreateInfoRow(dungeonPanel, L.DUNGEON_CHALLENGE_TIMER_LABEL, dungeonStatusRow)

local resetDungeonTimerButton = CreateFrame("Button", nil, dungeonPanel, "UIPanelButtonTemplate")
resetDungeonTimerButton:SetSize(180, 24)
resetDungeonTimerButton:SetPoint("TOPLEFT", dungeonTimerRow, "BOTTOMLEFT", 0, -12)
resetDungeonTimerButton:SetText(L.DUNGEON_CHALLENGE_RESET_TIMER)
resetDungeonTimerButton:SetScript("OnClick", function()
	addon.DungeonChallenge.resetTimer()
	addon.RefreshDungeonPanel()
end)

local showCompletionBannerButton = CreateFrame("Button", nil, dungeonPanel, "UIPanelButtonTemplate")
showCompletionBannerButton:SetSize(180, 24)
showCompletionBannerButton:SetPoint("LEFT", resetDungeonTimerButton, "RIGHT", 12, 0)
showCompletionBannerButton:SetText(L.DUNGEON_CHALLENGE_SHOW_COMPLETION_BANNER)

local function FormatDuration(seconds)
	seconds = math.max(0, math.floor(seconds or 0))
	return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

function addon.RefreshDungeonPanel()
	local isActive = addon.DungeonChallenge and addon.DungeonChallenge.ShouldUse and addon.DungeonChallenge.ShouldUse()
	dungeonStatusRow.value:SetText(isActive and L.STATE_ENABLED or L.STATE_DISABLED)
	dungeonTimerRow.value:SetText(FormatDuration(addon.DungeonChallenge and addon.DungeonChallenge.GetElapsedTime and addon.DungeonChallenge.GetElapsedTime() or 0))
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
	if tabs[tab] then
		activeTab = tab
	else
		activeTab = "info"
	end

	PanelTemplates_SetTab(frame, tabs[activeTab]:GetID())

	infoPanel:SetShown(activeTab == "info")
	settingsPanel:SetShown(activeTab == "settings")
	waypointsPanel:SetShown(activeTab == "waypoints")
	dungeonPanel:SetShown(activeTab == "dungeon")
	debugPanel:SetShown(activeTab == "debug")

	if activeTab == "info" then
		addon.RefreshInfoPanel()
	elseif activeTab == "settings" then
		addon.RefreshWindow()
	elseif activeTab == "waypoints" then
		RefreshWaypointButtons()
	elseif activeTab == "dungeon" then
		addon.RefreshDungeonPanel()
	elseif activeTab == "debug" then
		addon.RefreshWindow()
	end
end

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

showCompletionBannerButton:SetScript("OnClick", function()
	ReportCompletionBannerResult(addon.DungeonChallenge.ShowCompletionBanner())
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
spellBookFilterCheckbox:SetPoint("TOPLEFT", talentFilterCheckbox, "BOTTOMLEFT", 0, -8)
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
	playerMarksCheckbox:SetPoint("TOPLEFT", talentFilterCheckbox, "BOTTOMLEFT", 0, -8)
else
	playerMarksCheckbox:SetPoint("TOPLEFT", spellBookFilterCheckbox, "BOTTOMLEFT", 0, -8)
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
shadowlandsProtectionCheckbox:SetPoint("TOPLEFT", playerMarksCheckbox, "BOTTOMLEFT", 0, -8)

local dungeonChallengeFrameCheckbox = CreateCheckbox(
	settingsContent,
	L.DUNGEON_CHALLENGE_FRAME_LABEL,
	L.DUNGEON_CHALLENGE_FRAME_TOOLTIP,
	function(checked)
		addon.DungeonChallenge.setEnabled(checked)
	end
)
dungeonChallengeFrameCheckbox:SetPoint("TOPLEFT", shadowlandsProtectionCheckbox, "BOTTOMLEFT", 0, -8)

local bagFoldersCheckbox = CreateCheckbox(
	settingsContent,
	L.BAG_FOLDERS_SETTING_LABEL,
	L.BAG_FOLDERS_SETTING_TOOLTIP,
	function(checked)
		addon.SetBagFoldersEnabled(checked)
	end
)
bagFoldersCheckbox:SetPoint("TOPLEFT", dungeonChallengeFrameCheckbox, "BOTTOMLEFT", 0, -8)

settingsContent:SetPoint("TOPLEFT", settingsScrollFrame, "TOPLEFT", 0, 0)
settingsContent:SetHeight(252)
settingsScrollFrame.ScrollBar:Update()

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
debugCovenantWarningCheckbox:SetPoint("TOPLEFT", debugXPWarningCheckbox, "BOTTOMLEFT", 0, -8)

local debugPlayerMarksCheckbox = CreateCheckbox(
	debugContent,
	L.DEBUG_PLAYER_MARKS_LABEL,
	L.DEBUG_PLAYER_MARKS_TOOLTIP,
	function(checked)
		Level20DB.debugPlayerMarks = checked
		addon.RefreshPlayerMarks()
	end
)
debugPlayerMarksCheckbox:SetPoint("TOPLEFT", debugCovenantWarningCheckbox, "BOTTOMLEFT", 0, -8)

local completionBannerPlayerCountSlider = CreateSlider(
	debugContent,
	"Level20CompletionBannerPlayerCountSlider",
	L.DEBUG_COMPLETION_BANNER_PLAYERS_LABEL,
	1,
	40,
	1
)
completionBannerPlayerCountSlider:SetPoint("TOPLEFT", debugPlayerMarksCheckbox, "BOTTOMLEFT", 4, -32)

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
showTestCompletionBannerButton:SetSize(180, 24)
showTestCompletionBannerButton:SetPoint("TOPLEFT", completionBannerPlayerCountSlider, "BOTTOMLEFT", -4, -28)
showTestCompletionBannerButton:SetText(L.DEBUG_SHOW_COMPLETION_BANNER)
showTestCompletionBannerButton:SetScript("OnClick", function()
	local playerCount = math.floor(completionBannerPlayerCountSlider:GetValue() + 0.5)
	ReportCompletionBannerResult(addon.DungeonChallenge.ShowTestCompletionBanner(playerCount))
end)

local resetBagFoldersButton = CreateFrame("Button", nil, debugContent, "UIPanelButtonTemplate")
resetBagFoldersButton:SetSize(180, 24)
resetBagFoldersButton:SetPoint("TOPLEFT", showTestCompletionBannerButton, "BOTTOMLEFT", 0, -8)
resetBagFoldersButton:SetText(L.DEBUG_RESET_BAG_FOLDERS)
resetBagFoldersButton:SetScript("OnClick", function()
	if addon.ResetBagFolders then
		addon.ResetBagFolders()
		print(L.DEBUG_RESET_BAG_FOLDERS_DONE)
	end
end)
resetBagFoldersButton:SetScript("OnEnter", function(self)
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	GameTooltip:SetText(L.DEBUG_RESET_BAG_FOLDERS, 1, 1, 1)
	GameTooltip:AddLine(L.DEBUG_RESET_BAG_FOLDERS_TOOLTIP, nil, nil, nil, true)
	GameTooltip:Show()
end)
resetBagFoldersButton:SetScript("OnLeave", GameTooltip_Hide)

debugContent:SetPoint("TOPLEFT", debugScrollFrame, "TOPLEFT", 0, 0)
debugContent:SetHeight(268)
debugScrollFrame.ScrollBar:Update()

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
	bagFoldersCheckbox:SetChecked(Level20DB.bagFolders and Level20DB.bagFolders.enabled)
	debugXPWarningCheckbox:SetChecked(Level20DB.debugXPWarning)
	debugCovenantWarningCheckbox:SetChecked(Level20DB.debugCovenantWarning)
	debugPlayerMarksCheckbox:SetChecked(Level20DB.debugPlayerMarks)
	completionBannerPlayerCountSlider:SetValue(Level20DB.debugCompletionBannerPlayerCount or 5)
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
