local addonName, addon = ...
local BagFolders = addon.BagFolders
local L = addon.L

local DEFAULT_FOLDER_ID = BagFolders.DEFAULT_FOLDER_ID
local COLUMNS = BagFolders.COLUMNS
local CELL_SIZE = BagFolders.CELL_SIZE
local CELL_SPACING = BagFolders.CELL_SPACING
local ITEM_OFFSET_X = BagFolders.ITEM_OFFSET_X
local ITEM_OFFSET_Y = BagFolders.ITEM_OFFSET_Y
local FRAME_WIDTH = BagFolders.FRAME_WIDTH
local FRAME_PADDING_BOTTOM = BagFolders.FRAME_PADDING_BOTTOM

function BagFolders.ApplyNativePortraitSizing(folderFrame)
	folderFrame.layoutType = "HeldBagLayout"
	folderFrame:SetBorder("HeldBagLayout")
	folderFrame:SetPortraitTextureSizeAndOffset(36, -4, 1)
	folderFrame:SetTitleOffsets(35)
end

function BagFolders.UpdateItemButton(button)
	local bagID = button:GetBagID()
	local slotID = button:GetID()
	local info = C_Container.GetContainerItemInfo(bagID, slotID)
	local texture = info and info.iconFileID
	local itemCount = info and info.stackCount
	local locked = info and info.isLocked
	local quality = info and info.quality
	local readable = info and (info.IsReadable or info.isReadable)
	local itemLink = info and info.hyperlink
	local isFiltered = info and info.isFiltered
	local noValue = info and info.hasNoValue
	local isBound = info and info.isBound
	local questInfo = C_Container.GetContainerItemQuestInfo(bagID, slotID) or {}

	ClearItemButtonOverlay(button)
	button:SetHasItem(texture)
	button:SetItemButtonTexture(texture)
	SetItemButtonQuality(button, quality, itemLink, false, isBound)
	SetItemButtonCount(button, itemCount)
	SetItemButtonDesaturated(button, locked)
	button:UpdateExtended()
	button:UpdateQuestItem(questInfo.isQuestItem, questInfo.questID, questInfo.isActive)
	button:UpdateNewItem(quality)
	button:UpdateJunkItem(quality, noValue)
	button:UpdateItemContextMatching()
	button:UpdateCooldown(texture)
	button:SetReadable(readable)
	button:SetMatchesSearch(not isFiltered)
end

function BagFolders.GetOrCreateItemButton(parent, index)
	local button = BagFolders.itemButtons[index]
	if button then
		button:SetParent(parent)
		return button
	end

	button = CreateFrame("ItemButton", nil, parent, "ContainerFrameItemButtonTemplate")
	button:SetScript("OnDragStart", function(self, mouseButton)
		BagFolders.pendingDraggedItemGUID = self.itemGUID
		ContainerFrameItemButtonMixin.OnDragStart(self, mouseButton)
	end)
	button:SetScript("OnReceiveDrag", function(self)
		if not BagFolders.PlaceItemGUIDToCell(BagFolders.pendingDraggedItemGUID, self.folderID, self.cellIndex) and not BagFolders.DropCursorItemToCell(self.folderID, self.cellIndex) then
			ContainerFrameItemButtonMixin.OnReceiveDrag(self)
		end
	end)
	button:SetScript("OnMouseUp", function(self, mouseButton)
		if mouseButton == "LeftButton" and CursorHasItem() and (BagFolders.PlaceItemGUIDToCell(BagFolders.pendingDraggedItemGUID, self.folderID, self.cellIndex) or BagFolders.DropCursorItemToCell(self.folderID, self.cellIndex)) then
			self.skipNextFolderClick = true
		end
	end)
	button:SetScript("OnClick", function(self, mouseButton)
		if self.skipNextFolderClick then
			self.skipNextFolderClick = nil
			return
		end
		if mouseButton == "LeftButton" and CursorHasItem() and BagFolders.DropCursorItemToCell(self.folderID, self.cellIndex) then
			return
		end

		ContainerFrameItemButtonMixin.OnClick(self, mouseButton)
	end)

	BagFolders.itemButtons[index] = button
	return button
end

function BagFolders.GetOrCreateEmptyButton(parent, index)
	local button = BagFolders.emptyButtons[index]
	if button then
		button:SetParent(parent)
		return button
	end

	button = CreateFrame("Button", nil, parent)
	button:SetSize(CELL_SIZE, CELL_SIZE)
	button:RegisterForClicks("LeftButtonUp")
	button:RegisterForDrag("LeftButton")
	button.ItemSlotBackground = button:CreateTexture(nil, "BACKGROUND", "ItemSlotBackgroundCombinedBagsTemplate", -6)
	button.ItemSlotBackground:SetAllPoints()
	button.background = button:CreateTexture(nil, "BACKGROUND")
	button.background:SetAllPoints()
	button.background:SetAtlas("bags-item-slot64")
	button.Border = button:CreateTexture(nil, "OVERLAY")
	button.Border:SetTexture("Interface/Buttons/UI-Quickslot2")
	button.Border:SetSize(64, 64)
	button.Border:SetPoint("CENTER", button, "CENTER", 0, -1)
	button.Border:SetAlpha(0.55)
	button:SetHighlightTexture("Interface/Buttons/ButtonHilight-Square", "ADD")
	local highlight = button:GetHighlightTexture()
	if highlight then
		highlight:SetSize(CELL_SIZE, CELL_SIZE)
		highlight:SetPoint("CENTER")
	end
	button:SetScript("OnReceiveDrag", function(self)
		if not BagFolders.PlaceItemGUIDToCell(BagFolders.pendingDraggedItemGUID, self.folderID, self.cellIndex) then
			BagFolders.DropCursorItemToCell(self.folderID, self.cellIndex)
		end
	end)
	button:SetScript("OnMouseUp", function(self, mouseButton)
		if mouseButton == "LeftButton" and CursorHasItem() then
			if not BagFolders.PlaceItemGUIDToCell(BagFolders.pendingDraggedItemGUID, self.folderID, self.cellIndex) then
				BagFolders.DropCursorItemToCell(self.folderID, self.cellIndex)
			end
		end
	end)
	button:SetScript("OnClick", function(self)
		if CursorHasItem() then
			BagFolders.DropCursorItemToCell(self.folderID, self.cellIndex)
		end
	end)

	BagFolders.emptyButtons[index] = button
	return button
end

local function GetFolderCellFromFocus(frame)
	while frame do
		if frame.folderID and frame.cellIndex then
			return frame
		end
		frame = frame.GetParent and frame:GetParent()
	end

	return nil
end

local function GetMouseFolderCell()
	if GetMouseFoci then
		for _, focus in ipairs(GetMouseFoci()) do
			local cell = GetFolderCellFromFocus(focus)
			if cell then
				return cell
			end
		end
	elseif GetMouseFocus then
		return GetFolderCellFromFocus(GetMouseFocus())
	end

	return nil
end

local dragDropFrame = CreateFrame("Frame")
dragDropFrame:RegisterEvent("GLOBAL_MOUSE_UP")
dragDropFrame:SetScript("OnEvent", function(_, _, mouseButton)
	if mouseButton ~= "LeftButton" or not BagFolders.pendingDraggedItemGUID or not CursorHasItem() then
		BagFolders.pendingDraggedItemGUID = nil
		return
	end

	local cell = GetMouseFolderCell()
	if cell then
		BagFolders.PlaceItemGUIDToCell(BagFolders.pendingDraggedItemGUID, cell.folderID, cell.cellIndex)
	else
		BagFolders.pendingDraggedItemGUID = nil
	end
end)

function BagFolders.PositionCell(button, cellIndex)
	local column = (cellIndex - 1) % COLUMNS
	local row = math.floor((cellIndex - 1) / COLUMNS)
	button:ClearAllPoints()

	local parent = button:GetParent()
	if parent and parent.itemGridAnchor then
		button:SetPoint("BOTTOMRIGHT", parent.itemGridAnchor, "BOTTOMRIGHT", -(COLUMNS - column - 1) * (CELL_SIZE + CELL_SPACING), row * (CELL_SIZE + CELL_SPACING))
	else
		button:SetPoint("TOPLEFT", parent, "TOPLEFT", ITEM_OFFSET_X + column * (CELL_SIZE + CELL_SPACING), -(ITEM_OFFSET_Y + row * (CELL_SIZE + CELL_SPACING)))
	end
end

function BagFolders.CalculateItemsHeight(rowCount)
	return rowCount * CELL_SIZE + math.max(0, rowCount - 1) * CELL_SPACING
end

function BagFolders.CalculateFrameHeight(rowCount, extraBottomHeight)
	return ITEM_OFFSET_Y + BagFolders.CalculateItemsHeight(rowCount) + (extraBottomHeight or FRAME_PADDING_BOTTOM)
end

function BagFolders.ShowTextPopup(dialogName, text, defaultText, accept)
	StaticPopupDialogs[dialogName] = StaticPopupDialogs[dialogName] or {
		text = text,
		button1 = ACCEPT,
		button2 = CANCEL,
		hasEditBox = true,
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
		preferredIndex = 3,
		OnAccept = function(self, data)
			local editBox = self.editBox or self.EditBox
			local value = editBox and editBox:GetText() or ""
			if data and data.accept then
				data.accept(strtrim(value or ""))
			end
		end,
		OnShow = function(self, data)
			local editBox = self.editBox or self.EditBox
			if editBox then
				editBox:SetText(data and data.defaultText or "")
				editBox:HighlightText()
				editBox:SetFocus()
			end
		end,
	}

	StaticPopup_Show(dialogName, nil, nil, { defaultText = defaultText, accept = accept })
end

local function EnsureIconSelectorPopup()
	if BagFolders.iconSelectorPopup then
		return BagFolders.iconSelectorPopup
	end

	if not IconSelectorPopupFrameTemplateMixin or not IconDataProviderMixin or not IconDataProviderExtraType or not IconSelectorPopupFrameIconFilterTypes then
		if C_AddOns and C_AddOns.LoadAddOn then
			pcall(C_AddOns.LoadAddOn, "Blizzard_MacroUI")
		elseif LoadAddOn then
			pcall(LoadAddOn, "Blizzard_MacroUI")
		end
	end

	if not IconSelectorPopupFrameTemplateMixin or not IconDataProviderMixin or not IconDataProviderExtraType or not IconSelectorPopupFrameIconFilterTypes or not CreateAndInitFromMixin then
		print("|cffffd100Level20:|r Blizzard icon selector UI is not available.")
		return nil
	end

	BagFolders.iconSelectorPopup = CreateFrame("Frame", "Level20BagFolderIconSelector", UIParent, "IconSelectorPopupFrameTemplate")
	local popup = BagFolders.iconSelectorPopup
	popup:SetFrameStrata("HIGH")
	popup:SetFrameLevel(1000)
	popup:SetToplevel(true)
	popup:EnableMouse(true)
	popup:SetClampedToScreen(true)
	popup:SetPoint("CENTER")

	function popup:OnShow()
		IconSelectorPopupFrameTemplateMixin.OnShow(self)
		PlaySound(SOUNDKIT.IG_CHARACTER_INFO_OPEN)
		self.iconDataProvider = CreateAndInitFromMixin(IconDataProviderMixin, IconDataProviderExtraType.None)
		self:SetIconFilter(IconSelectorPopupFrameIconFilterTypes.All)
		self:Update()
		self.BorderBox.IconSelectorEditBox:SetText(BagFolders.GetFolderName(self.folderID))
		self.BorderBox.IconSelectorEditBox:HighlightText()
		self.BorderBox.IconSelectorEditBox:ClearFocus()

		self.IconSelector:SetSelectedCallback(function(_, icon)
			self.BorderBox.SelectedIconArea.SelectedIconButton:SetIconTexture(icon)
			self:SetSelectedIconText()
		end)
	end

	function popup:OnHide()
		IconSelectorPopupFrameTemplateMixin.OnHide(self)
		if self.iconDataProvider then
			self.iconDataProvider:Release()
			self.iconDataProvider = nil
		end
	end

	function popup:Update()
		local selectedIcon = BagFolders.GetFolderIcon(self.folderID)
		local selectedIndex = self:GetIndexOfIcon(selectedIcon) or 1
		local getSelection = GenerateClosure(self.GetIconByIndex, self)
		local getNumSelections = GenerateClosure(self.GetNumIcons, self)
		self.IconSelector:SetSelectionsDataProvider(getSelection, getNumSelections)
		self.IconSelector:SetSelectedIndex(selectedIndex)
		self.IconSelector:ScrollToSelectedIndex()
		self.BorderBox.SelectedIconArea.SelectedIconButton:SetIconTexture(self:GetIconByIndex(selectedIndex) or selectedIcon)
		self:SetSelectedIconText()
	end

	function popup:OkayButton_OnClick()
		IconSelectorPopupFrameTemplateMixin.OkayButton_OnClick(self)
		local icon = self.BorderBox.SelectedIconArea.SelectedIconButton:GetIconTexture()
		BagFolders.SetFolderIcon(self.folderID, icon)
	end

	popup:SetScript("OnShow", function(self)
		self:OnShow()
	end)
	popup:SetScript("OnHide", function(self)
		self:OnHide()
	end)
	popup:SetScript("OnEvent", function(self, event, ...)
		self:OnEvent(event, ...)
	end)
	popup:Hide()

	return popup
end

function BagFolders.OpenIconSelector(folderID)
	local popup = EnsureIconSelectorPopup()
	if not popup then
		return
	end

	popup.folderID = folderID
	if popup:IsShown() then
		popup:Hide()
	end

	local opened, errorMessage = pcall(popup.Show, popup)
	if not opened then
		print("|cffffd100Level20:|r Could not open the folder icon selector: " .. tostring(errorMessage))
		return
	end
	popup:Raise()
end

local function PopulateFolderMenu(rootDescription, folderID)
	rootDescription:SetTag("LEVEL20_BAG_FOLDER")
	rootDescription:CreateTitle(BagFolders.GetFolderName(folderID))
	rootDescription:CreateButton(L.BAG_FOLDERS_CREATE, function()
		BagFolders.ShowTextPopup("LEVEL20_CREATE_BAG_FOLDER", L.BAG_FOLDERS_NAME_PROMPT, L.BAG_FOLDERS_NEW_FOLDER, BagFolders.CreateFolder)
	end)
	rootDescription:CreateButton(L.BAG_FOLDERS_SELECT_ICON, function()
		if C_Timer and C_Timer.After then
			C_Timer.After(0, function()
				BagFolders.OpenIconSelector(folderID)
			end)
		else
			BagFolders.OpenIconSelector(folderID)
		end
	end)
	if BagFolders.HasHiddenFolders() then
		rootDescription:CreateButton(L.BAG_FOLDERS_SHOW_ALL, BagFolders.ShowAllFolders)
	end
	if folderID ~= DEFAULT_FOLDER_ID then
		rootDescription:CreateButton(L.BAG_FOLDERS_RENAME, function()
			BagFolders.ShowTextPopup("LEVEL20_RENAME_BAG_FOLDER", L.BAG_FOLDERS_NAME_PROMPT, BagFolders.GetFolderName(folderID), function(name)
				BagFolders.RenameFolder(folderID, name)
			end)
		end)
		rootDescription:CreateButton(L.BAG_FOLDERS_HIDE, function()
			BagFolders.HideFolder(folderID)
		end)
		rootDescription:CreateButton(L.BAG_FOLDERS_DELETE, function()
			BagFolders.DeleteFolder(folderID)
		end)
	end
end

function BagFolders.OpenFolderMenu(owner, folderID)
	if MenuUtil and MenuUtil.CreateContextMenu then
		MenuUtil.CreateContextMenu(owner, function(_, rootDescription)
			PopulateFolderMenu(rootDescription, folderID)
		end)
	else
		BagFolders.ShowTextPopup("LEVEL20_CREATE_BAG_FOLDER", L.BAG_FOLDERS_NAME_PROMPT, L.BAG_FOLDERS_NEW_FOLDER, BagFolders.CreateFolder)
	end
end

local function CreateFolderFrame(folderID)
	local folderFrame = CreateFrame("Frame", "Level20BagFolder" .. BagFolders.GetFolderKey(folderID), UIParent, "PortraitFrameFlatTemplate")
	folderFrame:SetSize(FRAME_WIDTH, BagFolders.CalculateFrameHeight(1))
	folderFrame:SetMovable(false)
	folderFrame:SetClampedToScreen(true)
	folderFrame:EnableMouse(true)
	folderFrame:SetScript("OnHide", function(self)
		self.items = nil
		if EventRegistry then
			EventRegistry:UnregisterCallback("TokenFrame.OnTokenWatchChanged", self)
		end
		if self.CurrencyFrame then
			self.CurrencyFrame:Hide()
			self.CurrencyFrame:UnregisterEvent("CURRENCY_DISPLAY_UPDATE")
		end
	end)
	folderFrame:SetScript("OnShow", function(self)
		if folderID == DEFAULT_FOLDER_ID and EventRegistry then
			EventRegistry:RegisterCallback("TokenFrame.OnTokenWatchChanged", function()
				addon.RefreshBagFolders()
			end, self)
		end
	end)
	BagFolders.ApplyNativePortraitSizing(folderFrame)
	folderFrame:SetFrameStrata("MEDIUM")
	folderFrame:SetToplevel(true)
	folderFrame:Hide()

	folderFrame.IsCombinedBagContainer = function()
		return true
	end
	folderFrame.GetID = function()
		return Enum.BagIndex.Backpack
	end
	folderFrame.GetBagID = folderFrame.GetID

	folderFrame.CloseButton = folderFrame.CloseButton or CreateFrame("Button", nil, folderFrame, "UIPanelCloseButtonDefaultAnchors")

	folderFrame.PortraitButton = CreateFrame("DropdownButton", nil, folderFrame, "ContainerFramePortraitButtonTemplate")
	folderFrame.PortraitButton:SetPoint("CENTER", folderFrame:GetPortrait(), "CENTER", 3, -3)
	folderFrame.PortraitButton:SetID(Enum.BagIndex.Backpack)
	if folderFrame.PortraitButton.SetupMenu then
		folderFrame.PortraitButton:SetupMenu(function(_, rootDescription)
			PopulateFolderMenu(rootDescription, folderFrame.folderID or folderID)
		end)
	end
	folderFrame.PortraitButton:SetScript("OnEnter", nil)
	folderFrame.PortraitButton:SetScript("OnLeave", nil)

	folderFrame.menuButton = CreateFrame("Button", nil, folderFrame)
	folderFrame.menuButton:SetSize(50, 40)
	folderFrame.menuButton:SetPoint("TOPLEFT", folderFrame.TitleContainer, "TOPLEFT", 0, 0)
	folderFrame.menuButton:SetPoint("BOTTOMRIGHT", folderFrame.TitleContainer, "BOTTOMRIGHT", 0, 0)
	folderFrame.menuButton:SetScript("OnClick", function(self)
		BagFolders.OpenFolderMenu(self, self:GetParent().folderID)
	end)
	folderFrame.menuButton:SetScript("OnMouseUp", function(self, mouseButton)
		if mouseButton == "RightButton" then
			BagFolders.OpenFolderMenu(self, self:GetParent().folderID)
		end
	end)

	for _, event in ipairs(BagFolders.events) do
		folderFrame:RegisterEvent(event)
	end
	folderFrame:SetScript("OnEvent", function()
		if not BagFolders.isRefreshing and addon.AreBagFoldersShown and addon.AreBagFoldersShown() then
			addon.RequestBagFoldersRefresh()
		end
	end)

	return folderFrame
end

function BagFolders.GetOrCreateFolderFrame(folderID)
	local folderKey = BagFolders.GetFolderKey(folderID)
	BagFolders.folderFrames[folderKey] = BagFolders.folderFrames[folderKey] or CreateFolderFrame(folderID)
	return BagFolders.folderFrames[folderKey]
end

function BagFolders.HideUnusedFrames(activeFolders)
	for folderKey, folderFrame in pairs(BagFolders.folderFrames) do
		if not activeFolders[folderKey] then
			folderFrame:Hide()
		end
	end
end

function BagFolders.HideAllItemCells()
	for _, button in ipairs(BagFolders.itemButtons) do
		button:Hide()
	end
	for _, button in ipairs(BagFolders.emptyButtons) do
		button:Hide()
	end
end
