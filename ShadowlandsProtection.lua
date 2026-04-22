local addonName, addon = ...
local L = addon.L

local GOSSIP_OPTION_SKIP_SHADOWLANDS_CAMPAIGN = 131497
local gossipAPIGuardInstalled = false

local warning = CreateFrame("Frame", "Level20ShadowlandsWarning", UIParent, "BackdropTemplate")
warning:SetSize(620, 150)
warning:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
warning:SetFrameStrata("DIALOG")
warning:SetFrameLevel(200)
warning:SetBackdrop({
	bgFile = "Interface\\Buttons\\WHITE8x8",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	edgeSize = 12,
	insets = { left = 4, right = 4, top = 4, bottom = 4 },
})
warning:SetBackdropColor(0.28, 0.05, 0.02, 0.96)
warning:SetBackdropBorderColor(1.0, 0.82, 0.0, 1)
warning:Hide()

warning.title = warning:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
warning.title:SetPoint("TOP", warning, "TOP", 0, -18)
warning.title:SetTextColor(1.0, 0.82, 0.0)
warning.title:SetText(L.SL_WARNING_TITLE)

warning.text = warning:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
warning.text:SetPoint("TOPLEFT", warning, "TOPLEFT", 22, -48)
warning.text:SetPoint("TOPRIGHT", warning, "TOPRIGHT", -22, -48)
warning.text:SetJustifyH("CENTER")
warning.text:SetSpacing(2)
warning.text:SetTextColor(1.0, 0.92, 0.75)

local actionButton = CreateFrame("Button", nil, warning, "UIPanelButtonTemplate")
actionButton:SetSize(190, 26)
actionButton:SetPoint("BOTTOM", warning, "BOTTOM", 0, 18)

local function IsQuestActive(questID)
	return C_QuestLog.GetLogIndexForQuestID(questID) ~= nil
end

local function ShouldBlockShadowlandsSkipOptionID(gossipOptionID)
	return gossipOptionID == GOSSIP_OPTION_SKIP_SHADOWLANDS_CAMPAIGN
end

function addon.IsShadowlandsProtectionEnabled()
	return Level20DB.shadowlandsProtection
end

local function GetGossipOptionInfoByOrderIndex(orderIndex)
	if not C_GossipInfo or not C_GossipInfo.GetOptions then
		return nil
	end

	for _, optionInfo in ipairs(C_GossipInfo.GetOptions() or {}) do
		if optionInfo.orderIndex == orderIndex then
			return optionInfo
		end
	end

	return nil
end

local function AbandonQuest(questID)
	if not IsQuestActive(questID) then
		return false
	end

	if C_QuestLog.CanAbandonQuest and not C_QuestLog.CanAbandonQuest(questID) then
		return false
	end

	C_QuestLog.SetSelectedQuest(questID)
	C_QuestLog.SetAbandonQuest()
	C_QuestLog.AbandonQuest()
	return true
end

function addon.InstallShadowlandsProtection()
	if not gossipAPIGuardInstalled and C_GossipInfo and C_GossipInfo.SelectOption and C_GossipInfo.SelectOptionByIndex then
		local originalSelectOption = C_GossipInfo.SelectOption
		local originalSelectOptionByIndex = C_GossipInfo.SelectOptionByIndex

		C_GossipInfo.SelectOption = function(optionID, text, confirmed)
			if addon.IsShadowlandsProtectionEnabled() and ShouldBlockShadowlandsSkipOptionID(optionID) then
				print(L.SL_SKIP_BLOCKED_MESSAGE)
				return
			end

			return originalSelectOption(optionID, text, confirmed)
		end

		C_GossipInfo.SelectOptionByIndex = function(orderIndex, text, confirmed)
			local optionInfo = GetGossipOptionInfoByOrderIndex(orderIndex)
			if addon.IsShadowlandsProtectionEnabled() and optionInfo and ShouldBlockShadowlandsSkipOptionID(optionInfo.gossipOptionID) then
				print(L.SL_SKIP_BLOCKED_MESSAGE)
				return
			end

			return originalSelectOptionByIndex(orderIndex, text, confirmed)
		end

		gossipAPIGuardInstalled = true
	end
end

local function ShowCovenantWarning()
	warning.title:SetText(L.SL_WARNING_TITLE)
	warning.text:SetText(L.SL_COVENANT_WARNING)
	actionButton:SetText(L.SL_CANCEL_COVENANT_QUEST)
	actionButton:SetScript("OnClick", function()
		if AbandonQuest(addon.SHADOWLANDS_QUEST_CHOOSING_YOUR_PURPOSE_CAMPAIGN) then
			print(L.SL_COVENANT_QUEST_CANCELLED)
		else
			print(L.SL_COVENANT_QUEST_CANCEL_FAILED)
		end

		addon.RefreshShadowlandsProtection()
	end)
	warning:Show()
end

function addon.RefreshShadowlandsProtection()
	if addon.IsShadowlandsProtectionEnabled() and (addon.IsShadowlandsCovenantChoiceActive() or Level20DB.debugMode) then
		ShowCovenantWarning()
	else
		warning:Hide()
	end
end
