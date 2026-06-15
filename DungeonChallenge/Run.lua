local addonName, addon = ...

local challenge = addon.DungeonChallenge
local constants = challenge.constants
local state = challenge.state

local function GetRunStore()
	Level20DB.dungeonChallengeRuns = Level20DB.dungeonChallengeRuns or {}
	return Level20DB.dungeonChallengeRuns
end

function challenge.GetCurrentDungeonKey()
	local status = challenge.GetStatus and challenge.GetStatus() or nil
	if not status then
		return state.activeRunRecordKey
	end

	local instanceType = status.instanceType or "unknown"
	local instanceID = tonumber(status.instanceID)
	local lfgDungeonID = tonumber(status.lfgDungeonID)
	local name = status.name

	local key
	if instanceID and instanceID > 0 then
		key = string.format("instance:%s:%d", instanceType, instanceID)
	elseif lfgDungeonID and lfgDungeonID > 0 then
		key = string.format("lfg:%s:%d", instanceType, lfgDungeonID)
	elseif name and name ~= "" then
		key = string.format("name:%s:%s", instanceType, name)
	end

	if key then
		state.activeRunRecordKey = key
	end

	return key or state.activeRunRecordKey
end

function challenge.GetCurrentServerTime()
	if GetServerTime then
		return GetServerTime()
	end

	return time()
end

function challenge.GetRunRecord()
	local store = GetRunStore()
	local dungeonKey = challenge.GetCurrentDungeonKey()
	if not dungeonKey then
		return nil
	end

	store[dungeonKey] = store[dungeonKey] or {}
	return store[dungeonKey]
end

function challenge.GetEncounterCompletionTimes(run)
	if not run then
		return nil
	end

	run.encounterCompletionTimes = run.encounterCompletionTimes or {}
	return run.encounterCompletionTimes
end

function challenge.GetEncounterCriteriaSnapshot(run)
	if not run then
		return nil
	end

	run.encounterCriteriaSnapshot = run.encounterCriteriaSnapshot or {}
	return run.encounterCriteriaSnapshot
end

function challenge.GetDeathCount(run)
	run = run or challenge.GetRunRecord()
	if not run then
		return 0
	end

	return math.max(0, tonumber(run.deathCount) or 0)
end

function challenge.ClearRunRecord()
	challenge.CancelCompletionBannerTimer()

	local store = GetRunStore()
	local dungeonKey = challenge.GetCurrentDungeonKey()
	if not dungeonKey then
		return
	end

	store[dungeonKey] = {}
	if challenge.UpdateManagedCombatLog then
		challenge.UpdateManagedCombatLog()
	end
end

function challenge.ResetTimerState()
	if InCombatLockdown and InCombatLockdown() then
		return false
	end

	Level20DB.showDungeonChallengeFrame = true
	challenge.ClearRunRecord()

	if ScenarioTimerFrame then
		ScenarioTimerFrame:StopTimer(constants.FAKE_TIMER_ID)
	end

	if ScenarioObjectiveTracker and ScenarioObjectiveTracker.ChallengeModeBlock then
		ScenarioObjectiveTracker.ChallengeModeBlock.timerID = nil
	end

	return true
end

function challenge.HasShownCompletionBanner(run)
	return run and run.completionBannerShown and true or false
end

function challenge.MarkCompletionBannerShown(run, shown)
	if not run then
		return
	end

	run.completionBannerShown = shown and true or false
end

function challenge.CancelCompletionBannerTimer()
	if state.completionBannerTimer then
		state.completionBannerTimer:Cancel()
		state.completionBannerTimer = nil
	end
end

function challenge.ScheduleCompletionBanner(run)
	if not run or not run.completedAt or challenge.HasShownCompletionBanner(run) then
		return false
	end

	challenge.CancelCompletionBannerTimer()
	state.completionBannerTimer = C_Timer.NewTimer(constants.COMPLETION_BANNER_DELAY_SECONDS, function()
		state.completionBannerTimer = nil
		challenge.TriggerCompletionBanner(run)
	end)
	return true
end

function challenge.TriggerCompletionBanner(run)
	if not run or not run.completedAt or challenge.HasShownCompletionBanner(run) then
		return false
	end

	if not challenge.ShowCompletionBanner then
		return false
	end

	local shown = challenge.ShowCompletionBanner()
	if shown then
		challenge.MarkCompletionBannerShown(run, true)
	end

	return shown and true or false
end

function challenge.GetEncounterCompletionKey(criteria)
	if not criteria then
		return nil
	end

	if criteria.criteriaID then
		return tostring(criteria.criteriaID)
	end

	if criteria.assetID and criteria.assetID > 0 then
		return tostring(criteria.assetID)
	end

	return criteria.description
end

function challenge.GetEncounterCompletionTime(run, criteria)
	if not run or not criteria then
		return nil
	end

	local encounterCompletionTimes = challenge.GetEncounterCompletionTimes(run)
	local encounterKey = challenge.GetEncounterCompletionKey(criteria)
	if not encounterCompletionTimes or not encounterKey then
		return nil
	end

	return encounterCompletionTimes[encounterKey]
end

function challenge.RecordEncounterCompletionTime(run, criteria)
	if not run or not run.startedAt or not criteria or not criteria.completed then
		return nil
	end

	local encounterCompletionTimes = challenge.GetEncounterCompletionTimes(run)
	local encounterKey = challenge.GetEncounterCompletionKey(criteria)
	if not encounterCompletionTimes or not encounterKey then
		return nil
	end

	if encounterCompletionTimes[encounterKey] == nil then
		local completedElapsed
		if run.completedElapsed then
			completedElapsed = run.completedElapsed
		else
			completedElapsed = math.max(0, challenge.GetCurrentServerTime() - run.startedAt)
		end

		encounterCompletionTimes[encounterKey] = math.floor(completedElapsed)
	end

	return encounterCompletionTimes[encounterKey]
end

function challenge.CopyCriteria(criteria)
	if not criteria then
		return nil
	end

	local copy = {}
	for key, value in pairs(criteria) do
		copy[key] = value
	end

	return copy
end

function challenge.SaveEncounterCriteriaSnapshot(run)
	if not run then
		return
	end

	local snapshot = challenge.GetEncounterCriteriaSnapshot(run)
	table.wipe(snapshot)

	for index, criteria in ipairs(state.encounterCriteria) do
		if not criteria.excludeFromSnapshot then
			table.insert(snapshot, challenge.CopyCriteria(criteria))
		end
	end
end

function challenge.RestoreEncounterCriteriaSnapshot(run)
	if not run then
		return false
	end

	local snapshot = challenge.GetEncounterCriteriaSnapshot(run)
	if #snapshot == 0 then
		return false
	end

	for _, criteria in ipairs(snapshot) do
		table.insert(state.encounterCriteria, challenge.CopyCriteria(criteria))
	end

	return #state.encounterCriteria > 0
end

function challenge.StartRun(run)
	if not run or run.startedAt or run.completedAt then
		return false
	end

	run.startedAt = challenge.GetCurrentServerTime()
	run.deathCount = math.max(0, tonumber(run.deathCount) or 0)
	run.enemyForcesCounts = run.enemyForcesCounts or {}
	if challenge.UpdateManagedCombatLog then
		challenge.UpdateManagedCombatLog()
	end
	return true
end

function challenge.RecordDeath(run)
	run = run or challenge.GetRunRecord()
	if not run or not run.startedAt or run.completedAt then
		return false
	end

	run.deathCount = challenge.GetDeathCount(run) + 1
	return true
end

function challenge.RecordEnemyForcesProgress(classification, run)
	run = run or challenge.GetRunRecord()
	classification = classification or "normal"
	if not run then
		return false
	end

	local counts = challenge.GetEnemyForcesCounts(run)
	counts[classification] = math.max(0, tonumber(counts[classification]) or 0) + 1
	return true
end

function challenge.CompleteRun(run)
	if not run or not run.startedAt or run.completedAt then
		return false
	end

	local now = challenge.GetCurrentServerTime()
	run.completedAt = now
	run.completedElapsed = math.max(0, now - run.startedAt)
	if challenge.UpdateManagedCombatLog then
		challenge.UpdateManagedCombatLog()
	end
	challenge.ScheduleCompletionBanner(run)
	return true
end

function challenge.GetElapsedTime()
	local run = challenge.GetRunRecord()
	if not run or not run.startedAt then
		return 0
	end

	if run.completedAt then
		return math.max(0, math.floor(run.completedElapsed or (run.completedAt - run.startedAt)))
	end

	return math.max(0, math.floor(challenge.GetCurrentServerTime() - run.startedAt))
end

function challenge.IsTimerStarted()
	local run = challenge.GetRunRecord()
	return run and run.startedAt and true or false
end

function challenge.IsTimerStopped(run)
	run = run or challenge.GetRunRecord()
	return run and run.startedAt and run.completedAt and true or false
end
