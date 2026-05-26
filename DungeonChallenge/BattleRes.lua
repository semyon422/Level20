local _, addon = ...

local challenge = addon.DungeonChallenge
local groupData = addon.GroupData
local state = challenge.state

local UTTS_ITEM_ID = 158379
local BATTLE_RES_COOLDOWN_SECONDS = 600
local CLASS_BATTLE_RES_SPELL_BY_CLASS = {
	PALADIN = 391054,
	DEATHKNIGHT = 61999,
	DRUID = 20484,
}
local ITEM_BATTLE_RES_SPELL_IDS = {
	[265116] = true, -- UTTS
}

local function IsTrackedGroupUnit(unit)
	return unit == "player"
		or (type(unit) == "string" and unit:match("^party%d+$") ~= nil)
		or (type(unit) == "string" and unit:match("^raid%d+$") ~= nil)
end

local function GetPlayerItemBattleResCount()
	return GetItemCount(UTTS_ITEM_ID, false, false) or 0
end

local function GetPlayerKeyForUnit(unit)
	if not unit or not UnitExists(unit) then
		return nil
	end

	local fullName = GetUnitName(unit, true)
	return fullName and groupData.GetPlayerKey and groupData.GetPlayerKey(fullName) or nil
end

local function GetSyncedPlayerData(unit)
	local playerKey = GetPlayerKeyForUnit(unit)
	if not playerKey or not groupData.state or not groupData.state.players then
		return nil
	end

	return groupData.state.players[playerKey]
end

local function GetBattleResCategoryForSpell(spellID)
	for _, classSpellID in pairs(CLASS_BATTLE_RES_SPELL_BY_CLASS) do
		if classSpellID == spellID then
			return "class"
		end
	end

	if ITEM_BATTLE_RES_SPELL_IDS[spellID] then
		return "item"
	end
end

local function GetBattleResCooldownStore(category)
	state.battleResCooldowns = state.battleResCooldowns or {
		class = {},
		item = {},
	}

	return state.battleResCooldowns[category]
end

local function GetObservedItemBattleResOwners()
	state.battleResObservedItemOwners = state.battleResObservedItemOwners or {}
	return state.battleResObservedItemOwners
end

local function GetRemainingCooldownSeconds(expirationTime, now)
	if not expirationTime or expirationTime <= now then
		return 0
	end

	return math.max(0, expirationTime - now)
end

local function GetLocalClassBattleResCooldownExpiration(now)
	local className = UnitClassBase("player")
	local spellID = className and CLASS_BATTLE_RES_SPELL_BY_CLASS[className]
	if not spellID then
		return nil
	end

	local cooldownInfo = C_Spell.GetSpellCooldown(spellID)
	if not cooldownInfo or not cooldownInfo.isActive then
		return nil
	end

	local startTime = cooldownInfo.startTime or 0
	local duration = cooldownInfo.duration or 0
	if startTime <= 0 or duration <= 0 then
		return nil
	end

	return startTime + duration
end

local function GetRemoteCooldownExpiration(unit, category, now)
	if not unit or UnitIsUnit(unit, "player") then
		return nil
	end

	local syncedData = GetSyncedPlayerData(unit)
	if not syncedData then
		return nil
	end

	local endTime
	if category == "class" then
		endTime = tonumber(syncedData.classBattleResCooldownEndTime) or 0
	elseif category == "item" then
		endTime = tonumber(syncedData.itemBattleResCooldownEndTime) or 0
	end

	if endTime <= 0 then
		return nil
	end

	local serverNow = GetServerTime and GetServerTime() or 0
	local remainingSeconds = endTime - serverNow
	if remainingSeconds <= 0 then
		return nil
	end

	return now + remainingSeconds
end

local function GetCooldownExpirationForUnit(unit, guid, category, now)
	if not guid then
		return nil
	end

	if UnitIsUnit(unit, "player") then
		if category == "class" then
			return GetLocalClassBattleResCooldownExpiration(now) or GetBattleResCooldownStore(category)[guid]
		end

		return GetBattleResCooldownStore(category)[guid]
	end

	return GetRemoteCooldownExpiration(unit, category, now) or GetBattleResCooldownStore(category)[guid]
end

local function PruneExpiredBattleResCooldowns(now)
	state.battleResCooldowns = state.battleResCooldowns or {
		class = {},
		item = {},
	}

	for _, cooldowns in pairs(state.battleResCooldowns) do
		for guid, expirationTime in pairs(cooldowns) do
			if not expirationTime or expirationTime <= now then
				cooldowns[guid] = nil
			end
		end
	end
end

local function GetBattleResRosterData(now)
	local roster = groupData.GetSortedPlayers and groupData.GetSortedPlayers() or {}
	local summary = {
		current = 0,
		max = 0,
		classCurrent = 0,
		classMax = 0,
		itemCurrent = 0,
		itemMax = 0,
		nextReadyAt = nil,
	}

	PruneExpiredBattleResCooldowns(now)

	for _, playerData in ipairs(roster) do
		local unit = playerData.unit
		if unit and UnitExists(unit) and UnitIsPlayer(unit) then
			local guid = UnitGUID(unit)
			local className = UnitClassBase(unit)
			local isAlive = not UnitIsDeadOrGhost(unit)
			local hasClassBattleRes = guid and className and CLASS_BATTLE_RES_SPELL_BY_CLASS[className] ~= nil
			local hasItemBattleRes = false

			if guid then
				if UnitIsUnit(unit, "player") then
					hasItemBattleRes = GetPlayerItemBattleResCount() > 0
				else
					local syncedData = GetSyncedPlayerData(unit) or playerData
					hasItemBattleRes = (tonumber(syncedData and syncedData.uttsCount) or 0) > 0
						or GetObservedItemBattleResOwners()[guid] == true
				end
			end

			if hasClassBattleRes then
				summary.classMax = summary.classMax + 1
				local expirationTime = GetCooldownExpirationForUnit(unit, guid, "class", now)
				if isAlive and (not expirationTime or expirationTime <= now) then
					summary.classCurrent = summary.classCurrent + 1
				elseif expirationTime and (not summary.nextReadyAt or expirationTime < summary.nextReadyAt) then
					summary.nextReadyAt = expirationTime
				end
			end

			if hasItemBattleRes then
				summary.itemMax = summary.itemMax + 1
				local expirationTime = GetCooldownExpirationForUnit(unit, guid, "item", now)
				if isAlive and (not expirationTime or expirationTime <= now) then
					summary.itemCurrent = summary.itemCurrent + 1
				elseif expirationTime and (not summary.nextReadyAt or expirationTime < summary.nextReadyAt) then
					summary.nextReadyAt = expirationTime
				end
			end
		end
	end

	summary.current = summary.classCurrent + summary.itemCurrent
	summary.max = summary.classMax + summary.itemMax
	return summary
end

function challenge.GetBattleResSummary()
	return GetBattleResRosterData(GetTime())
end

function challenge.RecordBattleResCast(unit, spellID)
	if not unit or not spellID or not IsTrackedGroupUnit(unit) or not UnitExists(unit) then
		return false
	end

	local category = GetBattleResCategoryForSpell(spellID)
	local guid = UnitGUID(unit)
	if not category or not guid then
		return false
	end

	if category == "item" then
		GetObservedItemBattleResOwners()[guid] = true
	end

	local cooldowns = GetBattleResCooldownStore(category)
	cooldowns[guid] = GetTime() + BATTLE_RES_COOLDOWN_SECONDS
	return true
end

function challenge.GetBattleResSyncPayload()
	local now = GetTime()
	local serverNow = GetServerTime and GetServerTime() or 0
	local playerGUID = UnitGUID("player")
	local classCooldownExpiration = GetLocalClassBattleResCooldownExpiration(now)
		or (playerGUID and GetBattleResCooldownStore("class")[playerGUID] or nil)
	local itemCooldownExpiration = playerGUID and GetBattleResCooldownStore("item")[playerGUID] or nil
	local classCooldownRemaining = GetRemainingCooldownSeconds(classCooldownExpiration, now)
	local itemCooldownRemaining = GetRemainingCooldownSeconds(itemCooldownExpiration, now)

	return {
		brce = classCooldownRemaining > 0 and (serverNow + math.floor(classCooldownRemaining)) or 0,
		brie = itemCooldownRemaining > 0 and (serverNow + math.floor(itemCooldownRemaining)) or 0,
	}
end

function challenge.UpdateBattleResFrameLayout(block)
	local battleResFrame = block and block.BattleRes
	if not battleResFrame then
		return
	end

	battleResFrame:ClearAllPoints()
	if block.DeathCount and block.DeathCount:IsShown() then
		battleResFrame:SetPoint("RIGHT", block.DeathCount, "LEFT", -4, 0)
	else
		battleResFrame:SetPoint("TOPRIGHT", block, "BOTTOMRIGHT", -24, 43)
	end
end

function challenge.UpdateBattleResFrame(block)
	local battleResFrame = block and block.BattleRes
	if not battleResFrame then
		return
	end

	local summary = challenge.GetBattleResSummary()
	block.battleResSummary = summary

	if summary.max <= 0 then
		battleResFrame:Hide()
		challenge.UpdateRaidSizeFrameLayout(block)
		return
	end

	battleResFrame.Count:SetText(summary.current)
	battleResFrame:Show()
	challenge.UpdateBattleResFrameLayout(block)
	challenge.UpdateRaidSizeFrameLayout(block)
end

function challenge.RefreshBattleResDisplay()
	if state.customTrackerModule then
		state.customTrackerModule:MarkDirty()
	end

	if not ScenarioObjectiveTracker or not ScenarioObjectiveTracker.ChallengeModeBlock then
		return state.customTrackerModule and true or false
	end

	local block = ScenarioObjectiveTracker.ChallengeModeBlock
	if block.timerID ~= challenge.constants.FAKE_TIMER_ID then
		return state.customTrackerModule and true or false
	end

	challenge.UpdateBattleResFrame(block)
	return true
end

function challenge.EnsureBattleResFrame(block)
	if not block or block.BattleRes then
		return
	end

	local battleResFrame = CreateFrame("Frame", nil, block)
	battleResFrame:SetSize(28, 16)
	battleResFrame:Hide()

	local icon = battleResFrame:CreateTexture(nil, "ARTWORK")
	icon:SetTexture(C_Spell.GetSpellTexture(20484))
	icon:SetPoint("LEFT")
	icon:SetSize(14, 14)
	battleResFrame.Icon = icon

	local count = battleResFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall2")
	count:SetPoint("LEFT", icon, "RIGHT", 0, 0)
	battleResFrame.Count = count

	battleResFrame:SetScript("OnEnter", function(self)
		local summary = block.battleResSummary or challenge.GetBattleResSummary()
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:SetText(challenge.L.DUNGEON_CHALLENGE_BATTLE_RES_TITLE:format(summary.current, summary.max), 1, 1, 1)
		GameTooltip:AddLine(challenge.L.DUNGEON_CHALLENGE_BATTLE_RES_CLASS:format(summary.classCurrent, summary.classMax), nil, nil, nil, true)
		GameTooltip:AddLine(challenge.L.DUNGEON_CHALLENGE_BATTLE_RES_ITEM:format(summary.itemCurrent, summary.itemMax), nil, nil, nil, true)
		if summary.nextReadyAt then
			GameTooltip:AddLine(challenge.L.DUNGEON_CHALLENGE_BATTLE_RES_READY:format(SecondsToTime(math.max(0, summary.nextReadyAt - GetTime()))), nil, nil, nil, true)
		end
		GameTooltip:Show()
	end)
	battleResFrame:SetScript("OnLeave", GameTooltip_Hide)

	block.BattleRes = battleResFrame
	challenge.UpdateBattleResFrameLayout(block)
end
