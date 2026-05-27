local addonName, addon = ...

local challenge = addon.DungeonChallenge
local state = challenge.state

function challenge.IsEnemyForcesEnabled()
	return Level20DB.enableEnemyForces and true or false
end

function challenge.BuildEnemyForcesCriteria(run)
	if not challenge.IsEnemyForcesEnabled() then
		return nil
	end

	local config = challenge.GetEnemyForcesConfig(run, state.encounterCriteria)
	local totalQuantity = math.max(1, tonumber(config and config.requiredScore) or 100)
	local quantity = 0
	if run and run.startedAt and challenge.GetEnemyForcesScore then
		quantity = challenge.GetEnemyForcesScore(run)
	end

	return {
		description = challenge.L.DUNGEON_CHALLENGE_ENEMY_FORCES,
		quantity = quantity,
		totalQuantity = totalQuantity,
		completed = quantity >= totalQuantity,
		enemyForcesConfig = config,
		duration = 0,
		elapsed = 0,
		failed = false,
		isWeightedProgress = true,
		isFormatted = true,
		quantityString = nil,
		criteriaType = 0,
		flags = 0,
		assetID = challenge.constants.FAKE_AFFIX_ID,
		criteriaID = challenge.constants.FAKE_AFFIX_ID,
		excludeFromCompletion = true,
		excludeFromSnapshot = true,
		syntheticEnemyForces = true,
	}
end

function challenge.FormatEncounterDescription(criteria, run)
	if not criteria or not criteria.description then
		return nil
	end

	local description = criteria.description
	if not criteria.completed then
		return description
	end

	local completionTime = challenge.GetEncounterCompletionTime(run, criteria)
	if completionTime == nil then
		return description
	end

	return string.format("%s |cff9d9d9d(%s)|r", description, SecondsToClock(completionTime))
end

function challenge.HasAnyCompletedCriteria(criteriaList)
	if not criteriaList then
		return false
	end

	for _, criteria in ipairs(criteriaList) do
		if not criteria.excludeFromCompletion and criteria.completed then
			return true
		end
	end

	return false
end

function challenge.IsFreshDungeon(criteriaList)
	criteriaList = criteriaList or state.encounterCriteria
	return #criteriaList > 0 and not challenge.HasAnyCompletedCriteria(criteriaList)
end

function challenge.GetLiveCriteriaFreshness()
	if not C_Scenario or not C_ScenarioInfo then
		return nil
	end

	local stepOk, _, _, numCriteria = pcall(C_Scenario.GetStepInfo)
	if not stepOk or not numCriteria or numCriteria <= 0 then
		return nil
	end

	local hasCriteria = false
	for index = 1, numCriteria do
		local criteriaOk, criteriaInfo = pcall(C_ScenarioInfo.GetCriteriaInfo, index)
		if criteriaOk and criteriaInfo and criteriaInfo.description and criteriaInfo.description ~= "" then
			hasCriteria = true
			if criteriaInfo.completed then
				return false
			end
		end
	end

	if hasCriteria then
		return true
	end

	return nil
end

function challenge.GetLiveScenarioState()
	if not C_Scenario then
		return nil
	end

	if not C_Scenario.GetInfo then
		return nil
	end

	local infoOk, scenarioName, currentStage, numStages, flags, _, _, _, xp, money, scenarioType, areaName, textureKit, scenarioID =
		pcall(C_Scenario.GetInfo)
	if not infoOk then
		return nil
	end

	local shouldShowCriteria
	if C_Scenario.ShouldShowCriteria then
		local showOk, showValue = pcall(C_Scenario.ShouldShowCriteria)
		if showOk then
			shouldShowCriteria = showValue and true or false
		end
	end

	local isComplete
	if currentStage and numStages then
		isComplete = currentStage > numStages
	end

	return {
		name = scenarioName,
		currentStage = currentStage,
		numStages = numStages,
		flags = flags,
		xp = xp,
		money = money,
		scenarioType = scenarioType,
		areaName = areaName,
		textureKit = textureKit,
		scenarioID = scenarioID,
		isComplete = isComplete,
		shouldShowCriteria = shouldShowCriteria,
	}
end

function challenge.IsFreshDungeonForAutoReset(liveScenarioState)
	if liveScenarioState and (liveScenarioState.isComplete or liveScenarioState.shouldShowCriteria == false) then
		return false
	end

	return challenge.GetLiveCriteriaFreshness()
end

function challenge.DoesCriteriaListMatchSnapshot(criteriaList, snapshot)
	if not criteriaList or not snapshot then
		return false
	end

	local filteredCriteriaList = {}
	for _, criteria in ipairs(criteriaList) do
		if not criteria.excludeFromSnapshot then
			table.insert(filteredCriteriaList, criteria)
		end
	end

	if #filteredCriteriaList ~= #snapshot then
		return false
	end

	for index, criteria in ipairs(filteredCriteriaList) do
		local snapshotCriteria = snapshot[index]
		if not snapshotCriteria then
			return false
		end

		if criteria.criteriaID ~= snapshotCriteria.criteriaID
			or criteria.assetID ~= snapshotCriteria.assetID then
			return false
		end
	end

	return true
end

function challenge.HasCompletedAllCriteria()
	if #state.encounterCriteria == 0 then
		return false
	end

	for _, criteria in ipairs(state.encounterCriteria) do
		if not criteria.excludeFromCompletion and not criteria.completed then
			return false
		end
	end

	return true
end

function challenge.BuildEncounterCriteriaFromJournal(status)
	if not status or status.instanceType ~= "raid" then
		return false
	end

	if not EJ_SelectInstance or not EJ_GetEncounterInfoByIndex then
		return false
	end

	local journalInstanceID
	if AdventureGuideUtil and AdventureGuideUtil.GetCurrentJournalInstance then
		journalInstanceID = AdventureGuideUtil.GetCurrentJournalInstance()
	elseif C_EncounterJournal and C_EncounterJournal.GetInstanceForGameMap and status.instanceID and status.instanceID > 0 then
		journalInstanceID = C_EncounterJournal.GetInstanceForGameMap(status.instanceID)
	end

	if not journalInstanceID or journalInstanceID <= 0 then
		return false
	end

	local selectOk = pcall(EJ_SelectInstance, journalInstanceID)
	if not selectOk then
		return false
	end

	local index = 1
	local run = challenge.GetRunRecord()
	while true do
		local name, _, encounterID = EJ_GetEncounterInfoByIndex(index)
		if not name then
			break
		end

		if name and name ~= "" then
			local completed = false
			if encounterID and C_EncounterJournal and C_EncounterJournal.IsEncounterComplete then
				local completedOk, isComplete = pcall(C_EncounterJournal.IsEncounterComplete, encounterID)
				completed = completedOk and isComplete and true or false
			end

			local criteria = {
				description = name,
				quantity = completed and 1 or 0,
				totalQuantity = 1,
				completed = completed,
				duration = 0,
				elapsed = 0,
				failed = false,
				isWeightedProgress = false,
				isFormatted = false,
				quantityString = nil,
				criteriaType = 0,
				flags = 0,
				assetID = encounterID or 0,
				criteriaID = encounterID or index,
			}
			if criteria.completed then
				challenge.RecordEncounterCompletionTime(run, criteria)
			end
			criteria.description = challenge.FormatEncounterDescription(criteria, run)

			table.insert(state.encounterCriteria, criteria)
		end

		index = index + 1
	end

	return #state.encounterCriteria > 0
end

function challenge.RefreshEncounterCriteria()
	table.wipe(state.encounterCriteria)

	local run = challenge.GetRunRecord()
	local enemyForcesCriteria = challenge.BuildEnemyForcesCriteria(run)

	if not C_Scenario or not C_ScenarioInfo then
		challenge.BuildEncounterCriteriaFromJournal(challenge.GetStatus())
		if enemyForcesCriteria then
			table.insert(state.encounterCriteria, enemyForcesCriteria)
		end
		return
	end

	local stepOk, _, _, numCriteria = pcall(C_Scenario.GetStepInfo)
	if stepOk and numCriteria and numCriteria > 0 then
		for index = 1, numCriteria do
			local criteriaOk, criteriaInfo = pcall(C_ScenarioInfo.GetCriteriaInfo, index)
			if criteriaOk and criteriaInfo and criteriaInfo.description and criteriaInfo.description ~= "" then
				local criteria = {
					description = criteriaInfo.description,
					quantity = criteriaInfo.quantity or 0,
					totalQuantity = criteriaInfo.totalQuantity or 1,
					completed = criteriaInfo.completed or false,
					duration = criteriaInfo.duration or 0,
					elapsed = criteriaInfo.elapsed or 0,
					failed = criteriaInfo.failed or false,
					isWeightedProgress = criteriaInfo.isWeightedProgress or false,
					isFormatted = criteriaInfo.isFormatted or false,
					quantityString = criteriaInfo.quantityString,
					criteriaType = criteriaInfo.criteriaType or 0,
					flags = criteriaInfo.flags or 0,
					assetID = criteriaInfo.assetID or 0,
					criteriaID = criteriaInfo.criteriaID or index,
				}
				if criteria.completed then
					challenge.RecordEncounterCompletionTime(run, criteria)
				end
				criteria.description = challenge.FormatEncounterDescription(criteria, run)

				table.insert(state.encounterCriteria, criteria)
			end
		end

		if enemyForcesCriteria then
			table.insert(state.encounterCriteria, enemyForcesCriteria)
		end

		if #state.encounterCriteria > 0 then
			if run and run.completedAt and not challenge.HasAnyCompletedCriteria(state.encounterCriteria) then
				local snapshot = challenge.GetEncounterCriteriaSnapshot(run)
				if challenge.DoesCriteriaListMatchSnapshot(state.encounterCriteria, snapshot) then
					table.wipe(state.encounterCriteria)
					challenge.RestoreEncounterCriteriaSnapshot(run)
					if enemyForcesCriteria then
						table.insert(state.encounterCriteria, enemyForcesCriteria)
					end
					return
				end
			end

			challenge.SaveEncounterCriteriaSnapshot(run)
			if run and challenge.HasCompletedAllCriteria() then
				challenge.CompleteRun(run)
			end

			return
		end
	end

	if enemyForcesCriteria then
		table.insert(state.encounterCriteria, enemyForcesCriteria)
	end

	if challenge.BuildEncounterCriteriaFromJournal(challenge.GetStatus()) then
		if enemyForcesCriteria then
			table.insert(state.encounterCriteria, enemyForcesCriteria)
		end
		challenge.SaveEncounterCriteriaSnapshot(run)
		if run and challenge.HasCompletedAllCriteria() then
			challenge.CompleteRun(run)
		end
		return
	end

	table.wipe(state.encounterCriteria)
	challenge.RestoreEncounterCriteriaSnapshot(run)
	if enemyForcesCriteria then
		table.insert(state.encounterCriteria, enemyForcesCriteria)
	end
end

function challenge.BuildCriteriaInfo(index)
	local criteria = state.encounterCriteria[index]
	if not criteria then
		return nil
	end

	return {
		criteriaID = criteria.criteriaID or index,
		description = criteria.description,
		quantity = criteria.quantity,
		totalQuantity = criteria.totalQuantity,
		completed = criteria.completed or false,
		duration = criteria.duration or 0,
		elapsed = criteria.elapsed or 0,
		failed = criteria.failed or false,
		isWeightedProgress = criteria.isWeightedProgress or false,
		isFormatted = criteria.isFormatted or false,
		quantityString = criteria.quantityString,
		flags = criteria.flags or 0,
		assetID = criteria.assetID or 0,
		criteriaType = criteria.criteriaType or 0,
	}
end
