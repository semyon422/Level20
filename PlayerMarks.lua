local addonName, addon = ...

local MARK_WIDTH = 38
local MARK_HEIGHT = 24
local MARK_OFFSET_Y = 18
local MARK_TEXT = "20"

local marksByPlate = setmetatable({}, { __mode = "k" })

local function GetNamePlateUnit(plate)
	return plate.namePlateUnitToken or plate.unitFrame and plate.unitFrame.unit or plate.UnitFrame and plate.UnitFrame.unit
end

local function ShouldMarkUnit(unit)
	return Level20DB.showPlayerMarks and unit and UnitExists(unit) and UnitIsPlayer(unit) and UnitLevel(unit) == addon.LEVEL_CAP
end

local function GetMark(plate)
	local mark = marksByPlate[plate]
	if mark then
		return mark
	end

	mark = CreateFrame("Frame", nil, plate, "BackdropTemplate")
	mark:SetSize(MARK_WIDTH, MARK_HEIGHT)
	mark:SetPoint("BOTTOM", plate, "TOP", 0, MARK_OFFSET_Y)
	mark:SetFrameLevel((plate:GetFrameLevel() or 0) + 20)
	mark:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8x8",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		edgeSize = 10,
		insets = { left = 3, right = 3, top = 3, bottom = 3 },
	})
	mark:SetBackdropColor(0.02, 0.12, 0.08, 0.92)
	mark:SetBackdropBorderColor(0.35, 1.0, 0.75, 1)

	mark.text = mark:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	mark.text:SetPoint("CENTER", 0, 0)
	mark.text:SetText(MARK_TEXT)
	mark.text:SetTextColor(1.0, 0.82, 0.0)
	mark.text:SetShadowColor(0, 0, 0, 1)
	mark.text:SetShadowOffset(1, -1)

	marksByPlate[plate] = mark
	return mark
end

local function HideMark(plate)
	local mark = marksByPlate[plate]
	if mark then
		mark:Hide()
	end
end

local function RefreshNamePlate(unit)
	local plate = C_NamePlate.GetNamePlateForUnit(unit)
	if not plate then
		return
	end

	if ShouldMarkUnit(unit) then
		GetMark(plate):Show()
	else
		HideMark(plate)
	end
end

function addon.RefreshPlayerMarks()
	for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
		local unit = GetNamePlateUnit(plate)
		if unit then
			RefreshNamePlate(unit)
		end
	end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
eventFrame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:SetScript("OnEvent", function(_, event, unit)
	if event == "NAME_PLATE_UNIT_ADDED" then
		RefreshNamePlate(unit)
	elseif event == "NAME_PLATE_UNIT_REMOVED" then
		local plate = C_NamePlate.GetNamePlateForUnit(unit)
		if plate then
			HideMark(plate)
		end
	elseif event == "PLAYER_ENTERING_WORLD" then
		addon.RefreshPlayerMarks()
	end
end)
