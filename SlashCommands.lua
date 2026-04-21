local addonName, addon = ...

local function HandleSlashCommand(message)
	message = string.lower(message or "")

	if message == "talents on" then
		addon.SetTalentFilterEnabled(true)
	elseif message == "talents off" then
		addon.SetTalentFilterEnabled(false)
	elseif message == "talents" then
		local stateText = Level20DB.hideHighLevelTalents and "enabled" or "disabled"
		print("|cff00ff98Level20|r level-20 talent filtering is " .. stateText .. ". Use /l20 talents on or /l20 talents off.")
	else
		addon.ToggleWindow()
	end
end

SLASH_LEVEL201 = "/level20"
SLASH_LEVEL202 = "/l20"
SlashCmdList["LEVEL20"] = HandleSlashCommand
