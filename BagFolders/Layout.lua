local addonName, addon = ...
local BagFolders = addon.BagFolders

local DEFAULT_FOLDER_ID = BagFolders.DEFAULT_FOLDER_ID
local COLUMNS = BagFolders.COLUMNS
local FRAME_WIDTH = BagFolders.FRAME_WIDTH
local FRAME_PADDING_BOTTOM = BagFolders.FRAME_PADDING_BOTTOM
local MONEY_FRAME_HEIGHT = BagFolders.MONEY_FRAME_HEIGHT
local TOKEN_FRAME_SPACING = BagFolders.TOKEN_FRAME_SPACING
local CURRENCY_BOTTOM_PADDING = BagFolders.CURRENCY_BOTTOM_PADDING
local CONTAINER_SPACING = BagFolders.CONTAINER_SPACING
local MIN_SCALE = BagFolders.MIN_SCALE

local function BuildFolderItems(visibleItems, assignmentsAreNormalized)
	BagFolders.EnsureDatabase()
	local charData = BagFolders.GetCharacterData()
	visibleItems = visibleItems or BagFolders.GetVisibleItems()
	if not assignmentsAreNormalized then
		BagFolders.NormalizeVisibleItemAssignments(visibleItems)
	end
	local buckets = {}

	for _, folder in ipairs(BagFolders.GetOrderedFolders()) do
		buckets[folder.id] = {}
	end

	for _, item in ipairs(visibleItems) do
		local folderID = BagFolders.NormalizeFolderID(charData.itemFolders[item.guid])
		if not BagFolders.FolderExists(folderID) then
			folderID = DEFAULT_FOLDER_ID
			charData.itemFolders[item.guid] = nil
		end
		buckets[folderID] = buckets[folderID] or {}
		item.position = charData.itemPositions[item.guid]
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
	local folderFrame = BagFolders.GetOrCreateFolderFrame(folder.id)
	local rows = GetRowsForFolder(itemsByPosition)
	local cellCount = rows * COLUMNS
	local isDefaultFolder = folder.id == DEFAULT_FOLDER_ID
	local extraBottomHeight = isDefaultFolder and UpdateDefaultCurrencyFrames(folderFrame) or FRAME_PADDING_BOTTOM
	if not isDefaultFolder then
		HideCurrencyFrames(folderFrame)
	end
	folderFrame.folderID = folder.id
	folderFrame:SetTitle(folder.name)
	folderFrame:SetPortraitToAsset(BagFolders.GetFolderIcon(folder.id))
	BagFolders.ApplyNativePortraitSizing(folderFrame)
	folderFrame:SetSize(FRAME_WIDTH, BagFolders.CalculateFrameHeight(rows, extraBottomHeight))
	folderFrame.items = itemsByPosition
	folderFrame:Show()
	folderFrame:Raise()

	for cellIndex = 1, cellCount do
		local item = itemsByPosition[cellIndex]
		if item then
			cellState.usedItemButtons = cellState.usedItemButtons + 1
			local button = BagFolders.GetOrCreateItemButton(folderFrame, cellState.usedItemButtons)
			button.folderID = folder.id
			button.cellIndex = cellIndex
			button.itemGUID = item.guid
			button:Initialize(item.bagID, item.slotID)
			BagFolders.PositionCell(button, cellIndex)
			button:Show()
			BagFolders.UpdateItemButton(button)
		else
			cellState.usedEmptyButtons = cellState.usedEmptyButtons + 1
			local button = BagFolders.GetOrCreateEmptyButton(folderFrame, cellState.usedEmptyButtons)
			button.folderID = folder.id
			button.cellIndex = cellIndex
			BagFolders.PositionCell(button, cellIndex)
			button:Show()
		end
	end

	return folderFrame
end

function addon.RefreshBagFolders(visibleItems, assignmentsAreNormalized)
	if BagFolders.isRefreshing then
		BagFolders.needsRefresh = true
		return
	end

	BagFolders.isRefreshing = true
	BagFolders.refreshQueued = false
	BagFolders.needsRefresh = false
	BagFolders.EnsureDatabase()
	BagFolders.HideAllItemCells()

	local activeFolders = {}
	local autoFrames = {}
	local buckets = BuildFolderItems(visibleItems, assignmentsAreNormalized)
	local cellState = {
		usedItemButtons = 0,
		usedEmptyButtons = 0,
	}

	for _, folder in ipairs(BagFolders.GetOrderedFolders()) do
		if BagFolders.IsFolderHidden(folder.id) then
			local folderKey = BagFolders.GetFolderKey(folder.id)
			if BagFolders.folderFrames[folderKey] then
				BagFolders.folderFrames[folderKey]:Hide()
			end
		else
			local folderFrame = RenderFolder(folder, buckets[folder.id] or {}, cellState)
			local folderKey = BagFolders.GetFolderKey(folder.id)
			activeFolders[folderKey] = true
			table.insert(autoFrames, folderFrame)
		end
	end

	BagFolders.HideUnusedFrames(activeFolders)
	LayoutAutoFrames(autoFrames)
	BagFolders.isRefreshing = false

	if BagFolders.needsRefresh then
		addon.RequestBagFoldersRefresh()
	end
end

function addon.RequestBagFoldersRefresh()
	if BagFolders.refreshQueued then
		return
	end

	BagFolders.refreshQueued = true
	C_Timer.After(0, function()
		if BagFolders.refreshQueued and BagFolders.IsEnabled() and addon.AreBagFoldersShown and addon.AreBagFoldersShown() then
			addon.RefreshBagFolders()
		else
			BagFolders.refreshQueued = false
		end
	end)
end
