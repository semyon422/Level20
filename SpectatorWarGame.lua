local addonName, addon = ...
local L = addon.L

local function Trim(text)
	return strtrim(text or "")
end

local function StripBattleTagSuffix(text)
	text = Trim(text)
	return (text:gsub("#%d+$", ""))
end

local function GetSpectatorTargets(leaderA, leaderB)
	leaderA = StripBattleTagSuffix(leaderA)
	leaderB = StripBattleTagSuffix(leaderB)

	if leaderA == "" or leaderB == "" then
		return nil, nil
	end

	return leaderA, leaderB
end

local function GetBNetAccountID(target)
	if BNet_GetBNetIDAccountFromCharacterName then
		local accountID = BNet_GetBNetIDAccountFromCharacterName(target)
		if accountID then
			return accountID
		end
	end

	if BNet_GetBNetIDAccount then
		return BNet_GetBNetIDAccount(target)
	end

	return nil
end

local function RunSpectatorCommand(leaderA, leaderB, arenaID)
	StartSpectatorWarGame(
		GetBNetAccountID(leaderA) or leaderA,
		GetBNetAccountID(leaderB) or leaderB,
		2,
		arenaID,
		false
	)
end

local function EnsureWarGameListLoaded()
	if C_AddOns and C_AddOns.LoadAddOn then
		pcall(C_AddOns.LoadAddOn, "Blizzard_PVPUI")
	end
end

local function IsArenaPvpType(pvpType)
	if INSTANCE_TYPE_ARENA and pvpType == INSTANCE_TYPE_ARENA then
		return true
	end

	local text = pvpType and tostring(pvpType):lower() or ""
	return text == "arena" or text == "pvp_arena"
end

local function GetWarGameScanLimit()
	if GetNumWarGameTypes then
		local ok, numWarGames = pcall(GetNumWarGameTypes)
		if ok and numWarGames and numWarGames > 0 then
			return numWarGames
		end
	end

	return 300
end

local battlegroundNamesByID

local function GetBattlegroundNamesByID()
	if battlegroundNamesByID then
		return battlegroundNamesByID
	end

	battlegroundNamesByID = {}
	for index = 1, 300 do
		if C_PvP and C_PvP.GetBattlegroundInfo then
			local ok, info = pcall(C_PvP.GetBattlegroundInfo, index)
			if ok and info and info.battlegroundID and info.name and info.name ~= "" then
				battlegroundNamesByID[info.battlegroundID] = info.name
			end
		end

		if GetBattlegroundInfo then
			local ok, localizedName, canEnter, isHoliday, isRandom, battlegroundID = pcall(GetBattlegroundInfo, index)
			if ok and battlegroundID and localizedName and localizedName ~= "" then
				battlegroundNamesByID[battlegroundID] = localizedName
			end
		end
	end

	return battlegroundNamesByID
end

local function GetArenaOptionName(name, battlegroundID)
	if battlegroundID then
		local battlegroundName = GetBattlegroundNamesByID()[battlegroundID]
		if battlegroundName and battlegroundName ~= "" then
			return battlegroundName
		end
	end

	return name
end

local function NormalizeArenaName(name)
	if not name then
		return nil
	end

	name = name:gsub("[%c%s]+", " ")
	return strtrim(name)
end

local function IsTruncatedName(name)
	return name and (name:find("%.%.%.") or name:find("…"))
end

local function AddArenaEntry(entries, nameCounts, name, battlegroundID, isArena)
	name = NormalizeArenaName(GetArenaOptionName(name, battlegroundID))
	if isArena and battlegroundID and name and name ~= "" and name ~= "header" and not IsTruncatedName(name) then
		nameCounts[name] = (nameCounts[name] or 0) + 1
		table.insert(entries, {
			id = battlegroundID,
			name = name,
		})
	end
end

local function GetFriendPresenceText(accountInfo)
	local gameAccountInfo = accountInfo and accountInfo.gameAccountInfo
	if gameAccountInfo and gameAccountInfo.isOnline and gameAccountInfo.clientProgram == BNET_CLIENT_WOW then
		return gameAccountInfo.characterName or gameAccountInfo.richPresence or nil
	end

	if gameAccountInfo and gameAccountInfo.isOnline then
		return gameAccountInfo.richPresence
	end

	return nil
end

local function SortFriendOptions(left, right)
	if left.isOnline ~= right.isOnline then
		return left.isOnline
	end

	return left.label < right.label
end

function addon.GetSpectatorWarGameArenaOptions()
	local entries = {}
	local nameCounts = {}

	EnsureWarGameListLoaded()

	if not GetWarGameTypeInfo then
		return entries
	end

	if UpdateWarGamesList then
		pcall(UpdateWarGamesList)
	end

	local missingCount = 0
	local currentHeaderIsArena = false
	for index = 1, GetWarGameScanLimit() do
		local infoOk, name, pvpType, collapsed, id, minPlayers, maxPlayers = pcall(GetWarGameTypeInfo, index)
		if infoOk and name then
			missingCount = 0
			if name == "header" then
				currentHeaderIsArena = IsArenaPvpType(pvpType)
			else
				AddArenaEntry(entries, nameCounts, name, id, IsArenaPvpType(pvpType) or currentHeaderIsArena)
			end
		else
			missingCount = missingCount + 1
			if missingCount >= 20 then
				break
			end
		end
	end

	local options = {}
	for _, entry in ipairs(entries) do
		local label = entry.name
		if nameCounts[entry.name] and nameCounts[entry.name] > 1 and entry.id then
			label = ("%s (%s)"):format(entry.name, tostring(entry.id))
		end

		table.insert(options, {
			value = entry.id,
			label = label,
			name = entry.name,
			id = entry.id,
		})
	end

	return options
end

function addon.GetSpectatorWarGameBNetFriendOptions()
	local options = {}
	if not C_BattleNet or not C_BattleNet.GetFriendAccountInfo then
		return options
	end

	local totalFriends = BNGetNumFriends and BNGetNumFriends() or 0

	for index = 1, totalFriends do
		local accountInfo = C_BattleNet.GetFriendAccountInfo(index)
		local gameAccountInfo = accountInfo and accountInfo.gameAccountInfo
		if accountInfo
			and gameAccountInfo
			and gameAccountInfo.isOnline
			and gameAccountInfo.clientProgram == BNET_CLIENT_WOW
			and accountInfo.accountName
			and accountInfo.accountName ~= ""
		then
			local presenceText = GetFriendPresenceText(accountInfo)
			local label = accountInfo.accountName
			if presenceText and presenceText ~= "" then
				label = ("%s - %s"):format(label, presenceText)
			end

			table.insert(options, {
				value = accountInfo.accountName,
				label = label,
				isOnline = gameAccountInfo.isOnline and true or false,
			})
		end
	end

	table.sort(options, SortFriendOptions)
	return options
end

function addon.GetSpectatorWarGameDefaultArenaID()
	local options = addon.GetSpectatorWarGameArenaOptions()
	return options[1] and options[1].value or nil
end

function addon.OpenSpectatorWarGameCommand(leaderA, leaderB, arenaID)
	leaderA, leaderB = GetSpectatorTargets(leaderA, leaderB)
	arenaID = arenaID or addon.GetSpectatorWarGameDefaultArenaID()
	if not leaderA or not leaderB or not arenaID or arenaID == "" then
		print(L.SPECTATOR_WARGAME_SELECT_REQUIRED)
		return
	end

	RunSpectatorCommand(leaderA, leaderB, arenaID)
	print(L.SPECTATOR_WARGAME_COMMAND_SENT)
end
