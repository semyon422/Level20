local addonName, addon = ...

local challenge = addon.DungeonChallenge
local constants = challenge.constants

function challenge.refresh(forceShow)
	if forceShow then
		Level20DB.showDungeonChallengeFrame = true
	end

	challenge.InstallHooks()
	if challenge.ShouldUse() then
		challenge.RefreshEncounterCriteria()
		local run = challenge.GetRunRecord()
		if run and run.completedAt and not challenge.HasShownCompletionBanner(run) and not challenge.state.completionBannerTimer then
			challenge.TriggerCompletionBanner(run)
		end
	end
	challenge.ActivateBlizzardBlock()
end

function challenge.setEnabled(enabled)
	Level20DB.showDungeonChallengeFrame = enabled and true or false
	challenge.refresh(Level20DB.showDungeonChallengeFrame)
end

function challenge.resetTimer()
	if InCombatLockdown and InCombatLockdown() then
		return
	end

	Level20DB.showDungeonChallengeFrame = true
	challenge.ClearRunRecord()

	if ScenarioTimerFrame then
		ScenarioTimerFrame:StopTimer(constants.FAKE_TIMER_ID)
	end

	if ScenarioObjectiveTracker and ScenarioObjectiveTracker.ChallengeModeBlock then
		ScenarioObjectiveTracker.ChallengeModeBlock.timerID = nil
	end

	challenge.refresh(true)
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
