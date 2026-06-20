local addonName, addon = ...

local challenge = addon.DungeonChallenge
local constants = challenge.constants

function challenge.refresh(forceShow)
	if forceShow then
		Level20DB.showDungeonChallengeFrame = true
	end

	if challenge.ShouldUse() then
		challenge.RefreshEncounterCriteria()
		challenge.AutoResetTimerIfNeeded()
		local run = challenge.GetRunRecord()
		if run and run.completedAt and not challenge.HasShownCompletionBanner(run) and not challenge.state.completionBannerTimer then
			challenge.TriggerCompletionBanner(run)
		end
	end
	challenge.ActivateBlizzardBlock()
end

function challenge.SetEnemyForcesMode(mode)
	if mode ~= addon.ENEMY_FORCES_MODE_REQUIRED and mode ~= addon.ENEMY_FORCES_MODE_UNLIMITED then
		mode = addon.ENEMY_FORCES_MODE_DISABLED
	end

	Level20DB.enemyForcesMode = mode
	challenge.refresh(Level20DB.showDungeonChallengeFrame)
end

function challenge.SetScoreCriteriaEnabled(enabled)
	Level20DB.showDungeonChallengeScoreCriteria = enabled and true or false
	challenge.refresh(Level20DB.showDungeonChallengeFrame)
end

function challenge.AutoResetTimerIfNeeded()
	local run = challenge.GetRunRecord()
	local isStopped = challenge.IsTimerStopped(run)
	local elapsedTime = challenge.GetElapsedTime()
	local liveScenarioState = challenge.GetLiveScenarioState()
	local isFreshDungeon = challenge.IsFreshDungeonForAutoReset(liveScenarioState)
	local hasAutoResetDelay = run
		and run.completedAt
		and (challenge.GetCurrentServerTime() - run.completedAt) >= constants.AUTORESET_DELAY_SECONDS

	if isStopped and elapsedTime > 0 and isFreshDungeon and hasAutoResetDelay then
		return challenge.ResetTimerState()
	end

	return false
end

function challenge.setEnabled(enabled)
	Level20DB.showDungeonChallengeFrame = enabled and true or false
	challenge.refresh(Level20DB.showDungeonChallengeFrame)
end

function challenge.resetTimer()
	if challenge.ResetTimerState() then
		challenge.refresh(true)
	end
end

function challenge.startTimer()
	if not challenge.ShouldUse() then
		return
	end

	if challenge.StartRun(challenge.GetRunRecord()) then
		challenge.refresh(true)
		challenge.StartVisibleTimerIfNeeded()
	end
end

function challenge.completeRun()
	if not challenge.ShouldUse() then
		return
	end

	if challenge.CompleteRun(challenge.GetRunRecord()) then
		challenge.refresh(true)
	end
end
