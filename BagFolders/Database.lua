local addonName, addon = ...
local BagFolders = addon.BagFolders
local L = addon.L

local DEFAULT_FOLDER_ID = BagFolders.DEFAULT_FOLDER_ID
local DEFAULT_FOLDER_ICON = BagFolders.DEFAULT_FOLDER_ICON

function BagFolders.EnsureDatabase()
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

function BagFolders.NormalizeFolderID(folderID)
	if folderID == nil then
		return DEFAULT_FOLDER_ID
	end

	return folderID
end

function BagFolders.GetFolderKey(folderID)
	return BagFolders.NormalizeFolderID(folderID)
end

function BagFolders.IsNormalBagID(bagID)
	return type(bagID) == "number"
		and bagID >= Enum.BagIndex.Backpack
		and bagID <= Constants.InventoryConstants.NumBagSlots
end

function BagFolders.ForEachNormalBag(callback)
	for bagID = Enum.BagIndex.Backpack, Constants.InventoryConstants.NumBagSlots do
		callback(bagID)
	end
end

function BagFolders.IsEnabled()
	return BagFolders.EnsureDatabase().enabled
end

function BagFolders.CanOpenBags()
	if ContainerFrame_AllowedToOpenBags then
		return ContainerFrame_AllowedToOpenBags()
	end

	return CanOpenPanels()
end

function BagFolders.FolderExists(folderID)
	folderID = BagFolders.NormalizeFolderID(folderID)
	if folderID == DEFAULT_FOLDER_ID then
		return true
	end

	for _, folder in ipairs(BagFolders.EnsureDatabase().folders) do
		if folder.id == folderID then
			return true
		end
	end

	return false
end

function BagFolders.GetNextFolderID()
	local usedIDs = {}
	for _, folder in ipairs(BagFolders.EnsureDatabase().folders) do
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

function BagFolders.GetFolderName(folderID)
	folderID = BagFolders.NormalizeFolderID(folderID)
	if folderID == DEFAULT_FOLDER_ID then
		return L.BAG_FOLDERS_DEFAULT
	end

	for _, folder in ipairs(BagFolders.EnsureDatabase().folders) do
		if folder.id == folderID then
			return folder.name
		end
	end

	return L.BAG_FOLDERS_DEFAULT
end

function BagFolders.GetFolderIcon(folderID)
	folderID = BagFolders.NormalizeFolderID(folderID)
	local db = BagFolders.EnsureDatabase()
	if folderID == DEFAULT_FOLDER_ID then
		return db.defaultIcon or DEFAULT_FOLDER_ICON
	end

	for _, folder in ipairs(db.folders) do
		if folder.id == folderID then
			return folder.icon or DEFAULT_FOLDER_ICON
		end
	end

	return DEFAULT_FOLDER_ICON
end

function BagFolders.SetFolderIcon(folderID, icon)
	if not icon then
		return
	end

	folderID = BagFolders.NormalizeFolderID(folderID)
	local db = BagFolders.EnsureDatabase()
	if folderID == DEFAULT_FOLDER_ID then
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

function BagFolders.GetOrderedFolders()
	local db = BagFolders.EnsureDatabase()
	local orderedFolders = {
		{ id = DEFAULT_FOLDER_ID, name = L.BAG_FOLDERS_DEFAULT },
	}

	for _, folder in ipairs(db.folders) do
		table.insert(orderedFolders, folder)
	end

	return orderedFolders
end

function BagFolders.IsFolderHidden(folderID)
	return BagFolders.EnsureDatabase().hiddenFolders[BagFolders.NormalizeFolderID(folderID)] == true
end

function BagFolders.HasHiddenFolders()
	for _, hidden in pairs(BagFolders.EnsureDatabase().hiddenFolders) do
		if hidden then
			return true
		end
	end

	return false
end

function BagFolders.CreateFolder(name)
	local db = BagFolders.EnsureDatabase()
	local folderName = name ~= "" and name or L.BAG_FOLDERS_NEW_FOLDER
	local folderID = BagFolders.GetNextFolderID()
	table.insert(db.folders, {
		id = folderID,
		name = folderName,
		icon = DEFAULT_FOLDER_ICON,
	})
	addon.RefreshBagFolders()
end

function BagFolders.RenameFolder(folderID, name)
	folderID = BagFolders.NormalizeFolderID(folderID)
	if name == "" then
		return
	end

	for _, folder in ipairs(BagFolders.EnsureDatabase().folders) do
		if folder.id == folderID then
			folder.name = name
			break
		end
	end
	addon.RefreshBagFolders()
end

function BagFolders.DeleteFolder(folderID)
	folderID = BagFolders.NormalizeFolderID(folderID)
	local db = BagFolders.EnsureDatabase()
	for index, folder in ipairs(db.folders) do
		if folder.id == folderID then
			table.remove(db.folders, index)
			break
		end
	end

	for itemGUID, assignedFolderID in pairs(db.itemFolders) do
		if BagFolders.NormalizeFolderID(assignedFolderID) == folderID then
			db.itemFolders[itemGUID] = nil
			db.itemPositions[itemGUID] = nil
		end
	end
	db.hiddenFolders[folderID] = nil
	addon.RefreshBagFolders()
end

function BagFolders.HideFolder(folderID)
	folderID = BagFolders.NormalizeFolderID(folderID)
	if folderID == DEFAULT_FOLDER_ID then
		return
	end

	BagFolders.EnsureDatabase().hiddenFolders[folderID] = true
	addon.RefreshBagFolders()
end

function BagFolders.ShowAllFolders()
	wipe(BagFolders.EnsureDatabase().hiddenFolders)
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

	for _, folderFrame in pairs(BagFolders.folderFrames) do
		folderFrame:Hide()
	end
	wipe(BagFolders.folderFrames)
	BagFolders.pendingDraggedItemGUID = nil

	addon.RefreshBagFolders()
end
