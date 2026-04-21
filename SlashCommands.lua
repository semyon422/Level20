local addonName, addon = ...
local L = addon.L

local function HandleSlashCommand(message)
	message = string.lower(message or "")

	if message == "talents on" then
		addon.SetTalentFilterEnabled(true)
	elseif message == "talents off" then
		addon.SetTalentFilterEnabled(false)
	elseif message == "talents" then
		local stateText = Level20DB.hideHighLevelTalents and L.STATE_ENABLED or L.STATE_DISABLED
		print(string.format(L.TALENT_FILTER_SLASH_STATUS, stateText))
	else
		addon.ToggleWindow()
	end
end

SLASH_LEVEL201 = "/level20"
SLASH_LEVEL202 = "/l20"
SlashCmdList["LEVEL20"] = HandleSlashCommand
