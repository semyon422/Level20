local addonName, addon = ...

local challenge = addon.DungeonChallenge
local state = challenge.state

function challenge.GetCurrentServerTime()
	if GetServerTime then
		return GetServerTime()
	end

	return time()
end

function challenge.GetRunRecord()
	Level20DB.dungeonChallengeTimer = Level20DB.dungeonChallengeTimer or {}
	return Level20DB.dungeonChallengeTimer
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

function challenge.ClearRunRecord()
	Level20DB.dungeonChallengeTimer = {}
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
		snapshot[index] = challenge.CopyCriteria(criteria)
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
	return true
end

function challenge.CompleteRun(run)
	if not run or not run.startedAt or run.completedAt then
		return false
	end

	local now = challenge.GetCurrentServerTime()
	run.completedAt = now
	run.completedElapsed = math.max(0, now - run.startedAt)
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
