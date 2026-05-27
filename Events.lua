local addonName, addon = ...
local L = addon.L

local eventFrame = CreateFrame("Frame")
local trackedGroupDeathState = {}
local trackedEnemyNameplates = {}

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

local function IsTrackedEnemyUnit(unit)
	if not unit then
		return false
	end

	if C_NamePlate and C_NamePlate.GetNamePlateForUnit then
		local ok, nameplate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
		if not ok or not nameplate then
			return false
		end
	end

	return UnitExists(unit) and UnitCanAttack("player", unit)
end

local function GetTooltipEnemyUnitToken()
	for _, unit in ipairs({ "mouseover", "target" }) do
		if UnitExists(unit) and UnitCanAttack("player", unit) then
			return unit
		end
	end

	return nil
end

local function AddEnemyTooltipValues(tooltip)
	if not tooltip or not Level20DB.debugUnitTooltipValues then
		return
	end

	local unit = GetTooltipEnemyUnitToken()
	if not unit then
		return
	end

	tooltip:AddLine(" ")
	tooltip:AddLine("Level20 Safe Unit Values", 0.25, 1, 0.6)
	tooltip:AddLine(("Classification: %s"):format(tostring(UnitClassification(unit) or "nil")), 1, 1, 1)
	tooltip:AddLine(("Creature Family: %s"):format(tostring(UnitCreatureFamily(unit) or "nil")), 1, 1, 1)
	tooltip:AddLine(("Level: %s"):format(tostring(UnitLevel(unit) or "nil")), 1, 1, 1)
	if UnitEffectiveLevel then
		tooltip:AddLine(("Effective Level: %s"):format(tostring(UnitEffectiveLevel(unit) or "nil")), 1, 1, 1)
	end
	tooltip:AddLine(("Is Trivial: %s"):format(tostring(UnitIsTrivial(unit) and true or false)), 1, 1, 1)
	tooltip:AddLine(("Can Attack: %s"):format(tostring(UnitCanAttack("player", unit) and true or false)), 1, 1, 1)
	if UnitSelectionType then
		tooltip:AddLine(("Selection Type: %s"):format(tostring(UnitSelectionType(unit, true) or "nil")), 1, 1, 1)
	end
	tooltip:Show()
end

local function HookEnemyTooltipValues()
	if addon.enemyTooltipValuesHooked or not TooltipDataProcessor or not TooltipDataProcessor.AddTooltipPostCall or not Enum or not Enum.TooltipDataType or not Enum.TooltipDataType.Unit then
		return
	end

	TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip)
		AddEnemyTooltipValues(tooltip)
	end)

	addon.enemyTooltipValuesHooked = true
end

local function FindTrackedEnemyNameplateIndex(unit)
	for index, entry in ipairs(trackedEnemyNameplates) do
		if entry and entry.unit and UnitIsUnit(entry.unit, unit) then
			return index, entry
		end
	end

	return nil, nil
end

local function ResetTrackedEnemyNameplates()
	table.wipe(trackedEnemyNameplates)
end

local function UpdateTrackedEnemyNameplate(unit, sourceEvent)
	if not IsTrackedEnemyUnit(unit) then
		return
	end

	local _, entry = FindTrackedEnemyNameplateIndex(unit)
	if not entry then
		return
	end

	if UnitIsDead(unit) and not entry.deathReported then
		entry.deathReported = true
		entry.dead = true
		local classification = UnitClassification(unit) or "normal"
		local amount = addon.DungeonChallenge.GetEnemyForcesWeight(classification)
		local recorded = addon.DungeonChallenge.ShouldUse() and addon.DungeonChallenge.RecordEnemyForcesProgress(amount)
		if recorded then
			addon.DungeonChallenge.refresh()
		end
	end
end

local function AddTrackedEnemyNameplate(unit)
	if not IsTrackedEnemyUnit(unit) then
		return
	end

	local _, existingEntry = FindTrackedEnemyNameplateIndex(unit)
	if existingEntry then
		existingEntry.unit = unit
		existingEntry.dead = UnitIsDead(unit) and true or false
		return
	end

	table.insert(trackedEnemyNameplates, {
		unit = unit,
		dead = UnitIsDead(unit) and true or false,
		deathReported = false,
	})
end

local function RemoveTrackedEnemyNameplate(unit)
	if not unit then
		return
	end

	local index = FindTrackedEnemyNameplateIndex(unit)
	if index then
		table.remove(trackedEnemyNameplates, index)
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
eventFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
eventFrame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
eventFrame:RegisterEvent("UNIT_HEALTH")
eventFrame:SetScript("OnEvent", function(_, event, ...)
	if event == "PLAYER_LOGIN" then
		HookEnemyTooltipValues()
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
		ResetTrackedEnemyNameplates()
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
	elseif event == "NAME_PLATE_UNIT_ADDED" then
		local unit = ...
		AddTrackedEnemyNameplate(unit)
	elseif event == "NAME_PLATE_UNIT_REMOVED" then
		local unit = ...
		RemoveTrackedEnemyNameplate(unit)
	elseif event == "UNIT_HEALTH" then
		local unit = ...
		UpdateTrackedEnemyNameplate(unit, event)
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
