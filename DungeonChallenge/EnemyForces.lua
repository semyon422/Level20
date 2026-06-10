local addonName, addon = ...

local challenge = addon.DungeonChallenge
local state = challenge.state
local ENEMY_FORCES_SYNC_FIELD_PREFIX = "efc_"
local ENEMY_FORCES_SYNC_START_TIME_TOLERANCE_SECONDS = 30
local DEFAULT_ENEMY_FORCES_CLASSIFICATIONS = {
	"normal",
	"minus",
	"elite",
	"rare",
	"rareelite",
	"worldboss",
}

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

function challenge.GetEnemyForcesMode()
	local mode = Level20DB.enemyForcesMode
	if mode == addon.ENEMY_FORCES_MODE_DISABLED
		or mode == addon.ENEMY_FORCES_MODE_REQUIRED
		or mode == addon.ENEMY_FORCES_MODE_UNLIMITED then
		return mode
	end

	return addon.ENEMY_FORCES_MODE_DISABLED
end

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

function challenge.GetEnemyForcesSyncFieldName(classification)
	return ENEMY_FORCES_SYNC_FIELD_PREFIX .. tostring(classification or "normal")
end

function challenge.GetEnemyForcesTrackedClassifications(run, criteriaList)
	local seen = {}
	local classifications = {}
	local config = challenge.GetEnemyForcesConfig(run, criteriaList)

	for _, classification in ipairs(DEFAULT_ENEMY_FORCES_CLASSIFICATIONS) do
		seen[classification] = true
		classifications[#classifications + 1] = classification
	end

	for classification in pairs(config.weights or {}) do
		if not seen[classification] then
			seen[classification] = true
			classifications[#classifications + 1] = classification
		end
	end

	return classifications
end

function challenge.GetEnemyForcesSyncPayload(run)
	run = run or challenge.GetRunRecord()
	if not run or not run.startedAt or run.completedAt then
		return {
			efa = false,
		}
	end

	local payload = {
		efa = true,
		efdk = challenge.GetCurrentDungeonKey(),
		efst = math.floor(tonumber(run.startedAt) or 0),
	}
	local counts = challenge.GetEnemyForcesCounts(run)

	for _, classification in ipairs(challenge.GetEnemyForcesTrackedClassifications(run, state.encounterCriteria)) do
		local count = math.max(0, tonumber(counts[classification]) or 0)
		if count > 0 then
			payload[challenge.GetEnemyForcesSyncFieldName(classification)] = count
		end
	end

	return payload
end

function challenge.ApplyEnemyForcesSyncPayload(payload, run)
	if type(payload) ~= "table" or not payload.efa or not challenge.ShouldUse() then
		return false
	end

	run = run or challenge.GetRunRecord()
	if not run or not run.startedAt or run.completedAt then
		return false
	end

	local currentDungeonKey = challenge.GetCurrentDungeonKey()
	if not currentDungeonKey or payload.efdk ~= currentDungeonKey then
		return false
	end

	local localStartedAt = math.floor(tonumber(run.startedAt) or 0)
	local remoteStartedAt = math.floor(tonumber(payload.efst) or 0)
	if localStartedAt <= 0 or remoteStartedAt <= 0 then
		return false
	end

	if math.abs(localStartedAt - remoteStartedAt) > ENEMY_FORCES_SYNC_START_TIME_TOLERANCE_SECONDS then
		return false
	end

	local counts = challenge.GetEnemyForcesCounts(run)
	local changed = false

	for key, value in pairs(payload) do
		local classification = string.match(key, "^" .. ENEMY_FORCES_SYNC_FIELD_PREFIX .. "(.+)$")
		local remoteCount = math.max(0, tonumber(value) or 0)
		if classification and remoteCount > 0 then
			local localCount = math.max(0, tonumber(counts[classification]) or 0)
			if remoteCount > localCount then
				counts[classification] = remoteCount
				changed = true
			end
		end
	end

	return changed
end

function challenge.GetEnemyForcesScore(run, criteriaList)
	local counts = challenge.GetEnemyForcesCounts(run)
	local config = challenge.GetEnemyForcesConfig(run, criteriaList)
	local score = 0

	for classification, count in pairs(counts) do
		local amount = tonumber(config.weights[classification]) or tonumber(config.weights.normal)
		score = score + (math.max(0, tonumber(count) or 0) * amount)
	end

	return math.max(0, score)
end
