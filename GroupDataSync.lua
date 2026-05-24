local addonName, addon = ...
local L = addon.L

local COMM_PREFIX = "L20TRK"
local MESSAGE_VERSION = "2"
local TRINKET_SLOT_1 = INVSLOT_TRINKET1 or 13
local TRINKET_SLOT_2 = INVSLOT_TRINKET2 or 14
local WATCHED_ITEM_1 = 178769
local WATCHED_ITEM_2 = 158379

local state = {
	initialized = false,
	players = {},
	lastBroadcastMessage = nil,
}

local groupDataFrame
local groupDataRows = {}

local function GetPlayerKey(name)
	if not name or name == "" then
		return nil
	end

	return Ambiguate(name, "none")
end

local function IsOwnSender(sender)
	local playerName = GetUnitName("player", true)
	return playerName and sender and Ambiguate(sender, "none") == Ambiguate(playerName, "none")
end

local function GetGroupDistribution()
	if IsInRaid(LE_PARTY_CATEGORY_INSTANCE) then
		return "INSTANCE_CHAT"
	end

	if IsInRaid() then
		return "RAID"
	end

	if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
		return "INSTANCE_CHAT"
	end

	if IsInGroup() then
		return "PARTY"
	end
end

local function GetEquippedTrinketLink(slotID)
	if not UnitExists("player") then
		return nil
	end

	return GetInventoryItemLink("player", slotID)
end

local function GetTrackedItemCount(itemID)
	if not itemID then
		return 0
	end

	return GetItemCount(itemID, false, false) or 0
end

local function BuildRosterOrder()
	local players = {}

	if UnitExists("player") then
		players[#players + 1] = {
			key = GetPlayerKey(GetUnitName("player", true)),
			displayName = GetUnitName("player", false),
		}
	end

	if IsInRaid() then
		for index = 1, GetNumGroupMembers() do
			local unit = "raid" .. index
			if UnitExists(unit) and UnitIsPlayer(unit) and not UnitIsUnit(unit, "player") then
				players[#players + 1] = {
					key = GetPlayerKey(GetUnitName(unit, true)),
					displayName = GetUnitName(unit, false),
				}
			end
		end
	elseif IsInGroup() then
		for index = 1, GetNumSubgroupMembers() do
			local unit = "party" .. index
			if UnitExists(unit) and UnitIsPlayer(unit) then
				players[#players + 1] = {
					key = GetPlayerKey(GetUnitName(unit, true)),
					displayName = GetUnitName(unit, false),
				}
			end
		end
	end

	return players
end

local function GetSortedSyncedPlayers()
	local rosterOrder = BuildRosterOrder()
	local indexed = {}

	for orderIndex, rosterEntry in ipairs(rosterOrder) do
		if rosterEntry and rosterEntry.key then
			indexed[rosterEntry.key] = orderIndex
		end
	end

	local results = {}
	for _, rosterEntry in ipairs(rosterOrder) do
		local data = rosterEntry.key and state.players[rosterEntry.key] or nil
		results[#results + 1] = data or {
			name = rosterEntry.key,
			displayName = rosterEntry.displayName,
		}
	end

	table.sort(results, function(left, right)
		local leftOrder = indexed[left.name]
		local rightOrder = indexed[right.name]
		if leftOrder and rightOrder and leftOrder ~= rightOrder then
			return leftOrder < rightOrder
		end
		return (left.displayName or left.name or "") < (right.displayName or right.name or "")
	end)

	return results
end

local function SetFrameLinkText(fontString, link)
	fontString:SetText(link or L.GROUP_TRINKETS_UNKNOWN)
end

local function SetFrameCountText(fontString, count)
	fontString:SetText(tostring(count or 0))
end

local function EnsureRow(index)
	if groupDataRows[index] then
		return groupDataRows[index]
	end

	local parent = groupDataFrame.content
	local row = CreateFrame("Frame", nil, parent)
	row:SetSize(640, 22)

	if index == 1 then
		row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
	else
		row:SetPoint("TOPLEFT", groupDataRows[index - 1], "BOTTOMLEFT", 0, -6)
	end

	row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	row.name:SetPoint("LEFT", row, "LEFT", 0, 0)
	row.name:SetWidth(120)
	row.name:SetJustifyH("LEFT")

	row.trinket1 = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	row.trinket1:SetPoint("LEFT", row.name, "RIGHT", 12, 0)
	row.trinket1:SetWidth(220)
	row.trinket1:SetJustifyH("LEFT")

	row.trinket2 = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	row.trinket2:SetPoint("TOPLEFT", row.trinket1, "BOTTOMLEFT", 0, -2)
	row.trinket2:SetWidth(220)
	row.trinket2:SetJustifyH("LEFT")

	row.item178769 = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	row.item178769:SetPoint("LEFT", row.trinket1, "RIGHT", 16, 0)
	row.item178769:SetWidth(70)
	row.item178769:SetJustifyH("CENTER")

	row.item158379 = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	row.item158379:SetPoint("LEFT", row.item178769, "RIGHT", 8, 0)
	row.item158379:SetWidth(70)
	row.item158379:SetJustifyH("CENTER")

	row:SetHeight(34)
	groupDataRows[index] = row
	return row
end

local function RefreshGroupDataWindow()
	if not groupDataFrame then
		return
	end

	local players = GetSortedSyncedPlayers()

	for _, row in ipairs(groupDataRows) do
		row:Hide()
	end

	if #players == 0 then
		groupDataFrame.emptyLabel:Show()
		groupDataFrame.content:SetHeight(24)
		return
	end

	groupDataFrame.emptyLabel:Hide()

	for index, data in ipairs(players) do
		local row = EnsureRow(index)
		row.name:SetText(data.displayName or data.name or L.UNKNOWN)
		SetFrameLinkText(row.trinket1, data.trinket1)
		SetFrameLinkText(row.trinket2, data.trinket2)
		SetFrameCountText(row.item178769, data.item178769)
		SetFrameCountText(row.item158379, data.item158379)
		row:Show()
	end

	groupDataFrame.content:SetHeight(math.max(24, (#players * 40) - 6))
end

local function SaveGroupDataWindowPosition(self)
	self:StopMovingOrSizing()

	local point, _, relativePoint, xOfs, yOfs = self:GetPoint()
	Level20DB.groupDataWindowPoint = point
	Level20DB.groupDataWindowRelativePoint = relativePoint
	Level20DB.groupDataWindowXOfs = xOfs
	Level20DB.groupDataWindowYOfs = yOfs
end

local function EnsureGroupDataWindow()
	if groupDataFrame then
		return groupDataFrame
	end

	local frame = CreateFrame("Frame", "Level20GroupDataFrame", UIParent, "DefaultPanelTemplate")
	frame:SetSize(760, 300)
	frame:SetPoint("CENTER", UIParent, "CENTER", 120, 0)
	frame:SetMovable(true)
	frame:SetClampedToScreen(true)
	frame:EnableMouse(true)
	frame:SetToplevel(true)
	frame:SetFrameStrata("DIALOG")
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnMouseDown", function(self)
		self:Raise()
	end)
	frame:SetScript("OnDragStart", function(self)
		self:Raise()
		self:StartMoving()
	end)
	frame:SetScript("OnDragStop", SaveGroupDataWindowPosition)
	frame:SetTitle(L.GROUP_TRINKETS_WINDOW_TITLE)
	frame:Hide()
	frame.CloseButton = CreateFrame("Button", nil, frame, "UIPanelCloseButtonDefaultAnchors")

	local refreshButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	refreshButton:SetSize(100, 22)
	refreshButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -32, -32)
	refreshButton:SetText(REFRESH)
	refreshButton:SetScript("OnClick", function()
		addon.UpdateLocalGroupData()
		addon.BroadcastGroupData(true)
		addon.RefreshGroupDataWindow()
	end)

	local headerPlayer = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	headerPlayer:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -38)
	headerPlayer:SetWidth(120)
	headerPlayer:SetJustifyH("LEFT")
	headerPlayer:SetText(L.GROUP_TRINKETS_HEADER_PLAYER)

	local headerTrinkets = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	headerTrinkets:SetPoint("LEFT", headerPlayer, "RIGHT", 12, 0)
	headerTrinkets:SetWidth(220)
	headerTrinkets:SetJustifyH("LEFT")
	headerTrinkets:SetText(L.GROUP_TRINKETS_HEADER_TRINKET_1 .. " / " .. L.GROUP_TRINKETS_HEADER_TRINKET_2)

	local headerItem178769 = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	headerItem178769:SetPoint("LEFT", headerTrinkets, "RIGHT", 16, 0)
	headerItem178769:SetWidth(70)
	headerItem178769:SetJustifyH("CENTER")
	headerItem178769:SetText(L.GROUP_TRINKETS_HEADER_ITEM_178769)

	local headerItem158379 = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	headerItem158379:SetPoint("LEFT", headerItem178769, "RIGHT", 8, 0)
	headerItem158379:SetWidth(70)
	headerItem158379:SetJustifyH("CENTER")
	headerItem158379:SetText(L.GROUP_TRINKETS_HEADER_ITEM_158379)

	local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "ScrollFrameTemplate")
	scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -58)
	scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, 12)

	local content = CreateFrame("Frame", nil, scrollFrame)
	content:SetSize(1, 24)
	scrollFrame:SetScrollChild(content)
	scrollFrame:SetScript("OnSizeChanged", function(self, width)
		content:SetWidth(math.max(1, width))
	end)

	local emptyLabel = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	emptyLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 4, -8)
	emptyLabel:SetText(L.GROUP_TRINKETS_EMPTY)

	frame.content = content
	frame.emptyLabel = emptyLabel
	frame:SetScript("OnShow", function()
		frame:Raise()
		addon.RefreshGroupDataWindow()
	end)

	if Level20DB.groupDataWindowPoint then
		frame:ClearAllPoints()
		frame:SetPoint(
			Level20DB.groupDataWindowPoint,
			UIParent,
			Level20DB.groupDataWindowRelativePoint or Level20DB.groupDataWindowPoint,
			Level20DB.groupDataWindowXOfs or 0,
			Level20DB.groupDataWindowYOfs or 0
		)
	end

	groupDataFrame = frame
	return groupDataFrame
end

local function BuildMessage()
	local trinket1 = GetEquippedTrinketLink(TRINKET_SLOT_1) or ""
	local trinket2 = GetEquippedTrinketLink(TRINKET_SLOT_2) or ""
	local item178769 = tostring(GetTrackedItemCount(WATCHED_ITEM_1))
	local item158379 = tostring(GetTrackedItemCount(WATCHED_ITEM_2))
	return table.concat({ MESSAGE_VERSION, trinket1, trinket2, item178769, item158379 }, "\t")
end

local function UpdatePlayerData(fullName, trinket1, trinket2, item178769, item158379)
	local playerKey = GetPlayerKey(fullName)
	if not playerKey then
		return
	end

	state.players[playerKey] = {
		name = playerKey,
		displayName = Ambiguate(fullName, "short"),
		trinket1 = trinket1 ~= "" and trinket1 or nil,
		trinket2 = trinket2 ~= "" and trinket2 or nil,
		item178769 = tonumber(item178769) or 0,
		item158379 = tonumber(item158379) or 0,
	}

	addon.RefreshGroupDataWindow()
end

function addon.InitializeGroupDataSync()
	if state.initialized then
		return
	end

	if not C_ChatInfo or not C_ChatInfo.RegisterAddonMessagePrefix or not C_ChatInfo.SendAddonMessage then
		return
	end

	C_ChatInfo.RegisterAddonMessagePrefix(COMM_PREFIX)
	state.initialized = true
end

function addon.UpdateLocalGroupData()
	local message = BuildMessage()
	local _, trinket1, trinket2, item178769, item158379 = strsplit("\t", message, 5)
	UpdatePlayerData(GetUnitName("player", true), trinket1, trinket2, item178769, item158379)
	return message
end

function addon.BroadcastGroupData(force)
	if not state.initialized then
		return
	end

	local distribution = GetGroupDistribution()
	if distribution then
		local message = addon.UpdateLocalGroupData()
		if not force and message == state.lastBroadcastMessage then
			return
		end

		state.lastBroadcastMessage = message
		C_ChatInfo.SendAddonMessage(COMM_PREFIX, message, distribution)
	end
end

function addon.OnGroupDataMessage(prefix, message, _, sender)
	if prefix ~= COMM_PREFIX or not sender or IsOwnSender(sender) then
		return
	end

	local version, trinket1, trinket2, item178769, item158379 = strsplit("\t", message or "", 5)
	if version ~= MESSAGE_VERSION then
		return
	end

	UpdatePlayerData(sender, trinket1, trinket2, item178769, item158379)
end

function addon.RefreshGroupDataWindow()
	RefreshGroupDataWindow()
end

function addon.ShowGroupDataWindow()
	addon.UpdateLocalGroupData()
	EnsureGroupDataWindow():Show()
	addon.BroadcastGroupData(true)
end

function addon.ToggleGroupDataWindow()
	local frame = EnsureGroupDataWindow()
	if frame:IsShown() then
		frame:Hide()
	else
		addon.ShowGroupDataWindow()
	end
end
