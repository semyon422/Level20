local addonName, addon = ...
local L = addon.L

local BAG_FOLDER_DEFAULT_ID = "default"
local COLUMNS = 4
local CELL_SIZE = 37
local CELL_SPACING = 5
local ITEM_OFFSET_X = 7
local ITEM_OFFSET_Y = 44
local FRAME_WIDTH = 178
local FRAME_PADDING_BOTTOM = 12
local MONEY_FRAME_HEIGHT = 20
local TOKEN_FRAME_SPACING = 3
local CURRENCY_BOTTOM_PADDING = 8
local CONTAINER_SPACING = 8
local MIN_SCALE = 0.75
local DEFAULT_FOLDER_ICON = "Interface/Icons/Inv_misc_bag_08"

local folderFrames = {}
local itemButtons = {}
local emptyButtons = {}
local originalFunctions = {}
local hooksInstalled = false
local hookRetryFrame
local iconSelectorPopup
local isRefreshing = false
local pendingDraggedItemGUID

local events = {
	"BAG_UPDATE",
	"BAG_UPDATE_DELAYED",
	"ITEM_LOCK_CHANGED",
	"BAG_UPDATE_COOLDOWN",
	"BAG_NEW_ITEMS_UPDATED",
	"CURRENCY_DISPLAY_UPDATE",
	"INVENTORY_SEARCH_UPDATE",
	"PLAYER_LOGIN",
}

local function EnsureDatabase()
	Level20DB.bagFolders = Level20DB.bagFolders or {}
	local db = Level20DB.bagFolders

	if db.enabled == nil then
		db.enabled = false
	end
	db.folders = db.folders or {}
	db.itemFolders = db.itemFolders or {}
	db.itemPositions = db.itemPositions or {}
	db.hiddenFolders = db.hiddenFolders or {}
	db.defaultIcon = db.defaultIcon or DEFAULT_FOLDER_ICON

	return db
end

local function NormalizeFolderID(folderID)
	if folderID == nil then
		return BAG_FOLDER_DEFAULT_ID
	end

	return folderID
end

local function GetFolderKey(folderID)
	return NormalizeFolderID(folderID)
end

local function IsNormalBagID(bagID)
	return type(bagID) == "number"
		and bagID >= Enum.BagIndex.Backpack
		and bagID <= Constants.InventoryConstants.NumBagSlots
end

local function ForEachNormalBag(callback)
	for bagID = Enum.BagIndex.Backpack, Constants.InventoryConstants.NumBagSlots do
		callback(bagID)
	end
end

local function IsEnabled()
	return EnsureDatabase().enabled
end

local function CanOpenBags()
	if ContainerFrame_AllowedToOpenBags then
		return ContainerFrame_AllowedToOpenBags()
	end

	return CanOpenPanels()
end

local function FolderExists(folderID)
	folderID = NormalizeFolderID(folderID)
	if folderID == BAG_FOLDER_DEFAULT_ID then
		return true
	end

	for _, folder in ipairs(EnsureDatabase().folders) do
		if folder.id == folderID then
			return true
		end
	end

	return false
end

local function GetNextFolderID()
	local usedIDs = {}
	for _, folder in ipairs(EnsureDatabase().folders) do
		local numericID = tonumber(folder.id)
		if numericID and numericID > 0 and numericID == math.floor(numericID) then
			usedIDs[numericID] = true
		end
	end

	local nextID = 1
	while usedIDs[nextID] do
		nextID = nextID + 1
	end

	return tostring(nextID)
end

local function GetFolderName(folderID)
	folderID = NormalizeFolderID(folderID)
	if folderID == BAG_FOLDER_DEFAULT_ID then
		return L.BAG_FOLDERS_DEFAULT
	end

	for _, folder in ipairs(EnsureDatabase().folders) do
		if folder.id == folderID then
			return folder.name
		end
	end

	return L.BAG_FOLDERS_DEFAULT
end

local function GetFolderIcon(folderID)
	folderID = NormalizeFolderID(folderID)
	local db = EnsureDatabase()
	if folderID == BAG_FOLDER_DEFAULT_ID then
		return db.defaultIcon or DEFAULT_FOLDER_ICON
	end

	for _, folder in ipairs(db.folders) do
		if folder.id == folderID then
			return folder.icon or DEFAULT_FOLDER_ICON
		end
	end

	return DEFAULT_FOLDER_ICON
end

local function SetFolderIcon(folderID, icon)
	if not icon then
		return
	end

	folderID = NormalizeFolderID(folderID)
	local db = EnsureDatabase()
	if folderID == BAG_FOLDER_DEFAULT_ID then
		db.defaultIcon = icon
	else
		for _, folder in ipairs(db.folders) do
			if folder.id == folderID then
				folder.icon = icon
				break
			end
		end
	end

	addon.RefreshBagFolders()
end

local function ApplyNativePortraitSizing(folderFrame)
	folderFrame.layoutType = "HeldBagLayout"
	folderFrame:SetBorder("HeldBagLayout")
	folderFrame:SetPortraitTextureSizeAndOffset(36, -4, 1)
	folderFrame:SetTitleOffsets(35)
end

local function GetOrderedFolders()
	local db = EnsureDatabase()
	local orderedFolders = {
		{ id = BAG_FOLDER_DEFAULT_ID, name = L.BAG_FOLDERS_DEFAULT },
	}

	for _, folder in ipairs(db.folders) do
		table.insert(orderedFolders, folder)
	end

	return orderedFolders
end

local function IsFolderHidden(folderID)
	return EnsureDatabase().hiddenFolders[NormalizeFolderID(folderID)] == true
end

local function HasHiddenFolders()
	for _, hidden in pairs(EnsureDatabase().hiddenFolders) do
		if hidden then
			return true
		end
	end

	return false
end

local function GetItemGUID(bagID, slotID)
	if not bagID or not slotID then
		return nil
	end

	local itemLocation = ItemLocation:CreateFromBagAndSlot(bagID, slotID)
	if not itemLocation or not itemLocation:IsValid() then
		return nil
	end

	return C_Item.GetItemGUID(itemLocation)
end

local function GetCursorItemGUID()
	local cursorItemLocation = C_Cursor.GetCursorItem()
	if not cursorItemLocation then
		return nil
	end

	local bagID, slotID = cursorItemLocation:GetBagAndSlot()
	if not IsNormalBagID(bagID) then
		return nil
	end

	return GetItemGUID(bagID, slotID), bagID, slotID
end

local function GetVisibleItems()
	local items = {}

	ForEachNormalBag(function(bagID)
		local slotCount = C_Container.GetContainerNumSlots(bagID) or 0
		for slotID = 1, slotCount do
			local info = C_Container.GetContainerItemInfo(bagID, slotID)
			if info and info.iconFileID then
				local itemGUID = GetItemGUID(bagID, slotID)
				if itemGUID then
					table.insert(items, {
						guid = itemGUID,
						bagID = bagID,
						slotID = slotID,
					})
				end
			end
		end
	end)

	return items
end

local function GetVisibleGUIDs()
	local visibleGUIDs = {}
	for _, item in ipairs(GetVisibleItems()) do
		visibleGUIDs[item.guid] = true
	end
	return visibleGUIDs
end

local function GetNextFreePosition(usedPositions)
	local position = 1
	while usedPositions[position] do
		position = position + 1
	end
	return position
end

local function NormalizeVisibleItemAssignments()
	local db = EnsureDatabase()
	local usedByFolder = {}

	for _, item in ipairs(GetVisibleItems()) do
		local folderID = NormalizeFolderID(db.itemFolders[item.guid])
		if not FolderExists(folderID) then
			folderID = BAG_FOLDER_DEFAULT_ID
			db.itemFolders[item.guid] = nil
		end

		local folderKey = GetFolderKey(folderID)
		usedByFolder[folderKey] = usedByFolder[folderKey] or {}

		local position = db.itemPositions[item.guid]
		if type(position) ~= "number" or position < 1 or usedByFolder[folderKey][position] then
			position = GetNextFreePosition(usedByFolder[folderKey])
			db.itemPositions[item.guid] = position
		end
		usedByFolder[folderKey][position] = item.guid
	end
end

local function AssignItemToCell(itemGUID, folderID, cellIndex)
	local db = EnsureDatabase()
	local targetFolderID = NormalizeFolderID(folderID)
	local targetCellIndex = math.max(1, math.floor(cellIndex or 1))
	local oldFolderID = NormalizeFolderID(db.itemFolders[itemGUID])
	local oldPosition = db.itemPositions[itemGUID]
	local targetGUID
	local visibleGUIDs = GetVisibleGUIDs()

	for guid, position in pairs(db.itemPositions) do
		local guidFolderID = NormalizeFolderID(db.itemFolders[guid])
		if visibleGUIDs[guid] and guid ~= itemGUID and guidFolderID == targetFolderID and position == targetCellIndex then
			targetGUID = guid
			break
		end
	end

	if targetFolderID == BAG_FOLDER_DEFAULT_ID then
		db.itemFolders[itemGUID] = nil
	else
		db.itemFolders[itemGUID] = targetFolderID
	end
	db.itemPositions[itemGUID] = targetCellIndex

	if targetGUID then
		if oldFolderID == BAG_FOLDER_DEFAULT_ID then
			db.itemFolders[targetGUID] = nil
		else
			db.itemFolders[targetGUID] = oldFolderID
		end
		db.itemPositions[targetGUID] = oldPosition or targetCellIndex
	end
end

local function PlaceItemGUIDToCell(itemGUID, folderID, cellIndex)
	if not itemGUID then
		return false
	end

	NormalizeVisibleItemAssignments()
	AssignItemToCell(itemGUID, folderID, cellIndex)
	ClearCursor()
	pendingDraggedItemGUID = nil
	addon.RefreshBagFolders()
	return true
end

local function DropCursorItemToCell(folderID, cellIndex)
	local itemGUID = GetCursorItemGUID()
	return PlaceItemGUIDToCell(itemGUID, folderID, cellIndex)
end

local function UpdateItemButton(button)
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

local function GetOrCreateItemButton(parent, index)
	local button = itemButtons[index]
	if button then
		button:SetParent(parent)
		return button
	end

	button = CreateFrame("ItemButton", nil, parent, "ContainerFrameItemButtonTemplate")
	button:SetScript("OnDragStart", function(self, mouseButton)
		pendingDraggedItemGUID = self.itemGUID
		ContainerFrameItemButtonMixin.OnDragStart(self, mouseButton)
	end)
	button:SetScript("OnReceiveDrag", function(self)
		if not PlaceItemGUIDToCell(pendingDraggedItemGUID, self.folderID, self.cellIndex) and not DropCursorItemToCell(self.folderID, self.cellIndex) then
			ContainerFrameItemButtonMixin.OnReceiveDrag(self)
		end
	end)
	button:SetScript("OnMouseUp", function(self, mouseButton)
		if mouseButton == "LeftButton" and CursorHasItem() and (PlaceItemGUIDToCell(pendingDraggedItemGUID, self.folderID, self.cellIndex) or DropCursorItemToCell(self.folderID, self.cellIndex)) then
			self.skipNextFolderClick = true
		end
	end)
	button:SetScript("OnClick", function(self, mouseButton)
		if self.skipNextFolderClick then
			self.skipNextFolderClick = nil
			return
		end
		if mouseButton == "LeftButton" and CursorHasItem() and DropCursorItemToCell(self.folderID, self.cellIndex) then
			return
		end

		ContainerFrameItemButtonMixin.OnClick(self, mouseButton)
	end)

	itemButtons[index] = button
	return button
end

local function GetOrCreateEmptyButton(parent, index)
	local button = emptyButtons[index]
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
		if not PlaceItemGUIDToCell(pendingDraggedItemGUID, self.folderID, self.cellIndex) then
			DropCursorItemToCell(self.folderID, self.cellIndex)
		end
	end)
	button:SetScript("OnMouseUp", function(self, mouseButton)
		if mouseButton == "LeftButton" and CursorHasItem() then
			if not PlaceItemGUIDToCell(pendingDraggedItemGUID, self.folderID, self.cellIndex) then
				DropCursorItemToCell(self.folderID, self.cellIndex)
			end
		end
	end)
	button:SetScript("OnClick", function(self)
		if CursorHasItem() then
			DropCursorItemToCell(self.folderID, self.cellIndex)
		end
	end)

	emptyButtons[index] = button
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
	if mouseButton ~= "LeftButton" or not pendingDraggedItemGUID or not CursorHasItem() then
		pendingDraggedItemGUID = nil
		return
	end

	local cell = GetMouseFolderCell()
	if cell then
		PlaceItemGUIDToCell(pendingDraggedItemGUID, cell.folderID, cell.cellIndex)
	else
		pendingDraggedItemGUID = nil
	end
end)

local function PositionCell(button, cellIndex)
	local column = (cellIndex - 1) % COLUMNS
	local row = math.floor((cellIndex - 1) / COLUMNS)
	button:ClearAllPoints()
	button:SetPoint("TOPLEFT", button:GetParent(), "TOPLEFT", ITEM_OFFSET_X + column * (CELL_SIZE + CELL_SPACING), -(ITEM_OFFSET_Y + row * (CELL_SIZE + CELL_SPACING)))
end

local function CalculateItemsHeight(rowCount)
	return rowCount * CELL_SIZE + math.max(0, rowCount - 1) * CELL_SPACING
end

local function CalculateFrameHeight(rowCount, extraBottomHeight)
	return ITEM_OFFSET_Y + CalculateItemsHeight(rowCount) + (extraBottomHeight or FRAME_PADDING_BOTTOM)
end

local function ShowTextPopup(dialogName, text, defaultText, accept)
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

local function CreateFolder(name)
	local db = EnsureDatabase()
	local folderName = name ~= "" and name or L.BAG_FOLDERS_NEW_FOLDER
	local folderID = GetNextFolderID()
	table.insert(db.folders, {
		id = folderID,
		name = folderName,
		icon = DEFAULT_FOLDER_ICON,
	})
	addon.RefreshBagFolders()
end

local function RenameFolder(folderID, name)
	folderID = NormalizeFolderID(folderID)
	if name == "" then
		return
	end

	for _, folder in ipairs(EnsureDatabase().folders) do
		if folder.id == folderID then
			folder.name = name
			break
		end
	end
	addon.RefreshBagFolders()
end

local function DeleteFolder(folderID)
	folderID = NormalizeFolderID(folderID)
	local db = EnsureDatabase()
	for index, folder in ipairs(db.folders) do
		if folder.id == folderID then
			table.remove(db.folders, index)
			break
		end
	end

	for itemGUID, assignedFolderID in pairs(db.itemFolders) do
		if NormalizeFolderID(assignedFolderID) == folderID then
			db.itemFolders[itemGUID] = nil
			db.itemPositions[itemGUID] = nil
		end
	end
	db.hiddenFolders[folderID] = nil
	addon.RefreshBagFolders()
end

local function HideFolder(folderID)
	folderID = NormalizeFolderID(folderID)
	if folderID == BAG_FOLDER_DEFAULT_ID then
		return
	end

	EnsureDatabase().hiddenFolders[folderID] = true
	addon.RefreshBagFolders()
end

local function ShowAllFolders()
	wipe(EnsureDatabase().hiddenFolders)
	addon.RefreshBagFolders()
end

function addon.ResetBagFolders()
	local enabled = false
	if Level20DB.bagFolders and Level20DB.bagFolders.enabled ~= nil then
		enabled = Level20DB.bagFolders.enabled and true or false
	end

	Level20DB.bagFolders = {
		enabled = enabled,
		folders = {},
		itemFolders = {},
		itemPositions = {},
		hiddenFolders = {},
		defaultIcon = DEFAULT_FOLDER_ICON,
	}

	for _, folderFrame in pairs(folderFrames) do
		folderFrame:Hide()
	end
	wipe(folderFrames)
	pendingDraggedItemGUID = nil

	addon.RefreshBagFolders()
end

local function EnsureIconSelectorPopup()
	if iconSelectorPopup then
		return iconSelectorPopup
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

	iconSelectorPopup = CreateFrame("Frame", "Level20BagFolderIconSelector", UIParent, "IconSelectorPopupFrameTemplate")
	iconSelectorPopup:SetFrameStrata("HIGH")
	iconSelectorPopup:SetFrameLevel(1000)
	iconSelectorPopup:SetToplevel(true)
	iconSelectorPopup:EnableMouse(true)
	iconSelectorPopup:SetClampedToScreen(true)
	iconSelectorPopup:SetPoint("CENTER")

	function iconSelectorPopup:OnShow()
		IconSelectorPopupFrameTemplateMixin.OnShow(self)
		PlaySound(SOUNDKIT.IG_CHARACTER_INFO_OPEN)
		self.iconDataProvider = CreateAndInitFromMixin(IconDataProviderMixin, IconDataProviderExtraType.None)
		self:SetIconFilter(IconSelectorPopupFrameIconFilterTypes.All)
		self:Update()
		self.BorderBox.IconSelectorEditBox:SetText(GetFolderName(self.folderID))
		self.BorderBox.IconSelectorEditBox:HighlightText()
		self.BorderBox.IconSelectorEditBox:ClearFocus()

		self.IconSelector:SetSelectedCallback(function(_, icon)
			self.BorderBox.SelectedIconArea.SelectedIconButton:SetIconTexture(icon)
			self:SetSelectedIconText()
		end)
	end

	function iconSelectorPopup:OnHide()
		IconSelectorPopupFrameTemplateMixin.OnHide(self)
		if self.iconDataProvider then
			self.iconDataProvider:Release()
			self.iconDataProvider = nil
		end
	end

	function iconSelectorPopup:Update()
		local selectedIcon = GetFolderIcon(self.folderID)
		local selectedIndex = self:GetIndexOfIcon(selectedIcon) or 1
		local getSelection = GenerateClosure(self.GetIconByIndex, self)
		local getNumSelections = GenerateClosure(self.GetNumIcons, self)
		self.IconSelector:SetSelectionsDataProvider(getSelection, getNumSelections)
		self.IconSelector:SetSelectedIndex(selectedIndex)
		self.IconSelector:ScrollToSelectedIndex()
		self.BorderBox.SelectedIconArea.SelectedIconButton:SetIconTexture(self:GetIconByIndex(selectedIndex) or selectedIcon)
		self:SetSelectedIconText()
	end

	function iconSelectorPopup:OkayButton_OnClick()
		IconSelectorPopupFrameTemplateMixin.OkayButton_OnClick(self)
		local icon = self.BorderBox.SelectedIconArea.SelectedIconButton:GetIconTexture()
		SetFolderIcon(self.folderID, icon)
	end

	iconSelectorPopup:SetScript("OnShow", function(self)
		self:OnShow()
	end)
	iconSelectorPopup:SetScript("OnHide", function(self)
		self:OnHide()
	end)
	iconSelectorPopup:SetScript("OnEvent", function(self, event, ...)
		self:OnEvent(event, ...)
	end)
	iconSelectorPopup:Hide()

	return iconSelectorPopup
end

local function OpenIconSelector(folderID)
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
	rootDescription:CreateTitle(GetFolderName(folderID))
	rootDescription:CreateButton(L.BAG_FOLDERS_CREATE, function()
		ShowTextPopup("LEVEL20_CREATE_BAG_FOLDER", L.BAG_FOLDERS_NAME_PROMPT, L.BAG_FOLDERS_NEW_FOLDER, CreateFolder)
	end)
	rootDescription:CreateButton(L.BAG_FOLDERS_SELECT_ICON, function()
		if C_Timer and C_Timer.After then
			C_Timer.After(0, function()
				OpenIconSelector(folderID)
			end)
		else
			OpenIconSelector(folderID)
		end
	end)
	if HasHiddenFolders() then
		rootDescription:CreateButton(L.BAG_FOLDERS_SHOW_ALL, ShowAllFolders)
	end
	if folderID ~= BAG_FOLDER_DEFAULT_ID then
		rootDescription:CreateButton(L.BAG_FOLDERS_RENAME, function()
			ShowTextPopup("LEVEL20_RENAME_BAG_FOLDER", L.BAG_FOLDERS_NAME_PROMPT, GetFolderName(folderID), function(name)
				RenameFolder(folderID, name)
			end)
		end)
		rootDescription:CreateButton(L.BAG_FOLDERS_HIDE, function()
			HideFolder(folderID)
		end)
		rootDescription:CreateButton(L.BAG_FOLDERS_DELETE, function()
			DeleteFolder(folderID)
		end)
	end
end

local function OpenFolderMenu(owner, folderID)
	if MenuUtil and MenuUtil.CreateContextMenu then
		MenuUtil.CreateContextMenu(owner, function(_, rootDescription)
			PopulateFolderMenu(rootDescription, folderID)
		end)
	else
		ShowTextPopup("LEVEL20_CREATE_BAG_FOLDER", L.BAG_FOLDERS_NAME_PROMPT, L.BAG_FOLDERS_NEW_FOLDER, CreateFolder)
	end
end

local function CreateFolderFrame(folderID)
	local folderFrame = CreateFrame("Frame", "Level20BagFolder" .. GetFolderKey(folderID), UIParent, "PortraitFrameFlatTemplate")
	folderFrame:SetSize(FRAME_WIDTH, CalculateFrameHeight(1))
	folderFrame:SetMovable(false)
	folderFrame:SetClampedToScreen(true)
	folderFrame:EnableMouse(true)
	folderFrame:SetScript("OnHide", function(self)
		self.items = nil
		if EventRegistry then
			EventRegistry:UnregisterCallback("TokenFrame.OnTokenWatchChanged", self)
		end
		if self.TokenFrame then
			self.TokenFrame:Hide()
			self.TokenFrame:SetParent(UIParent)
		end
	end)
	folderFrame:SetScript("OnShow", function(self)
		if folderID == BAG_FOLDER_DEFAULT_ID and EventRegistry then
			EventRegistry:RegisterCallback("TokenFrame.OnTokenWatchChanged", function()
				addon.RefreshBagFolders()
			end, self)
		end
	end)
	ApplyNativePortraitSizing(folderFrame)
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
		OpenFolderMenu(self, self:GetParent().folderID)
	end)
	folderFrame.menuButton:SetScript("OnMouseUp", function(self, mouseButton)
		if mouseButton == "RightButton" then
			OpenFolderMenu(self, self:GetParent().folderID)
		end
	end)

	for _, event in ipairs(events) do
		folderFrame:RegisterEvent(event)
	end
	folderFrame:SetScript("OnEvent", function()
		if not isRefreshing and addon.AreBagFoldersShown and addon.AreBagFoldersShown() then
			addon.RefreshBagFolders()
		end
	end)

	return folderFrame
end

local function GetOrCreateFolderFrame(folderID)
	local folderKey = GetFolderKey(folderID)
	folderFrames[folderKey] = folderFrames[folderKey] or CreateFolderFrame(folderID)
	return folderFrames[folderKey]
end

local function HideUnusedFrames(activeFolders)
	for folderKey, folderFrame in pairs(folderFrames) do
		if not activeFolders[folderKey] then
			folderFrame:Hide()
		end
	end
end

local function HideAllItemCells()
	for _, button in ipairs(itemButtons) do
		button:Hide()
	end
	for _, button in ipairs(emptyButtons) do
		button:Hide()
	end
end

local function BuildFolderItems()
	local db = EnsureDatabase()
	NormalizeVisibleItemAssignments()
	local buckets = {}

	for _, folder in ipairs(GetOrderedFolders()) do
		buckets[folder.id] = {}
	end

	for _, item in ipairs(GetVisibleItems()) do
		local folderID = NormalizeFolderID(db.itemFolders[item.guid])
		if not FolderExists(folderID) then
			folderID = BAG_FOLDER_DEFAULT_ID
			db.itemFolders[item.guid] = nil
		end
		buckets[folderID] = buckets[folderID] or {}
		item.position = db.itemPositions[item.guid]
		buckets[folderID][item.position] = item
	end

	return buckets
end

local function GetRowsForFolder(itemsByPosition)
	local highestPosition = 0
	for position in pairs(itemsByPosition or {}) do
		if type(position) == "number" and position > highestPosition then
			highestPosition = position
		end
	end

	local highestOccupiedRow = math.ceil(highestPosition / COLUMNS)
	return math.max(1, highestOccupiedRow + 1)
end

local function GetBackpackTokenFrame()
	if BackpackTokenFrame then
		return BackpackTokenFrame
	end

	if ContainerFrameSettingsManager and ContainerFrameSettingsManager.GetTokenTracker then
		return ContainerFrameSettingsManager:GetTokenTracker()
	end

	return nil
end

local function EnsureMoneyFrame(folderFrame)
	if folderFrame.MoneyFrame then
		return folderFrame.MoneyFrame
	end

	folderFrame.MoneyFrame = CreateFrame("Frame", nil, folderFrame, "ContainerMoneyFrameTemplate")
	folderFrame.MoneyFrame:SetHeight(MONEY_FRAME_HEIGHT)
	return folderFrame.MoneyFrame
end

local function UpdateDefaultCurrencyFrames(folderFrame)
	local moneyFrame = EnsureMoneyFrame(folderFrame)
	local tokenFrame = GetBackpackTokenFrame()
	local tokenHeight = 0

	if tokenFrame and tokenFrame.ShouldShow and tokenFrame:ShouldShow() then
		folderFrame.TokenFrame = tokenFrame
		tokenFrame:SetParent(folderFrame)
		if tokenFrame.SetIsCombinedInventory then
			tokenFrame:SetIsCombinedInventory(false)
		end
		tokenFrame:ClearAllPoints()
		tokenFrame:SetPoint("BOTTOMLEFT", folderFrame, "BOTTOMLEFT", 8, CURRENCY_BOTTOM_PADDING)
		tokenFrame:SetPoint("BOTTOMRIGHT", folderFrame, "BOTTOMRIGHT", -8, CURRENCY_BOTTOM_PADDING)
		tokenFrame:Show()
		tokenHeight = tokenFrame:GetHeight() + TOKEN_FRAME_SPACING
	else
		if folderFrame.TokenFrame then
			folderFrame.TokenFrame:Hide()
			folderFrame.TokenFrame:SetParent(UIParent)
			folderFrame.TokenFrame = nil
		end
	end

	moneyFrame:ClearAllPoints()
	moneyFrame:SetPoint("BOTTOMLEFT", folderFrame, "BOTTOMLEFT", 8, CURRENCY_BOTTOM_PADDING + tokenHeight)
	moneyFrame:SetPoint("BOTTOMRIGHT", folderFrame, "BOTTOMRIGHT", -8, CURRENCY_BOTTOM_PADDING + tokenHeight)
	moneyFrame:Show()

	return CURRENCY_BOTTOM_PADDING + tokenHeight + moneyFrame:GetHeight() + 4
end

local function HideCurrencyFrames(folderFrame)
	if folderFrame.MoneyFrame then
		folderFrame.MoneyFrame:Hide()
	end
	if folderFrame.TokenFrame then
		folderFrame.TokenFrame:Hide()
		folderFrame.TokenFrame:SetParent(UIParent)
		folderFrame.TokenFrame = nil
	end
end

local function GetInitialContainerFrameOffsetX()
	if EditModeUtil and EditModeUtil.GetRightActionBarWidth then
		return EditModeUtil:GetRightActionBarWidth() + 10
	end

	return 10
end

local function GetAutoScale(autoFrames)
	local scale = 1
	while scale > MIN_SCALE do
		local screenHeight = GetScreenHeight() / scale
		local screenWidth = GetScreenWidth()
		local xOffset = GetInitialContainerFrameOffsetX()
		local yOffset = 85 / scale
		local freeHeight = screenHeight - yOffset
		local leftMostPoint = screenWidth - xOffset
		local column = 1
		local forceScaleDecrease = false
		local framesInColumn = 0

		for _, folderFrame in ipairs(autoFrames) do
			framesInColumn = framesInColumn + 1
			local frameHeight = folderFrame:GetHeight()
			if freeHeight < frameHeight then
				if framesInColumn == 1 then
					forceScaleDecrease = true
					break
				end

				column = column + 1
				framesInColumn = 1
				leftMostPoint = screenWidth - (column * folderFrame:GetWidth() * scale) - xOffset
				freeHeight = screenHeight - yOffset
			end

			freeHeight = freeHeight - frameHeight
		end

		if forceScaleDecrease or leftMostPoint < 0 then
			scale = scale - 0.01
		else
			break
		end
	end

	return math.max(scale, MIN_SCALE)
end

local function LayoutAutoFrames(autoFrames)
	local scale = GetAutoScale(autoFrames)
	local screenHeight = GetScreenHeight() / scale
	local xOffset = GetInitialContainerFrameOffsetX() / scale
	local yOffset = 85 / scale
	local freeHeight = screenHeight - yOffset
	local previousFrame
	local firstFrameInColumn

	for index, folderFrame in ipairs(autoFrames) do
		folderFrame:SetScale(scale)
		folderFrame:ClearAllPoints()
		if index == 1 then
			folderFrame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -xOffset, yOffset)
			firstFrameInColumn = folderFrame
		elseif freeHeight < folderFrame:GetHeight() then
			freeHeight = screenHeight - yOffset
			folderFrame:SetPoint("BOTTOMRIGHT", firstFrameInColumn, "BOTTOMLEFT", -11, 0)
			firstFrameInColumn = folderFrame
		else
			folderFrame:SetPoint("BOTTOMRIGHT", previousFrame, "TOPRIGHT", 0, CONTAINER_SPACING)
		end

		previousFrame = folderFrame
		freeHeight = freeHeight - folderFrame:GetHeight()
	end
end

local function RenderFolder(folder, itemsByPosition, cellState)
	local folderFrame = GetOrCreateFolderFrame(folder.id)
	local rows = GetRowsForFolder(itemsByPosition)
	local cellCount = rows * COLUMNS
	local isDefaultFolder = folder.id == BAG_FOLDER_DEFAULT_ID
	local extraBottomHeight = isDefaultFolder and UpdateDefaultCurrencyFrames(folderFrame) or FRAME_PADDING_BOTTOM
	if not isDefaultFolder then
		HideCurrencyFrames(folderFrame)
	end
	folderFrame.folderID = folder.id
	folderFrame:SetTitle(folder.name)
	folderFrame:SetPortraitToAsset(GetFolderIcon(folder.id))
	ApplyNativePortraitSizing(folderFrame)
	folderFrame:SetSize(FRAME_WIDTH, CalculateFrameHeight(rows, extraBottomHeight))
	folderFrame.items = itemsByPosition
	folderFrame:Show()
	folderFrame:Raise()

	for cellIndex = 1, cellCount do
		local item = itemsByPosition[cellIndex]
		if item then
			cellState.usedItemButtons = cellState.usedItemButtons + 1
			local button = GetOrCreateItemButton(folderFrame, cellState.usedItemButtons)
			button.folderID = folder.id
			button.cellIndex = cellIndex
			button.itemGUID = item.guid
			button:Initialize(item.bagID, item.slotID)
			PositionCell(button, cellIndex)
			button:Show()
			UpdateItemButton(button)
		else
			cellState.usedEmptyButtons = cellState.usedEmptyButtons + 1
			local button = GetOrCreateEmptyButton(folderFrame, cellState.usedEmptyButtons)
			button.folderID = folder.id
			button.cellIndex = cellIndex
			PositionCell(button, cellIndex)
			button:Show()
		end
	end

	return folderFrame
end

function addon.RefreshBagFolders()
	if isRefreshing then
		return
	end

	isRefreshing = true
	EnsureDatabase()
	HideAllItemCells()

	local activeFolders = {}
	local autoFrames = {}
	local buckets = BuildFolderItems()
	local cellState = {
		usedItemButtons = 0,
		usedEmptyButtons = 0,
	}

	for _, folder in ipairs(GetOrderedFolders()) do
		if IsFolderHidden(folder.id) then
			local folderKey = GetFolderKey(folder.id)
			if folderFrames[folderKey] then
				folderFrames[folderKey]:Hide()
			end
		else
			local folderFrame = RenderFolder(folder, buckets[folder.id] or {}, cellState)
			local folderKey = GetFolderKey(folder.id)
			activeFolders[folderKey] = true
			table.insert(autoFrames, folderFrame)
		end
	end

	HideUnusedFrames(activeFolders)
	LayoutAutoFrames(autoFrames)
	isRefreshing = false
end

local function HideBlizzardNormalBags()
	if ContainerFrameCombinedBags then
		ContainerFrameCombinedBags:Hide()
	end

	if NUM_CONTAINER_FRAMES then
		for index = 1, NUM_CONTAINER_FRAMES do
			local containerFrame = _G["ContainerFrame" .. index]
			if containerFrame and containerFrame:IsShown() and IsNormalBagID(containerFrame:GetID()) then
				containerFrame:Hide()
			end
		end
	end
end

function addon.AreBagFoldersShown()
	for _, folderFrame in pairs(folderFrames) do
		if folderFrame:IsShown() then
			return true
		end
	end

	return false
end

local function ShowBagFolders()
	if not IsEnabled() or not CanOpenBags() then
		return
	end

	HideBlizzardNormalBags()
	addon.RefreshBagFolders()
end

local function HideBagFolders()
	local hiddenAny = false
	for _, folderFrame in pairs(folderFrames) do
		if folderFrame:IsShown() then
			folderFrame:Hide()
			hiddenAny = true
		end
	end

	return hiddenAny
end

function addon.SetBagFoldersEnabled(enabled)
	EnsureDatabase().enabled = not not enabled
	if not enabled then
		HideBagFolders()
	end
end

local function CallOriginal(name, ...)
	local original = originalFunctions[name]
	if original then
		return original(...)
	end
end

local function InstallFunctionHooks()
	if hooksInstalled then
		return true
	end

	local names = {
		"ToggleBackpack",
		"OpenBackpack",
		"CloseBackpack",
		"ToggleBag",
		"OpenBag",
		"CloseBag",
		"CloseAllBags",
		"ToggleAllBags",
		"OpenAllBags",
		"IsBagOpen",
	}

	for _, name in ipairs(names) do
		if type(_G[name]) ~= "function" then
			return false
		end
	end

	for _, name in ipairs(names) do
		originalFunctions[name] = _G[name]
	end

	_G.ToggleBackpack = function()
		if IsEnabled() then
			if addon.AreBagFoldersShown() then
				HideBagFolders()
			else
				ShowBagFolders()
			end
			return
		end

		return CallOriginal("ToggleBackpack")
	end

	_G.OpenBackpack = function()
		if IsEnabled() then
			ShowBagFolders()
			return
		end

		return CallOriginal("OpenBackpack")
	end

	_G.CloseBackpack = function()
		if IsEnabled() then
			return HideBagFolders()
		end

		return CallOriginal("CloseBackpack")
	end

	_G.ToggleBag = function(bagID)
		if IsEnabled() and IsNormalBagID(bagID) then
			if addon.AreBagFoldersShown() then
				HideBagFolders()
			else
				ShowBagFolders()
			end
			return
		end

		return CallOriginal("ToggleBag", bagID)
	end

	_G.OpenBag = function(bagID, force)
		if IsEnabled() and IsNormalBagID(bagID) then
			ShowBagFolders()
			return
		end

		return CallOriginal("OpenBag", bagID, force)
	end

	_G.CloseBag = function(bagID)
		if IsEnabled() and IsNormalBagID(bagID) then
			return HideBagFolders()
		end

		return CallOriginal("CloseBag", bagID)
	end

	_G.CloseAllBags = function(...)
		local closed = false
		if IsEnabled() then
			closed = HideBagFolders() or closed
		end

		local originalClosed = CallOriginal("CloseAllBags", ...)
		return closed or originalClosed
	end

	_G.ToggleAllBags = function()
		if IsEnabled() then
			if addon.AreBagFoldersShown() then
				HideBagFolders()
			else
				ShowBagFolders()
			end
			return
		end

		return CallOriginal("ToggleAllBags")
	end

	_G.OpenAllBags = function(frameThatOpenedBags, forceUpdate)
		if IsEnabled() then
			ShowBagFolders()
			return
		end

		return CallOriginal("OpenAllBags", frameThatOpenedBags, forceUpdate)
	end

	_G.IsBagOpen = function(bagID)
		if IsEnabled() and IsNormalBagID(bagID) and addon.AreBagFoldersShown() then
			return true
		end

		return CallOriginal("IsBagOpen", bagID)
	end

	hooksInstalled = true
	return true
end

function addon.InstallBagFolders()
	EnsureDatabase()
	if InstallFunctionHooks() and hookRetryFrame then
		hookRetryFrame:UnregisterAllEvents()
	end
end

addon.InstallBagFolders()

if not hooksInstalled then
	hookRetryFrame = CreateFrame("Frame")
	hookRetryFrame:RegisterEvent("ADDON_LOADED")
	hookRetryFrame:RegisterEvent("PLAYER_LOGIN")
	hookRetryFrame:SetScript("OnEvent", function()
		addon.InstallBagFolders()
	end)
end
