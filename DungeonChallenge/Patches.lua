local addonName, addon = ...

local challenge = addon.DungeonChallenge
local L = addon.L
local constants = challenge.constants
local state = challenge.state

state.patched.C_ChallengeMode = {
	GetActiveKeystoneInfo = function()
		return challenge.GetChallengeLevel(), {}, true
	end,

	GetAffixInfo = function()
		return L.DUNGEON_CHALLENGE_AFFIX, L.DUNGEON_CHALLENGE_AFFIX_TOOLTIP, "Interface\\Icons\\Ability_DualWield"
	end,

	GetDeathCount = function()
		return 0, 0
	end,

	GetActiveChallengeMapID = function()
		return constants.FAKE_SCENARIO_ID
	end,

	GetMapUIInfo = function()
		local status = challenge.GetStatus()
		return status.name or L.DUNGEON_CHALLENGE_UNKNOWN_DUNGEON, constants.FAKE_SCENARIO_ID, constants.TIME_LIMIT_SECONDS
	end,
}

state.patched.C_Scenario = {
	GetInfo = function()
		local status = challenge.GetStatus()
		return status.name or L.DUNGEON_CHALLENGE_UNKNOWN_DUNGEON,
			1,
			1,
			0,
			nil,
			nil,
			nil,
			0,
			0,
			LE_SCENARIO_TYPE_CHALLENGE_MODE,
			nil,
			nil,
			constants.FAKE_SCENARIO_ID
	end,

	GetStepInfo = function()
		return L.DUNGEON_CHALLENGE_SUBTITLE,
			"",
			#state.encounterCriteria,
			nil,
			nil,
			nil,
			nil,
			0,
			nil,
			nil,
			nil,
			nil
	end,

	ShouldShowCriteria = function()
		return true
	end,
}

state.patched.C_ScenarioInfo = {
	GetCriteriaInfo = function(criteriaIndex)
		return challenge.BuildCriteriaInfo(criteriaIndex)
	end,
}

function challenge.GetPatchTarget(tableName)
	if tableName == "_G" then
		return _G
	end

	return _G[tableName]
end

function challenge.InstallHooks()
	if state.hooksInstalled then
		return
	end

	if not C_ChallengeMode or not C_Scenario or not C_ScenarioInfo then
		return
	end

	for tableName, functions in pairs(state.patched) do
		local target = challenge.GetPatchTarget(tableName)
		if not target then
			return
		end

		state.originals[tableName] = state.originals[tableName] or {}

		for functionName, patchedFunction in pairs(functions) do
			state.originals[tableName][functionName] = target[functionName]
			target[functionName] = function(...)
				if challenge.ShouldUse() then
					return patchedFunction(...)
				end

				return state.originals[tableName][functionName](...)
			end
		end
	end

	state.originals.C_ChallengeMode.IsChallengeModeActive = C_ChallengeMode.IsChallengeModeActive
	state.hooksInstalled = true
end
