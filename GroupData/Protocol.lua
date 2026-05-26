local _, addon = ...
local L = addon.L

local groupData = addon.GroupData
local serializer = groupData.Serializer

local COMM_PREFIX = "L20TRK"
local MESSAGE_FORMAT_VERSION = "1"
local AMBER_ITEM_ID = 86577
local OOZE_TRINKET_ITEM_ID = 178769
local UTTS_ITEM_ID = 158379
local DRAGONLING_TRINKET_ITEM_ID = 77530

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

local function IsWarModeEnabled()
	return C_PvP and C_PvP.IsWarModeDesired and C_PvP.IsWarModeDesired() or false
end

local function IsLorewalkingEnabled()
	return addon.IsLorewalkingActive and addon.IsLorewalkingActive() or false
end

function groupData.FormatChromieStatusText(chromieText, warModeEnabled, lorewalkingActive)
	local text = chromieText or L.UNKNOWN

	if warModeEnabled then
		text = text .. " + WM"
	end

	if lorewalkingActive then
		text = text .. " + LW"
	end

	return text
end

function groupData.GetCommPrefix()
	return COMM_PREFIX
end

function groupData.BuildLocalPayload()
	return {
		addon = GetAddonVersionText(),
		wm = IsWarModeEnabled(),
		lw = IsLorewalkingEnabled(),
		ooze = IsTrackedTrinketEquipped(OOZE_TRINKET_ITEM_ID),
		dragon = IsTrackedTrinketEquipped(DRAGONLING_TRINKET_ITEM_ID),
		utts = GetTrackedItemCount(UTTS_ITEM_ID),
		amber = GetTrackedItemCount(AMBER_ITEM_ID) > 0,
	}
end

function groupData.SerializePayload(payload)
	return MESSAGE_FORMAT_VERSION .. "\t" .. serializer.Serialize(payload)
end

function groupData.BuildLocalMessage()
	local payload = groupData.BuildLocalPayload()
	return groupData.SerializePayload(payload), payload
end

local function CreateEmptyPayload()
	return {}
end

local function ParseTypedMessage(message)
	local payload = CreateEmptyPayload()
	local version, serializedPayload = strsplit("\t", message or "", 2)

	if version ~= MESSAGE_FORMAT_VERSION then
		return nil
	end

	local fields = serializer.Deserialize(serializedPayload or "")
	for key, value in pairs(fields) do
		payload[key] = value
	end

	return payload
end

function groupData.ParseMessage(message)
	if type(message) ~= "string" or message == "" then
		return nil
	end

	return ParseTypedMessage(message)
end
