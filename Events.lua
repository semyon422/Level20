local addonName, addon = ...
local L = addon.L

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("TRAIT_CONFIG_UPDATED")
eventFrame:RegisterEvent("PLAYER_LEVEL_UP")
eventFrame:RegisterEvent("PLAYER_LEVEL_CHANGED")
eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
eventFrame:RegisterEvent("ZONE_CHANGED")
eventFrame:RegisterEvent("ZONE_CHANGED_INDOORS")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
eventFrame:RegisterEvent("PLAYER_DIFFICULTY_CHANGED")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
eventFrame:RegisterEvent("SCENARIO_CRITERIA_UPDATE")
eventFrame:RegisterEvent("SCENARIO_UPDATE")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("ENCOUNTER_END")
eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
eventFrame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
eventFrame:RegisterEvent("PLAYER_FOCUS_CHANGED")
eventFrame:RegisterEvent("PLAYER_MONEY")
eventFrame:RegisterEvent("ENABLE_XP_GAIN")
eventFrame:RegisterEvent("DISABLE_XP_GAIN")
eventFrame:RegisterEvent("QUEST_ACCEPTED")
eventFrame:RegisterEvent("QUEST_REMOVED")
eventFrame:RegisterEvent("QUEST_TURNED_IN")
eventFrame:RegisterEvent("GOSSIP_SHOW")
eventFrame:RegisterEvent("GOSSIP_CLOSED")
eventFrame:RegisterEvent("COVENANT_CHOSEN")
eventFrame:SetScript("OnEvent", function(_, event, ...)
	if event == "PLAYER_LOGIN" then
		addon.RestoreWindowPosition()
		addon.DungeonChallenge.refresh()
		addon.RefreshXPWarning()
		addon.DungeonChallenge.refresh()
		addon.RefreshShadowlandsProtection()
		addon.InstallShadowlandsProtection()
		addon.InstallTalentFilter()
		addon.InstallPvPTalentFilter()
		addon.InstallSpellBookFilter()
		addon.InstallCharacterInfoFilter()
		print(L.LOADED_MESSAGE)
	elseif event == "ADDON_LOADED" then
		local loadedAddonName = ...
		if loadedAddonName == "Blizzard_PlayerSpells" then
			addon.InstallTalentFilter()
			addon.InstallPvPTalentFilter()
			addon.InstallSpellBookFilter()
		elseif loadedAddonName == "Blizzard_UIPanels_Game" then
			addon.InstallCharacterInfoFilter()
		elseif loadedAddonName == "Blizzard_ObjectiveTracker" then
			addon.DungeonChallenge.refresh()
		end

		addon.InstallShadowlandsProtection()
	elseif event == "TRAIT_CONFIG_UPDATED"
		or event == "PLAYER_LEVEL_UP"
		or event == "PLAYER_LEVEL_CHANGED"
		or event == "PLAYER_SPECIALIZATION_CHANGED" then
		addon.RefreshTalentsFrame()
		addon.RefreshPvPTalentFrame()
		addon.RefreshSpellBookFrame()
		addon.RefreshPlayerMarks()
		addon.RefreshCharacterInfo()
	end

	if event == "PLAYER_ENTERING_WORLD"
		or event == "ZONE_CHANGED"
		or event == "ZONE_CHANGED_INDOORS"
		or event == "ZONE_CHANGED_NEW_AREA"
		or event == "PLAYER_DIFFICULTY_CHANGED"
		or event == "GROUP_ROSTER_UPDATE"
		or event == "SCENARIO_CRITERIA_UPDATE"
		or event == "SCENARIO_UPDATE"
		or event == "PLAYER_TARGET_CHANGED"
		or event == "UPDATE_MOUSEOVER_UNIT"
		or event == "PLAYER_FOCUS_CHANGED"
		or event == "PLAYER_LEVEL_UP"
		or event == "PLAYER_LEVEL_CHANGED" then
		addon.DungeonChallenge.refresh()
	end

	if event == "PLAYER_REGEN_DISABLED" then
		addon.DungeonChallenge.startTimer()
	elseif event == "ENCOUNTER_END" then
		local _, _, _, _, success = ...
		if success == 1 then
			addon.DungeonChallenge.refresh()
		end
	end

	if event == "PLAYER_ENTERING_WORLD"
		or event == "PLAYER_LEVEL_UP"
		or event == "PLAYER_LEVEL_CHANGED"
		or event == "ENABLE_XP_GAIN"
		or event == "DISABLE_XP_GAIN" then
		addon.RefreshXPWarning()
	end

	if event == "PLAYER_ENTERING_WORLD"
		or event == "QUEST_ACCEPTED"
		or event == "QUEST_REMOVED"
		or event == "QUEST_TURNED_IN"
		or event == "GOSSIP_SHOW"
		or event == "GOSSIP_CLOSED"
		or event == "COVENANT_CHOSEN" then
		addon.RefreshShadowlandsProtection()
	end

	if addon.IsWindowShown() then
		addon.RefreshWindow()
	end
end)
