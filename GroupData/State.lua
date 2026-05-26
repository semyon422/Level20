local _, addon = ...

local groupData = addon.GroupData

groupData.state = groupData.state or {
	initialized = false,
	players = {},
	lastBroadcastMessage = nil,
	lastLocalMessage = nil,
	syncTicker = nil,
}

function groupData.GetPlayerKey(name)
	if not name or name == "" then
		return nil
	end

	return Ambiguate(name, "none")
end

function groupData.IsOwnSender(sender)
	local playerName = GetUnitName("player", true)
	return playerName and sender and Ambiguate(sender, "none") == Ambiguate(playerName, "none")
end

function groupData.StorePlayerData(fullName, payload)
	local playerKey = groupData.GetPlayerKey(fullName)
	if not playerKey or type(payload) ~= "table" then
		return
	end

	groupData.state.players[playerKey] = {
		name = playerKey,
		displayName = Ambiguate(fullName, "short"),
		hasSync = true,
		oozeEquipped = payload.oozeEquipped and true or false,
		uttsCount = tonumber(payload.uttsCount) or 0,
		dragonlingEquipped = payload.dragonlingEquipped and true or false,
		addonVersion = payload.addonVersion ~= "" and payload.addonVersion or "v?",
		chromieTimeID = tonumber(payload.chromieTimeID) or -1,
		warModeEnabled = payload.warModeEnabled and true or false,
	}
end
