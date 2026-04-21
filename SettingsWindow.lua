local addon = Level20

local frame = CreateFrame("Frame", "Level20SettingsFrame", UIParent, "BasicFrameTemplateWithInset")
frame:SetSize(330, 180)
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
frame.title:SetText("Level20 Settings")

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
	frame,
	"Level-20 talent filtering",
	"Filters class/spec and PvP talent UI to the level-20 usable view.",
	function(checked)
		addon.SetTalentFilterEnabled(checked)
	end
)
talentFilterCheckbox:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, -44)

local spellBookFilterCheckbox = CreateCheckbox(
	frame,
	"Level-20 spellbook filtering",
	"Hides spellbook abilities learned above level 20.",
	function(checked)
		addon.SetSpellBookFilterEnabled(checked)
	end
)
spellBookFilterCheckbox:SetPoint("TOPLEFT", talentFilterCheckbox, "BOTTOMLEFT", 0, -8)

local minimapButtonCheckbox = CreateCheckbox(
	frame,
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
end

function addon.ShowSettingsWindow()
	addon.RefreshSettingsWindow()
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
