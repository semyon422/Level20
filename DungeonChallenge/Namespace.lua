local addonName, addon = ...
local L = addon.L

addon.DungeonChallenge = addon.DungeonChallenge or {}

local challenge = addon.DungeonChallenge

challenge.L = L
challenge.constants = {
	FAKE_TIMER_ID = 200020,
	FAKE_AFFIX_ID = 200020,
	FAKE_SCENARIO_ID = 200020,
	TIME_LIMIT_SECONDS = 30 * 60,
	COMPLETION_BANNER_DELAY_SECONDS = 1,
	COMBAT_LOG_STOP_DELAY_SECONDS = 1,
	AUTORESET_DELAY_SECONDS = 10,
}

challenge.state = challenge.state or {
	challengeBlockPatched = false,
	scenarioTimerPatched = false,
	customTrackerModule = nil,
	customTrackerModuleRegistered = false,
	defaultScenarioModuleDetached = false,
	defaultScenarioModuleHidden = false,
	battleResCooldowns = nil,
	battleResObservedItemOwners = nil,
	originalChallengeModeBlockParent = nil,
	originalObjectivesBlockParent = nil,
	encounterCriteria = {},
	criteriaCompletionStates = {},
	observedDungeonInstanceID = nil,
	observedDungeonLevel = nil,
	combatLogManagedRunActive = false,
	combatLogStopPending = false,
	combatLogStopTimer = nil,
	activeBossFight = nil,
}
