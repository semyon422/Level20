local addonName, addon = ...

local challenge = addon.DungeonChallenge

function challenge.refresh(forceShow)
	if forceShow then
		Level20DB.showDungeonChallengeFrame = true
	end

	challenge.InstallHooks()
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

function challenge.AutoResetTimerIfNeeded()
	local run = challenge.GetRunRecord()
	local status = challenge.GetStatus()
	local isStopped = challenge.IsTimerStopped(run)
	local elapsedTime = challenge.GetElapsedTime()
	local liveScenarioState = challenge.GetLiveScenarioState()
	local isFreshDungeon = challenge.IsFreshDungeonForAutoReset(status, liveScenarioState)

	if isStopped and elapsedTime > 0 and isFreshDungeon then
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
