local _, addon = ...
local L = addon.L

local groupData = addon.GroupData

local COMM_PREFIX = "L20TRK"
local MESSAGE_VERSION = "5"
local OOZE_TRINKET_ITEM_ID = 178769
local UTTS_ITEM_ID = 158379
local DRAGONLING_TRINKET_ITEM_ID = 77530
local BOOL_TRUE = "1"
local BOOL_FALSE = "0"

local function EncodeBoolean(value)
	return value and BOOL_TRUE or BOOL_FALSE
end

local function DecodeBoolean(value)
	return value == BOOL_TRUE
end

local function IsTrackedTrinketEquipped(itemID)
	if not itemID then
		return false
	end

	return GetInventoryItemID("player", INVSLOT_TRINKET1) == itemID
		or GetInventoryItemID("player", INVSLOT_TRINKET2) == itemID
end

local function GetTrackedItemCount(itemID)
	if not itemID then
		return 0
	end

	return GetItemCount(itemID, false, false) or 0
end

local function GetAddonVersionText()
	local version = addon.GetCurrentVersion and addon.GetCurrentVersion()
	if not version or version <= 0 then
		return "v?"
	end

	return "v" .. tostring(version)
end

function groupData.GetChromieTimeTextFromID(chromieTimeID)
	if chromieTimeID == 0 then
		return L.CHROMIE_TIME_PRESENT
	end

	if not chromieTimeID or chromieTimeID < 0 then
		return L.UNKNOWN
	end

	local options = C_ChromieTime and C_ChromieTime.GetChromieTimeExpansionOptions and C_ChromieTime.GetChromieTimeExpansionOptions()
	if type(options) ~= "table" then
		return L.UNKNOWN
	end

	for _, option in ipairs(options) do
		if option.id == chromieTimeID then
			return option.name or L.UNKNOWN
		end
	end

	return L.UNKNOWN
end

function groupData.GetChromieTimeText()
	if not C_PlayerInfo or not C_PlayerInfo.IsPlayerInChromieTime or not C_PlayerInfo.IsPlayerInChromieTime() then
		return L.CHROMIE_TIME_PRESENT
	end

	local chromieTimeID = UnitChromieTimeID("player")
	if not chromieTimeID then
		return L.UNKNOWN
	end

	return groupData.GetChromieTimeTextFromID(chromieTimeID)
end

local function GetChromieTimeSyncValue()
	if not C_PlayerInfo or not C_PlayerInfo.IsPlayerInChromieTime or not C_PlayerInfo.IsPlayerInChromieTime() then
		return 0
	end

	local chromieTimeID = UnitChromieTimeID("player")
	return chromieTimeID or -1
end

local function IsWarModeEnabled()
	return C_PvP and C_PvP.IsWarModeDesired and C_PvP.IsWarModeDesired() or false
end

function groupData.GetCommPrefix()
	return COMM_PREFIX
end

function groupData.BuildLocalPayload()
	return {
		oozeEquipped = IsTrackedTrinketEquipped(OOZE_TRINKET_ITEM_ID),
		uttsCount = GetTrackedItemCount(UTTS_ITEM_ID),
		dragonlingEquipped = IsTrackedTrinketEquipped(DRAGONLING_TRINKET_ITEM_ID),
		addonVersion = GetAddonVersionText(),
		chromieTimeID = GetChromieTimeSyncValue(),
		warModeEnabled = IsWarModeEnabled(),
	}
end

function groupData.SerializePayload(payload)
	return table.concat({
		MESSAGE_VERSION,
		EncodeBoolean(payload.oozeEquipped),
		tostring(payload.uttsCount or 0),
		EncodeBoolean(payload.dragonlingEquipped),
		payload.addonVersion or "v?",
		tostring(payload.chromieTimeID or -1),
		EncodeBoolean(payload.warModeEnabled),
	}, "\t")
end

function groupData.BuildLocalMessage()
	local payload = groupData.BuildLocalPayload()
	return groupData.SerializePayload(payload), payload
end

function groupData.ParseMessage(message)
	local version, oozeEquipped, uttsCount, dragonlingEquipped, addonVersion, chromieTimeID, warModeEnabled = strsplit("\t", message or "", 7)
	if version ~= MESSAGE_VERSION then
		return nil
	end

	return {
		oozeEquipped = DecodeBoolean(oozeEquipped),
		uttsCount = tonumber(uttsCount) or 0,
		dragonlingEquipped = DecodeBoolean(dragonlingEquipped),
		addonVersion = addonVersion ~= "" and addonVersion or "v?",
		chromieTimeID = tonumber(chromieTimeID) or -1,
		warModeEnabled = DecodeBoolean(warModeEnabled),
	}
end
