local addonName, addon = ...

local challenge = addon.DungeonChallenge
local L = addon.L

-- Blizzard ChallengeModeCompleteBanner layout values.
local PARTY_MEMBER_DISTANCE = -131
local PARTY_MEMBER_WIDTH = 61
local PARTY_MEMBER_SPACING = 22
local BANNER_BASE_HEIGHT = 356

-- Level20 raid banner layout tuning.
local PARTY_MEMBERS_PER_ROW = 10

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

local function ResetCompletionBannerLayout(banner)
	if not banner then
		return
	end

	banner:SetHeight(BANNER_BASE_HEIGHT)
	for _, texture in ipairs({ banner.BannerTop, banner.BannerTopGlow, banner.BannerBottom, banner.BannerBottomGlow }) do
		if texture and texture.Level20OriginalWidth then
			texture:SetWidth(texture.Level20OriginalWidth)
		end
	end
end

local function BuildPartyMemberRows(count)
	if count <= 0 then
		return {}
	end

	if count <= 5 then
		return { count }
	end

	if count <= PARTY_MEMBERS_PER_ROW then
		return { 5, count - 5 }
	end

	local rows = {}
	local remaining = count
	while remaining > 0 do
		local rowMemberCount = math.min(PARTY_MEMBERS_PER_ROW, remaining)
		table.insert(rows, rowMemberCount)
		remaining = remaining - rowMemberCount
	end

	return rows
end

local function ExpandCompletionBannerForPartyMembers(banner, count, rowDistance)
	local rows = BuildPartyMemberRows(count)
	local extraHeight = math.max(0, #rows - 1) * math.abs(rowDistance)
	local maxRowMemberCount = 0
	for _, rowMemberCount in ipairs(rows) do
		maxRowMemberCount = math.max(maxRowMemberCount, rowMemberCount)
	end

	banner:SetHeight(BANNER_BASE_HEIGHT + extraHeight)
	for _, texture in ipairs({ banner.BannerTop, banner.BannerTopGlow, banner.BannerBottom, banner.BannerBottomGlow }) do
		if texture then
			texture.Level20OriginalWidth = texture.Level20OriginalWidth or texture:GetWidth()
			local extraMemberCount = math.max(0, maxRowMemberCount - 5)
			local extraWidth = extraMemberCount * (PARTY_MEMBER_WIDTH + PARTY_MEMBER_SPACING)
			local bannerWidth = texture.Level20OriginalWidth + extraWidth
			texture:SetWidth(math.max(texture.Level20OriginalWidth, bannerWidth))
		end
	end
end

local function ReanchorPartyMembers(partyMembers, relativeTo, distance, count)
	if not partyMembers or not relativeTo then
		return
	end

	count = math.min(count or #partyMembers, #partyMembers)
	if count == 0 then
		return
	end

	local rows = BuildPartyMemberRows(count)
	local memberIndex = 1
	for rowIndex, rowMemberCount in ipairs(rows) do
		local totalWidth = (rowMemberCount * PARTY_MEMBER_WIDTH) + ((rowMemberCount - 1) * PARTY_MEMBER_SPACING)
		local startOffset = -(totalWidth / 2)

		for column = 0, rowMemberCount - 1 do
			local memberFrame = partyMembers[memberIndex]
			memberFrame:SetScale(1)
			memberFrame:ClearAllPoints()
			memberFrame:SetPoint("TOPLEFT", relativeTo, "TOP", startOffset + (column * (PARTY_MEMBER_WIDTH + PARTY_MEMBER_SPACING)), distance + ((rowIndex - 1) * distance))
			memberIndex = memberIndex + 1
		end
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

	if IsInRaid and IsInRaid() then
		for index = 1, GetNumGroupMembers() do
			local unitToken = "raid" .. index
			if CanUseBannerUnit(unitToken) then
				table.insert(units, unitToken)
			end
		end
	else
		for _, unitToken in ipairs({ "player", "party1", "party2", "party3", "party4" }) do
			if CanUseBannerUnit(unitToken) then
				table.insert(units, unitToken)
			end
		end
	end

	return units
end

local function GetCompletionFinishedText()
	local status = challenge.GetStatus and challenge.GetStatus() or nil
	if status and status.instanceType == "raid" then
		return L.DUNGEON_CHALLENGE_COMPLETION_RAID_FINISHED
	end

	return L.DUNGEON_CHALLENGE_COMPLETION_FINISHED
end

local function BuildRunDescriptionData()
	local run = challenge.GetRunRecord and challenge.GetRunRecord() or nil
	if not run or not run.completedAt then
		return nil
	end

	local elapsedTime = challenge.GetElapsedTime and challenge.GetElapsedTime() or 0
	local lineOne = GetCompletionFinishedText()
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

	if not runDescription or not mapName or not level or #unitTokens == 0 then
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
	ResetCompletionBannerLayout(banner)
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
		local partyMemberDistance = PARTY_MEMBER_DISTANCE + 24
		ExpandCompletionBannerForPartyMembers(self, #unitTokens, partyMemberDistance)

		self.Title:SetText(challengeCompletionInfo.mapName or L.UNKNOWN)

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

		ReanchorPartyMembers(self.PartyMembers, self.Title, partyMemberDistance, #unitTokens)

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

function challenge.ShowTestCompletionBanner(playerCount)
	playerCount = math.max(1, math.min(40, tonumber(playerCount) or 1))

	local unitTokens = {}
	for index = 1, playerCount do
		unitTokens[index] = "player"
	end

	return challenge.ShowCompletionBanner({
		isLevel20Banner = true,
		mapName = GetInstanceInfo() or addonName,
		level = challenge.GetChallengeLevel(),
		runDescription = {
			lineOne = GetCompletionFinishedText(),
			lineTwo = L.DUNGEON_CHALLENGE_COMPLETION_TIME_VALUE:format(SecondsToClock(challenge.GetElapsedTime and challenge.GetElapsedTime() or 0)),
			lineTwoColor = { 0.2, 1, 0.2 },
		},
		unitTokens = unitTokens,
	})
end
