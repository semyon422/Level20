local addonName, addon = ...
local L = addon.L

-- Known issue: modifying Blizzard's talent frame can taint the protected
-- talent-application casting bar path. RefreshLoadoutOptions, SetNodesFilter,
-- and SetBasePanOffset each reproduced the taint independently in testing.
-- The resulting CastingBarFrame:GetTypeInfo error is an accepted tradeoff for
-- preserving the filtered Blizzard talent window; see README.md.

local talentFilterInstalled = false
local TALENT_ROW_HEIGHT = 600
local TALENT_ROW_OFFSET = 3
local TALENT_POSITION_SCALE = 10
local TALENT_FILTER_RELOAD_POPUP = "LEVEL20_TALENT_FILTER_RELOAD"

StaticPopupDialogs[TALENT_FILTER_RELOAD_POPUP] = {
	text = L.TALENT_FILTER_RELOAD_PROMPT,
	button1 = RELOADUI,
	button2 = LATER,
	OnAccept = ReloadUI,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	preferredIndex = 3,
}

local function GetTalentOwnerLevel(talentsFrame)
	if talentsFrame.IsInspecting and talentsFrame:IsInspecting() and talentsFrame.GetInspectUnit then
		local inspectUnit = talentsFrame:GetInspectUnit()
		if inspectUnit then
			return UnitLevel(inspectUnit)
		end
	end

	return UnitLevel("player")
end

local function ShouldFilterTalents(talentsFrame)
	if not Level20DB.hideHighLevelTalents then
		return false
	end

	local level = GetTalentOwnerLevel(talentsFrame)
	return level and level > 0 and level <= addon.LEVEL_CAP
end

local function PrepareTalentsFrame()
	local talentsFrame = PlayerSpellsFrame and PlayerSpellsFrame.TalentsFrame
	if not talentsFrame then
		return nil
	end

	if talentsFrame.RefreshLoadoutOptions then
		talentsFrame:RefreshLoadoutOptions()
	end

	if talentsFrame.RefreshConfigID then
		talentsFrame:RefreshConfigID()
	end

	return talentsFrame
end

local function IsNodeInfoUnavailableAndUninvested(nodeInfo)
	if not nodeInfo then
		return false
	end

	return not nodeInfo.isAvailable and (nodeInfo.ranksPurchased or 0) == 0 and (nodeInfo.ranksIncreased or 0) == 0
end

local function IsUnavailableAndUninvested(talentsFrame, nodeID)
	return IsNodeInfoUnavailableAndUninvested(C_Traits.GetNodeInfo(talentsFrame:GetConfigID(), nodeID))
end

local function FilterTalentNodes(talentsFrame, nodeIDs)
	if not ShouldFilterTalents(talentsFrame) then
		return nodeIDs
	end

	local filteredNodeIDs = {}

	for _, nodeID in ipairs(nodeIDs) do
		if not IsUnavailableAndUninvested(talentsFrame, nodeID) then
			table.insert(filteredNodeIDs, nodeID)
		end
	end

	return filteredNodeIDs
end

local function ApplyTalentLayoutOffset(talentsFrame)
	if not talentsFrame.SetBasePanOffset then
		return
	end

	local currentBasePanOffsetX = talentsFrame.basePanOffsetX or 0
	local currentBasePanOffsetY = talentsFrame.basePanOffsetY or 0
	local previousOffsetY = talentsFrame.level20AppliedLayoutOffsetY or 0

	local basePanOffsetX = currentBasePanOffsetX
	local basePanOffsetY = currentBasePanOffsetY
	if talentsFrame.level20AdjustedBasePanOffsetX == currentBasePanOffsetX
		and talentsFrame.level20AdjustedBasePanOffsetY == currentBasePanOffsetY then
		basePanOffsetY = currentBasePanOffsetY - previousOffsetY
	end

	local offsetY = ShouldFilterTalents(talentsFrame) and -((TALENT_ROW_HEIGHT * TALENT_ROW_OFFSET) / TALENT_POSITION_SCALE) or 0
	local adjustedBasePanOffsetY = basePanOffsetY + offsetY
	talentsFrame:SetBasePanOffset(basePanOffsetX, adjustedBasePanOffsetY)
	talentsFrame.level20AppliedLayoutOffsetY = offsetY
	talentsFrame.level20AdjustedBasePanOffsetX = basePanOffsetX
	talentsFrame.level20AdjustedBasePanOffsetY = adjustedBasePanOffsetY

	if talentsFrame.UpdateAllTalentButtonPositions then
		talentsFrame:UpdateAllTalentButtonPositions()
	end

	if talentsFrame.UpdateAllGatePositions then
		talentsFrame:UpdateAllGatePositions()
	end
end

function addon.RefreshTalentsFrame()
	if not Level20DB.hideHighLevelTalents then
		return
	end

	local talentsFrame = PrepareTalentsFrame()
	if talentsFrame then
		ApplyTalentLayoutOffset(talentsFrame)
		talentsFrame:LoadTalentTree()
	end
end

function addon.InstallTalentFilter()
	if not Level20DB.hideHighLevelTalents or talentFilterInstalled then
		return
	end

	local talentsFrame = PrepareTalentsFrame()
	if not talentsFrame then
		return
	end

	talentsFrame:SetNodesFilter(function(nodeIDs)
		return FilterTalentNodes(talentsFrame, nodeIDs)
	end)

	if talentsFrame.UpdateClassVisuals then
		hooksecurefunc(talentsFrame, "UpdateClassVisuals", function()
			ApplyTalentLayoutOffset(talentsFrame)
		end)
	end

	talentFilterInstalled = true
	addon.RefreshTalentsFrame()
end

function addon.SetTalentFilterEnabled(enabled)
	Level20DB.hideHighLevelTalents = enabled

	-- WoW cannot remove taint from a frame in the current UI session. Offer a
	-- reload when disabling an installed filter; choosing Later leaves the saved
	-- setting disabled, but the existing taint remains until the next UI reload.
	if not enabled and talentFilterInstalled then
		StaticPopup_Show(TALENT_FILTER_RELOAD_POPUP)
		return
	end

	addon.InstallTalentFilter()
	addon.RefreshTalentsFrame()
	addon.InstallPvPTalentFilter()
	addon.RefreshPvPTalentFrame()
	addon.RefreshWindow()

	local stateText = enabled and L.STATE_ENABLED or L.STATE_DISABLED
	print(string.format(L.TALENT_FILTER_STATUS, stateText))
end
