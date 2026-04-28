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

		return CallOriginal("ToggleBag", bagID)
	end

	_G.OpenBag = function(bagID, force)
		if BagFolders.IsEnabled() and BagFolders.IsNormalBagID(bagID) then
			ShowBagFolders()
			return
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
		if BagFolders.IsEnabled() then
			ShowBagFolders()
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
