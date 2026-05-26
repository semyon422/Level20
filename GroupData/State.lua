local _, addon = ...

local groupData = addon.GroupData

local PERSISTED_PLAYER_FIELDS = {
	"name",
	"displayName",
	"hasSync",
	"addonVersion",
	"warModeEnabled",
	"lorewalkingActive",
	"oozeEquipped",
	"dragonlingEquipped",
	"uttsCount",
	"amberOwned",
	"classBattleResCooldownEndTime",
	"itemBattleResCooldownEndTime",
}

groupData.state = groupData.state or {
	initialized = false,
	players = {},
	lastBroadcastMessage = nil,
	lastLocalMessage = nil,
	syncTicker = nil,
}

local function CopyPersistedPlayerData(playerData)
	if type(playerData) ~= "table" then
		return nil
	end

	local copy = {}
	for _, field in ipairs(PERSISTED_PLAYER_FIELDS) do
		copy[field] = playerData[field]
	end

	if not copy.name or copy.name == "" then
		return nil
	end

	return copy
end

function groupData.SavePlayersToDB()
	if type(Level20DB) ~= "table" then
		return
	end

	local persistedPlayers = {}
	for playerKey, playerData in pairs(groupData.state.players) do
		local persistedData = CopyPersistedPlayerData(playerData)
		if persistedData then
			persistedPlayers[playerKey] = persistedData
		end
	end

	Level20DB.groupDataPlayers = persistedPlayers
end

function groupData.LoadPlayersFromDB()
	if type(Level20DB) ~= "table" or type(Level20DB.groupDataPlayers) ~= "table" then
		return
	end

	local restoredPlayers = {}
	for playerKey, playerData in pairs(Level20DB.groupDataPlayers) do
		local restoredData = CopyPersistedPlayerData(playerData)
		if restoredData then
			restoredPlayers[playerKey] = restoredData
		end
	end

	groupData.state.players = restoredPlayers
end

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

	groupData.SavePlayersToDB()
end
