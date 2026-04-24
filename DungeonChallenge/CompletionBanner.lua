local addonName, addon = ...

local challenge = addon.DungeonChallenge
local L = addon.L

local PARTY_MEMBER_DISTANCE = -131
local PARTY_MEMBER_WIDTH = 61
local PARTY_MEMBER_SPACING = 22

local function StopTimer(timerHandle)
	if timerHandle and timerHandle.Cancel then
		timerHandle:Cancel()
	end
end

local function ResetBannerVisualState(banner)
	if not banner then
		return
	end

	banner:SetAlpha(1)
	banner.BannerTop:SetAlpha(0)
	banner.BannerTopGlow:SetAlpha(0)
	banner.BannerBottom:SetAlpha(0)
	banner.BannerBottomGlow:SetAlpha(0)
	banner.BannerMiddle:SetAlpha(0)
	banner.BannerMiddleGlow:SetAlpha(0)
	banner.SkullCircle:SetAlpha(0)
	banner.BottomFillagree:SetAlpha(0)
	banner.RightFillagree:SetAlpha(0)
	banner.LeftFillagree:SetAlpha(0)
	banner.Title:SetAlpha(0)
	banner.DescriptionLineOne:SetAlpha(0)
	banner.DescriptionLineTwo:SetAlpha(0)
	banner.DescriptionLineThree:SetAlpha(0)
	banner.Glow:SetAlpha(0)
end

local function ReanchorPartyMembers(partyMembers, relativeTo, distance)
	if not partyMembers or not relativeTo then
		return
	end

	local activeMembers = {}
	for _, memberFrame in ipairs(partyMembers) do
		if memberFrame then
			table.insert(activeMembers, memberFrame)
		end
	end

	local count = #activeMembers
	if count == 0 then
		return
	end

	local totalWidth = (count * PARTY_MEMBER_WIDTH) + ((count - 1) * PARTY_MEMBER_SPACING)
	local startOffset = -(totalWidth / 2)
	for index, memberFrame in ipairs(activeMembers) do
		memberFrame:ClearAllPoints()
		memberFrame:SetPoint("TOPLEFT", relativeTo, "TOP", startOffset + ((index - 1) * (PARTY_MEMBER_WIDTH + PARTY_MEMBER_SPACING)), distance)
	end
end

local function LoadChallengesUI()
	if ChallengeModeCompleteBanner then
		return true
	end

	if UIParentLoadAddOn then
		UIParentLoadAddOn("Blizzard_ChallengesUI")
	elseif C_AddOns and C_AddOns.LoadAddOn then
		C_AddOns.LoadAddOn("Blizzard_ChallengesUI")
	end

	return ChallengeModeCompleteBanner ~= nil
end

local function CanUseBannerUnit(unitToken)
	if not unitToken or not UnitExists or not UnitExists(unitToken) then
		return false
	end

	return UnitName(unitToken) ~= nil and UnitClass(unitToken) ~= nil
end

local function BuildBannerUnitTokens()
	local units = {}
	for _, unitToken in ipairs({ "player", "party1", "party2", "party3", "party4" }) do
		if CanUseBannerUnit(unitToken) then
			table.insert(units, unitToken)
		end
	end

	return units
end

local function BuildRunDescriptionData()
	local run = challenge.GetRunRecord and challenge.GetRunRecord() or nil
	if not run or not run.completedAt then
		return nil
	end

	local elapsedTime = challenge.GetElapsedTime and challenge.GetElapsedTime() or 0
	local lineOne = L.DUNGEON_CHALLENGE_COMPLETION_FINISHED
	local lineTwo = L.DUNGEON_CHALLENGE_COMPLETION_TIME_VALUE:format(SecondsToClock(elapsedTime))
	local lineTwoColor = { 0.2, 1, 0.2 }

	return {
		lineOne = lineOne,
		lineTwo = lineTwo,
		lineTwoColor = lineTwoColor,
	}
end

local function BuildCompletionInfo()
	local mapName = GetInstanceInfo()
	local level = challenge.GetChallengeLevel()
	local runDescription = BuildRunDescriptionData()
	local unitTokens = BuildBannerUnitTokens()

	if not runDescription then
		return nil, L.DUNGEON_CHALLENGE_COMPLETION_PENDING
	end

	if not mapName then
		return nil, L.DUNGEON_CHALLENGE_UNKNOWN_DUNGEON
	end

	if not level then
		return nil, L.UNKNOWN
	end

	if #unitTokens == 0 then
		return nil, L.UNKNOWN
	end

	return {
		isLevel20Banner = true,
		mapName = mapName,
		level = level,
		runDescription = runDescription,
		unitTokens = unitTokens,
	}
end

local function RestoreCompletionBanner(banner)
	if not banner or not banner.Level20PatchedBanner then
		return
	end

	banner.PlayBanner = banner.Level20OriginalPlayBanner
	banner.StopBanner = banner.Level20OriginalStopBanner
	banner.unitTokens = banner.Level20OriginalUnitTokens or banner.unitTokens
	banner.Level20ActiveCompletionInfo = nil
	banner.Level20PatchedBanner = nil
end

local function PatchCompletionBannerForPlayback(banner, completionInfo)
	if not banner then
		return nil
	end

	if banner.Level20PatchedBanner then
		RestoreCompletionBanner(banner)
	end

	banner.Level20OriginalPlayBanner = banner.PlayBanner
	banner.Level20OriginalStopBanner = banner.StopBanner
	banner.Level20OriginalUnitTokens = banner.unitTokens
	banner.Level20ActiveCompletionInfo = completionInfo
	banner.Level20PatchedBanner = true

	function banner:StopBanner()
		local originalStopBanner = self.Level20OriginalStopBanner
		RestoreCompletionBanner(self)
		return originalStopBanner(self)
	end

	function banner:PlayBanner(challengeCompletionInfo)
		if challengeCompletionInfo ~= self.Level20ActiveCompletionInfo then
			local originalPlayBanner = self.Level20OriginalPlayBanner
			RestoreCompletionBanner(self)
			return originalPlayBanner(self, challengeCompletionInfo)
		end

		local unitTokens = challengeCompletionInfo.unitTokens or {}
		self.unitTokens = unitTokens

		StopTimer(self.AnimOutTimer)
		self.AnimOutTimer = nil
		self.AnimOut:Stop()
		self.AnimIn:Stop()
		ResetBannerVisualState(self)

		self.Title:SetText(challengeCompletionInfo.mapName or L.DUNGEON_CHALLENGE_UNKNOWN_DUNGEON)

		local levelText = tostring(challengeCompletionInfo.level or 0)
		self.Level:SetText(levelText)
		self.Level:ClearAllPoints()
		if tonumber(levelText:sub(1, 1)) == 1 then
			self.Level:SetPoint("CENTER", self.SkullCircle, "CENTER", -4, 0)
		else
			self.Level:SetPoint("CENTER", self.SkullCircle, "CENTER", 0, 0)
		end
		self.Level:Show()

		local runDescription = challengeCompletionInfo.runDescription or BuildRunDescriptionData()
		self.DescriptionLineOne:SetText(runDescription.lineOne or "")
		self.DescriptionLineTwo:SetText(runDescription.lineTwo or "")
		if runDescription.lineTwoColor then
			self.DescriptionLineTwo:SetTextColor(unpack(runDescription.lineTwoColor))
		else
			self.DescriptionLineTwo:SetTextColor(1, 1, 1)
		end

		self.DescriptionLineThree:SetText("")
		self.DescriptionLineThree:Hide()

		self:CreateAndPositionPartyMembers(#unitTokens)

		for index = 1, #self.PartyMembers do
			if index > #unitTokens then
				self.PartyMembers[index]:Hide()
			end
		end

		ReanchorPartyMembers(self.PartyMembers, self.Title, PARTY_MEMBER_DISTANCE + 24)

		self:Show()
		self.AnimIn:Play()

		for index, unitToken in ipairs(unitTokens) do
			self.PartyMembers[index]:SetUp(unitToken)
		end

		self.AnimOutTimer = C_Timer.NewTimer(self.timeToHold or 8, GenerateClosure(self.PerformAnimOut, self))
	end

	return banner
end

function challenge.ShowCompletionBanner(completionInfo)
	if not LoadChallengesUI() then
		return false, "Blizzard_ChallengesUI"
	end

	local banner = ChallengeModeCompleteBanner
	if not banner then
		return false, "ChallengeModeCompleteBanner"
	end

	local resolvedCompletionInfo, buildError = completionInfo or BuildCompletionInfo()
	if not resolvedCompletionInfo then
		return false, buildError or L.UNKNOWN
	end

	banner = PatchCompletionBannerForPlayback(banner, resolvedCompletionInfo)
	banner:PlayBanner(resolvedCompletionInfo)
	return true
end
