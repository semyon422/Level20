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
}

challenge.state = challenge.state or {
	hooksInstalled = false,
	challengeBlockPatched = false,
	scenarioTimerPatched = false,
	encounterCriteria = {},
	observedDungeonInstanceID = nil,
	observedDungeonLevel = nil,
	originals = {},
	patched = {},
}
