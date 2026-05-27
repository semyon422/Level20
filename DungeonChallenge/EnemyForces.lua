local addonName, addon = ...

local challenge = addon.DungeonChallenge
local state = challenge.state

challenge.enemyForcesConfig = {
	default = {
		requiredScorePerBoss = 50,
		weights = {
			normal = 2,
			minus = 1,
			elite = 5,
			rare = 5,
			rareelite = 5,
			worldboss = 5,
		},
	},
	instances = {
		-- Example:
		-- [2648] = {
		-- 	requiredScore = 100,
		-- 	weights = {
		-- 		normal = 0.5,
		-- 		elite = 1,
		-- 	},
		-- },
	},
}

local function CopyWeights(weights)
	local copy = {}
	for classification, amount in pairs(weights) do
		copy[classification] = amount
	end

	return copy
end

local function CountBossCriteria(criteriaList)
	local count = 0
	for _, criteria in ipairs(criteriaList) do
		if criteria and not criteria.syntheticEnemyForces then
			count = count + 1
		end
	end

	return count
end

function challenge.GetEnemyForcesBossCount(run, criteriaList)
	local count = CountBossCriteria(criteriaList or state.encounterCriteria)
	if count > 0 then
		return count
	end

	local snapshot = challenge.GetEncounterCriteriaSnapshot(run or challenge.GetRunRecord())
	count = CountBossCriteria(snapshot)
	if count > 0 then
		return count
	end

	if C_Scenario and C_Scenario.GetStepInfo then
		local stepOk, _, _, numCriteria = pcall(C_Scenario.GetStepInfo)
		if stepOk and numCriteria and numCriteria > 0 then
			return numCriteria
		end
	end

	return 4
end

function challenge.GetEnemyForcesConfig(run, criteriaList)
	local configRoot = challenge.enemyForcesConfig
	local defaultConfig = configRoot.default
	local defaultWeights = defaultConfig.weights
	local status = challenge.GetStatus()
	local instanceID = tonumber(status.instanceID)
	local instanceConfig = instanceID and configRoot.instances[instanceID] or nil
	local weights = CopyWeights(defaultWeights)

	for classification, amount in pairs(instanceConfig and instanceConfig.weights or {}) do
		weights[classification] = amount
	end

	local requiredScore = tonumber(instanceConfig and instanceConfig.requiredScore)
	if not requiredScore or requiredScore <= 0 then
		local requiredScorePerBoss = tonumber(defaultConfig.requiredScorePerBoss)
		requiredScore = challenge.GetEnemyForcesBossCount(run, criteriaList) * requiredScorePerBoss
	end

	requiredScore = math.max(1, requiredScore)

	return {
		instanceID = instanceID,
		requiredScore = requiredScore,
		weights = weights,
	}
end

function challenge.GetEnemyForcesWeight(classification, run, criteriaList)
	local normalizedClassification = classification or "normal"
	local config = challenge.GetEnemyForcesConfig(run, criteriaList)
	local weights = config.weights

	return tonumber(weights[normalizedClassification]) or tonumber(weights.normal)
end

function challenge.GetEnemyForcesCounts(run)
	run = run or challenge.GetRunRecord()
	if not run then
		return {}
	end

	run.enemyForcesCounts = run.enemyForcesCounts or {}
	return run.enemyForcesCounts
end

function challenge.GetEnemyForcesScore(run, criteriaList)
	local counts = challenge.GetEnemyForcesCounts(run)
	local config = challenge.GetEnemyForcesConfig(run, criteriaList)
	local score = 0

	for classification, count in pairs(counts) do
		local amount = tonumber(config.weights[classification]) or tonumber(config.weights.normal)
		score = score + (math.max(0, tonumber(count) or 0) * amount)
	end

	return math.max(0, math.min(config.requiredScore, score))
end
