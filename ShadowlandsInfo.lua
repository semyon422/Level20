local addonName, addon = ...
local L = addon.L

addon.SHADOWLANDS_QUEST_THREADS_OF_FATE_SELECTED = 62713
addon.SHADOWLANDS_QUEST_CHOOSING_YOUR_PURPOSE_CAMPAIGN = 57878

local function IsQuestCompleted(questID)
	return C_QuestLog.IsQuestFlaggedCompleted(questID)
end

local function IsQuestActive(questID)
	return C_QuestLog.GetLogIndexForQuestID(questID) ~= nil
end

function addon.IsShadowlandsCampaignSkipped()
	return IsQuestCompleted(addon.SHADOWLANDS_QUEST_THREADS_OF_FATE_SELECTED)
end

function addon.IsShadowlandsCovenantChoiceActive()
	return IsQuestActive(addon.SHADOWLANDS_QUEST_CHOOSING_YOUR_PURPOSE_CAMPAIGN)
end

function addon.GetShadowlandsStateText()
	local covenantID = C_Covenants and C_Covenants.GetActiveCovenantID and C_Covenants.GetActiveCovenantID() or 0

	if addon.IsShadowlandsCampaignSkipped() then
		if covenantID > 0 then
			return L.SL_STATE_THREADS_COVENANT
		end

		if addon.IsShadowlandsCovenantChoiceActive() then
			return L.SL_STATE_THREADS_CHOOSING
		end

		return L.SL_STATE_THREADS
	end

	if covenantID > 0 then
		return L.SL_STATE_COVENANT
	end

	if addon.IsShadowlandsCovenantChoiceActive() then
		return L.SL_STATE_COVENANT_CHOICE
	end

	if IsQuestCompleted(addon.SHADOWLANDS_QUEST_CHOOSING_YOUR_PURPOSE_CAMPAIGN) then
		return L.SL_STATE_CAMPAIGN_COMPLETE
	end

	return L.SL_STATE_CAMPAIGN
end
