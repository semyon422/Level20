local addon = Level20

local frame = CreateFrame("Frame", "Level20SettingsFrame", UIParent, "BasicFrameTemplateWithInset")
frame:SetSize(380, 270)
frame:SetPoint("CENTER")
frame:SetMovable(true)
frame:SetClampedToScreen(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", function(self)
	self:StopMovingOrSizing()

	local point, _, relativePoint, xOfs, yOfs = self:GetPoint()
	Level20DB.settingsPoint = point
	Level20DB.settingsRelativePoint = relativePoint
	Level20DB.settingsXOfs = xOfs
	Level20DB.settingsYOfs = yOfs
end)
frame:Hide()

frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
frame.title:SetPoint("LEFT", frame.TitleBg, "LEFT", 8, 0)
frame.title:SetText("Level20")

local activeTab

local function CreateTab(parent, label)
	local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	button:SetSize(92, 24)
	button:SetText(label)
	return button
end

local infoTab = CreateTab(frame, "Info")
infoTab:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -31)

local settingsTab = CreateTab(frame, "Settings")
settingsTab:SetPoint("LEFT", infoTab, "RIGHT", 6, 0)

local infoPanel = CreateFrame("Frame", nil, frame)
infoPanel:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -66)
infoPanel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 20)

local settingsPanel = CreateFrame("Frame", nil, frame)
settingsPanel:SetPoint("TOPLEFT", infoPanel)
settingsPanel:SetPoint("BOTTOMRIGHT", infoPanel)

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
	row.value:SetText("Unknown")

	return row
end

local accountTypeRow = CreateInfoRow(infoPanel, "Account type:")
local subscriptionRow = CreateInfoRow(infoPanel, "Subscription:", accountTypeRow)
local xpGainRow = CreateInfoRow(infoPanel, "XP gain:", subscriptionRow)
local chromieTimeRow = CreateInfoRow(infoPanel, "Chromie Time:", xpGainRow)

local function GetAccountTypeText()
	if IsTrialAccount() then
		return "Trial"
	end

	if IsVeteranTrialAccount() then
		return "Veteran"
	end

	return "Standard"
end

local function GetSubscriptionText()
	local levelCap = GetRestrictedAccountData()
	if levelCap == addon.LEVEL_CAP then
		return "Inactive"
	end

	return "Active"
end

local function GetXPGainText()
	return IsXPUserDisabled() and "Disabled" or "Enabled"
end

local function GetChromieTimeText()
	if not C_PlayerInfo.IsPlayerInChromieTime() then
		return "Present"
	end

	local chromieTimeID = UnitChromieTimeID("player")
	if not chromieTimeID then
		return "Unknown"
	end

	local options = C_ChromieTime.GetChromieTimeExpansionOptions()
	if type(options) ~= "table" then
		return "Unknown"
	end

	for _, option in ipairs(options) do
		if option.id == chromieTimeID then
			return option.name or "Unknown"
		end
	end

	return "Unknown"
end

function addon.RefreshInfoPanel()
	accountTypeRow.value:SetText(GetAccountTypeText())
	subscriptionRow.value:SetText(GetSubscriptionText())
	xpGainRow.value:SetText(GetXPGainText())
	chromieTimeRow.value:SetText(GetChromieTimeText())
end

local function ShowTab(tab)
	activeTab = tab == "settings" and "settings" or "info"

	infoPanel:SetShown(activeTab == "info")
	settingsPanel:SetShown(activeTab == "settings")
	infoTab:SetEnabled(activeTab ~= "info")
	settingsTab:SetEnabled(activeTab ~= "settings")

	if activeTab == "info" then
		addon.RefreshInfoPanel()
	else
		addon.RefreshSettingsWindow()
	end
end

infoTab:SetScript("OnClick", function()
	ShowTab("info")
end)

settingsTab:SetScript("OnClick", function()
	ShowTab("settings")
end)

local function CreateCheckbox(parent, label, tooltip, onClick)
	local checkbox = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	checkbox.Text:SetText(label)
	checkbox.tooltipText = tooltip
	checkbox:SetScript("OnClick", function(self)
		onClick(self:GetChecked())
		addon.RefreshSettingsWindow()
	end)

	return checkbox
end

local talentFilterCheckbox = CreateCheckbox(
	settingsPanel,
	"Level-20 talent filtering",
	"Filters class/spec and PvP talent UI to the level-20 usable view.",
	function(checked)
		addon.SetTalentFilterEnabled(checked)
	end
)
talentFilterCheckbox:SetPoint("TOPLEFT", settingsPanel, "TOPLEFT", 0, 0)

local spellBookFilterCheckbox = CreateCheckbox(
	settingsPanel,
	"Level-20 spellbook filtering",
	"Hides spellbook abilities learned above level 20.",
	function(checked)
		addon.SetSpellBookFilterEnabled(checked)
	end
)
spellBookFilterCheckbox:SetPoint("TOPLEFT", talentFilterCheckbox, "BOTTOMLEFT", 0, -8)

local minimapButtonCheckbox = CreateCheckbox(
	settingsPanel,
	"Show minimap button",
	"Shows the Level20 button near the minimap.",
	function(checked)
		Level20DB.showMinimapButton = checked
		addon.RefreshMinimapButton()
	end
)
minimapButtonCheckbox:SetPoint("TOPLEFT", spellBookFilterCheckbox, "BOTTOMLEFT", 0, -8)

function addon.RestoreSettingsWindowPosition()
	if not Level20DB.settingsPoint then
		return
	end

	frame:ClearAllPoints()
	frame:SetPoint(
		Level20DB.settingsPoint,
		UIParent,
		Level20DB.settingsRelativePoint or Level20DB.settingsPoint,
		Level20DB.settingsXOfs or 0,
		Level20DB.settingsYOfs or 0
	)
end

function addon.RefreshSettingsWindow()
	talentFilterCheckbox:SetChecked(Level20DB.hideHighLevelTalents)
	spellBookFilterCheckbox:SetChecked(Level20DB.hideHighLevelSpells)
	minimapButtonCheckbox:SetChecked(Level20DB.showMinimapButton)
	addon.RefreshInfoPanel()
end

function addon.ShowSettingsWindow()
	addon.RefreshSettingsWindow()
	ShowTab("info")
	frame:Show()
end

function addon.ToggleSettingsWindow()
	if frame:IsShown() then
		frame:Hide()
	else
		addon.ShowSettingsWindow()
	end
end

function addon.IsSettingsWindowShown()
	return frame:IsShown()
end
