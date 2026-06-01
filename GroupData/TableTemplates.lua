Level20GroupDataHeaderMixin = CreateFromMixins(TableBuilderElementMixin)

local OFFLINE_COLOR = GRAY_FONT_COLOR or HIGHLIGHT_FONT_COLOR
local ONLINE_COLOR = HIGHLIGHT_FONT_COLOR
local OFFLINE_ROW_ALPHA = 0.65

local function SetTextColor(fontString, colorTable)
	if not fontString or not colorTable then
		return
	end

	fontString:SetTextColor(colorTable.r, colorTable.g, colorTable.b)
end

function Level20GroupDataHeaderMixin:Init(text)
	self:SetText(text or "")
	self:EnableMouse(false)
end


Level20GroupDataCellMixin = CreateFromMixins(TableBuilderCellMixin)

function Level20GroupDataCellMixin:Init(field, justifyH, fontObjectName)
	self.field = field
	self.justifyH = justifyH or "LEFT"
	self.fontObjectName = fontObjectName

	if self.Text then
		self.Text:SetJustifyH(self.justifyH)
		if self.fontObjectName and _G[self.fontObjectName] then
			self.Text:SetFontObject(_G[self.fontObjectName])
		end
	end
end

function Level20GroupDataCellMixin:Populate(rowData)
	local value = rowData and rowData[self.field] or ""
	self.Text:SetText(value ~= nil and tostring(value) or "")

	if rowData and rowData.isOffline then
		SetTextColor(self.Text, OFFLINE_COLOR)
	else
		SetTextColor(self.Text, ONLINE_COLOR)
	end
end


Level20GroupDataIconCellMixin = CreateFromMixins(TableBuilderCellMixin)

function Level20GroupDataIconCellMixin:Init(field)
	self.field = field
end

function Level20GroupDataIconCellMixin:Populate(rowData)
	local iconData = rowData and rowData[self.field] or nil
	if not self.Icon then
		return
	end

	if rowData and rowData.isOffline then
		self.Icon:SetVertexColor(OFFLINE_COLOR.r, OFFLINE_COLOR.g, OFFLINE_COLOR.b)
	else
		self.Icon:SetVertexColor(1, 1, 1)
	end

	if not iconData then
		self.Icon:Hide()
		self.Icon:SetAtlas(nil)
		self.Icon:SetTexture(nil)
		return
	end

	if iconData.atlas then
		self.Icon:SetAtlas(iconData.atlas, TextureKitConstants.IgnoreAtlasSize)
		self.Icon:SetTexCoord(0, 1, 0, 1)
		self.Icon:Show()
		return
	end

	if iconData.texture then
		self.Icon:SetAtlas(nil)
		self.Icon:SetTexture(iconData.texture)
		if iconData.texCoords then
			self.Icon:SetTexCoord(unpack(iconData.texCoords))
		else
			self.Icon:SetTexCoord(0, 1, 0, 1)
		end
		self.Icon:Show()
		return
	end

	self.Icon:Hide()
	self.Icon:SetAtlas(nil)
	self.Icon:SetTexture(nil)
end


Level20GroupDataBooleanCellMixin = CreateFromMixins(TableBuilderCellMixin)

function Level20GroupDataBooleanCellMixin:Init(field)
	self.field = field
end

function Level20GroupDataBooleanCellMixin:Populate(rowData)
	local value = rowData and rowData[self.field] or nil
	if not self.Icon or not self.Text then
		return
	end

	if rowData and rowData.isOffline then
		self.Icon:SetVertexColor(OFFLINE_COLOR.r, OFFLINE_COLOR.g, OFFLINE_COLOR.b)
		SetTextColor(self.Text, OFFLINE_COLOR)
	else
		self.Icon:SetVertexColor(1, 1, 1)
		SetTextColor(self.Text, ONLINE_COLOR)
	end

	if value and value.atlas then
		self.Text:SetText("")
		self.Icon:SetAtlas(value.atlas, TextureKitConstants.IgnoreAtlasSize)
		self.Icon:Show()
		return
	end

	self.Icon:Hide()
	self.Icon:SetAtlas(nil)
	self.Text:SetText(value ~= nil and tostring(value) or "")
end


Level20GroupDataRowMixin = CreateFromMixins(TableBuilderRowMixin)

function Level20GroupDataRowMixin:Populate(rowData)
	local atlas = (rowData and rowData.index and rowData.index % 2 == 0) and "auctionhouse-rowstripe-1" or "auctionhouse-rowstripe-2"
	self:GetNormalTexture():SetAtlas(atlas)
	self.SelectedHighlight:SetShown(rowData and rowData.isPlayer or false)
	self:SetAlpha(rowData and rowData.isOffline and OFFLINE_ROW_ALPHA or 1)
end

function Level20GroupDataRowMixin:OnLineEnter()
	self.HighlightTexture:Show()
end

function Level20GroupDataRowMixin:OnLineLeave()
	self.HighlightTexture:Hide()
end


Level20GroupDataTableBuilderMixin = {}

function Level20GroupDataTableBuilderMixin:AddUnsortableColumnInternal(headerText, cellTemplate, ...)
	local column = self:AddColumn()
	column:ConstructHeader("BUTTON", "Level20GroupDataHeaderTemplate", headerText)
	column:ConstructCells("FRAME", cellTemplate, ...)
	return column
end

function Level20GroupDataTableBuilderMixin:AddUnsortableFixedWidthColumn(padding, width, leftCellPadding, rightCellPadding, headerText, cellTemplate, ...)
	local column = self:AddUnsortableColumnInternal(headerText, cellTemplate, ...)
	column:SetFixedConstraints(width, padding)
	column:SetCellPadding(leftCellPadding, rightCellPadding)
	return column
end

function Level20GroupDataTableBuilderMixin:AddUnsortableFillColumn(padding, fillCoefficient, leftCellPadding, rightCellPadding, headerText, cellTemplate, ...)
	local column = self:AddUnsortableColumnInternal(headerText, cellTemplate, ...)
	column:SetFillConstraints(fillCoefficient, padding)
	column:SetCellPadding(leftCellPadding, rightCellPadding)
	return column
end
