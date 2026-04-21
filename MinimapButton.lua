local addon = Level20

local minimapShapes = {
	ROUND = { true, true, true, true },
	SQUARE = { false, false, false, false },
	["CORNER-TOPLEFT"] = { false, false, false, true },
	["CORNER-TOPRIGHT"] = { false, false, true, false },
	["CORNER-BOTTOMLEFT"] = { false, true, false, false },
	["CORNER-BOTTOMRIGHT"] = { true, false, false, false },
	["SIDE-LEFT"] = { false, true, false, true },
	["SIDE-RIGHT"] = { true, false, true, false },
	["SIDE-TOP"] = { false, false, true, true },
	["SIDE-BOTTOM"] = { true, true, false, false },
	["TRICORNER-TOPLEFT"] = { false, true, true, true },
	["TRICORNER-TOPRIGHT"] = { true, false, true, true },
	["TRICORNER-BOTTOMLEFT"] = { true, true, false, true },
	["TRICORNER-BOTTOMRIGHT"] = { true, true, true, false },
}

local button = CreateFrame("Button", "Level20MinimapButton", Minimap)
button:SetSize(33, 33)
button:SetFrameStrata("MEDIUM")
button:SetFrameLevel(8)
button:RegisterForClicks("LeftButtonUp")
button:RegisterForDrag("LeftButton")
button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight", "ADD")

local outlineOffsets = {
	{ -1, 1 },
	{ 1, 1 },
	{ -1, -1 },
	{ 1, -1 },
	{ 0, 2 },
	{ 2, 0 },
	{ 0, -2 },
	{ -2, 0 },
}

for index, offset in ipairs(outlineOffsets) do
	local outline = button:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	outline:SetPoint("CENTER", offset[1], 1 + offset[2])
	outline:SetText("20")
	outline:SetTextColor(0.02, 0.13, 0.09, 0.95)
	button["outline" .. index] = outline
end

button.text = button:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
button.text:SetPoint("CENTER", 0, 1)
button.text:SetText("20")
button.text:SetTextColor(0.35, 1, 0.75)
button.text:SetShadowColor(0, 0, 0, 1)
button.text:SetShadowOffset(1, -1)

local function SetButtonPosition()
	local rounding = 10
	local angle = math.rad(Level20DB.minimapButtonAngle or 195)
	local angleCos = math.cos(angle)
	local angleSin = math.sin(angle)
	local quadrant = 1

	if angleCos < 0 then
		quadrant = quadrant + 1
	end

	if angleSin > 0 then
		quadrant = quadrant + 2
	end

	local horizontalRadius = Minimap:GetWidth() / 2 + 5
	local verticalRadius = Minimap:GetHeight() / 2 + 5
	local minimapShape = GetMinimapShape and GetMinimapShape() or "ROUND"
	local quadrantTable = minimapShapes[minimapShape] or minimapShapes.ROUND
	local x, y

	if quadrantTable[quadrant] then
		x = angleCos * horizontalRadius
		y = angleSin * verticalRadius
	else
		local horizontalDiagonalRadius = math.sqrt(2 * (horizontalRadius ^ 2)) - rounding
		local verticalDiagonalRadius = math.sqrt(2 * (verticalRadius ^ 2)) - rounding

		x = math.max(-horizontalRadius, math.min(angleCos * horizontalDiagonalRadius, horizontalRadius))
		y = math.max(-verticalRadius, math.min(angleSin * verticalDiagonalRadius, verticalRadius))
	end

	button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function CalculateAngle(y, x)
	if math.atan2 then
		return math.atan2(y, x)
	end

	if x > 0 then
		return math.atan(y / x)
	elseif x < 0 and y >= 0 then
		return math.atan(y / x) + math.pi
	elseif x < 0 then
		return math.atan(y / x) - math.pi
	elseif y > 0 then
		return math.pi / 2
	elseif y < 0 then
		return -math.pi / 2
	end

	return 0
end

local function UpdateButtonAngle()
	local centerX, centerY = Minimap:GetCenter()
	local cursorX, cursorY = GetCursorPosition()
	local scale = UIParent:GetEffectiveScale()
	cursorX = cursorX / scale
	cursorY = cursorY / scale

	Level20DB.minimapButtonAngle = math.deg(CalculateAngle(cursorY - centerY, cursorX - centerX))
	SetButtonPosition()
end

button:SetScript("OnClick", function()
	addon.ToggleSettingsWindow()
end)

button:SetScript("OnEnter", function(self)
	GameTooltip:SetOwner(self, "ANCHOR_LEFT")
	GameTooltip:SetText("Level20")
	GameTooltip:AddLine("Open settings", 1, 1, 1)
	GameTooltip:AddLine("Drag to move", 0.7, 0.7, 0.7)
	GameTooltip:Show()
end)

button:SetScript("OnLeave", GameTooltip_Hide)

button:SetScript("OnDragStart", function(self)
	self:SetScript("OnUpdate", UpdateButtonAngle)
end)

button:SetScript("OnDragStop", function(self)
	self:SetScript("OnUpdate", nil)
	UpdateButtonAngle()
end)

function addon.RefreshMinimapButton()
	button:SetShown(Level20DB.showMinimapButton)
	SetButtonPosition()
end

Minimap:HookScript("OnSizeChanged", SetButtonPosition)
