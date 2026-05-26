local addonName, addon = ...
local L = addon.L

local eventFrame = CreateFrame("Frame")
local trackedGroupDeathState = {}

local function RefreshAndBroadcastGroupData(force)
	addon.GroupData.RefreshAndBroadcast(force)
end

local function DelayedRefreshAndBroadcastGroupData(force, delaySeconds)
	C_Timer.After(delaySeconds or 0, function()
		RefreshAndBroadcastGroupData(force)
	end)
end

local function IsTrackedGroupUnit(unit)
	return unit ~= nil
		and (
			unit == "player"
			or unit:match("^party%d+$")
			or unit:match("^raid%d+$")
		)
end

local function RefreshTrackedGroupDeathState()
	table.wipe(trackedGroupDeathState)
	trackedGroupDeathState.player = UnitExists("player") and UnitIsDeadOrGhost("player") and true or false

	if IsInRaid() then
		for index = 1, GetNumGroupMembers() do
			local unit = "raid" .. index
			if UnitExists(unit) and UnitIsPlayer(unit) then
				trackedGroupDeathState[unit] = UnitIsDeadOrGhost(unit) and true or false
			end
		end
	elseif IsInGroup() then
		for index = 1, GetNumSubgroupMembers() do
			local unit = "party" .. index
			if UnitExists(unit) and UnitIsPlayer(unit) then
				trackedGroupDeathState[unit] = UnitIsDeadOrGhost(unit) and true or false
			end
		end
	end
end

local function CheckGroupDeathState(unit, eventName)
	if not addon.DungeonChallenge.ShouldUse() then
		return
	end

	if not IsTrackedGroupUnit(unit) or not UnitExists(unit) or not UnitIsPlayer(unit) then
		return
	end

	local wasDead = trackedGroupDeathState[unit] and true or false
	local isDead = UnitIsDeadOrGhost(unit) and true or false
	trackedGroupDeathState[unit] = isDead

	if isDead and not wasDead then
		addon.DungeonChallenge.RecordDeath()
		addon.DungeonChallenge.RefreshDeathCountDisplay()
	end
end

local function CheckGroupCombatState(unit)
	if not addon.DungeonChallenge.ShouldUse() then
		return
	end

	if not IsTrackedGroupUnit(unit) or not UnitExists(unit) or not UnitIsPlayer(unit) then
		return
	end

	if UnitAffectingCombat(unit) then
		addon.DungeonChallenge.startTimer()
	end
end

eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("TRAIT_CONFIG_UPDATED")
eventFrame:RegisterEvent("PLAYER_LEVEL_UP")
eventFrame:RegisterEvent("PLAYER_LEVEL_CHANGED")
eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
eventFrame:RegisterEvent("ZONE_CHANGED")
eventFrame:RegisterEvent("ZONE_CHANGED_INDOORS")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
eventFrame:RegisterEvent("PLAYER_DIFFICULTY_CHANGED")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
eventFrame:RegisterEvent("SCENARIO_CRITERIA_UPDATE")
eventFrame:RegisterEvent("SCENARIO_UPDATE")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_ALIVE")
eventFrame:RegisterEvent("ENCOUNTER_END")
eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
eventFrame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
eventFrame:RegisterEvent("PLAYER_FOCUS_CHANGED")
eventFrame:RegisterEvent("UNIT_FLAGS")
eventFrame:RegisterEvent("PLAYER_MONEY")
eventFrame:RegisterEvent("ENABLE_XP_GAIN")
eventFrame:RegisterEvent("DISABLE_XP_GAIN")
eventFrame:RegisterEvent("CHAT_MSG_ADDON")
eventFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
eventFrame:RegisterEvent("WAR_MODE_STATUS_UPDATE")
eventFrame:RegisterEvent("UNIT_PHASE")
eventFrame:RegisterEvent("QUEST_ACCEPTED")
eventFrame:RegisterEvent("QUEST_REMOVED")
eventFrame:RegisterEvent("QUEST_TURNED_IN")
eventFrame:RegisterEvent("GOSSIP_SHOW")
eventFrame:RegisterEvent("GOSSIP_CLOSED")
eventFrame:RegisterEvent("COVENANT_CHOSEN")
eventFrame:SetScript("OnEvent", function(_, event, ...)
	if event == "PLAYER_LOGIN" then
		addon.RestoreWindowPosition()
		addon.DungeonChallenge.refresh()
		addon.RefreshXPWarning()
		addon.DungeonChallenge.refresh()
		addon.InitializeVersionCheck()
		addon.BroadcastVersionCheck(true)
		addon.GroupData.Initialize()
		addon.GroupData.RefreshAndBroadcast(true)
		addon.RefreshShadowlandsProtection()
		addon.InstallShadowlandsProtection()
		addon.InstallTalentFilter()
		addon.InstallPvPTalentFilter()
		addon.InstallSpellBookFilter()
		addon.InstallCharacterInfoFilter()
		print(L.LOADED_MESSAGE)
	elseif event == "ADDON_LOADED" then
		local loadedAddonName = ...
		if loadedAddonName == "Blizzard_PlayerSpells" then
			addon.InstallTalentFilter()
			addon.InstallPvPTalentFilter()
			addon.InstallSpellBookFilter()
		elseif loadedAddonName == "Blizzard_UIPanels_Game" then
			addon.InstallCharacterInfoFilter()
		elseif loadedAddonName == "Blizzard_ObjectiveTracker" then
			addon.DungeonChallenge.refresh()
		end

		addon.InstallShadowlandsProtection()
	elseif event == "CHAT_MSG_ADDON" then
		addon.OnVersionCheckMessage(...)
		addon.GroupData.HandleMessage(...)
		addon.DungeonChallenge.RefreshBattleResDisplay()
	elseif event == "TRAIT_CONFIG_UPDATED"
		or event == "PLAYER_LEVEL_UP"
		or event == "PLAYER_LEVEL_CHANGED"
		or event == "PLAYER_SPECIALIZATION_CHANGED" then
		addon.RefreshTalentsFrame()
		addon.RefreshPvPTalentFrame()
		addon.RefreshSpellBookFrame()
		addon.RefreshPlayerMarks()
		addon.RefreshCharacterInfo()
	end

	if event == "PLAYER_ENTERING_WORLD"
		or event == "ZONE_CHANGED"
		or event == "ZONE_CHANGED_INDOORS"
		or event == "ZONE_CHANGED_NEW_AREA"
		or event == "PLAYER_DIFFICULTY_CHANGED"
		or event == "GROUP_ROSTER_UPDATE"
		or event == "SCENARIO_CRITERIA_UPDATE"
		or event == "SCENARIO_UPDATE"
		or event == "PLAYER_TARGET_CHANGED"
		or event == "UPDATE_MOUSEOVER_UNIT"
		or event == "PLAYER_FOCUS_CHANGED"
		or event == "PLAYER_LEVEL_UP"
		or event == "PLAYER_LEVEL_CHANGED" then
			addon.DungeonChallenge.refresh()
	end

	if event == "PLAYER_ENTERING_WORLD"
		or event == "GROUP_ROSTER_UPDATE" then
		RefreshTrackedGroupDeathState()
		addon.DungeonChallenge.RefreshBattleResDisplay()
	end

	if event == "GROUP_ROSTER_UPDATE" then
		addon.BroadcastVersionCheck()
		RefreshAndBroadcastGroupData(true)
	elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
		local unit, _, spellID = ...
		if addon.DungeonChallenge.RecordBattleResCast(unit, spellID) then
			if unit == "player" then
				addon.GroupData.RefreshAndBroadcast(true)
			end
			addon.DungeonChallenge.RefreshBattleResDisplay()
		end
	elseif event == "PLAYER_EQUIPMENT_CHANGED"
		or event == "BAG_UPDATE_DELAYED"
		or event == "WAR_MODE_STATUS_UPDATE" then
		if event == "WAR_MODE_STATUS_UPDATE" then
			DelayedRefreshAndBroadcastGroupData(true, 0)
			DelayedRefreshAndBroadcastGroupData(true, 1)
		else
			RefreshAndBroadcastGroupData()
		end

		if event == "PLAYER_EQUIPMENT_CHANGED" or event == "BAG_UPDATE_DELAYED" then
			addon.DungeonChallenge.RefreshBattleResDisplay()
		end
	elseif event == "UNIT_PHASE" then
		local unit = ...
		if unit == "player" then
			DelayedRefreshAndBroadcastGroupData(true, 0)
			DelayedRefreshAndBroadcastGroupData(true, 1)
		end
	end

	if event == "PLAYER_REGEN_DISABLED" then
		addon.DungeonChallenge.startTimer()
	elseif event == "UNIT_FLAGS" then
		local unit = ...
		CheckGroupCombatState(unit)
		CheckGroupDeathState(unit, event)
		if IsTrackedGroupUnit(unit) then
			addon.DungeonChallenge.RefreshBattleResDisplay()
		end
	elseif event == "ENCOUNTER_END" then
		local _, _, _, _, success = ...
		if success == 1 then
			addon.DungeonChallenge.refresh()
		end
	end

	if event == "PLAYER_ENTERING_WORLD"
		or event == "PLAYER_LEVEL_UP"
		or event == "PLAYER_LEVEL_CHANGED"
		or event == "ENABLE_XP_GAIN"
		or event == "DISABLE_XP_GAIN"
		or event == "PLAYER_ALIVE" then
		addon.RefreshXPWarning()
		if event == "PLAYER_ALIVE" then
			addon.DungeonChallenge.RefreshBattleResDisplay()
		end
	end

	if event == "PLAYER_ENTERING_WORLD" then
		RefreshAndBroadcastGroupData(true)
		DelayedRefreshAndBroadcastGroupData(true, 1)
	end

	if event == "PLAYER_ENTERING_WORLD"
		or event == "QUEST_ACCEPTED"
		or event == "QUEST_REMOVED"
		or event == "QUEST_TURNED_IN"
		or event == "GOSSIP_SHOW"
		or event == "GOSSIP_CLOSED"
		or event == "COVENANT_CHOSEN" then
		addon.RefreshShadowlandsProtection()
	end

	if addon.IsWindowShown() then
		addon.RefreshWindow()
	end
end)
