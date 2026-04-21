local addonName, addon = ...

local characterInfoHookInstalled = false

local function ShouldHideTrialLevelError()
	if not GameLimitedMode_IsActive or not GameLimitedMode_IsActive() then
		return false
	end

	if not GetRestrictedAccountData then
		return false
	end

	return GetRestrictedAccountData() == addon.LEVEL_CAP
end

local function HideTrialLevelError()
	if not ShouldHideTrialLevelError() then
		return
	end

	if CharacterTrialLevelErrorText then
		CharacterTrialLevelErrorText:Hide()
	end

	if CharacterLevelText and PaperDollFrame then
		CharacterLevelText:SetPoint("CENTER", PaperDollFrame, "TOP", 0, -42)
	end
end

function addon.RefreshCharacterInfo()
	HideTrialLevelError()
end

function addon.InstallCharacterInfoFilter()
	if characterInfoHookInstalled then
		return
	end

	if not PaperDollFrame_SetLevel then
		return
	end

	hooksecurefunc("PaperDollFrame_SetLevel", HideTrialLevelError)

	characterInfoHookInstalled = true
	addon.RefreshCharacterInfo()
end
