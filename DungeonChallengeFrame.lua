local addonName, addon = ...
local L = addon.L

local FAKE_TIMER_ID = 200020
local FAKE_AFFIX_ID = 200020
local FAKE_SCENARIO_ID = 200020
local TIME_LIMIT_SECONDS = 30 * 60

local hooksInstalled = false
local challengeBlockPatched = false
local fakeRunStartTime
local currentInstanceKey
local encounterCriteria = {}

local originals = {}
local patched = {}

local function GetDungeonChallengeLevel()
	local effectiveLevel = UnitEffectiveLevel and UnitEffectiveLevel("player")
	if effectiveLevel and effectiveLevel > 0 then
		return effectiveLevel
	end

	local level = UnitLevel("player")
	if level and level > 0 then
		return level
	end

	return addon.LEVEL_CAP
end

local function GetDungeonChallengeStatus()
	local isInInstance, instanceType = IsInInstance()
	local name, _, difficultyID, difficultyName, maxPlayers, _, _, instanceID, instanceGroupSize, lfgDungeonID = GetInstanceInfo()

	return {
		isInInstance = isInInstance,
		instanceType = instanceType,
		name = name,
		difficultyID = difficultyID,
		difficultyName = difficultyName,
		maxPlayers = maxPlayers,
		instanceID = instanceID,
		instanceGroupSize = instanceGroupSize,
		lfgDungeonID = lfgDungeonID,
	}
end

local function GetInstanceKey()
	local status = GetDungeonChallengeStatus()
	return string.format("%s:%s:%s", tostring(status.instanceID), tostring(status.difficultyID), tostring(status.lfgDungeonID))
end

local function IsRealChallengeModeActive()
	if originals.C_ChallengeMode and originals.C_ChallengeMode.IsChallengeModeActive then
		return originals.C_ChallengeMode.IsChallengeModeActive()
	end

	return false
end

local function ShouldUseDungeonChallenge()
	if not Level20DB.showDungeonChallengeFrame or IsRealChallengeModeActive() then
		return false
	end

	local status = GetDungeonChallengeStatus()
	return status.isInInstance and status.instanceType == "party"
end

local function GetElapsedTime()
	if not fakeRunStartTime then
		return 0
	end

	return math.floor(GetTime() - fakeRunStartTime)
end

local function RefreshEncounterCriteria()
	table.wipe(encounterCriteria)

	if not C_Scenario or not C_ScenarioInfo then
		return
	end

	local originalScenario = originals.C_Scenario or C_Scenario
	local originalScenarioInfo = originals.C_ScenarioInfo or C_ScenarioInfo
	local originalGetStepInfo = originalScenario.GetStepInfo
	local originalGetCriteriaInfo = originalScenarioInfo.GetCriteriaInfo
	local stepOk, _, _, numCriteria = pcall(originalGetStepInfo)
	if stepOk and numCriteria and numCriteria > 0 then
		for index = 1, numCriteria do
			local criteriaOk, criteriaInfo = pcall(originalGetCriteriaInfo, index)
			if criteriaOk and criteriaInfo and criteriaInfo.description and criteriaInfo.description ~= "" then
				table.insert(encounterCriteria, {
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
				})
			end
		end

		if #encounterCriteria > 0 then
			return
		end
	end
end

local function GetCriteria()
	local criteria = {}

	for _, encounter in ipairs(encounterCriteria) do
		table.insert(criteria, encounter)
	end

	-- table.insert(criteria, {
	-- 	description = L.DUNGEON_CHALLENGE_ENEMY_FORCES,
	-- 	quantity = 0,
	-- 	totalQuantity = 100,
	-- 	isWeightedProgress = true,
	-- 	isFormatted = true,
	-- })

	return criteria
end

local function BuildCriteriaInfo(index)
	local criteria = GetCriteria()[index]
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

patched.C_ChallengeMode = {
	GetActiveKeystoneInfo = function()
		return GetDungeonChallengeLevel(), { FAKE_AFFIX_ID }, true
	end,

	GetAffixInfo = function()
		return L.DUNGEON_CHALLENGE_AFFIX, L.DUNGEON_CHALLENGE_AFFIX_TOOLTIP, "Interface\\Icons\\Ability_DualWield"
	end,

	GetDeathCount = function()
		return 0, 0
	end,

	GetActiveChallengeMapID = function()
		return FAKE_SCENARIO_ID
	end,

	GetMapUIInfo = function()
		local status = GetDungeonChallengeStatus()
		return status.name or L.DUNGEON_CHALLENGE_UNKNOWN_DUNGEON, FAKE_SCENARIO_ID, TIME_LIMIT_SECONDS
	end,
}

patched._G = {
	GetWorldElapsedTime = function()
		return L.DUNGEON_CHALLENGE_SUBTITLE, GetElapsedTime(), Enum.WorldElapsedTimerTypes.ChallengeMode
	end,

	GetWorldElapsedTimers = function()
		return FAKE_TIMER_ID
	end,
}

patched.C_Scenario = {
	GetInfo = function()
		local status = GetDungeonChallengeStatus()
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
			FAKE_SCENARIO_ID
	end,

	GetStepInfo = function()
		local criteria = GetCriteria()
		return L.DUNGEON_CHALLENGE_SUBTITLE,
			"",
			#criteria,
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

patched.C_ScenarioInfo = {
	GetCriteriaInfo = function(criteriaIndex)
		return BuildCriteriaInfo(criteriaIndex)
	end,
}

local function GetPatchTarget(tableName)
	if tableName == "_G" then
		return _G
	end

	return _G[tableName]
end

local function InstallHooks()
	if hooksInstalled then
		return
	end

	if not C_ChallengeMode or not C_Scenario or not C_ScenarioInfo then
		return
	end

	for tableName, functions in pairs(patched) do
		local target = GetPatchTarget(tableName)
		if not target then
			return
		end

		originals[tableName] = originals[tableName] or {}

		for functionName, patchedFunction in pairs(functions) do
			originals[tableName][functionName] = target[functionName]
			target[functionName] = function(...)
				if ShouldUseDungeonChallenge() then
					return patchedFunction(...)
				end

				return originals[tableName][functionName](...)
			end
		end
	end

	originals.C_ChallengeMode.IsChallengeModeActive = C_ChallengeMode.IsChallengeModeActive
	hooksInstalled = true
end

local function ActivateBlizzardChallengeBlock()
	if not ShouldUseDungeonChallenge() then
		fakeRunStartTime = nil

		if ScenarioTimerFrame then
			ScenarioTimerFrame:StopTimer(FAKE_TIMER_ID)
		end

		if ScenarioObjectiveTracker and ScenarioObjectiveTracker.ChallengeModeBlock then
			ScenarioObjectiveTracker.ChallengeModeBlock.timerID = nil
			ScenarioObjectiveTracker.ChallengeModeBlock:Hide()
		end

		if ScenarioObjectiveTracker then
			ScenarioObjectiveTracker:MarkDirty()
		end
		return false
	end

	if not ScenarioObjectiveTracker or not ScenarioObjectiveTracker.ChallengeModeBlock or not ScenarioTimerFrame then
		return false
	end

	local isNewRun = not fakeRunStartTime
	if isNewRun then
		fakeRunStartTime = GetTime()
	end

	local instanceKey = GetInstanceKey()
	if isNewRun or currentInstanceKey ~= instanceKey then
		currentInstanceKey = instanceKey
	end

	local block = ScenarioObjectiveTracker.ChallengeModeBlock
	if not challengeBlockPatched then
		local originalUpdateTime = block.UpdateTime
		block.UpdateTime = function(self, elapsedTime)
			if ShouldUseDungeonChallenge() and self.timerID == FAKE_TIMER_ID then
				local statusBar = self.StatusBar
				local displayedElapsedTime = math.min(elapsedTime, TIME_LIMIT_SECONDS)
				statusBar:SetValue(TIME_LIMIT_SECONDS - displayedElapsedTime)
				self.TimeLeft:SetTextColor(HIGHLIGHT_FONT_COLOR:GetRGB())
				self.TimeLeft:SetText(SecondsToClock(elapsedTime))
				self.StartedDepleted:Hide()
				self.TimesUpLootStatus:Hide()
			else
				originalUpdateTime(self, elapsedTime)
			end
		end
		challengeBlockPatched = true
	end

	if not block:IsActive() or block.timerID ~= FAKE_TIMER_ID then
		block:Activate(FAKE_TIMER_ID, GetElapsedTime(), TIME_LIMIT_SECONDS)
	end

	ScenarioObjectiveTracker:SetShouldShowCriteria(true)
	ScenarioObjectiveTracker:ForceExpand()
	ScenarioObjectiveTracker:MarkDirty()
	return true
end

function addon.RefreshDungeonChallengeFrame(forceShow)
	if forceShow then
		Level20DB.showDungeonChallengeFrame = true
	end

	InstallHooks()
	if ShouldUseDungeonChallenge() then
		RefreshEncounterCriteria()
	end
	ActivateBlizzardChallengeBlock()
end

function addon.InitializeDungeonChallengeFrame()
	addon.RefreshDungeonChallengeFrame()
end

function addon.ShowDungeonChallengeFrame()
	addon.RefreshDungeonChallengeFrame(true)
end

function addon.SetDungeonChallengeFrameEnabled(enabled)
	Level20DB.showDungeonChallengeFrame = enabled and true or false
	addon.RefreshDungeonChallengeFrame(Level20DB.showDungeonChallengeFrame)
end

function addon.ScheduleDungeonChallengeFrameRefresh()
	addon.RefreshDungeonChallengeFrame()
	-- C_Timer.After(0.5, addon.RefreshDungeonChallengeFrame)
	-- C_Timer.After(1, addon.RefreshDungeonChallengeFrame)
	-- C_Timer.After(3, addon.RefreshDungeonChallengeFrame)
end

function addon.ResetDungeonChallengeTimer()
	if InCombatLockdown and InCombatLockdown() then
		return
	end

	Level20DB.showDungeonChallengeFrame = true
	fakeRunStartTime = GetTime()

	if ScenarioTimerFrame then
		ScenarioTimerFrame:StopTimer(FAKE_TIMER_ID)
	end

	if ScenarioObjectiveTracker and ScenarioObjectiveTracker.ChallengeModeBlock then
		ScenarioObjectiveTracker.ChallengeModeBlock.timerID = nil
	end

	addon.RefreshDungeonChallengeFrame(true)
end

function addon.IsDungeonChallengeActive()
	return ShouldUseDungeonChallenge()
end

function addon.GetDungeonChallengeElapsedTime()
	return GetElapsedTime()
end
