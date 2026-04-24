local addonName, addon = ...
local L = addon.L

local FAKE_TIMER_ID = 200020
local FAKE_AFFIX_ID = 200020
local FAKE_SCENARIO_ID = 200020
local TIME_LIMIT_SECONDS = 30 * 60

local hooksInstalled = false
local challengeBlockPatched = false
local scenarioTimerPatched = false
local encounterCriteria = {}
local observedDungeonInstanceID
local observedDungeonLevel

local originals = {}
local patched = {}

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

local function GetDungeonDifficultyText()
	local status = GetDungeonChallengeStatus()
	if not status then
		return nil
	end

	local difficultyName
	if DifficultyUtil and DifficultyUtil.GetDifficultyName and status.difficultyID then
		difficultyName = DifficultyUtil.GetDifficultyName(status.difficultyID)
	end

	if not difficultyName or difficultyName == "" then
		difficultyName = status.difficultyName
	end

	if not difficultyName or difficultyName == "" then
		return nil
	end

	return difficultyName
end

local function GetDungeonGroupSizeText()
	local status = GetDungeonChallengeStatus()
	if not status or status.instanceType ~= "raid" then
		return nil
	end

	local groupSize = tonumber(status.instanceGroupSize) or tonumber(status.maxPlayers)
	if not groupSize or groupSize <= 0 then
		return nil
	end

	return tostring(groupSize)
end

local function UpdateRaidSizeFrameLayout(block)
	local raidSizeFrame = block and block.RaidSize
	if not raidSizeFrame then
		return
	end

	raidSizeFrame:ClearAllPoints()
	if block.DeathCount and block.DeathCount:IsShown() then
		raidSizeFrame:SetPoint("RIGHT", block.DeathCount, "LEFT", -2, 0)
	else
		raidSizeFrame:SetPoint("TOPRIGHT", block, "BOTTOMRIGHT", -24, 43)
	end
end

local function UpdateRaidSizeFrame(block)
	if not block or not block.RaidSize then
		return
	end

	local groupSizeText = GetDungeonGroupSizeText()
	if not groupSizeText then
		block.RaidSize:Hide()
		return
	end

	block.RaidSize.Count:SetText(groupSizeText)
	UpdateRaidSizeFrameLayout(block)
	block.RaidSize:Show()
end

local function EnsureRaidSizeFrame(block)
	if not block or block.RaidSize then
		return
	end

	local raidSizeFrame = CreateFrame("Frame", nil, block)
	raidSizeFrame:SetSize(30, 16)
	raidSizeFrame:Hide()

	local icon = raidSizeFrame:CreateTexture(nil, "ARTWORK")
	icon:SetAtlas("socialqueuing-icon-group", false)
	icon:SetPoint("LEFT")
	icon:SetSize(14, 14)
	raidSizeFrame.Icon = icon

	local count = raidSizeFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall2")
	count:SetPoint("LEFT", icon, "RIGHT", 0, 0)
	raidSizeFrame.Count = count

	block.RaidSize = raidSizeFrame
	UpdateRaidSizeFrameLayout(block)
end

local function ResetObservedDungeonLevelIfNeeded(status)
	if observedDungeonInstanceID ~= status.instanceID then
		observedDungeonInstanceID = status.instanceID
		observedDungeonLevel = nil
	end
end

local function UpdateObservedDungeonLevel(level)
	level = tonumber(level)
	if not level or level <= 0 then
		return observedDungeonLevel
	end

	level = math.floor(level)
	if not observedDungeonLevel then
		observedDungeonLevel = level
		return observedDungeonLevel
	end

	local difference = level - observedDungeonLevel
	if difference >= 5 then
		observedDungeonLevel = level
	elseif math.abs(difference) < 5 and level % 5 == 0 then
		observedDungeonLevel = level
	end

	return observedDungeonLevel
end

local function ObserveDungeonUnitLevel(unit)
	if not unit or not UnitExists(unit) or not UnitCanAttack("player", unit) then
		return nil
	end

	local level = UnitEffectiveLevel and UnitEffectiveLevel(unit)
	if not level or level <= 0 then
		level = UnitLevel(unit)
	end

	level = tonumber(level)

	if level and level > 0 then
		return UpdateObservedDungeonLevel(level)
	end

	return nil
end

local function GetObservedDungeonLevel()
	local status = GetDungeonChallengeStatus()
	ResetObservedDungeonLevelIfNeeded(status)

	for _, unit in ipairs({ "target", "mouseover", "focus" }) do
		local level = ObserveDungeonUnitLevel(unit)
		if level then
			return level
		end
	end

	return observedDungeonLevel
end

local function GetDungeonChallengeLevel()
	local status = GetDungeonChallengeStatus()
	ResetObservedDungeonLevelIfNeeded(status)

	local observedLevel = GetObservedDungeonLevel()
	if observedLevel and observedLevel > 0 then
		return observedLevel
	end

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

local function GetChallengeLevelDisplayText()
	local levelText = CHALLENGE_MODE_POWER_LEVEL:format(GetDungeonChallengeLevel())
	local difficultyText = GetDungeonDifficultyText()
	if not difficultyText then
		return levelText
	end

	return string.format("%s |cff9d9d9d%s|r", levelText, difficultyText)
end

local function IsRealChallengeModeActive()
	if originals.C_ChallengeMode and originals.C_ChallengeMode.IsChallengeModeActive then
		return originals.C_ChallengeMode.IsChallengeModeActive()
	end

	return false
end

local function IsSupportedDungeonChallengeInstanceType(instanceType)
	return instanceType == "party" or instanceType == "raid"
end

local function ShouldUseDungeonChallenge()
	if not Level20DB.showDungeonChallengeFrame or IsRealChallengeModeActive() then
		return false
	end

	local status = GetDungeonChallengeStatus()
	return status.isInInstance and IsSupportedDungeonChallengeInstanceType(status.instanceType)
end

local function GetCurrentServerTime()
	if GetServerTime then
		return GetServerTime()
	end

	return time()
end

local function GetRunRecord()
	Level20DB.dungeonChallengeTimer = Level20DB.dungeonChallengeTimer or {}
	return Level20DB.dungeonChallengeTimer
end

local function GetEncounterCompletionTimes(run)
	if not run then
		return nil
	end

	run.encounterCompletionTimes = run.encounterCompletionTimes or {}
	return run.encounterCompletionTimes
end

local function GetEncounterCriteriaSnapshot(run)
	if not run then
		return nil
	end

	run.encounterCriteriaSnapshot = run.encounterCriteriaSnapshot or {}
	return run.encounterCriteriaSnapshot
end

local function ClearRunRecord()
	Level20DB.dungeonChallengeTimer = {}
end

local function GetEncounterCompletionKey(criteria)
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

local function GetEncounterCompletionTime(run, criteria)
	if not run or not criteria then
		return nil
	end

	local encounterCompletionTimes = GetEncounterCompletionTimes(run)
	local encounterKey = GetEncounterCompletionKey(criteria)
	if not encounterCompletionTimes or not encounterKey then
		return nil
	end

	return encounterCompletionTimes[encounterKey]
end

local function FormatEncounterDescription(criteria, run)
	if not criteria or not criteria.description then
		return nil
	end

	local description = criteria.description
	if not criteria.completed then
		return description
	end

	local completionTime = GetEncounterCompletionTime(run, criteria)
	if completionTime == nil then
		return description
	end

	return string.format("%s |cff9d9d9d(%s)|r", description, SecondsToClock(completionTime))
end

local function RecordEncounterCompletionTime(run, criteria)
	if not run or not run.startedAt or not criteria or not criteria.completed then
		return nil
	end

	local encounterCompletionTimes = GetEncounterCompletionTimes(run)
	local encounterKey = GetEncounterCompletionKey(criteria)
	if not encounterCompletionTimes or not encounterKey then
		return nil
	end

	if encounterCompletionTimes[encounterKey] == nil then
		local completedElapsed
		if run.completedElapsed then
			completedElapsed = run.completedElapsed
		else
			completedElapsed = math.max(0, GetCurrentServerTime() - run.startedAt)
		end

		encounterCompletionTimes[encounterKey] = math.floor(completedElapsed)
	end

	return encounterCompletionTimes[encounterKey]
end

local function CopyCriteria(criteria)
	if not criteria then
		return nil
	end

	local copy = {}
	for key, value in pairs(criteria) do
		copy[key] = value
	end

	return copy
end

local function SaveEncounterCriteriaSnapshot(run)
	if not run then
		return
	end

	local snapshot = GetEncounterCriteriaSnapshot(run)
	table.wipe(snapshot)

	for index, criteria in ipairs(encounterCriteria) do
		snapshot[index] = CopyCriteria(criteria)
	end
end

local function RestoreEncounterCriteriaSnapshot(run)
	if not run then
		return false
	end

	local snapshot = GetEncounterCriteriaSnapshot(run)
	if #snapshot == 0 then
		return false
	end

	for _, criteria in ipairs(snapshot) do
		table.insert(encounterCriteria, CopyCriteria(criteria))
	end

	return #encounterCriteria > 0
end

local function HasAnyCompletedCriteria(criteriaList)
	if not criteriaList then
		return false
	end

	for _, criteria in ipairs(criteriaList) do
		if criteria.completed then
			return true
		end
	end

	return false
end

local function DoesCriteriaListMatchSnapshot(criteriaList, snapshot)
	if not criteriaList or not snapshot or #criteriaList ~= #snapshot then
		return false
	end

	for index, criteria in ipairs(criteriaList) do
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

local function HasCompletedAllCriteria()
	if #encounterCriteria == 0 then
		return false
	end

	for _, criteria in ipairs(encounterCriteria) do
		if not criteria.completed then
			return false
		end
	end

	return true
end

local function BuildEncounterCriteriaFromJournal(status)
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
	local run = GetRunRecord()
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
				RecordEncounterCompletionTime(run, criteria)
			end
			criteria.description = FormatEncounterDescription(criteria, run)

			table.insert(encounterCriteria, criteria)
		end

		index = index + 1
	end

	return #encounterCriteria > 0
end

local function StartRun(run)
	if not run or run.startedAt or run.completedAt then
		return false
	end

	run.startedAt = GetCurrentServerTime()
	return true
end

local function CompleteRun(run)
	if not run or not run.startedAt or run.completedAt then
		return false
	end

	local now = GetCurrentServerTime()
	run.completedAt = now
	run.completedElapsed = math.max(0, now - run.startedAt)
	return true
end

local function GetElapsedTime()
	local run = GetRunRecord()
	if not run or not run.startedAt then
		return 0
	end

	if run.completedAt then
		return math.max(0, math.floor(run.completedElapsed or (run.completedAt - run.startedAt)))
	end

	return math.max(0, math.floor(GetCurrentServerTime() - run.startedAt))
end

local function IsTimerStarted()
	local run = GetRunRecord()
	return run and run.startedAt and true or false
end

local function RefreshEncounterCriteria()
	table.wipe(encounterCriteria)

	if not C_Scenario or not C_ScenarioInfo then
		BuildEncounterCriteriaFromJournal(GetDungeonChallengeStatus())
		return
	end

	local originalScenario = originals.C_Scenario or C_Scenario
	local originalScenarioInfo = originals.C_ScenarioInfo or C_ScenarioInfo
	local originalGetStepInfo = originalScenario.GetStepInfo
	local originalGetCriteriaInfo = originalScenarioInfo.GetCriteriaInfo
	local run = GetRunRecord()
	local stepOk, _, _, numCriteria = pcall(originalGetStepInfo)
	if stepOk and numCriteria and numCriteria > 0 then
		for index = 1, numCriteria do
			local criteriaOk, criteriaInfo = pcall(originalGetCriteriaInfo, index)
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
					RecordEncounterCompletionTime(run, criteria)
				end
				criteria.description = FormatEncounterDescription(criteria, run)

				table.insert(encounterCriteria, criteria)
			end
		end

		if #encounterCriteria > 0 then
			if run and run.completedAt and not HasAnyCompletedCriteria(encounterCriteria) then
				local snapshot = GetEncounterCriteriaSnapshot(run)
				if DoesCriteriaListMatchSnapshot(encounterCriteria, snapshot) then
					table.wipe(encounterCriteria)
					RestoreEncounterCriteriaSnapshot(run)
					return
				end
			end

			SaveEncounterCriteriaSnapshot(run)
			if run and HasCompletedAllCriteria() then
				CompleteRun(run)
			end

			return
		end
	end

	if BuildEncounterCriteriaFromJournal(GetDungeonChallengeStatus()) then
		local run = GetRunRecord()
		SaveEncounterCriteriaSnapshot(run)
		if run and HasCompletedAllCriteria() then
			CompleteRun(run)
		end
		return
	end

	RestoreEncounterCriteriaSnapshot(run)
end

local function BuildCriteriaInfo(index)
	local criteria = encounterCriteria[index]
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
		return GetDungeonChallengeLevel(), {}, true
		-- return GetDungeonChallengeLevel(), { FAKE_AFFIX_ID }, true
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
		return L.DUNGEON_CHALLENGE_SUBTITLE,
			"",
			#encounterCriteria,
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

	local run = GetRunRecord()
	local block = ScenarioObjectiveTracker.ChallengeModeBlock
	EnsureRaidSizeFrame(block)
	if not challengeBlockPatched then
		local originalUpdateTime = block.UpdateTime
		local originalUpdateDeathCount = block.UpdateDeathCount
		block.UpdateTime = function(self, elapsedTime)
			if ShouldUseDungeonChallenge() and self.timerID == FAKE_TIMER_ID then
				local effectiveElapsedTime = GetElapsedTime()
				local statusBar = self.StatusBar
				local displayedElapsedTime = math.min(effectiveElapsedTime, TIME_LIMIT_SECONDS)
				statusBar:SetValue(TIME_LIMIT_SECONDS - displayedElapsedTime)
				self.TimeLeft:SetTextColor(HIGHLIGHT_FONT_COLOR:GetRGB())
				self.TimeLeft:SetText(SecondsToClock(effectiveElapsedTime))
				self.StartedDepleted:Hide()
				self.TimesUpLootStatus:Hide()
			else
				originalUpdateTime(self, elapsedTime)
			end
		end
		block.UpdateDeathCount = function(self, ...)
			originalUpdateDeathCount(self, ...)
			UpdateRaidSizeFrame(self)
		end
		challengeBlockPatched = true
	end

	if not scenarioTimerPatched then
		local originalStartTimer = ScenarioTimerFrame.StartTimer
		ScenarioTimerFrame.StartTimer = function(self, activeBlock)
			if activeBlock and activeBlock.timerID == FAKE_TIMER_ID and not IsTimerStarted() then
				self:Hide()
				self.baseTime = nil
				self.timeSinceBase = nil
				self.block = nil
				return
			end

			originalStartTimer(self, activeBlock)
		end
		scenarioTimerPatched = true
	end

	if not block:IsActive() or block.timerID ~= FAKE_TIMER_ID then
		block:Activate(FAKE_TIMER_ID, GetElapsedTime(), TIME_LIMIT_SECONDS)
	elseif run and run.startedAt and ScenarioTimerFrame.block ~= block then
		ScenarioTimerFrame:StartTimer(block)
	elseif run and run.completedAt then
		block:UpdateTime(GetElapsedTime())
	end

	if block.Level then
		block.Level:SetText(GetChallengeLevelDisplayText())
	end

	UpdateRaidSizeFrame(block)

	ScenarioObjectiveTracker:SetShouldShowCriteria(true)
	ScenarioObjectiveTracker:ForceExpand()
	ScenarioObjectiveTracker:MarkDirty()
	return true
end

local function StartVisibleTimerIfNeeded()
	if not ScenarioTimerFrame or not ScenarioObjectiveTracker or not ScenarioObjectiveTracker.ChallengeModeBlock then
		return
	end

	local block = ScenarioObjectiveTracker.ChallengeModeBlock
	if block.timerID == FAKE_TIMER_ID then
		ScenarioTimerFrame:StartTimer(block)
	end
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
end

function addon.ResetDungeonChallengeTimer()
	if InCombatLockdown and InCombatLockdown() then
		return
	end

	Level20DB.showDungeonChallengeFrame = true
	ClearRunRecord()

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

function addon.StartDungeonChallengeTimer()
	if not ShouldUseDungeonChallenge() then
		return
	end

	if StartRun(GetRunRecord()) then
		addon.RefreshDungeonChallengeFrame(true)
		StartVisibleTimerIfNeeded()
	end
end
