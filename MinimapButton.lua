local addonName, addon = ...
local L = addon.L

local BUTTON_SIZE = 40
local BUTTON_EDGE_MARGIN = 10
local BUTTON_NORMAL_TEXTURE = "Interface\\AddOns\\Level20\\Resources\\button_normal.png"
local BUTTON_HOVERED_TEXTURE = "Interface\\AddOns\\Level20\\Resources\\button_hovered.png"
local BUTTON_PRESSED_TEXTURE = "Interface\\AddOns\\Level20\\Resources\\button_pressed.png"

local button = CreateFrame("Button", "Level20MinimapButton", Minimap)
button:SetSize(BUTTON_SIZE, BUTTON_SIZE)
button:SetFrameStrata("MEDIUM")
button:SetFrameLevel(8)
button:RegisterForClicks("LeftButtonUp")
button:RegisterForDrag("LeftButton")

button.texture = button:CreateTexture(nil, "BACKGROUND")
button.texture:SetAllPoints()
button.texture:SetTexture(BUTTON_NORMAL_TEXTURE)

local function SetButtonTexture(texture)
	button.texture:SetTexture(texture)
end

local function SetButtonPosition()
	local angle = math.rad(Level20DB.minimapButtonAngle or 195)
	local angleCos = math.cos(angle)
	local angleSin = math.sin(angle)
	local horizontalRadius = Minimap:GetWidth() / 2 + BUTTON_EDGE_MARGIN
	local verticalRadius = Minimap:GetHeight() / 2 + BUTTON_EDGE_MARGIN

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
	if IsControlKeyDown() and IsShiftKeyDown() then
		addon.ShowHiddenTabsWindow()
	else
		addon.ToggleWindow()
	end
end)

button:SetScript("OnEnter", function(self)
	SetButtonTexture(BUTTON_HOVERED_TEXTURE)
	GameTooltip:SetOwner(self, "ANCHOR_LEFT")
	GameTooltip:SetText(L.ADDON_TITLE)
	GameTooltip:AddLine(L.MINIMAP_OPEN, 1, 1, 1)
	GameTooltip:AddLine(L.MINIMAP_DRAG, 0.7, 0.7, 0.7)
	GameTooltip:Show()
end)

button:SetScript("OnLeave", function()
	SetButtonTexture(BUTTON_NORMAL_TEXTURE)
	GameTooltip_Hide()
end)

button:SetScript("OnMouseDown", function(_, mouseButton)
	if mouseButton == "LeftButton" then
		SetButtonTexture(BUTTON_PRESSED_TEXTURE)
	end
end)

button:SetScript("OnMouseUp", function(self, mouseButton)
	if mouseButton == "LeftButton" then
		SetButtonTexture(self:IsMouseOver() and BUTTON_HOVERED_TEXTURE or BUTTON_NORMAL_TEXTURE)
	end
end)

button:SetScript("OnDragStart", function(self)
	SetButtonTexture(BUTTON_PRESSED_TEXTURE)
	self:SetScript("OnUpdate", UpdateButtonAngle)
end)

button:SetScript("OnDragStop", function(self)
	self:SetScript("OnUpdate", nil)
	UpdateButtonAngle()
	SetButtonTexture(self:IsMouseOver() and BUTTON_HOVERED_TEXTURE or BUTTON_NORMAL_TEXTURE)
end)

function addon.RefreshMinimapButton()
	button:Show()
	SetButtonPosition()
end

addon.RefreshMinimapButton()
Minimap:HookScript("OnSizeChanged", SetButtonPosition)
