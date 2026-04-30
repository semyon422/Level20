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
		charData.itemPositions[targetGUID] = oldPosition or targetCellIndex
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

function BagFolders.DropCursorItemToCell(folderID, cellIndex)
	local itemGUID = BagFolders.GetCursorItemGUID()
	return BagFolders.PlaceItemGUIDToCell(itemGUID, folderID, cellIndex)
end
