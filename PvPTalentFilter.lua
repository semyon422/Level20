local addon = Level20

local pvpTalentFilterInstalled = false
local PVP_TALENT_SLOT_WIDTH = 58
local PVP_TALENT_SLOT_GAP = 4
local PVP_TALENT_SLOT_OFFSET = 2

local function PreparePvPTalentFrames()
	local talentsFrame = PlayerSpellsFrame and PlayerSpellsFrame.TalentsFrame
	if not talentsFrame then
		return nil, nil, nil
	end

	return talentsFrame, talentsFrame.PvPTalentSlotTray, talentsFrame.PvPTalentList
end

local function ShouldFilterPvPTalents()
	return Level20DB.hideHighLevelTalents and (UnitLevel("player") or 0) <= addon.LEVEL_CAP
end

local function IsPvPTalentUnlocked(talentID)
	local talentInfo = C_SpecializationInfo.GetPvpTalentInfo(talentID)
	return talentInfo and talentInfo.unlocked
end

local function GetFilteredPvPTalentIDs(availableTalentIDs)
	local filteredTalentIDs = {}

	for _, talentID in ipairs(availableTalentIDs or {}) do
		if IsPvPTalentUnlocked(talentID) then
			table.insert(filteredTalentIDs, talentID)
		end
	end

	return filteredTalentIDs
end

local function SortPvPTalentIDs(slotInfo, selectedPvpTalents, talentID1, talentID2)
	local selectedOther1 = tContains(selectedPvpTalents, talentID1) and slotInfo.selectedTalentID ~= talentID1
	local selectedOther2 = tContains(selectedPvpTalents, talentID2) and slotInfo.selectedTalentID ~= talentID2

	if selectedOther1 ~= selectedOther2 then
		return selectedOther2
	end

	return talentID1 < talentID2
end

local function SaveFramePoint(frame, storageKey)
	if frame[storageKey] then
		return
	end

	local point, relativeTo, relativePoint, offsetX, offsetY = frame:GetPoint(1)
	frame[storageKey] = {
		point = point,
		relativeTo = relativeTo,
		relativePoint = relativePoint,
		offsetX = offsetX or 0,
		offsetY = offsetY or 0,
	}
end

local function RestoreFramePoint(frame, storageKey, offsetX, offsetY)
	local savedPoint = frame[storageKey]
	if not savedPoint then
		return
	end

	frame:ClearAllPoints()
	frame:SetPoint(
		savedPoint.point,
		savedPoint.relativeTo,
		savedPoint.relativePoint,
		savedPoint.offsetX + (offsetX or 0),
		savedPoint.offsetY + (offsetY or 0)
	)
end

local function ApplyPvPTalentSlotTrayOffset(pvpTalentSlotTray)
	SaveFramePoint(pvpTalentSlotTray, "level20OriginalPoint")

	local offsetX = ShouldFilterPvPTalents() and (PVP_TALENT_SLOT_WIDTH + PVP_TALENT_SLOT_GAP) * PVP_TALENT_SLOT_OFFSET or 0
	RestoreFramePoint(pvpTalentSlotTray, "level20OriginalPoint", offsetX, 0)
end

local function ApplyPvPTalentListFilter(pvpTalentList)
	if not ShouldFilterPvPTalents() then
		return
	end

	local slotIndex = pvpTalentList.slotIndex
	if slotIndex ~= 1 then
		pvpTalentList:Hide()
		return
	end

	local slotInfo = C_SpecializationInfo.GetPvpTalentSlotInfo(slotIndex)
	if not slotInfo then
		return
	end

	local selectedPvpTalents = C_SpecializationInfo.GetAllSelectedPvpTalentIDs()
	local availableTalentIDs = GetFilteredPvPTalentIDs(slotInfo.availableTalentIDs)

	table.sort(availableTalentIDs, function(talentID1, talentID2)
		return SortPvPTalentIDs(slotInfo, selectedPvpTalents, talentID1, talentID2)
	end)

	local dataProvider = CreateDataProvider()
	for _, talentID in ipairs(availableTalentIDs) do
		local selectedHere = slotInfo.selectedTalentID == talentID
		local selectedOther = not selectedHere and tContains(selectedPvpTalents, talentID)
		dataProvider:Insert({ talentID = talentID, selectedHere = selectedHere, selectedOther = selectedOther, owner = pvpTalentList })
	end

	pvpTalentList.ScrollBox:SetDataProvider(dataProvider)
end

local function ApplyPvPTalentSlotFilter(pvpTalentSlotTray)
	if not pvpTalentSlotTray.Slots then
		return
	end

	ApplyPvPTalentSlotTrayOffset(pvpTalentSlotTray)

	local shouldFilter = ShouldFilterPvPTalents()
	for slotIndex, slot in ipairs(pvpTalentSlotTray.Slots) do
		if shouldFilter and slotIndex > 1 then
			slot:Hide()
			slot:Disable()
		else
			slot:Show()
			slot:Update()
		end
	end

	if shouldFilter and pvpTalentSlotTray.selectedSlotIndex and pvpTalentSlotTray.selectedSlotIndex > 1 then
		pvpTalentSlotTray:UnselectSlot()
	end

	pvpTalentSlotTray:UpdateNewNotification()
end

function addon.RefreshPvPTalentFrame()
	local _, pvpTalentSlotTray, pvpTalentList = PreparePvPTalentFrames()

	if pvpTalentSlotTray then
		pvpTalentSlotTray:Update()
		ApplyPvPTalentSlotFilter(pvpTalentSlotTray)
	end

	if pvpTalentList and pvpTalentList:IsShown() then
		pvpTalentList:Update()
		ApplyPvPTalentListFilter(pvpTalentList)
	end
end

function addon.InstallPvPTalentFilter()
	if pvpTalentFilterInstalled then
		return
	end

	local _, pvpTalentSlotTray, pvpTalentList = PreparePvPTalentFrames()
	if not pvpTalentSlotTray or not pvpTalentList then
		return
	end

	hooksecurefunc(pvpTalentSlotTray, "Update", function()
		ApplyPvPTalentSlotFilter(pvpTalentSlotTray)
	end)

	hooksecurefunc(pvpTalentList, "Update", function()
		ApplyPvPTalentListFilter(pvpTalentList)
	end)

	pvpTalentFilterInstalled = true
	addon.RefreshPvPTalentFrame()
end
