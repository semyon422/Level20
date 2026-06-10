local addonName, addon = ...

local trialFeatures = {
	travelersLogPatched = false,
	subscriptionInterstitialPatched = false,
	expansionTrialDialogPatched = false,
}

local function IsRestrictedAccount()
	return IsTrialAccount()
		or IsVeteranTrialAccount()
		or (GetRestrictedAccountData and GetRestrictedAccountData() == addon.LEVEL_CAP)
end

local function ShouldPatchTrialOnlyFeatures()
	return IsTrialAccount() or IsVeteranTrialAccount()
end

function addon.PatchTravelersLogRestrictions()
	if trialFeatures.travelersLogPatched or not ShouldPatchTrialOnlyFeatures() then
		return
	end

	AreMonthlyActivitiesRestricted = function()
		return false
	end

	if C_PlayerInfo then
		C_PlayerInfo.IsTravelersLogAvailable = function()
			return true
		end
	end

	if EncounterJournalMonthlyActivitiesTab and MONTHLY_ACTIVITIES_TAB then
		EncounterJournalMonthlyActivitiesTab:SetText(MONTHLY_ACTIVITIES_TAB)
	end

	trialFeatures.travelersLogPatched = true
end

function addon.SuppressSubscriptionInterstitial()
	if not IsRestrictedAccount() then
		return
	end

	if SubscriptionInterstitialFrame then
		if not trialFeatures.subscriptionInterstitialPatched then
			SubscriptionInterstitialFrame:HookScript("OnShow", function(self)
				if IsRestrictedAccount() then
					C_Timer.After(0, function()
						self:Hide()
					end)
				end
			end)
			trialFeatures.subscriptionInterstitialPatched = true
		end

		SubscriptionInterstitialFrame:Hide()
		SubscriptionInterstitialFrame:UnregisterAllEvents()
	end
end

function addon.SuppressExpansionTrialDialog()
	if not IsRestrictedAccount() then
		return
	end

	if ExpansionTrialCheckPointDialog then
		if not trialFeatures.expansionTrialDialogPatched then
			ExpansionTrialCheckPointDialog:HookScript("OnShow", function(self)
				if IsRestrictedAccount() then
					C_Timer.After(0, function()
						self:Hide()
					end)
				end
			end)
			trialFeatures.expansionTrialDialogPatched = true
		end

		ExpansionTrialCheckPointDialog:Hide()
		ExpansionTrialCheckPointDialog:UnregisterAllEvents()
	end
end

function addon.SuppressTrialPopups()
	addon.SuppressSubscriptionInterstitial()
	addon.SuppressExpansionTrialDialog()
end

function addon.InitializeTrialFeatures()
	if C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Blizzard_EncounterJournal") then
		addon.PatchTravelersLogRestrictions()
	end

	addon.SuppressTrialPopups()
	C_Timer.After(0, addon.SuppressTrialPopups)
end
