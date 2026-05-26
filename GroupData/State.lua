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
		addonVersion = payload.addon,
		warModeEnabled = payload.wm,
		lorewalkingActive = payload.lw,
		oozeEquipped = payload.ooze,
		dragonlingEquipped = payload.dragon,
		uttsCount = payload.utts,
		amberOwned = payload.amber,
		classBattleResCooldownEndTime = payload.brce,
		itemBattleResCooldownEndTime = payload.brie,
	}
end
