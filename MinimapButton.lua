local addonName, addon = ...

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
	local angle = math.rad(Level20DB.minimapButtonAngle or 195)
	local angleCos = math.cos(angle)
	local angleSin = math.sin(angle)
	local horizontalRadius = Minimap:GetWidth() / 2 + 5
	local verticalRadius = Minimap:GetHeight() / 2 + 5

	button:SetPoint("CENTER", Minimap, "CENTER", angleCos * horizontalRadius, angleSin * verticalRadius)
end

local function CalculateAngle(y, x)
	return math.atan2(y, x)
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
	addon.ToggleWindow()
end)

button:SetScript("OnEnter", function(self)
	GameTooltip:SetOwner(self, "ANCHOR_LEFT")
	GameTooltip:SetText("Level20")
	GameTooltip:AddLine("Open Level20", 1, 1, 1)
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
