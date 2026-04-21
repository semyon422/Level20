local addonName, addon = ...

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
eventFrame:RegisterEvent("PLAYER_MONEY")
eventFrame:RegisterEvent("ENABLE_XP_GAIN")
eventFrame:RegisterEvent("DISABLE_XP_GAIN")
eventFrame:SetScript("OnEvent", function(_, event, ...)
	if event == "PLAYER_LOGIN" then
		addon.RestoreWindowPosition()
		addon.RefreshMinimapButton()
		addon.InstallTalentFilter()
		addon.InstallPvPTalentFilter()
		addon.InstallSpellBookFilter()
		print("|cff00ff98Level20|r loaded. Click the minimap button or type /level20 to open Level20.")
	elseif event == "ADDON_LOADED" then
		local loadedAddonName = ...
		if loadedAddonName == "Blizzard_PlayerSpells" then
			addon.InstallTalentFilter()
			addon.InstallPvPTalentFilter()
			addon.InstallSpellBookFilter()
		end
	elseif event == "TRAIT_CONFIG_UPDATED"
		or event == "PLAYER_LEVEL_UP"
		or event == "PLAYER_LEVEL_CHANGED"
		or event == "PLAYER_SPECIALIZATION_CHANGED" then
		addon.RefreshTalentsFrame()
		addon.RefreshPvPTalentFrame()
		addon.RefreshSpellBookFrame()
		addon.RefreshPlayerMarks()
	end

	if addon.IsWindowShown() then
		addon.RefreshWindow()
	end
end)
