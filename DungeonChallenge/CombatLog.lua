local addonName, addon = ...

local challenge = addon.DungeonChallenge
local state = challenge.state

local function CanInspectCombatLog()
	return C_ChatInfo and C_ChatInfo.IsLoggingCombat and true or false
end

local function CanInspectAdvancedCombatLog()
	return C_CVar and C_CVar.GetCVarBool and true or false
end

function challenge.CanControlCombatLog()
	return type(LoggingCombat) == "function" and CanInspectCombatLog()
end

function challenge.CanControlAdvancedCombatLog()
	return C_CVar and C_CVar.SetCVar and CanInspectAdvancedCombatLog() and true or false
end

function challenge.GetCombatLogState()
	if not CanInspectCombatLog() then
		return false, false
	end

	local ok, enabled, advanced = pcall(C_ChatInfo.IsLoggingCombat)
	if not ok then
		return false, false
	end

	return enabled and true or false, advanced and true or false
end

function challenge.IsCombatLogManagementEnabled()
	return Level20DB.manageCombatLog and true or false
end

function challenge.IsCombatLogRunActive()
	return challenge.ShouldUse()
		and challenge.IsTimerStarted()
		and not challenge.IsTimerStopped()
end

function challenge.SetCombatLogEnabled(enabled)
	if not challenge.CanControlCombatLog() then
		return false
	end

	local ok = pcall(LoggingCombat, enabled and true or false)
	if not ok then
		return false
	end

	local isEnabled = challenge.GetCombatLogState()
	return isEnabled == (enabled and true or false)
end

function challenge.IsAdvancedCombatLogEnabled()
	if not CanInspectAdvancedCombatLog() then
		return false
	end

	local ok, value = pcall(C_CVar.GetCVarBool, "advancedCombatLogging")
	if not ok then
		return false
	end

	return value and true or false
end

function challenge.SetAdvancedCombatLogEnabled(enabled)
	if not challenge.CanControlAdvancedCombatLog() then
		return false
	end

	local ok, success = pcall(C_CVar.SetCVar, "advancedCombatLogging", enabled and "1" or "0")
	if not ok or not success then
		return false
	end

	return challenge.IsAdvancedCombatLogEnabled() == (enabled and true or false)
end

function challenge.ToggleAdvancedCombatLog()
	return challenge.SetAdvancedCombatLogEnabled(not challenge.IsAdvancedCombatLogEnabled())
end

function challenge.UpdateManagedCombatLog()
	if not challenge.IsCombatLogManagementEnabled() then
		if state.combatLogManagedRunActive then
			state.combatLogManagedRunActive = false
			challenge.SetCombatLogEnabled(false)
		end

		if addon.RefreshCombatLogWarning then
			addon.RefreshCombatLogWarning()
		end

		state.combatLogManagedRunActive = false
		return false
	end

	if not challenge.IsAdvancedCombatLogEnabled() then
		challenge.SetAdvancedCombatLogEnabled(true)
	end

	if challenge.IsCombatLogRunActive() then
		state.combatLogManagedRunActive = true
		local updated = challenge.SetCombatLogEnabled(true)
		if addon.RefreshCombatLogWarning then
			addon.RefreshCombatLogWarning()
		end
		return updated
	end

	if state.combatLogManagedRunActive then
		state.combatLogManagedRunActive = false
		local updated = challenge.SetCombatLogEnabled(false)
		if addon.RefreshCombatLogWarning then
			addon.RefreshCombatLogWarning()
		end
		return updated
	end

	if addon.RefreshCombatLogWarning then
		addon.RefreshCombatLogWarning()
	end

	return false
end

function challenge.SetCombatLogManagementEnabled(enabled)
	Level20DB.manageCombatLog = enabled and true or false
	if Level20DB.manageCombatLog and not challenge.IsAdvancedCombatLogEnabled() then
		challenge.SetAdvancedCombatLogEnabled(true)
	end
	challenge.UpdateManagedCombatLog()
	if addon.RefreshCombatLogWarning then
		addon.RefreshCombatLogWarning()
	end
end

function challenge.ToggleCombatLog()
	local enabled = challenge.GetCombatLogState()
	return challenge.SetCombatLogEnabled(not enabled)
end

function challenge.GetCombatLogStatusText()
	if not challenge.CanControlCombatLog() then
		return challenge.L.UNKNOWN
	end

	local enabled = challenge.GetCombatLogState()
	if not enabled then
		return challenge.L.DUNGEON_CHALLENGE_COMBAT_LOG_DISABLED
	end

	return challenge.L.DUNGEON_CHALLENGE_COMBAT_LOG_ENABLED
end

function challenge.GetAdvancedCombatLogStatusText()
	if not CanInspectAdvancedCombatLog() then
		return challenge.L.UNKNOWN
	end

	return challenge.IsAdvancedCombatLogEnabled() and challenge.L.STATE_ENABLED or challenge.L.STATE_DISABLED
end

function challenge.GetAdvancedCombatLogToggleLabel()
	return challenge.IsAdvancedCombatLogEnabled()
		and challenge.L.DUNGEON_CHALLENGE_ADVANCED_COMBAT_LOG_STOP
		or challenge.L.DUNGEON_CHALLENGE_ADVANCED_COMBAT_LOG_START
end

function challenge.GetCombatLogToggleLabel()
	local enabled = challenge.GetCombatLogState()
	return enabled and challenge.L.DUNGEON_CHALLENGE_COMBAT_LOG_STOP or challenge.L.DUNGEON_CHALLENGE_COMBAT_LOG_START
end

function challenge.ShouldShowCombatLogWarning()
	if not challenge.IsCombatLogManagementEnabled() then
		return false
	end

	local enabled, advanced = challenge.GetCombatLogState()
	return challenge.IsCombatLogRunActive() and not enabled
		or not advanced
end

function challenge.GetCombatLogWarningText()
	local enabled, advanced = challenge.GetCombatLogState()
	if challenge.IsCombatLogRunActive() and not enabled then
		return challenge.L.DUNGEON_CHALLENGE_COMBAT_LOG_WARNING_DISABLED
	end

	if not advanced then
		return challenge.L.DUNGEON_CHALLENGE_COMBAT_LOG_WARNING_ADVANCED
	end

	return challenge.L.DUNGEON_CHALLENGE_COMBAT_LOG_WARNING_DISABLED
end
