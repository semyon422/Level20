local addonName, addon = ...
local L = addon.L

local COMM_PREFIX = "L20VER"

local versionState = {
	initialized = false,
	currentVersion = 0,
	latestVersion = nil,
	latestSource = nil,
}

local function GetMetadataVersion()
	local version

	if C_AddOns and C_AddOns.GetAddOnMetadata then
		version = C_AddOns.GetAddOnMetadata(addonName, "Version")
	elseif GetAddOnMetadata then
		version = GetAddOnMetadata(addonName, "Version")
	end

	return tonumber(version)
end

local function RefreshInfoPanel()
	if addon.RefreshInfoPanel then
		addon.RefreshInfoPanel()
	end
end

function addon.GetCurrentVersion()
	return versionState.currentVersion
end

function addon.HasVersionUpdate()
	return versionState.latestVersion ~= nil
end

function addon.GetVersionStatusText()
	if versionState.latestVersion then
		if versionState.latestSource then
			return string.format(L.VERSION_STATUS_UPDATE_SOURCE, versionState.latestVersion, versionState.latestSource)
		end

		return string.format(L.VERSION_STATUS_UPDATE, versionState.latestVersion)
	end

	return string.format(L.VERSION_STATUS_CURRENT, versionState.currentVersion)
end

function addon.GetVersionStatusColor()
	if versionState.latestVersion then
		return 1, 0.82, 0.2
	end

	return 0.35, 0.82, 1
end

function addon.ProcessRemoteVersion(version, sender)
	version = tonumber(version)
	if not version then
		return
	end

	if version <= versionState.currentVersion then
		return
	end

	if versionState.latestVersion and version <= versionState.latestVersion then
		return
	end

	versionState.latestVersion = version
	versionState.latestSource = sender
	Level20DB.lastSeenRemoteVersion = version
	Level20DB.lastSeenRemoteVersionSource = sender
	RefreshInfoPanel()
end

function addon.OnVersionCheckMessage(prefix, message, channel, sender)
	if prefix ~= COMM_PREFIX then
		return
	end

	local playerName = UnitName("player")
	if not playerName or not sender then
		return
	end

	if Ambiguate(sender, "short") == Ambiguate(playerName, "short") then
		return
	end

	addon.ProcessRemoteVersion(message, sender)
end

local function SendVersion(distribution)
	if not distribution then
		return
	end

	C_ChatInfo.SendAddonMessage(COMM_PREFIX, tostring(versionState.currentVersion), distribution)
end

function addon.BroadcastVersionCheck(sendToGuild)
	if not versionState.initialized then
		return
	end

	if IsInRaid(LE_PARTY_CATEGORY_INSTANCE) then
		SendVersion("INSTANCE_CHAT")
	elseif IsInRaid() then
		SendVersion("RAID")
	elseif IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
		SendVersion("INSTANCE_CHAT")
	elseif IsInGroup() then
		SendVersion("PARTY")
	end

	if sendToGuild and IsInGuild() then
		SendVersion("GUILD")
	end
end

function addon.InitializeVersionCheck()
	if versionState.initialized then
		return
	end

	if not C_ChatInfo or not C_ChatInfo.RegisterAddonMessagePrefix or not C_ChatInfo.SendAddonMessage then
		return
	end

	versionState.currentVersion = GetMetadataVersion() or versionState.currentVersion
	versionState.latestVersion = tonumber(Level20DB.lastSeenRemoteVersion)
	versionState.latestSource = Level20DB.lastSeenRemoteVersionSource

	if versionState.latestVersion and versionState.latestVersion <= versionState.currentVersion then
		versionState.latestVersion = nil
		versionState.latestSource = nil
		Level20DB.lastSeenRemoteVersion = nil
		Level20DB.lastSeenRemoteVersionSource = nil
	end

	C_ChatInfo.RegisterAddonMessagePrefix(COMM_PREFIX)
	versionState.initialized = true
	RefreshInfoPanel()
end
