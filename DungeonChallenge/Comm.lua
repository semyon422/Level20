local _, addon = ...

local challenge = addon.DungeonChallenge

local COMM_PREFIX = "L20DCH"
local COMMAND_START_RUN = "START"

local commState = {
	initialized = false,
}

local function CanUseAddonMessages()
	return C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix and C_ChatInfo.SendAddonMessage
end

function challenge.InitializeGuildStartComm()
	if commState.initialized then
		return
	end

	if not CanUseAddonMessages() then
		return
	end

	C_ChatInfo.RegisterAddonMessagePrefix(COMM_PREFIX)
	commState.initialized = true
end

function challenge.SetGuildStartEnabled(enabled)
	Level20DB.allowGuildChallengeStart = enabled and true or false
end

function challenge.IsGuildStartEnabled()
	return Level20DB.allowGuildChallengeStart and true or false
end

function challenge.SendGuildStartCommand()
	if not commState.initialized or not CanUseAddonMessages() or not IsInGuild() then
		return false
	end

	C_ChatInfo.SendAddonMessage(COMM_PREFIX, COMMAND_START_RUN, "GUILD")
	challenge.startTimer()
	return true
end

function challenge.HandleGuildStartMessage(prefix, message, channel)
	if prefix ~= COMM_PREFIX or message ~= COMMAND_START_RUN or channel ~= "GUILD" then
		return false
	end

	if not challenge.IsGuildStartEnabled() then
		return false
	end

	challenge.startTimer()
	return true
end
