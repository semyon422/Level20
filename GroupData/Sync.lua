local _, addon = ...

local groupData = addon.GroupData

local function GetGroupDistribution()
	if IsInRaid(LE_PARTY_CATEGORY_INSTANCE) then
		return "INSTANCE_CHAT"
	end

	if IsInRaid() then
		return "RAID"
	end

	if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
		return "INSTANCE_CHAT"
	end

	if IsInGroup() then
		return "PARTY"
	end
end

function groupData.RefreshLocalPlayerData()
	local message, payload = groupData.BuildLocalMessage()
	groupData.StorePlayerData(GetUnitName("player", true), payload)
	groupData.RefreshWindow()
	return message
end

function groupData.Broadcast(force, message)
	if not groupData.state.initialized then
		return
	end

	local distribution = GetGroupDistribution()
	if not distribution then
		return
	end

	message = message or groupData.RefreshLocalPlayerData()
	if not force and message == groupData.state.lastBroadcastMessage then
		return
	end

	groupData.state.lastBroadcastMessage = message
	C_ChatInfo.SendAddonMessage(groupData.GetCommPrefix(), message, distribution)
end

function groupData.RefreshAndBroadcast(force)
	local message = groupData.RefreshLocalPlayerData()
	if not force and message == groupData.state.lastLocalMessage then
		return
	end

	groupData.state.lastLocalMessage = message
	groupData.Broadcast(force, message)
end

function groupData.HandleMessage(prefix, message, _, sender)
	if prefix ~= groupData.GetCommPrefix() or not sender or groupData.IsOwnSender(sender) then
		return
	end

	local payload = groupData.ParseMessage(message)
	if not payload then
		return
	end

	groupData.StorePlayerData(sender, payload)
	groupData.RefreshWindow()

	if addon.DungeonChallenge and addon.DungeonChallenge.ApplyEnemyForcesSyncPayload and addon.DungeonChallenge.ApplyEnemyForcesSyncPayload(payload) then
		addon.DungeonChallenge.refresh()
	end
end

function groupData.Initialize()
	if groupData.state.initialized then
		return
	end

	if not C_ChatInfo or not C_ChatInfo.RegisterAddonMessagePrefix or not C_ChatInfo.SendAddonMessage then
		return
	end

	C_ChatInfo.RegisterAddonMessagePrefix(groupData.GetCommPrefix())
	groupData.LoadPlayersFromDB()
	groupData.state.initialized = true
	groupData.state.syncTicker = C_Timer.NewTicker(1, function()
		groupData.RefreshAndBroadcast()
	end)
	groupData.RefreshWindow()
end
