local addonName, addon = ...

local challenge = addon.DungeonChallenge
local constants = challenge.constants
local state = challenge.state

function challenge.UpdateRaidSizeFrameLayout(block)
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

function challenge.UpdateRaidSizeFrame(block)
	if not block or not block.RaidSize then
		return
	end

	local groupSizeText = challenge.GetDungeonGroupSizeText()
	if not groupSizeText then
		block.RaidSize:Hide()
		return
	end

	block.RaidSize.Count:SetText(groupSizeText)
	challenge.UpdateRaidSizeFrameLayout(block)
	block.RaidSize:Show()
end

function challenge.UpdateDeathCountFrame(block)
	local deathCount = block and block.DeathCount
	if not deathCount then
		return
	end

	local count = challenge.GetDeathCount()
	block.deathCount = count
	block.timeLost = 0

	if count > 0 then
		deathCount:Show()
		deathCount.Count:SetText(count)
	else
		deathCount:Hide()
	end

	challenge.UpdateRaidSizeFrameLayout(block)
end

function challenge.RefreshDeathCountDisplay()
	if not ScenarioObjectiveTracker or not ScenarioObjectiveTracker.ChallengeModeBlock then
		return false
	end

	local block = ScenarioObjectiveTracker.ChallengeModeBlock
	if block.timerID ~= constants.FAKE_TIMER_ID then
		return false
	end

	challenge.UpdateDeathCountFrame(block)
	return true
end

function challenge.EnsureRaidSizeFrame(block)
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
	challenge.UpdateRaidSizeFrameLayout(block)
end

function challenge.ActivateBlizzardBlock()
	if not challenge.ShouldUse() then
		if ScenarioTimerFrame then
			ScenarioTimerFrame:StopTimer(constants.FAKE_TIMER_ID)
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

	local run = challenge.GetRunRecord()
	local block = ScenarioObjectiveTracker.ChallengeModeBlock
	challenge.EnsureRaidSizeFrame(block)
	if not state.challengeBlockPatched then
		local originalUpdateTime = block.UpdateTime
		local originalUpdateDeathCount = block.UpdateDeathCount
		block.UpdateTime = function(self, elapsedTime)
			if challenge.ShouldUse() and self.timerID == constants.FAKE_TIMER_ID then
				local effectiveElapsedTime = challenge.GetElapsedTime()
				local statusBar = self.StatusBar
				local displayedElapsedTime = math.min(effectiveElapsedTime, constants.TIME_LIMIT_SECONDS)
				statusBar:SetValue(constants.TIME_LIMIT_SECONDS - displayedElapsedTime)
				self.TimeLeft:SetTextColor(HIGHLIGHT_FONT_COLOR:GetRGB())
				self.TimeLeft:SetText(SecondsToClock(effectiveElapsedTime))
				self.StartedDepleted:Hide()
				self.TimesUpLootStatus:Hide()
			else
				originalUpdateTime(self, elapsedTime)
			end
		end
		block.UpdateDeathCount = function(self, ...)
			if challenge.ShouldUse() and self.timerID == constants.FAKE_TIMER_ID then
				challenge.UpdateDeathCountFrame(self)
			else
				originalUpdateDeathCount(self, ...)
				challenge.UpdateRaidSizeFrame(self)
			end
		end
		state.challengeBlockPatched = true
	end

	if not state.scenarioTimerPatched then
		local originalStartTimer = ScenarioTimerFrame.StartTimer
		ScenarioTimerFrame.StartTimer = function(self, activeBlock)
			if activeBlock and activeBlock.timerID == constants.FAKE_TIMER_ID and not challenge.IsTimerStarted() then
				self:Hide()
				self.baseTime = nil
				self.timeSinceBase = nil
				self.block = nil
				return
			end

			originalStartTimer(self, activeBlock)
		end
		state.scenarioTimerPatched = true
	end

	if not block:IsActive() or block.timerID ~= constants.FAKE_TIMER_ID then
		block:Activate(constants.FAKE_TIMER_ID, challenge.GetElapsedTime(), constants.TIME_LIMIT_SECONDS)
	elseif run and run.startedAt and ScenarioTimerFrame.block ~= block then
		ScenarioTimerFrame:StartTimer(block)
	elseif run and run.completedAt then
		block:UpdateTime(challenge.GetElapsedTime())
	end

	if block.Level then
		block.Level:SetText(challenge.GetChallengeLevelDisplayText())
	end

	challenge.UpdateDeathCountFrame(block)
	challenge.UpdateRaidSizeFrame(block)

	if InCombatLockdown and InCombatLockdown() then
		return true
	end

	ScenarioObjectiveTracker:SetShouldShowCriteria(true)
	ScenarioObjectiveTracker:ForceExpand()
	ScenarioObjectiveTracker:MarkDirty()
	return true
end

function challenge.StartVisibleTimerIfNeeded()
	if not ScenarioTimerFrame or not ScenarioObjectiveTracker or not ScenarioObjectiveTracker.ChallengeModeBlock then
		return
	end

	local block = ScenarioObjectiveTracker.ChallengeModeBlock
	if block.timerID == constants.FAKE_TIMER_ID then
		ScenarioTimerFrame:StartTimer(block)
	end
end
