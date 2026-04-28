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

function BagFolders.GetVisibleGUIDs()
	local visibleGUIDs = {}
	for _, item in ipairs(BagFolders.GetVisibleItems()) do
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

function BagFolders.NormalizeVisibleItemAssignments()
	local db = BagFolders.EnsureDatabase()
	local usedByFolder = {}

	for _, item in ipairs(BagFolders.GetVisibleItems()) do
		local folderID = BagFolders.NormalizeFolderID(db.itemFolders[item.guid])
		if not BagFolders.FolderExists(folderID) then
			folderID = DEFAULT_FOLDER_ID
			db.itemFolders[item.guid] = nil
		end

		local folderKey = BagFolders.GetFolderKey(folderID)
		usedByFolder[folderKey] = usedByFolder[folderKey] or {}

		local position = db.itemPositions[item.guid]
		if type(position) ~= "number" or position < 1 or usedByFolder[folderKey][position] then
			position = GetNextFreePosition(usedByFolder[folderKey])
			db.itemPositions[item.guid] = position
		end
		usedByFolder[folderKey][position] = item.guid
	end
end

function BagFolders.AssignItemToCell(itemGUID, folderID, cellIndex)
	local db = BagFolders.EnsureDatabase()
	local targetFolderID = BagFolders.NormalizeFolderID(folderID)
	local targetCellIndex = math.max(1, math.floor(cellIndex or 1))
	local oldFolderID = BagFolders.NormalizeFolderID(db.itemFolders[itemGUID])
	local oldPosition = db.itemPositions[itemGUID]
	local targetGUID
	local visibleGUIDs = BagFolders.GetVisibleGUIDs()

	for guid, position in pairs(db.itemPositions) do
		local guidFolderID = BagFolders.NormalizeFolderID(db.itemFolders[guid])
		if visibleGUIDs[guid] and guid ~= itemGUID and guidFolderID == targetFolderID and position == targetCellIndex then
			targetGUID = guid
			break
		end
	end

	if targetFolderID == DEFAULT_FOLDER_ID then
		db.itemFolders[itemGUID] = nil
	else
		db.itemFolders[itemGUID] = targetFolderID
	end
	db.itemPositions[itemGUID] = targetCellIndex

	if targetGUID then
		if oldFolderID == DEFAULT_FOLDER_ID then
			db.itemFolders[targetGUID] = nil
		else
			db.itemFolders[targetGUID] = oldFolderID
		end
		db.itemPositions[targetGUID] = oldPosition or targetCellIndex
	end
end

function BagFolders.PlaceItemGUIDToCell(itemGUID, folderID, cellIndex)
	if not itemGUID then
		return false
	end

	BagFolders.NormalizeVisibleItemAssignments()
	BagFolders.AssignItemToCell(itemGUID, folderID, cellIndex)
	ClearCursor()
	BagFolders.pendingDraggedItemGUID = nil
	addon.RefreshBagFolders()
	return true
end

function BagFolders.DropCursorItemToCell(folderID, cellIndex)
	local itemGUID = BagFolders.GetCursorItemGUID()
	return BagFolders.PlaceItemGUIDToCell(itemGUID, folderID, cellIndex)
end
