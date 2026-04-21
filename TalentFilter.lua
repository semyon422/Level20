local addonName, addon = ...
local L = addon.L

local talentFilterInstalled = false
local TALENT_ROW_HEIGHT = 600
local TALENT_ROW_OFFSET = 3
local TALENT_POSITION_SCALE = 10

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
	if not Level20DB.hideHighLevelTalents then
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

	if not talentsFrame.level20BasePanOffsetX then
		talentsFrame.level20BasePanOffsetX = talentsFrame.basePanOffsetX or 0
		talentsFrame.level20BasePanOffsetY = talentsFrame.basePanOffsetY or 0
	end

	local offsetY = Level20DB.hideHighLevelTalents and -((TALENT_ROW_HEIGHT * TALENT_ROW_OFFSET) / TALENT_POSITION_SCALE) or 0
	talentsFrame:SetBasePanOffset(talentsFrame.level20BasePanOffsetX, talentsFrame.level20BasePanOffsetY + offsetY)
end

function addon.RefreshTalentsFrame()
	local talentsFrame = PrepareTalentsFrame()
	if talentsFrame then
		ApplyTalentLayoutOffset(talentsFrame)
		talentsFrame:LoadTalentTree()
	end
end

function addon.InstallTalentFilter()
	if talentFilterInstalled then
		return
	end

	local talentsFrame = PrepareTalentsFrame()
	if not talentsFrame then
		return
	end

	talentsFrame:SetNodesFilter(function(nodeIDs)
		return FilterTalentNodes(talentsFrame, nodeIDs)
	end)

	talentFilterInstalled = true
	addon.RefreshTalentsFrame()
end

function addon.SetTalentFilterEnabled(enabled)
	Level20DB.hideHighLevelTalents = enabled
	addon.InstallTalentFilter()
	addon.RefreshTalentsFrame()
	addon.InstallPvPTalentFilter()
	addon.RefreshPvPTalentFrame()
	addon.RefreshWindow()

	local stateText = enabled and L.STATE_ENABLED or L.STATE_DISABLED
	print(string.format(L.TALENT_FILTER_STATUS, stateText))
end
