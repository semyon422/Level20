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
local TOP_SCREEN_PADDING = BagFolders.TOP_SCREEN_PADDING

local function BuildFolderItems(visibleItems, assignmentsAreNormalized)
	BagFolders.EnsureDatabase()
	local charData = BagFolders.GetCharacterData()
	visibleItems = visibleItems or BagFolders.GetVisibleItems()
	BagFolders.PrepareVisibleItemAssignments(visibleItems, assignmentsAreNormalized)
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

local function EnsureMoneyFrame(folderFrame)
	if folderFrame.MoneyFrame then
		return folderFrame.MoneyFrame
	end

	folderFrame.MoneyFrame = CreateFrame("Frame", nil, folderFrame, "ContainerMoneyFrameTemplate")
	folderFrame.MoneyFrame:SetHeight(MONEY_FRAME_HEIGHT)
	return folderFrame.MoneyFrame
end

local function FormatCurrencyCount(count)
	local currencyText = BreakUpLargeNumbers(count)
	if strlenutf8(currencyText) > 5 then
		currencyText = AbbreviateNumbers(count)
	end
	return currencyText
end

local function EnsureCurrencyFrame(folderFrame)
	if folderFrame.CurrencyFrame then
		return folderFrame.CurrencyFrame
	end

	-- Mirrors BackpackTokenFrameTemplate in Blizzard_TokenUI.xml.
	local currencyFrame = CreateFrame("Frame", nil, folderFrame)
	currencyFrame:SetHeight(17)
	currencyFrame.buttons = {}

	local left = currencyFrame:CreateTexture(nil, "BACKGROUND")
	left:SetSize(8, 17)
	left:SetPoint("LEFT")
	left:SetAtlas("common-currencybox-left")
	currencyFrame.Left = left

	local right = currencyFrame:CreateTexture(nil, "BACKGROUND")
	right:SetSize(8, 17)
	right:SetPoint("RIGHT")
	right:SetAtlas("common-currencybox-right")
	currencyFrame.Right = right

	local middle = currencyFrame:CreateTexture(nil, "BACKGROUND")
	middle:SetPoint("TOPLEFT", left, "TOPRIGHT")
	middle:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT")
	middle:SetAtlas("_common-currencybox-center")
	currencyFrame.Middle = middle

	currencyFrame:SetScript("OnEvent", function()
		addon.RequestBagFoldersRefresh()
	end)

	folderFrame.CurrencyFrame = currencyFrame
	return currencyFrame
end

local function CreateCurrencyButton(parent)
	-- Mirrors BackpackTokenTemplate in Blizzard_TokenUI.xml.
	local button = CreateFrame("Button", nil, parent)
	button:SetSize(50, 12)

	button.Icon = button:CreateTexture(nil, "ARTWORK")
	button.Icon:SetSize(12, 12)
	button.Icon:SetPoint("RIGHT", button, "RIGHT", 4, 1)

	button.Count = button:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	button.Count:SetHeight(10)
	button.Count:SetPoint("TOPLEFT")
	button.Count:SetPoint("RIGHT", button.Icon, "LEFT")
	button.Count:SetJustifyH("RIGHT")

	button:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetBackpackToken(self:GetID())
		GameTooltip_AddBlankLineToTooltip(GameTooltip)
		if TOKEN_REMOVE_FROM_BACKPACK_INSTRUCTION then
			GameTooltip_AddInstructionLine(GameTooltip, TOKEN_REMOVE_FROM_BACKPACK_INSTRUCTION)
		end
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	button:SetScript("OnClick", function(self)
		if IsModifiedClick("CHATLINK") then
			local linkedToChat = HandleModifiedItemClick(C_CurrencyInfo.GetCurrencyLink(self.currencyID))
			if linkedToChat then
				return
			end
		end

		if IsModifiedClick("TOKENWATCHTOGGLE") then
			C_CurrencyInfo.SetCurrencyBackpackByID(self.currencyID, false)
			addon.RequestBagFoldersRefresh()
			if TokenFrame and TokenFrame:IsShown() then
				TokenFrame:Update()
			end
		elseif CharacterFrame and CharacterFrame.ToggleTokenFrame then
			CharacterFrame:ToggleTokenFrame()
		elseif ToggleCharacter then
			ToggleCharacter("TokenFrame")
		end
	end)

	return button
end

local function UpdateCurrencyFrame(folderFrame)
	if not C_CurrencyInfo or not C_CurrencyInfo.GetBackpackCurrencyInfo then
		if folderFrame.CurrencyFrame then
			folderFrame.CurrencyFrame:Hide()
		end
		return 0
	end

	local currencyFrame = EnsureCurrencyFrame(folderFrame)
	currencyFrame:ClearAllPoints()
	currencyFrame:SetPoint("BOTTOMLEFT", folderFrame, "BOTTOMLEFT", 8, CURRENCY_BOTTOM_PADDING)
	currencyFrame:SetPoint("BOTTOMRIGHT", folderFrame, "BOTTOMRIGHT", -8, CURRENCY_BOTTOM_PADDING)

	-- Mirrors BackpackTokenFrameMixin:GetMaxTokensWatched.
	local maxTokens = math.max(math.floor((FRAME_WIDTH - 16) / 50), 1)
	local tokenCount = 0
	for index = 1, maxTokens do
		local currencyInfo = C_CurrencyInfo.GetBackpackCurrencyInfo(index)
		local button = currencyFrame.buttons[index]
		if currencyInfo then
			if not button then
				button = CreateCurrencyButton(currencyFrame)
				currencyFrame.buttons[index] = button
			end

			button:SetID(index)
			button.currencyID = currencyInfo.currencyTypesID
			button.Icon:SetTexture(currencyInfo.iconFileID)
			button.Count:SetText(FormatCurrencyCount(currencyInfo.quantity))
			button:ClearAllPoints()
			button:SetPoint("RIGHT", currencyFrame, "RIGHT", -17 - tokenCount * 50, -1)
			button:Show()
			tokenCount = tokenCount + 1
		elseif button then
			button:Hide()
		end
	end

	if tokenCount == 0 then
		currencyFrame:Hide()
		currencyFrame:UnregisterEvent("CURRENCY_DISPLAY_UPDATE")
		return 0
	end

	currencyFrame:Show()
	currencyFrame:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
	return currencyFrame:GetHeight() + TOKEN_FRAME_SPACING
end

local function UpdateDefaultCurrencyFrames(folderFrame)
	local moneyFrame = EnsureMoneyFrame(folderFrame)
	local tokenHeight = UpdateCurrencyFrame(folderFrame)

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
	if folderFrame.CurrencyFrame then
		folderFrame.CurrencyFrame:Hide()
		folderFrame.CurrencyFrame:UnregisterEvent("CURRENCY_DISPLAY_UPDATE")
	end
end

local function EnsureItemGridAnchor(folderFrame)
	if folderFrame.itemGridAnchor then
		return folderFrame.itemGridAnchor
	end

	folderFrame.itemGridAnchor = CreateFrame("Frame", nil, folderFrame)
	folderFrame.itemGridAnchor:SetSize(1, 1)
	return folderFrame.itemGridAnchor
end

local function UpdateItemGridAnchor(folderFrame, rows, isDefaultFolder)
	local anchor = EnsureItemGridAnchor(folderFrame)
	anchor:ClearAllPoints()
	folderFrame.itemGridRows = rows

	-- Matches Blizzard ContainerFrameBackpackMixin:GetInitialItemAnchor.
	if isDefaultFolder and folderFrame.MoneyFrame then
		anchor:SetPoint("BOTTOMRIGHT", folderFrame.MoneyFrame, "TOPRIGHT", 0, 4)
	else
		-- Matches Blizzard ContainerFrameMixin:GetInitialItemAnchor.
		anchor:SetPoint("BOTTOMRIGHT", folderFrame, "BOTTOMRIGHT", -7, 9)
	end
end

local function GetInitialContainerFrameOffsetX()
	if EditModeUtil and EditModeUtil.GetRightActionBarWidth then
		-- Matches Blizzard ContainerFrame.lua GetInitialContainerFrameOffsetX.
		return EditModeUtil:GetRightActionBarWidth() + 10
	end

	return 10
end

local function GetAutoScale(autoFrames)
	-- Mirrors Blizzard ContainerFrame.lua GetContainerScale for bag column fitting.
	local scale = 1
	while scale > MIN_SCALE do
		local screenHeight = GetScreenHeight() / scale
		local screenWidth = GetScreenWidth()
		local xOffset = GetInitialContainerFrameOffsetX()
		local yOffset = 85 / scale
		local freeHeight = screenHeight - yOffset - TOP_SCREEN_PADDING
		local leftMostPoint = screenWidth - xOffset
		local column = 1
		local forceScaleDecrease = false
		local framesInColumn = 0

		for _, folderFrame in ipairs(autoFrames) do
			local frameHeight = folderFrame:GetHeight()
			local requiredHeight = frameHeight
			if framesInColumn > 0 then
				requiredHeight = requiredHeight + CONTAINER_SPACING
			end

			framesInColumn = framesInColumn + 1
			if freeHeight < requiredHeight then
				if framesInColumn == 1 then
					forceScaleDecrease = true
					break
				end

				column = column + 1
				framesInColumn = 1
				leftMostPoint = screenWidth - (column * folderFrame:GetWidth() * scale) - xOffset
				freeHeight = screenHeight - yOffset - TOP_SCREEN_PADDING
				requiredHeight = frameHeight
			end

			freeHeight = freeHeight - requiredHeight
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
	-- Mirrors Blizzard ContainerFrame.lua UpdateContainerFrameAnchors.
	local scale = GetAutoScale(autoFrames)
	local screenHeight = GetScreenHeight() / scale
	local xOffset = GetInitialContainerFrameOffsetX() / scale
	local yOffset = 85 / scale
	local freeHeight = screenHeight - yOffset - TOP_SCREEN_PADDING
	local previousFrame
	local firstFrameInColumn
	local framesInColumn = 0

	for index, folderFrame in ipairs(autoFrames) do
		folderFrame:SetScale(scale)
		folderFrame:ClearAllPoints()
		local frameHeight = folderFrame:GetHeight()
		local requiredHeight = frameHeight
		if framesInColumn > 0 then
			requiredHeight = requiredHeight + CONTAINER_SPACING
		end

		if index == 1 then
			folderFrame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -xOffset, yOffset)
			firstFrameInColumn = folderFrame
			framesInColumn = 1
		elseif freeHeight < requiredHeight then
			freeHeight = screenHeight - yOffset - TOP_SCREEN_PADDING
			-- Matches Blizzard UpdateContainerFrameAnchors column spacing.
			folderFrame:SetPoint("BOTTOMRIGHT", firstFrameInColumn, "BOTTOMLEFT", -11, 0)
			firstFrameInColumn = folderFrame
			requiredHeight = frameHeight
			framesInColumn = 1
		else
			folderFrame:SetPoint("BOTTOMRIGHT", previousFrame, "TOPRIGHT", 0, CONTAINER_SPACING)
			framesInColumn = framesInColumn + 1
		end

		previousFrame = folderFrame
		freeHeight = freeHeight - requiredHeight
	end

	BagFolders.layoutAnchorFrame = firstFrameInColumn
	BagFolders.layoutScale = scale
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
	UpdateItemGridAnchor(folderFrame, rows, isDefaultFolder)

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
		local folderKey = BagFolders.GetFolderKey(folder.id)
		if BagFolders.IsFolderHidden(folder.id) or BagFolders.sessionClosedFolders[folderKey] then
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
	if addon.PositionReagentBag then
		addon.PositionReagentBag()
	end
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
