local addonName, addon = ...
local BagFolders = addon.BagFolders

local OFFSCREEN_X = -20000
local OFFSCREEN_Y = -20000

local function IsShownNormalBagFrame(frame)
	return frame and frame:IsShown() and BagFolders.IsNormalBagID(frame:GetID())
end

local function IterateShownNormalBagFrames(callback)
	if ContainerFrameCombinedBags and ContainerFrameCombinedBags:IsShown() then
		callback(ContainerFrameCombinedBags)
	end

	if NUM_CONTAINER_FRAMES then
		for index = 1, NUM_CONTAINER_FRAMES do
			local containerFrame = _G["ContainerFrame" .. index]
			if IsShownNormalBagFrame(containerFrame) then
				callback(containerFrame)
			end
		end
	end
end

local function SetFrameItemsMouseEnabled(frame, enabled)
	if not frame or not frame.EnumerateValidItems then
		return
	end

	for _, itemButton in frame:EnumerateValidItems() do
		if itemButton then
			itemButton:EnableMouse(enabled)
		end
	end
end

local function SetFrameSuppressed(frame, suppressed)
	if not frame then
		return
	end

	if suppressed then
		if frame.Level20BagFoldersSuppressed then
			frame:SetAlpha(0)
			frame:ClearAllPoints()
			frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", OFFSCREEN_X, OFFSCREEN_Y)
			SetFrameItemsMouseEnabled(frame, false)
			return
		end

		frame.Level20BagFoldersSuppressed = true
		frame.Level20BagFoldersOriginalAlpha = frame:GetAlpha()
		frame.Level20BagFoldersOriginalMouseEnabled = frame:IsMouseEnabled()
		frame:SetAlpha(0)
		frame:EnableMouse(false)
		SetFrameItemsMouseEnabled(frame, false)
		frame:ClearAllPoints()
		frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", OFFSCREEN_X, OFFSCREEN_Y)
		return
	end

	if not frame.Level20BagFoldersSuppressed then
		return
	end

	frame.Level20BagFoldersSuppressed = nil
	frame:SetAlpha(frame.Level20BagFoldersOriginalAlpha or 1)
	frame:EnableMouse(frame.Level20BagFoldersOriginalMouseEnabled ~= false)
	frame.Level20BagFoldersOriginalAlpha = nil
	frame.Level20BagFoldersOriginalMouseEnabled = nil
	SetFrameItemsMouseEnabled(frame, true)
end

local function SuppressBlizzardNormalBags()
	if ContainerFrameCombinedBags then
		SetFrameSuppressed(ContainerFrameCombinedBags, true)
	end

	if NUM_CONTAINER_FRAMES then
		for index = 1, NUM_CONTAINER_FRAMES do
			local containerFrame = _G["ContainerFrame" .. index]
			if IsShownNormalBagFrame(containerFrame) then
				SetFrameSuppressed(containerFrame, true)
			end
		end
	end
end

local function RestoreBlizzardNormalBags()
	if ContainerFrameCombinedBags then
		SetFrameSuppressed(ContainerFrameCombinedBags, false)
	end

	if NUM_CONTAINER_FRAMES then
		for index = 1, NUM_CONTAINER_FRAMES do
			local containerFrame = _G["ContainerFrame" .. index]
			if containerFrame then
				SetFrameSuppressed(containerFrame, false)
			end
		end
	end

	if type(_G.UpdateContainerFrameAnchors) == "function" then
		UpdateContainerFrameAnchors()
	end
end

local function AreBlizzardNormalBagsSuppressed()
	if ContainerFrameCombinedBags and ContainerFrameCombinedBags.Level20BagFoldersSuppressed then
		return true
	end

	if NUM_CONTAINER_FRAMES then
		for index = 1, NUM_CONTAINER_FRAMES do
			local containerFrame = _G["ContainerFrame" .. index]
			if containerFrame and containerFrame.Level20BagFoldersSuppressed then
				return true
			end
		end
	end

	return false
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

local function AreAnyNormalBagsOpen()
	local isOpen = false
	IterateShownNormalBagFrames(function(frame)
		if frame == ContainerFrameCombinedBags then
			if frame:IsBagOpen(Enum.BagIndex.Backpack) then
				isOpen = true
			end
		else
			isOpen = true
		end
	end)
	return isOpen
end

local function ShowBagFolders()
	if not BagFolders.IsEnabled() or not BagFolders.CanOpenBags() then
		return
	end

	local firstShowThisSession = not BagFolders.bagSessionActive
	if not BagFolders.bagSessionActive then
		wipe(BagFolders.sessionClosedFolders)
		BagFolders.bagSessionActive = true
	end

	SuppressBlizzardNormalBags()

	if firstShowThisSession or not addon.AreBagFoldersShown() then
		addon.RefreshBagFolders()
	else
		addon.RequestBagFoldersRefresh()
	end
end

local function HideBagFolders()
	local hiddenAny = false
	for _, folderFrame in pairs(BagFolders.folderFrames) do
		if folderFrame:IsShown() then
			folderFrame:Hide()
			hiddenAny = true
		end
	end

	BagFolders.bagSessionActive = nil
	RestoreBlizzardNormalBags()
	return hiddenAny
end

function addon.SetBagFoldersEnabled(enabled)
	BagFolders.EnsureDatabase().enabled = not not enabled
	if enabled then
		if AreAnyNormalBagsOpen() then
			ShowBagFolders()
		end
	else
		HideBagFolders()
	end
end

local function RefreshBagFolderState()
	if BagFolders.IsEnabled() and BagFolders.CanOpenBags() and AreAnyNormalBagsOpen() then
		ShowBagFolders()
	elseif addon.AreBagFoldersShown() or AreBlizzardNormalBagsSuppressed() or BagFolders.bagSessionActive then
		HideBagFolders()
	end

	addon.PositionReagentBag()
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
	}

	for _, name in ipairs(names) do
		if type(_G[name]) ~= "function" then
			return false
		end
	end

	for _, name in ipairs(names) do
		hooksecurefunc(name, RefreshBagFolderState)
	end

	if type(_G.UpdateContainerFrameAnchors) == "function" and not BagFolders.reagentAnchorHookInstalled then
		hooksecurefunc("UpdateContainerFrameAnchors", function()
			addon.PositionReagentBag()
		end)
		BagFolders.reagentAnchorHookInstalled = true
	end

	BagFolders.hooksInstalled = true
	return true
end

function addon.InstallBagFolders()
	BagFolders.EnsureDatabase()
	if InstallFunctionHooks() and BagFolders.hookRetryFrame then
		BagFolders.hookRetryFrame:UnregisterAllEvents()
	end
	RefreshBagFolderState()
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
