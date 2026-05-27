local addonName, addon = ...

local challenge = addon.DungeonChallenge
local constants = challenge.constants
local state = challenge.state

local function AddScenarioStyleProgressBar(objectivesBlock, line, lineSpacing, percent)
	if not objectivesBlock or not line or not objectivesBlock.parentModule then
		return nil
	end

	local parentModule = objectivesBlock.parentModule
	parentModule.usedEnemyForcesProgressBars = parentModule.usedEnemyForcesProgressBars or {}

	local progressBar = parentModule.usedEnemyForcesProgressBars[line]
	if not progressBar then
		progressBar = parentModule:AcquireFrame("ScenarioProgressBarTemplate")
		parentModule.usedEnemyForcesProgressBars[line] = progressBar
		progressBar:Show()
		if not progressBar.height then
			progressBar.height = progressBar:GetHeight()
		end
	end

	progressBar.used = true
	if progressBar.Bar then
		if progressBar.Bar.Icon then
			progressBar.Bar.Icon:Hide()
		end
		if progressBar.Bar.IconBG then
			progressBar.Bar.IconBG:Hide()
		end
		if progressBar.Bar.BarGlow then
			progressBar.Bar.BarGlow:SetAtlas("bonusobjectives-bar-glow", true)
		end
	end
	lineSpacing = lineSpacing or objectivesBlock.parentModule.lineSpacing

	local anchor = objectivesBlock.lastRegion or objectivesBlock.HeaderText
	if anchor then
		progressBar:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -lineSpacing)
	else
		progressBar:SetPoint("TOPLEFT", 0, -lineSpacing)
	end

	line.progressBar = progressBar
	progressBar.parentLine = line

	objectivesBlock.height = objectivesBlock.height + progressBar.height + lineSpacing
	objectivesBlock.lastRegion = progressBar
	local isManaged = true
	objectivesBlock:OnAddedRegion(progressBar, isManaged)

	if progressBar.SetValue then
		progressBar:SetValue(percent or 0)
	end

	return progressBar
end

local function AddCriteriaLine(objectivesBlock, objectiveKey, criteriaInfo, progressBarLineSpacing)
	local criteriaString = criteriaInfo.description
	if not criteriaInfo.isWeightedProgress and not criteriaInfo.isFormatted then
		criteriaString = string.format("%d/%d %s", criteriaInfo.quantity, criteriaInfo.totalQuantity, criteriaInfo.description)
	end

	if criteriaInfo.syntheticEnemyForces then
		local line
		if criteriaInfo.completed then
			local existingLine = objectivesBlock:GetExistingLine(objectiveKey)
			line = objectivesBlock:AddObjective(objectiveKey, criteriaString, nil, nil, OBJECTIVE_DASH_STYLE_HIDE, OBJECTIVE_TRACKER_COLOR["Complete"])
			line.Icon:Show()
			line.Icon:SetAtlas("ui-questtracker-tracker-check", false)
			line.progressBar = nil
			if existingLine and (not line.state or line.state == ObjectiveTrackerAnimLineState.Present) then
				line:SetState(ObjectiveTrackerAnimLineState.Completing)
			end
		else
			line = objectivesBlock:AddObjective(objectiveKey, criteriaString, nil, nil, OBJECTIVE_DASH_STYLE_HIDE)
			line.Icon:Show()
			line.Icon:SetAtlas("ui-questtracker-objective-nub", false)
			AddScenarioStyleProgressBar(objectivesBlock, line, progressBarLineSpacing, tonumber(criteriaInfo.quantity) or 0)
		end
		return
	end

	local line
	if criteriaInfo.completed then
		local existingLine = objectivesBlock:GetExistingLine(objectiveKey)
		line = objectivesBlock:AddObjective(objectiveKey, criteriaString, nil, nil, OBJECTIVE_DASH_STYLE_HIDE, OBJECTIVE_TRACKER_COLOR["Complete"])
		line.Icon:Show()
		line.Icon:SetAtlas("ui-questtracker-tracker-check", false)
		if existingLine and (not line.state or line.state == ObjectiveTrackerAnimLineState.Present) then
			line:SetState(ObjectiveTrackerAnimLineState.Completing)
		end
	else
		line = objectivesBlock:AddObjective(objectiveKey, criteriaString, nil, nil, OBJECTIVE_DASH_STYLE_HIDE)
		line.Icon:Show()
		line.Icon:SetAtlas("ui-questtracker-objective-nub", false)
	end

	if criteriaInfo.isWeightedProgress and not criteriaInfo.completed then
		objectivesBlock:AddProgressBar(objectiveKey, progressBarLineSpacing)
	end

	if criteriaInfo.duration > 0 and criteriaInfo.elapsed <= criteriaInfo.duration then
		objectivesBlock:AddTimerBar(criteriaInfo.duration, GetTime() - criteriaInfo.elapsed)
	end
end

local customTrackerModuleMixin = {}

local function GetCustomTrackerHeaderText()
	local status = challenge.GetStatus()
	if status and status.name and status.name ~= "" then
		return status.name
	end

	return TRACKER_HEADER_DUNGEON
end

local function ApplyFakeChallengeModeState(challengeBlock, elapsedTime, timeLimit)
	if not challengeBlock then
		return
	end

	challenge.EnsureBattleResFrame(challengeBlock)
	challenge.EnsureRaidSizeFrame(challengeBlock)
	challengeBlock.timerID = constants.FAKE_TIMER_ID
	challengeBlock.timeLimit = timeLimit
	challengeBlock.lastMedalShown = nil
	challengeBlock.Level:SetText(challenge.GetChallengeLevelDisplayText())
	challengeBlock.wasDepleted = false
	challengeBlock.StartedDepleted:Hide()
	challengeBlock.TimesUpLootStatus:Hide()
	challengeBlock:SetUpAffixes({})
	challenge.UpdateDeathCountFrame(challengeBlock)
	challenge.UpdateBattleResFrame(challengeBlock)
	challenge.UpdateRaidSizeFrame(challengeBlock)

	local statusBar = challengeBlock.StatusBar
	statusBar:SetMinMaxValues(0, timeLimit)
	local displayedElapsedTime = math.min(elapsedTime, timeLimit)
	statusBar:SetValue(timeLimit - displayedElapsedTime)
	challengeBlock.TimeLeft:SetTextColor(HIGHLIGHT_FONT_COLOR:GetRGB())
	challengeBlock.TimeLeft:SetText(SecondsToClock(elapsedTime))
	challengeBlock:Show()
end

local function PrepareEmbeddedChallengeModeBlock(parentFrame, parentModule)
	if not ScenarioObjectiveTracker or not ScenarioObjectiveTracker.ChallengeModeBlock then
		return nil
	end

	local challengeBlock = ScenarioObjectiveTracker.ChallengeModeBlock
	state.originalChallengeModeBlockParent = state.originalChallengeModeBlockParent or challengeBlock:GetParent()

	challengeBlock:ClearAllPoints()
	if challengeBlock:GetParent() ~= parentFrame then
		challengeBlock:SetParent(parentFrame)
	end
	challengeBlock.parentModule = parentModule

	ApplyFakeChallengeModeState(challengeBlock, challenge.GetElapsedTime(), constants.TIME_LIMIT_SECONDS)

	return challengeBlock
end

local function PrepareEmbeddedObjectivesBlock(parentFrame, parentModule)
	if not ScenarioObjectiveTracker or not ScenarioObjectiveTracker.ObjectivesBlock then
		return nil
	end

	local objectivesBlock = ScenarioObjectiveTracker.ObjectivesBlock
	state.originalObjectivesBlockParent = state.originalObjectivesBlockParent or objectivesBlock:GetParent()

	if objectivesBlock:GetParent() ~= parentFrame then
		objectivesBlock:SetParent(parentFrame)
	end
	objectivesBlock.parentModule = parentModule
	objectivesBlock:Reset()

	return objectivesBlock
end

local function RestoreEmbeddedChallengeModeBlockParent()
	if not ScenarioObjectiveTracker or not ScenarioObjectiveTracker.ChallengeModeBlock or not state.originalChallengeModeBlockParent then
		return
	end

	local challengeBlock = ScenarioObjectiveTracker.ChallengeModeBlock
	if challengeBlock:GetParent() ~= state.originalChallengeModeBlockParent then
		challengeBlock:ClearAllPoints()
		challengeBlock:SetParent(state.originalChallengeModeBlockParent)
	end
end

local function RestoreEmbeddedObjectivesBlockParent()
	if not ScenarioObjectiveTracker or not ScenarioObjectiveTracker.ObjectivesBlock or not state.originalObjectivesBlockParent then
		return
	end

	local objectivesBlock = ScenarioObjectiveTracker.ObjectivesBlock
	if objectivesBlock:GetParent() ~= state.originalObjectivesBlockParent then
		objectivesBlock:SetParent(state.originalObjectivesBlockParent)
	end
end

function customTrackerModuleMixin:CanUpdate()
	return true
end

function customTrackerModuleMixin:MarkProgressBarsUnused()
	ObjectiveTrackerModuleMixin.MarkProgressBarsUnused(self)

	if self.usedEnemyForcesProgressBars then
		for _, progressBar in pairs(self.usedEnemyForcesProgressBars) do
			progressBar.used = nil
		end
	end
end

function customTrackerModuleMixin:FreeUnusedProgressBars()
	ObjectiveTrackerModuleMixin.FreeUnusedProgressBars(self)

	if self.usedEnemyForcesProgressBars then
		for key, progressBar in pairs(self.usedEnemyForcesProgressBars) do
			if not progressBar.used then
				self.usedEnemyForcesProgressBars[key] = nil
				if progressBar.OnFree then
					progressBar:OnFree()
				end
				ObjectiveTrackerManager:ReleaseFrame(progressBar)
			end
		end
	end
end

function customTrackerModuleMixin:InitModule()
	self:SetHeader(GetCustomTrackerHeaderText())
	self.Header:SetPoint("TOPLEFT", self, "TOPLEFT", self.blockOffsetX, 0)
	self:SetWidth(self:GetWidth() + self.blockOffsetX)
end

function customTrackerModuleMixin:LayoutContents()
	if not challenge.ShouldUse() then
		return
	end

	self.Header.Text:SetText(GetCustomTrackerHeaderText())

	local challengeBlock = PrepareEmbeddedChallengeModeBlock(self.ContentsFrame, self)
	if challengeBlock then
		self:LayoutBlock(challengeBlock)
	end

	local objectivesBlock = PrepareEmbeddedObjectivesBlock(self.ContentsFrame, self)
	if objectivesBlock and #state.encounterCriteria > 0 then
		for index, criteriaInfo in ipairs(state.encounterCriteria) do
			local objectiveKey = "criteria" .. tostring(criteriaInfo.criteriaID or criteriaInfo.assetID or index)
			AddCriteriaLine(objectivesBlock, objectiveKey, criteriaInfo, self.progressBarLineSpacing)
		end
	end

	if objectivesBlock then
		if #state.encounterCriteria == 0 then
			objectivesBlock:AddObjective("placeholder", challenge.L.DUNGEON_CHALLENGE_SUBTITLE, nil, nil, OBJECTIVE_DASH_STYLE_HIDE, OBJECTIVE_TRACKER_COLOR["Normal"])
		end

		if objectivesBlock.height > 0 then
			self:LayoutBlock(objectivesBlock)
		end
	end
end

function challenge.EnsureCustomTrackerModule()
	if state.customTrackerModule then
		return state.customTrackerModule
	end

	if not ObjectiveTrackerFrame or not ObjectiveTrackerManager or not ObjectiveTrackerModuleMixin then
		return nil
	end

	local module = CreateFrame("Frame", "Level20DungeonChallengeObjectiveTracker", ObjectiveTrackerFrame, "ObjectiveTrackerModuleTemplate")
	Mixin(module, customTrackerModuleMixin)
	module.blockTemplate = "ObjectiveTrackerAnimBlockTemplate"
	module.lineTemplate = "ObjectiveTrackerAnimLineTemplate"
	module.fromHeaderOffsetY = 0
	module.fromBlockOffsetY = -2
	module.blockOffsetX = 20
	module.lineSpacing = 12
	module.bottomSpacing = 6
	module.progressBarLineSpacing = 2
	module.leftMargin = -20
	module.headerText = TRACKER_HEADER_DUNGEON
	module.hasDisplayPriority = true
	module.uiOrder = (ScenarioObjectiveTracker and ScenarioObjectiveTracker.uiOrder and (ScenarioObjectiveTracker.uiOrder - 0.5)) or 0.5
	module:SetWidth(ScenarioObjectiveTracker and ScenarioObjectiveTracker:GetWidth() or 260)
	module:SetScript("OnUpdate", function(self, elapsed)
		if not challenge.ShouldUse() or not challenge.IsTimerStarted() or challenge.IsTimerStopped() then
			self.elapsedSinceRefresh = 0
			return
		end

		self.elapsedSinceRefresh = (self.elapsedSinceRefresh or 0) + elapsed
		if self.elapsedSinceRefresh >= 1 then
			self.elapsedSinceRefresh = 0
			self:MarkDirty()
		end
	end)

	state.customTrackerModule = module
	return module
end

function challenge.UpdateRaidSizeFrameLayout(block)
	local raidSizeFrame = block and block.RaidSize
	if not raidSizeFrame then
		return
	end

	raidSizeFrame:ClearAllPoints()
	if block.BattleRes and block.BattleRes:IsShown() then
		raidSizeFrame:SetPoint("RIGHT", block.BattleRes, "LEFT", -4, 0)
	elseif block.DeathCount and block.DeathCount:IsShown() then
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

	deathCount:Show()
	deathCount.Count:SetText(count)

	challenge.UpdateBattleResFrameLayout(block)
	challenge.UpdateRaidSizeFrameLayout(block)
end

function challenge.RefreshDeathCountDisplay()
	if state.customTrackerModule then
		state.customTrackerModule:MarkDirty()
	end

	if not ScenarioObjectiveTracker or not ScenarioObjectiveTracker.ChallengeModeBlock then
		return state.customTrackerModule and true or false
	end

	local block = ScenarioObjectiveTracker.ChallengeModeBlock
	if block.timerID ~= constants.FAKE_TIMER_ID then
		return state.customTrackerModule and true or false
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
	local customTrackerModule = challenge.EnsureCustomTrackerModule()
	if customTrackerModule then
		if not state.customTrackerModuleRegistered and ObjectiveTrackerManager and ObjectiveTrackerFrame then
			ObjectiveTrackerManager:SetModuleContainer(customTrackerModule, ObjectiveTrackerFrame)
			state.customTrackerModuleRegistered = ObjectiveTrackerManager:GetContainerForModule(customTrackerModule) == ObjectiveTrackerFrame
		end

		if ScenarioObjectiveTracker and ObjectiveTrackerFrame then
			if challenge.ShouldUse() then
				if not state.defaultScenarioModuleDetached and ObjectiveTrackerFrame:HasModule(ScenarioObjectiveTracker) then
					ObjectiveTrackerFrame:RemoveModule(ScenarioObjectiveTracker)
					state.defaultScenarioModuleDetached = true
				end

				ScenarioObjectiveTracker:Hide()
				ScenarioObjectiveTracker:SetAlpha(0)
				state.defaultScenarioModuleHidden = true
			else
				if state.defaultScenarioModuleDetached and ObjectiveTrackerManager then
					ObjectiveTrackerManager:SetModuleContainer(ScenarioObjectiveTracker, ObjectiveTrackerFrame)
					state.defaultScenarioModuleDetached = false
				end

				RestoreEmbeddedChallengeModeBlockParent()
				RestoreEmbeddedObjectivesBlockParent()

				ScenarioObjectiveTracker:SetAlpha(1)
				state.defaultScenarioModuleHidden = false
			end
		end

		if ScenarioTimerFrame then
			ScenarioTimerFrame:StopTimer(constants.FAKE_TIMER_ID)
		end

		if ScenarioObjectiveTracker and ScenarioObjectiveTracker.ChallengeModeBlock then
			ScenarioObjectiveTracker.ChallengeModeBlock.timerID = nil
			ScenarioObjectiveTracker.ChallengeModeBlock:Hide()
		end

		if ScenarioObjectiveTracker and ScenarioObjectiveTracker.SetShouldShowCriteria then
			ScenarioObjectiveTracker:SetShouldShowCriteria(not challenge.ShouldUse())
		end

		if challenge.ShouldUse() and ObjectiveTrackerFrame then
			ObjectiveTrackerFrame:ForceExpand()
		end

		if state.customTrackerModuleRegistered and ObjectiveTrackerManager then
			ObjectiveTrackerManager:UpdateModule(customTrackerModule)
		else
			customTrackerModule:MarkDirty()
		end

		return challenge.ShouldUse()
	end

	if not challenge.ShouldUse() then
		if state.defaultScenarioModuleDetached and ObjectiveTrackerManager and ScenarioObjectiveTracker and ObjectiveTrackerFrame then
			ObjectiveTrackerManager:SetModuleContainer(ScenarioObjectiveTracker, ObjectiveTrackerFrame)
			state.defaultScenarioModuleDetached = false
		end

		RestoreEmbeddedChallengeModeBlockParent()
		RestoreEmbeddedObjectivesBlockParent()

		if ScenarioObjectiveTracker and state.defaultScenarioModuleHidden then
			ScenarioObjectiveTracker:SetAlpha(1)
			state.defaultScenarioModuleHidden = false
		end

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
		local originalActivate = block.Activate
		local originalUpdateTime = block.UpdateTime
		local originalUpdateDeathCount = block.UpdateDeathCount
		block.Activate = function(self, timerID, elapsedTime, timeLimit)
			if challenge.ShouldUse() and timerID == constants.FAKE_TIMER_ID then
				ApplyFakeChallengeModeState(self, elapsedTime, timeLimit)
				ScenarioTimerFrame:StartTimer(self)
				ScenarioObjectiveTracker:ForceExpand()
			else
				originalActivate(self, timerID, elapsedTime, timeLimit)
			end
		end
		block.UpdateTime = function(self, elapsedTime)
			if challenge.ShouldUse() and self.timerID == constants.FAKE_TIMER_ID then
				ApplyFakeChallengeModeState(self, challenge.GetElapsedTime(), self.timeLimit or constants.TIME_LIMIT_SECONDS)
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
			if activeBlock and activeBlock.timerID == constants.FAKE_TIMER_ID and challenge.ShouldUse() then
				self.baseTime = challenge.GetElapsedTime()
				self.timeSinceBase = 0
				self.block = activeBlock
				self:Show()
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
	challenge.UpdateBattleResFrame(block)
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
