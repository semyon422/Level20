local addonName, addon = ...
local L = addon.L

local spellBookFilterInstalled = false

local function PrepareSpellBookFrame()
	return PlayerSpellsFrame and PlayerSpellsFrame.SpellBookFrame
end

local function ShouldFilterSpellBook()
	return Level20DB.hideHighLevelSpells
end

local function IsHighLevelSpellBookItem(slotIndex, spellBank)
	local spellBookItemInfo = C_SpellBook.GetSpellBookItemInfo(slotIndex, spellBank)
	if not spellBookItemInfo then
		return false
	end

	local levelLearned = C_SpellBook.GetSpellBookItemLevelLearned(slotIndex, spellBank)

	if spellBookItemInfo.itemType ~= Enum.SpellBookItemType.FutureSpell then
		return spellBookItemInfo.isOffSpec and levelLearned and levelLearned > addon.LEVEL_CAP
	end

	return levelLearned and levelLearned > addon.LEVEL_CAP
end

local function RefreshSpellBookFrame(spellBookFrame)
	if not spellBookFrame then
		return
	end

	spellBookFrame.cachedSpellBookItems = nil

	if spellBookFrame.MarkSpellDataDirty then
		spellBookFrame:MarkSpellDataDirty()
	elseif spellBookFrame.UpdateAllSpellData then
		spellBookFrame:UpdateAllSpellData()
	end
end

function addon.RefreshSpellBookFrame()
	RefreshSpellBookFrame(PrepareSpellBookFrame())
end

function addon.InstallSpellBookFilter()
	if spellBookFilterInstalled then
		return
	end

	local spellBookFrame = PrepareSpellBookFrame()
	if not spellBookFrame then
		return
	end

	local originalShouldDisplaySpellBookItem = spellBookFrame.ShouldDisplaySpellBookItem
	spellBookFrame.ShouldDisplaySpellBookItem = function(self, isKioskEnabled, isHidingPassives, slotIndex, spellBank)
		if not originalShouldDisplaySpellBookItem(self, isKioskEnabled, isHidingPassives, slotIndex, spellBank) then
			return false
		end

		if ShouldFilterSpellBook() and IsHighLevelSpellBookItem(slotIndex, spellBank) then
			return false
		end

		return true
	end

	spellBookFilterInstalled = true
	addon.RefreshSpellBookFrame()
end

function addon.SetSpellBookFilterEnabled(enabled)
	Level20DB.hideHighLevelSpells = enabled
	addon.InstallSpellBookFilter()
	addon.RefreshSpellBookFrame()
	addon.RefreshWindow()

	local stateText = enabled and L.STATE_ENABLED or L.STATE_DISABLED
	print(string.format(L.SPELLBOOK_FILTER_STATUS, stateText))
end
