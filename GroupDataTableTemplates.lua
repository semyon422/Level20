Level20GroupDataHeaderMixin = CreateFromMixins(TableBuilderElementMixin)

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
end


Level20GroupDataRowMixin = CreateFromMixins(TableBuilderRowMixin)

function Level20GroupDataRowMixin:Populate(rowData)
	local atlas = (rowData and rowData.index and rowData.index % 2 == 0) and "auctionhouse-rowstripe-1" or "auctionhouse-rowstripe-2"
	self:GetNormalTexture():SetAtlas(atlas)
	self.SelectedHighlight:SetShown(rowData and rowData.isPlayer or false)
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
