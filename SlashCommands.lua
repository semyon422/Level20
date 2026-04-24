local addonName, addon = ...

local function ReportBannerError(err)
	err = tostring(err or "unknown error")
	print(addon.L.DUNGEON_CHALLENGE_COMPLETION_ERROR:format(err))
	if debugstack then
		print(debugstack(2, 8, 8))
	end
end

local function HandleDungeonCommand(message)
	message = message and strtrim(message) or ""
	if message == "" then
		return false
	end

	local command = message:match("^(%S+)")
	if not command then
		return false
	end

	command = strlower(command)
	if command == "mplus" or command == "m+" then
		if addon.DungeonChallenge and addon.DungeonChallenge.ShowCompletionBanner then
			local ok, err = addon.DungeonChallenge.ShowCompletionBanner()
			if ok then
				print(addon.L.DUNGEON_CHALLENGE_COMPLETION_COMMAND)
			else
				ReportBannerError(err)
			end
		end
		return true
	end

	return false
end

SLASH_LEVEL201 = "/level20"
SLASH_LEVEL202 = "/l20"
SlashCmdList["LEVEL20"] = function(message)
	if HandleDungeonCommand(message) then
		return
	end

	addon.ToggleWindow()
end
