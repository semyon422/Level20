local addonName, addon = ...
local BagFolders = addon.BagFolders

local function HideBlizzardNormalBags()
	if ContainerFrameCombinedBags then
		ContainerFrameCombinedBags:Hide()
	end

	if NUM_CONTAINER_FRAMES then
		for index = 1, NUM_CONTAINER_FRAMES do
			local containerFrame = _G["ContainerFrame" .. index]
			if containerFrame and containerFrame:IsShown() and BagFolders.IsNormalBagID(containerFrame:GetID()) then
				containerFrame:Hide()
			end
		end
	end
end

function addon.AreBagFoldersShown()
	for _, folderFrame in pairs(BagFolders.folderFrames) do
		if folderFrame:IsShown() then
			return true
		end
	end

	return false
end

local function FindShownReagentBagFrame(bagID)
	if ContainerFrameUtil_GetShownFrameForID then
		local containerFrame = ContainerFrameUtil_GetShownFrameForID(bagID)
		if containerFrame and containerFrame:IsShown() then
			return containerFrame
		end
	end

	if NUM_CONTAINER_FRAMES then
		for index = 1, NUM_CONTAINER_FRAMES do
			local containerFrame = _G["ContainerFrame" .. index]
			if containerFrame and containerFrame:IsShown() and containerFrame:GetID() == bagID then
				return containerFrame
			end
		end
	end

	return nil
end

function addon.PositionReagentBag()
	if not BagFolders.IsEnabled() or not addon.AreBagFoldersShown() then
		return
	end

	local anchorFrame = BagFolders.layoutAnchorFrame
	if not anchorFrame or not anchorFrame:IsShown() then
		return
	end

	local reagentBagSlots = Constants.InventoryConstants.NumReagentBagSlots or 0
	local previousReagentFrame
	for bagID = Constants.InventoryConstants.NumBagSlots + 1, Constants.InventoryConstants.NumBagSlots + reagentBagSlots do
		local containerFrame = FindShownReagentBagFrame(bagID)
		if containerFrame then
			containerFrame:SetScale(BagFolders.layoutScale or anchorFrame:GetScale() or 1)
			containerFrame:ClearAllPoints()
			if previousReagentFrame then
				containerFrame:SetPoint("BOTTOMRIGHT", previousReagentFrame, "TOPRIGHT", 0, BagFolders.CONTAINER_SPACING)
			else
				containerFrame:SetPoint("BOTTOMRIGHT", anchorFrame, "BOTTOMLEFT", -11, 0)
			end
			containerFrame:Raise()
			previousReagentFrame = containerFrame
		end
	end
end

local function ShowBagFolders()
	if not BagFolders.IsEnabled() or not BagFolders.CanOpenBags() then
		return
	end

	HideBlizzardNormalBags()
	addon.RefreshBagFolders()
end

local function HideBagFolders()
	local hiddenAny = false
	for _, folderFrame in pairs(BagFolders.folderFrames) do
		if folderFrame:IsShown() then
			folderFrame:Hide()
			hiddenAny = true
		end
	end

	return hiddenAny
end

function addon.SetBagFoldersEnabled(enabled)
	BagFolders.EnsureDatabase().enabled = not not enabled
	if not enabled then
		HideBagFolders()
	end
end

local function CallOriginal(name, ...)
	local original = BagFolders.originalFunctions[name]
	if original then
		return original(...)
	end
end

local function ForEachReagentBagID(callback)
	local reagentBagSlots = Constants.InventoryConstants.NumReagentBagSlots or 0
	for bagID = Constants.InventoryConstants.NumBagSlots + 1, Constants.InventoryConstants.NumBagSlots + reagentBagSlots do
		callback(bagID)
	end
end

local function IsAnyReagentBagOpen()
	local isOpen = false
	ForEachReagentBagID(function(bagID)
		if CallOriginal("IsBagOpen", bagID) then
			isOpen = true
		end
	end)
	return isOpen
end

local function OpenReagentBags(force)
	ForEachReagentBagID(function(bagID)
		CallOriginal("OpenBag", bagID, force)
	end)
	addon.PositionReagentBag()
end

local function CloseReagentBags()
	ForEachReagentBagID(function(bagID)
		if CallOriginal("IsBagOpen", bagID) then
			CallOriginal("CloseBag", bagID)
		end
	end)
end

local function InstallFunctionHooks()
	if BagFolders.hooksInstalled then
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
		BagFolders.originalFunctions[name] = _G[name]
	end

	_G.ToggleBackpack = function()
		if BagFolders.IsEnabled() then
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
		if BagFolders.IsEnabled() then
			ShowBagFolders()
			return
		end

		return CallOriginal("OpenBackpack")
	end

	_G.CloseBackpack = function()
		if BagFolders.IsEnabled() then
			return HideBagFolders()
		end

		return CallOriginal("CloseBackpack")
	end

	_G.ToggleBag = function(bagID)
		if BagFolders.IsEnabled() and BagFolders.IsNormalBagID(bagID) then
			if addon.AreBagFoldersShown() then
				HideBagFolders()
			else
				ShowBagFolders()
			end
			return
		end

		if BagFolders.IsEnabled() and BagFolders.IsReagentBagID(bagID) then
			local result = CallOriginal("ToggleBag", bagID)
			addon.PositionReagentBag()
			return result
		end

		return CallOriginal("ToggleBag", bagID)
	end

	_G.OpenBag = function(bagID, force)
		if BagFolders.IsEnabled() and BagFolders.IsNormalBagID(bagID) then
			ShowBagFolders()
			return
		end

		if BagFolders.IsEnabled() and BagFolders.IsReagentBagID(bagID) then
			local result = CallOriginal("OpenBag", bagID, force)
			addon.PositionReagentBag()
			return result
		end

		return CallOriginal("OpenBag", bagID, force)
	end

	_G.CloseBag = function(bagID)
		if BagFolders.IsEnabled() and BagFolders.IsNormalBagID(bagID) then
			return HideBagFolders()
		end

		return CallOriginal("CloseBag", bagID)
	end

	_G.CloseAllBags = function(...)
		local closed = false
		if BagFolders.IsEnabled() then
			closed = HideBagFolders() or closed
		end

		local originalClosed = CallOriginal("CloseAllBags", ...)
		return closed or originalClosed
	end

	_G.ToggleAllBags = function()
		if BagFolders.IsEnabled() then
			if addon.AreBagFoldersShown() or IsAnyReagentBagOpen() then
				HideBagFolders()
				CloseReagentBags()
			else
				ShowBagFolders()
				OpenReagentBags()
			end
			return
		end

		return CallOriginal("ToggleAllBags")
	end

	_G.OpenAllBags = function(frameThatOpenedBags, forceUpdate)
		if BagFolders.IsEnabled() then
			ShowBagFolders()
			OpenReagentBags(forceUpdate)
			return
		end

		return CallOriginal("OpenAllBags", frameThatOpenedBags, forceUpdate)
	end

	_G.IsBagOpen = function(bagID)
		if BagFolders.IsEnabled() and BagFolders.IsNormalBagID(bagID) and addon.AreBagFoldersShown() then
			return true
		end

		return CallOriginal("IsBagOpen", bagID)
	end

	BagFolders.hooksInstalled = true

	if type(_G.UpdateContainerFrameAnchors) == "function" and not BagFolders.reagentAnchorHookInstalled then
		hooksecurefunc("UpdateContainerFrameAnchors", function()
			addon.PositionReagentBag()
		end)
		BagFolders.reagentAnchorHookInstalled = true
	end

	return true
end

function addon.InstallBagFolders()
	BagFolders.EnsureDatabase()
	if InstallFunctionHooks() and BagFolders.hookRetryFrame then
		BagFolders.hookRetryFrame:UnregisterAllEvents()
	end
end

addon.InstallBagFolders()

if not BagFolders.hooksInstalled then
	BagFolders.hookRetryFrame = CreateFrame("Frame")
	BagFolders.hookRetryFrame:RegisterEvent("ADDON_LOADED")
	BagFolders.hookRetryFrame:RegisterEvent("PLAYER_LOGIN")
	BagFolders.hookRetryFrame:SetScript("OnEvent", function()
		addon.InstallBagFolders()
	end)
end
