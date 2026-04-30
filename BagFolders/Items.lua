local addonName, addon = ...
local BagFolders = addon.BagFolders

local DEFAULT_FOLDER_ID = BagFolders.DEFAULT_FOLDER_ID

function BagFolders.GetItemGUID(bagID, slotID)
	if not bagID or not slotID then
		return nil
	end

	local itemLocation = ItemLocation:CreateFromBagAndSlot(bagID, slotID)
	if not itemLocation or not itemLocation:IsValid() then
		return nil
	end

	return C_Item.GetItemGUID(itemLocation)
end

function BagFolders.GetCursorItemGUID()
	local cursorItemLocation = C_Cursor.GetCursorItem()
	if not cursorItemLocation then
		return nil
	end

	local bagID, slotID = cursorItemLocation:GetBagAndSlot()
	if not BagFolders.IsNormalBagID(bagID) then
		return nil
	end

	return BagFolders.GetItemGUID(bagID, slotID), bagID, slotID
end

function BagFolders.GetCursorItemInfo()
	local cursorItemLocation = C_Cursor.GetCursorItem()
	if not cursorItemLocation then
		return nil
	end

	local bagID, slotID = cursorItemLocation:GetBagAndSlot()
	local itemGUID = C_Item.GetItemGUID(cursorItemLocation)
	if not itemGUID then
		itemGUID = BagFolders.GetItemGUID(bagID, slotID)
	end

	if not itemGUID then
		return nil
	end

	return itemGUID, bagID, slotID, BagFolders.IsNormalBagID(bagID)
end

function BagFolders.FindFirstEmptyNormalBagSlot()
	local emptyBagID, emptySlotID
	BagFolders.ForEachNormalBag(function(bagID)
		if emptyBagID then
			return
		end

		local slotCount = C_Container.GetContainerNumSlots(bagID) or 0
		for slotID = 1, slotCount do
			local info = C_Container.GetContainerItemInfo(bagID, slotID)
			if not info or not info.iconFileID then
				emptyBagID = bagID
				emptySlotID = slotID
				return
			end
		end
	end)

	return emptyBagID, emptySlotID
end

function BagFolders.GetVisibleItems()
	local items = {}

	BagFolders.ForEachNormalBag(function(bagID)
		local slotCount = C_Container.GetContainerNumSlots(bagID) or 0
		for slotID = 1, slotCount do
			local info = C_Container.GetContainerItemInfo(bagID, slotID)
			if info and info.iconFileID then
				local itemGUID = BagFolders.GetItemGUID(bagID, slotID)
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

function BagFolders.GetVisibleGUIDs(visibleItems)
	local visibleGUIDs = {}
	for _, item in ipairs(visibleItems or BagFolders.GetVisibleItems()) do
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

function BagFolders.NormalizeVisibleItemAssignments(visibleItems)
	BagFolders.EnsureDatabase()
	local charData = BagFolders.GetCharacterData()
	local usedByFolder = {}

	for _, item in ipairs(visibleItems or BagFolders.GetVisibleItems()) do
		local folderID = BagFolders.NormalizeFolderID(charData.itemFolders[item.guid])
		if not BagFolders.FolderExists(folderID) then
			folderID = DEFAULT_FOLDER_ID
			charData.itemFolders[item.guid] = nil
		end

		local folderKey = BagFolders.GetFolderKey(folderID)
		usedByFolder[folderKey] = usedByFolder[folderKey] or {}

		local position = charData.itemPositions[item.guid]
		if type(position) ~= "number" or position < 1 or usedByFolder[folderKey][position] then
			position = GetNextFreePosition(usedByFolder[folderKey])
			charData.itemPositions[item.guid] = position
		end
		usedByFolder[folderKey][position] = item.guid
	end
end

function BagFolders.MoveNewBankItemsToDefaultFolder(visibleItems)
	visibleItems = visibleItems or BagFolders.GetVisibleItems()

	local lastVisibleGUIDs = BagFolders.lastVisibleGUIDs
	local visibleGUIDs = BagFolders.GetVisibleGUIDs(visibleItems)
	if lastVisibleGUIDs and BankFrame and BankFrame:IsShown() then
		BagFolders.EnsureDatabase()
		local charData = BagFolders.GetCharacterData()
		local newBankItemGUIDs = {}
		local usedDefaultPositions = {}

		for _, item in ipairs(visibleItems) do
			if not lastVisibleGUIDs[item.guid] and not BagFolders.pendingExternalItemGUIDs[item.guid] then
				newBankItemGUIDs[item.guid] = true
			end
		end

		for _, item in ipairs(visibleItems) do
			if not newBankItemGUIDs[item.guid] then
				local folderID = BagFolders.NormalizeFolderID(charData.itemFolders[item.guid])
				local position = charData.itemPositions[item.guid]
				if folderID == DEFAULT_FOLDER_ID and type(position) == "number" and position >= 1 then
					usedDefaultPositions[position] = true
				end
			end
		end

		for _, item in ipairs(visibleItems) do
			if newBankItemGUIDs[item.guid] then
				local position = GetNextFreePosition(usedDefaultPositions)
				charData.itemFolders[item.guid] = nil
				charData.itemPositions[item.guid] = position
				usedDefaultPositions[position] = true
			end
		end
	end

	BagFolders.lastVisibleGUIDs = visibleGUIDs
	for itemGUID in pairs(BagFolders.pendingExternalItemGUIDs) do
		if visibleGUIDs[itemGUID] then
			BagFolders.pendingExternalItemGUIDs[itemGUID] = nil
		end
	end
end

function BagFolders.AssignItemToCell(itemGUID, folderID, cellIndex, visibleItems)
	BagFolders.EnsureDatabase()
	local charData = BagFolders.GetCharacterData()
	local targetFolderID = BagFolders.NormalizeFolderID(folderID)
	local targetCellIndex = math.max(1, math.floor(cellIndex or 1))
	local oldFolderID = BagFolders.NormalizeFolderID(charData.itemFolders[itemGUID])
	local oldPosition = charData.itemPositions[itemGUID]
	local targetGUID

	for _, item in ipairs(visibleItems or BagFolders.GetVisibleItems()) do
		local guid = item.guid
		local position = charData.itemPositions[guid]
		local guidFolderID = BagFolders.NormalizeFolderID(charData.itemFolders[guid])
		if guid ~= itemGUID and guidFolderID == targetFolderID and position == targetCellIndex then
			targetGUID = guid
			break
		end
	end

	if targetFolderID == DEFAULT_FOLDER_ID then
		charData.itemFolders[itemGUID] = nil
	else
		charData.itemFolders[itemGUID] = targetFolderID
	end
	charData.itemPositions[itemGUID] = targetCellIndex

	if targetGUID then
		if oldFolderID == DEFAULT_FOLDER_ID then
			charData.itemFolders[targetGUID] = nil
		else
			charData.itemFolders[targetGUID] = oldFolderID
		end
		if oldPosition then
			charData.itemPositions[targetGUID] = oldPosition
		else
			local usedPositions = {}
			for _, item in ipairs(visibleItems or BagFolders.GetVisibleItems()) do
				local guid = item.guid
				if guid ~= itemGUID and guid ~= targetGUID and BagFolders.NormalizeFolderID(charData.itemFolders[guid]) == oldFolderID then
					local position = charData.itemPositions[guid]
					if type(position) == "number" and position >= 1 then
						usedPositions[position] = true
					end
				end
			end
			charData.itemPositions[targetGUID] = GetNextFreePosition(usedPositions)
		end
	end
end

function BagFolders.PlaceItemGUIDToCell(itemGUID, folderID, cellIndex)
	if not itemGUID then
		return false
	end

	local visibleItems = BagFolders.GetVisibleItems()
	BagFolders.NormalizeVisibleItemAssignments(visibleItems)
	BagFolders.AssignItemToCell(itemGUID, folderID, cellIndex, visibleItems)
	ClearCursor()
	BagFolders.pendingDraggedItemGUID = nil
	addon.RefreshBagFolders(visibleItems, true)
	return true
end

function BagFolders.PlaceExternalCursorItemToCell(folderID, cellIndex)
	local itemGUID, _sourceBagID, _sourceSlotID, isNormalBagItem = BagFolders.GetCursorItemInfo()
	if not itemGUID or isNormalBagItem then
		return false
	end

	local targetBagID, targetSlotID = BagFolders.FindFirstEmptyNormalBagSlot()
	if not targetBagID or not targetSlotID then
		return false
	end

	local visibleItems = BagFolders.GetVisibleItems()
	BagFolders.NormalizeVisibleItemAssignments(visibleItems)
	BagFolders.AssignItemToCell(itemGUID, folderID, cellIndex, visibleItems)
	BagFolders.pendingExternalItemGUIDs[itemGUID] = true

	-- Mirrors Blizzard bank/container transfer behavior: drop the cursor item into a real empty bag slot.
	C_Container.PickupContainerItem(targetBagID, targetSlotID)
	BagFolders.pendingDraggedItemGUID = nil
	addon.RequestBagFoldersRefresh()
	return true
end

function BagFolders.DropCursorItemToCell(folderID, cellIndex)
	local itemGUID = BagFolders.GetCursorItemGUID()
	return BagFolders.PlaceItemGUIDToCell(itemGUID, folderID, cellIndex) or BagFolders.PlaceExternalCursorItemToCell(folderID, cellIndex)
end
