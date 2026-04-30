local addonName, addon = ...
local BagFolders = addon.BagFolders
local L = addon.L

local DEFAULT_FOLDER_ID = BagFolders.DEFAULT_FOLDER_ID
local DEFAULT_FOLDER_ICON = BagFolders.DEFAULT_FOLDER_ICON

function BagFolders.GetCharacterKey()
	local name = UnitName("player")
	local realm = GetRealmName()
	return name .. "-" .. realm
end

function BagFolders.EnsureDatabase()
	Level20DB.bagFolders = Level20DB.bagFolders or {}
	local db = Level20DB.bagFolders

	if db.enabled == nil then
		db.enabled = false
	end
	
	-- Initialize character-specific data
	local characterKey = BagFolders.GetCharacterKey()
	db.characters = db.characters or {}
	db.characters[characterKey] = db.characters[characterKey] or {}
	local charData = db.characters[characterKey]
	
	charData.folders = charData.folders or {}
	charData.itemFolders = charData.itemFolders or {}
	charData.itemPositions = charData.itemPositions or {}
	charData.hiddenFolders = charData.hiddenFolders or {}
	
	-- Global settings (shared across characters)
	db.defaultIcon = db.defaultIcon or DEFAULT_FOLDER_ICON

	return db
end

function BagFolders.GetCharacterData()
	local db = BagFolders.EnsureDatabase()
	local characterKey = BagFolders.GetCharacterKey()
	return db.characters[characterKey]
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

function BagFolders.IsReagentBagID(bagID)
	local reagentBagSlots = Constants.InventoryConstants.NumReagentBagSlots or 0
	local firstReagentBagID = Constants.InventoryConstants.NumBagSlots + 1
	local lastReagentBagID = Constants.InventoryConstants.NumBagSlots + reagentBagSlots
	return type(bagID) == "number"
		and bagID >= firstReagentBagID
		and bagID <= lastReagentBagID
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

	local charData = BagFolders.GetCharacterData()
	for _, folder in ipairs(charData.folders) do
		if folder.id == folderID then
			return true
		end
	end

	return false
end

function BagFolders.GetNextFolderID()
	local usedIDs = {}
	local charData = BagFolders.GetCharacterData()
	for _, folder in ipairs(charData.folders) do
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

	local charData = BagFolders.GetCharacterData()
	for _, folder in ipairs(charData.folders) do
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

	local charData = BagFolders.GetCharacterData()
	for _, folder in ipairs(charData.folders) do
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
		local charData = BagFolders.GetCharacterData()
		for _, folder in ipairs(charData.folders) do
			if folder.id == folderID then
				folder.icon = icon
				break
			end
		end
	end

	addon.RefreshBagFolders()
end

function BagFolders.GetOrderedFolders()
	local charData = BagFolders.GetCharacterData()
	local orderedFolders = {
		{ id = DEFAULT_FOLDER_ID, name = L.BAG_FOLDERS_DEFAULT },
	}

	for _, folder in ipairs(charData.folders) do
		table.insert(orderedFolders, folder)
	end

	return orderedFolders
end

function BagFolders.IsFolderHidden(folderID)
	local charData = BagFolders.GetCharacterData()
	return charData.hiddenFolders[BagFolders.NormalizeFolderID(folderID)] == true
end

function BagFolders.HasHiddenFolders()
	local charData = BagFolders.GetCharacterData()
	for _, hidden in pairs(charData.hiddenFolders) do
		if hidden then
			return true
		end
	end

	return false
end

function BagFolders.CreateFolder(name)
	local db = BagFolders.EnsureDatabase()
	local charData = BagFolders.GetCharacterData()
	local folderName = name ~= "" and name or L.BAG_FOLDERS_NEW_FOLDER
	local folderID = BagFolders.GetNextFolderID()
	table.insert(charData.folders, {
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

	local charData = BagFolders.GetCharacterData()
	for _, folder in ipairs(charData.folders) do
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
	local charData = BagFolders.GetCharacterData()
	for index, folder in ipairs(charData.folders) do
		if folder.id == folderID then
			table.remove(charData.folders, index)
			break
		end
	end

	for itemGUID, assignedFolderID in pairs(charData.itemFolders) do
		if BagFolders.NormalizeFolderID(assignedFolderID) == folderID then
			charData.itemFolders[itemGUID] = nil
			charData.itemPositions[itemGUID] = nil
		end
	end
	charData.hiddenFolders[folderID] = nil
	addon.RefreshBagFolders()
end

function BagFolders.HideFolder(folderID)
	folderID = BagFolders.NormalizeFolderID(folderID)
	if folderID == DEFAULT_FOLDER_ID then
		return
	end

	local charData = BagFolders.GetCharacterData()
	charData.hiddenFolders[folderID] = true
	addon.RefreshBagFolders()
end

function BagFolders.ShowAllFolders()
	local charData = BagFolders.GetCharacterData()
	wipe(charData.hiddenFolders)
	addon.RefreshBagFolders()
end

function addon.ResetBagFolders()
	local enabled = false
	if Level20DB.bagFolders and Level20DB.bagFolders.enabled ~= nil then
		enabled = Level20DB.bagFolders.enabled and true or false
	end

	Level20DB.bagFolders = {
		enabled = enabled,
		characters = {},
		defaultIcon = DEFAULT_FOLDER_ICON,
	}

	for _, folderFrame in pairs(BagFolders.folderFrames) do
		folderFrame:Hide()
	end
	wipe(BagFolders.folderFrames)
	BagFolders.pendingDraggedItemGUID = nil

	addon.RefreshBagFolders()
end
