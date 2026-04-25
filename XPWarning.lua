local addonName, addon = ...
local L = addon.L

local warning = CreateFrame("Frame", "Level20XPWarning", UIParent, "BackdropTemplate")
warning:SetSize(560, 44)
warning:SetPoint("TOP", UIParent, "TOP", 0, -96)
warning:SetFrameStrata("HIGH")
warning:SetFrameLevel(100)
warning:SetBackdrop({
	bgFile = "Interface\\Buttons\\WHITE8x8",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	edgeSize = 10,
	insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
warning:SetBackdropColor(0.28, 0.05, 0.02, 0.92)
warning:SetBackdropBorderColor(1.0, 0.82, 0.0, 1)
warning:Hide()

warning.text = warning:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
warning.text:SetPoint("LEFT", warning, "LEFT", 16, 0)
warning.text:SetPoint("RIGHT", warning, "RIGHT", -16, 0)
warning.text:SetJustifyH("CENTER")
warning.text:SetText(L.XP_WARNING)
warning.text:SetTextColor(1.0, 0.82, 0.0)
warning.text:SetShadowColor(0, 0, 0, 1)
warning.text:SetShadowOffset(1, -1)

local function ShouldShowXPWarning()
	local levelCap = GetRestrictedAccountData()

	return Level20DB.debugXPWarning
		or (UnitLevel("player") == addon.LEVEL_CAP
		and levelCap ~= addon.LEVEL_CAP
		and not IsXPUserDisabled())
end

function addon.RefreshXPWarning()
	warning:SetShown(ShouldShowXPWarning())
end
