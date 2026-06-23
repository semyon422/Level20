local addonName, addon = ...
local L = addon.L

local routes = addon.Routes or {}
addon.Routes = routes

local BLASTED_LANDS_MAP_ID = 17
local HELLFIRE_PENINSULA_MAP_ID = 100
local ORGRIMMAR_MAP_ID = 85
local OUTLAND_MAP_ID = 101
local STORMWIND_MAP_ID = 84

local BLASTED_LANDS_PHASE_FUTURE = "future"
local BLASTED_LANDS_PHASE_PAST = "past"
local BLASTED_LANDS_FUTURE_TAXI_NODE_IDS = { 1537, 1538 }
local BLASTED_LANDS_PAST_TAXI_NODE_IDS = { 45, 602, 603, 604 }

local OUTLAND_ROUTE_ID = "outland"
local ROUTE_STEP_PRESENT_TIME = "presentTime"
local ROUTE_STEP_TELEPORT_MAGE = "teleportMage"
local ROUTE_STEP_ZIDORMI_PAST = "zidormiPast"
local ROUTE_STEP_RETURN_TO_MAGE = "returnToMage"

local CHROMIE_WAYPOINTS = {
	Alliance = { labelKey = "WAYPOINT_CHROMIE", faction = "Alliance", mapID = STORMWIND_MAP_ID, x = 56.26, y = 17.32 },
	Horde = { labelKey = "WAYPOINT_CHROMIE", faction = "Horde", mapID = ORGRIMMAR_MAP_ID, x = 40.82, y = 80.16 },
}

local MAGE_WAYPOINTS = {
	Alliance = {
		labelKey = "ROUTE_WAYPOINT_HONOR_HOLD_MAGE",
		faction = "Alliance",
		mapID = STORMWIND_MAP_ID,
		x = 49.11,
		y = 87.34,
	},
	Horde = {
		labelKey = "ROUTE_WAYPOINT_THRALLMAR_MAGE",
		faction = "Horde",
		mapID = ORGRIMMAR_MAP_ID,
		x = 57.15,
		y = 90.71,
	},
}

local ZIDORMI_BLASTED_LANDS_WAYPOINT = {
	labelKey = "ROUTE_WAYPOINT_ZIDORMI_BLASTED_LANDS",
	mapID = BLASTED_LANDS_MAP_ID,
	x = 48.16,
	y = 7.28,
}

local routeDefinitions = {
	{
		id = OUTLAND_ROUTE_ID,
		titleKey = "ROUTE_OUTLAND",
		trackerFrameName = "Level20RoutesObjectiveTracker",
	},
}

local routeDefinitionByID = {}
for _, routeDefinition in ipairs(routeDefinitions) do
	routeDefinitionByID[routeDefinition.id] = routeDefinition
end

local state = {
	activeRouteID = nil,
	activeWaypointStepID = nil,
	activeWaypoint = nil,
	usedZidormiFallback = false,
	module = nil,
	moduleRegistered = false,
	previousTaxiNodeIDs = nil,
}

local function GetRouteDefinition(routeID)
	return routeDefinitionByID[routeID or OUTLAND_ROUTE_ID] or routeDefinitions[1]
end

function routes.GetRoutes()
	return routeDefinitions
end

function routes.GetDefaultRouteID()
	return OUTLAND_ROUTE_ID
end

function routes.IsActive(routeID)
	return state.activeRouteID == (routeID or OUTLAND_ROUTE_ID)
end

local function GetNodeIDSet(nodeIDs)
	local nodeIDSet = {}
	for _, nodeID in ipairs(nodeIDs or {}) do
		nodeIDSet[nodeID] = true
	end

	return nodeIDSet
end

local function FormatNodeIDs(nodeIDs)
	if not nodeIDs or #nodeIDs == 0 then
		return L.ROUTE_NO_FLYPATH_CHANGES
	end

	return table.concat(nodeIDs, ",")
end

local function CopyNodeIDs(nodeIDs)
	local copy = {}
	if nodeIDs then
		for index, nodeID in ipairs(nodeIDs) do
			copy[index] = nodeID
		end
	end

	return copy
end

local function GetTeleportMageWaypoint(faction)
	return MAGE_WAYPOINTS[faction]
end

function routes.CanStartRoute(routeID)
	if GetRouteDefinition(routeID).id ~= OUTLAND_ROUTE_ID then
		return false
	end

	return GetTeleportMageWaypoint(UnitFactionGroup("player")) ~= nil
end

local function GetTeleportMageName(faction)
	local waypoint = GetTeleportMageWaypoint(faction)
	if not waypoint then
		return L.UNKNOWN
	end

	return L[waypoint.labelKey] or L.UNKNOWN
end

local function CreateRouteStep(id, text, completed, waypoint)
	return {
		id = id,
		text = text,
		completed = completed,
		waypoint = waypoint,
	}
end

local function CreateTeleportMageStep(id, textKey, faction, completed)
	return CreateRouteStep(
		id,
		string.format(L[textKey], GetTeleportMageName(faction)),
		completed,
		GetTeleportMageWaypoint(faction)
	)
end

local function GetBlastedLandsPhase(mapID, nodeIDs)
	local nodeIDSet = GetNodeIDSet(nodeIDs)
	if mapID == BLASTED_LANDS_MAP_ID then
		for _, nodeID in ipairs(BLASTED_LANDS_FUTURE_TAXI_NODE_IDS) do
			if nodeIDSet[nodeID] then
				return BLASTED_LANDS_PHASE_FUTURE
			end
		end

		for _, nodeID in ipairs(BLASTED_LANDS_PAST_TAXI_NODE_IDS) do
			if nodeIDSet[nodeID] then
				return BLASTED_LANDS_PHASE_PAST
			end
		end
	end
end

local function GetDetectedRoutePhase(mapID, nodeIDs)
	if not mapID or not nodeIDs then
		return L.UNKNOWN
	end

	local blastedLandsPhase = GetBlastedLandsPhase(mapID, nodeIDs)
	if blastedLandsPhase == BLASTED_LANDS_PHASE_FUTURE then
		return L.ROUTE_BLASTED_LANDS_PHASE_FUTURE
	end
	if blastedLandsPhase == BLASTED_LANDS_PHASE_PAST then
		return L.ROUTE_BLASTED_LANDS_PHASE_PAST
	end

	return L.UNKNOWN
end

local function GetNodeIDDiff(previousNodeIDs, currentNodeIDs)
	if not previousNodeIDs then
		return L.ROUTE_NO_PREVIOUS_PHASE
	end

	local previousNodeIDSet = GetNodeIDSet(previousNodeIDs)
	local currentNodeIDSet = GetNodeIDSet(currentNodeIDs)
	local added = {}
	local removed = {}

	for _, nodeID in ipairs(currentNodeIDs or {}) do
		if not previousNodeIDSet[nodeID] then
			table.insert(added, nodeID)
		end
	end

	for _, nodeID in ipairs(previousNodeIDs or {}) do
		if not currentNodeIDSet[nodeID] then
			table.insert(removed, nodeID)
		end
	end

	if #added == 0 and #removed == 0 then
		return L.ROUTE_NO_FLYPATH_CHANGES
	end

	local parts = {}
	if #added > 0 then
		table.insert(parts, "+" .. FormatNodeIDs(added))
	end
	if #removed > 0 then
		table.insert(parts, "-" .. FormatNodeIDs(removed))
	end

	return table.concat(parts, " ")
end

local function GetTaxiMapNodeFingerprint(mapID)
	if not C_TaxiMap or not C_TaxiMap.GetTaxiNodesForMap or not C_TaxiMap.ShouldMapShowTaxiNodes then
		return nil, L.ROUTE_TAXI_MAP_UNAVAILABLE
	end

	local okShow, shouldShowNodes = pcall(C_TaxiMap.ShouldMapShowTaxiNodes, mapID)
	if not okShow or not shouldShowNodes then
		return {}, nil
	end

	local okNodes, taxiNodes = pcall(C_TaxiMap.GetTaxiNodesForMap, mapID)
	if not okNodes or type(taxiNodes) ~= "table" then
		return nil, L.UNKNOWN
	end

	local nodeIDs = {}
	for _, taxiNodeInfo in ipairs(taxiNodes) do
		if taxiNodeInfo.nodeID then
			table.insert(nodeIDs, taxiNodeInfo.nodeID)
		end
	end
	table.sort(nodeIDs)

	return nodeIDs, nil
end

local function GetCurrentBlastedLandsPhase(mapID)
	if mapID ~= BLASTED_LANDS_MAP_ID then
		return nil, nil, nil
	end

	local nodeIDs, errorText = GetTaxiMapNodeFingerprint(BLASTED_LANDS_MAP_ID)
	if errorText then
		return nil, nodeIDs, errorText
	end

	return GetBlastedLandsPhase(BLASTED_LANDS_MAP_ID, nodeIDs), nodeIDs, nil
end

local function GetMapDisplayText(mapID)
	if not mapID then
		return L.UNKNOWN
	end

	local mapInfo = C_Map.GetMapInfo and C_Map.GetMapInfo(mapID) or nil
	if mapInfo and mapInfo.name then
		return string.format("%s (%d)", mapInfo.name, mapID)
	end

	return tostring(mapID)
end

local function IsPlayerInPresentTime()
	return not (C_PlayerInfo and C_PlayerInfo.IsPlayerInChromieTime and C_PlayerInfo.IsPlayerInChromieTime())
end

local function IsMapInOutland(mapID)
	if not mapID then
		return false
	end
	if mapID == OUTLAND_MAP_ID or mapID == HELLFIRE_PENINSULA_MAP_ID then
		return true
	end

	local visitedMapIDs = {}
	local currentMapID = mapID
	while currentMapID and not visitedMapIDs[currentMapID] do
		visitedMapIDs[currentMapID] = true
		local mapInfo = C_Map.GetMapInfo and C_Map.GetMapInfo(currentMapID) or nil
		currentMapID = mapInfo and mapInfo.parentMapID or nil
		if currentMapID == OUTLAND_MAP_ID then
			return true
		end
	end

	return false
end

local function GetRouteWaypointDistance(waypoint)
	if not waypoint or not CreateVector2D or not C_Map.GetBestMapForUnit or not C_Map.GetPlayerMapPosition or not C_Map.GetWorldPosFromMapPos then
		return nil
	end

	local playerMapID = C_Map.GetBestMapForUnit("player")
	if not playerMapID then
		return nil
	end

	local playerMapPosition = C_Map.GetPlayerMapPosition(playerMapID, "player")
	if not playerMapPosition then
		return nil
	end

	local waypointMapPosition = CreateVector2D(waypoint.x / 100, waypoint.y / 100)
	local okPlayer, playerContinentID, playerWorldPosition = pcall(C_Map.GetWorldPosFromMapPos, playerMapID, playerMapPosition)
	local okWaypoint, waypointContinentID, waypointWorldPosition = pcall(C_Map.GetWorldPosFromMapPos, waypoint.mapID, waypointMapPosition)
	if not okPlayer or not okWaypoint then
		return nil
	end
	if not playerContinentID or not waypointContinentID or playerContinentID ~= waypointContinentID then
		return nil
	end
	if not playerWorldPosition or not waypointWorldPosition then
		return nil
	end

	local dx = waypointWorldPosition.x - playerWorldPosition.x
	local dy = waypointWorldPosition.y - playerWorldPosition.y
	return math.sqrt(dx * dx + dy * dy)
end

local function FormatRouteWaypointDistance(waypoint)
	local distance = GetRouteWaypointDistance(waypoint)
	if not distance then
		return L.ROUTE_DISTANCE_UNAVAILABLE
	end

	return string.format(L.ROUTE_DISTANCE_YARDS, math.floor(distance + 0.5))
end

local function GetRouteStepDisplayText(step)
	if not step then
		return L.UNKNOWN
	end
	if step.waypoint then
		return string.format("%s (%s)", step.text, FormatRouteWaypointDistance(step.waypoint))
	end

	return step.text
end

local function GetOutlandRouteProgress()
	local faction = UnitFactionGroup("player")
	if not GetTeleportMageWaypoint(faction) then
		return {
			unavailableText = L.ROUTE_UNSUPPORTED_FACTION,
			steps = {},
		}
	end

	local currentMapID = C_Map.GetBestMapForUnit("player")
	local isPresentTime = IsPlayerInPresentTime()
	local isInOutland = IsMapInOutland(currentMapID)
	local isInBlastedLands = currentMapID == BLASTED_LANDS_MAP_ID
	local blastedLandsPhase = GetCurrentBlastedLandsPhase(currentMapID)
	local isBlastedLandsPast = isInBlastedLands and blastedLandsPhase == BLASTED_LANDS_PHASE_PAST
	local shouldGoToZidormi = isPresentTime and isInBlastedLands and not isBlastedLandsPast
	if state.activeRouteID == OUTLAND_ROUTE_ID and isInBlastedLands then
		state.usedZidormiFallback = true
	end
	local showZidormiFallback = state.usedZidormiFallback or isInBlastedLands
	local steps = {
		CreateRouteStep(ROUTE_STEP_PRESENT_TIME, L.ROUTE_STEP_RETURN_TO_PRESENT, isPresentTime, CHROMIE_WAYPOINTS[faction]),
		CreateTeleportMageStep(ROUTE_STEP_TELEPORT_MAGE, "ROUTE_STEP_TELEPORT_MAGE", faction, isPresentTime and (isInOutland or isInBlastedLands)),
	}

	if showZidormiFallback then
		table.insert(steps, CreateRouteStep(ROUTE_STEP_ZIDORMI_PAST, L.ROUTE_STEP_SWITCH_BLASTED_LANDS_PAST, isInOutland or isBlastedLandsPast, ZIDORMI_BLASTED_LANDS_WAYPOINT))
		table.insert(steps, CreateTeleportMageStep(ROUTE_STEP_RETURN_TO_MAGE, "ROUTE_STEP_RETURN_TO_MAGE", faction, isInOutland))
	end

	local activeStep
	if not isPresentTime then
		activeStep = steps[1]
	elseif isInOutland then
		activeStep = nil
	elseif shouldGoToZidormi then
		activeStep = steps[3]
	elseif isBlastedLandsPast then
		activeStep = steps[4]
	else
		activeStep = steps[2]
	end

	return {
		steps = steps,
		activeStep = activeStep,
		completed = not activeStep,
	}
end

local function GetRouteProgress(routeID)
	if GetRouteDefinition(routeID).id == OUTLAND_ROUTE_ID then
		return GetOutlandRouteProgress()
	end

	return { unavailableText = L.UNKNOWN, steps = {} }
end

local function GetRouteStep(routeID)
	local progress = GetRouteProgress(routeID)
	if progress.unavailableText then
		return progress.unavailableText, nil, progress
	end
	if progress.completed then
		return L.ROUTE_COMPLETE, nil, progress
	end
	if progress.activeStep then
		return GetRouteStepDisplayText(progress.activeStep), progress.activeStep.waypoint, progress
	end

	return L.UNKNOWN, nil, progress
end

local function RefreshRouteTracker()
	if state.module and ObjectiveTrackerManager then
		ObjectiveTrackerManager:UpdateModule(state.module)
	elseif state.module then
		state.module:MarkDirty()
	end
end

local function HideRouteTracker()
	local module = state.module
	if not module then
		return
	end

	for _, routeDefinition in ipairs(routeDefinitions) do
		local block = module:GetExistingBlock(routeDefinition.id)
		if block then
			module:ForceRemoveBlock(block)
		end
	end
	module:Hide()

	if ObjectiveTrackerFrame and ObjectiveTrackerFrame.Update then
		ObjectiveTrackerFrame:Update()
	end
end

local function UpdateCustomWaypoint()
	local _, waypoint, progress = GetRouteStep(state.activeRouteID)
	local activeStepID = progress and progress.activeStep and progress.activeStep.id or nil
	state.activeWaypointStepID = activeStepID
	state.activeWaypoint = waypoint
end

local routeTrackerModuleMixin = {}

function routeTrackerModuleMixin:CanUpdate()
	return true
end

function routeTrackerModuleMixin:InitModule()
	local routeDefinition = GetRouteDefinition(state.activeRouteID)
	self:SetHeader(L[routeDefinition.titleKey])
	self.Header:SetPoint("TOPLEFT", self, "TOPLEFT", self.blockOffsetX, 0)
	self:SetWidth(self:GetWidth() + self.blockOffsetX)
end

function routeTrackerModuleMixin:LayoutContents()
	local routeID = state.activeRouteID
	if not routeID then
		return
	end

	local routeDefinition = GetRouteDefinition(routeID)
	self.Header.Text:SetText(L[routeDefinition.titleKey])

	local _, _, progress = GetRouteStep(routeID)
	local block = self:GetBlock(routeDefinition.id)
	block.offsetX = 32

	if progress.unavailableText then
		block:AddObjective("unavailable", progress.unavailableText, nil, nil, OBJECTIVE_DASH_STYLE_HIDE, OBJECTIVE_TRACKER_COLOR["Failed"])
	elseif progress.steps then
		for _, step in ipairs(progress.steps) do
			local colorStyle = step.completed and OBJECTIVE_TRACKER_COLOR["Complete"] or OBJECTIVE_TRACKER_COLOR["Normal"]
			local isActiveStep = progress.activeStep and progress.activeStep.id == step.id
			local lineText = isActiveStep and GetRouteStepDisplayText(step) or step.text
			local useFullHeight = true
			local line = block:AddObjective(step.id, lineText, nil, useFullHeight, OBJECTIVE_DASH_STYLE_HIDE, colorStyle)
			if line.Icon then
				line.Icon:Show()
				line.Icon:SetAtlas(step.completed and "ui-questtracker-tracker-check" or "ui-questtracker-objective-nub", false)
			end
		end
	end

	if block.height > 0 then
		self:LayoutBlock(block)
	end
end

local function EnsureRouteTrackerModule()
	if state.module then
		return state.module
	end
	if not ObjectiveTrackerFrame or not ObjectiveTrackerManager or not ObjectiveTrackerModuleMixin then
		return nil
	end

	local module = CreateFrame("Frame", "Level20RoutesObjectiveTracker", ObjectiveTrackerFrame, "ObjectiveTrackerModuleTemplate")
	Mixin(module, routeTrackerModuleMixin)
	module.blockTemplate = "ObjectiveTrackerAnimBlockTemplate"
	module.lineTemplate = "ObjectiveTrackerAnimLineTemplate"
	module.fromHeaderOffsetY = 0
	module.fromBlockOffsetY = -2
	module.blockOffsetX = 20
	module.lineSpacing = 12
	module.bottomSpacing = 6
	module.leftMargin = -20
	module.headerText = L[routeDefinitions[1].titleKey]
	module.hasDisplayPriority = true
	module.uiOrder = 0.75
	module:SetWidth(ScenarioObjectiveTracker and ScenarioObjectiveTracker:GetWidth() or 260)

	state.module = module
	return module
end

local function UpdateRouteTrackerRegistration()
	local module = EnsureRouteTrackerModule()
	if not module then
		return false
	end

	if ObjectiveTrackerManager and ObjectiveTrackerFrame and not state.moduleRegistered then
		ObjectiveTrackerManager:SetModuleContainer(module, ObjectiveTrackerFrame)
		state.moduleRegistered = ObjectiveTrackerManager:GetContainerForModule(module) == ObjectiveTrackerFrame
	end

	if state.activeRouteID and ObjectiveTrackerFrame and ObjectiveTrackerFrame.ForceExpand then
		ObjectiveTrackerFrame:ForceExpand()
	end

	RefreshRouteTracker()
	return state.moduleRegistered
end

function routes.RefreshAutomation()
	if state.activeRouteID then
		UpdateCustomWaypoint()
	else
		state.activeWaypointStepID = nil
		state.activeWaypoint = nil
	end

	RefreshRouteTracker()
end

function routes.Start(routeID)
	local routeDefinition = GetRouteDefinition(routeID)
	if not routes.CanStartRoute(routeDefinition.id) then
		return false
	end

	state.activeRouteID = routeDefinition.id
	state.activeWaypointStepID = nil
	state.activeWaypoint = nil
	state.usedZidormiFallback = false
	UpdateRouteTrackerRegistration()
	routes.RefreshAutomation()
	return true
end

function routes.Stop()
	local wasActive = state.activeRouteID ~= nil
	state.activeRouteID = nil
	state.activeWaypointStepID = nil
	state.activeWaypoint = nil
	state.usedZidormiFallback = false
	UpdateRouteTrackerRegistration()
	routes.RefreshAutomation()
	if wasActive then
		HideRouteTracker()
	end
end

function routes.Toggle(routeID)
	routeID = GetRouteDefinition(routeID).id
	if state.activeRouteID == routeID then
		routes.Stop()
		return false
	end

	return routes.Start(routeID)
end

function routes.GetPanelState(routeID)
	local routeDefinition = GetRouteDefinition(routeID)
	local faction = UnitFactionGroup("player") or L.UNKNOWN
	local mapID = C_Map.GetBestMapForUnit("player")
	local _, nodeIDs, errorText = GetCurrentBlastedLandsPhase(mapID)
	local nextStepText = GetRouteStep(routeDefinition.id)
	local phaseText = L.ROUTE_PHASE_CHECK_BLASTED_LANDS_ONLY
	if mapID == BLASTED_LANDS_MAP_ID then
		phaseText = errorText or GetDetectedRoutePhase(BLASTED_LANDS_MAP_ID, nodeIDs)
	end

	return {
		id = routeDefinition.id,
		title = L[routeDefinition.titleKey],
		faction = faction,
		mapID = mapID,
		mapText = GetMapDisplayText(mapID),
		phaseText = phaseText,
		nextStepText = nextStepText,
		active = state.activeRouteID == routeDefinition.id,
		canStart = routes.CanStartRoute(routeDefinition.id),
	}
end

function routes.GetDebugTaxiNodeDiff(updateBaseline)
	local mapID = C_Map.GetBestMapForUnit("player")
	local _, nodeIDs, errorText = GetCurrentBlastedLandsPhase(mapID)
	if mapID ~= BLASTED_LANDS_MAP_ID then
		return L.ROUTE_PHASE_CHECK_BLASTED_LANDS_ONLY
	end
	if updateBaseline and not errorText and nodeIDs then
		state.previousTaxiNodeIDs = CopyNodeIDs(nodeIDs)
	end

	return errorText or GetNodeIDDiff(state.previousTaxiNodeIDs, nodeIDs or {})
end

local routeRefreshFrame = CreateFrame("Frame")
routeRefreshFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
routeRefreshFrame:RegisterEvent("ZONE_CHANGED")
routeRefreshFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
routeRefreshFrame:SetScript("OnEvent", function()
	if addon.RefreshRoutesPanel then
		addon.RefreshRoutesPanel()
	end
	routes.RefreshAutomation()
end)
routeRefreshFrame:SetScript("OnUpdate", function(self, elapsed)
	if not state.activeRouteID then
		self.elapsedSinceRefresh = 0
		return
	end

	self.elapsedSinceRefresh = (self.elapsedSinceRefresh or 0) + elapsed
	if self.elapsedSinceRefresh >= 1 then
		self.elapsedSinceRefresh = 0
		if addon.RefreshRoutesPanel then
			addon.RefreshRoutesPanel()
		end
		routes.RefreshAutomation()
	end
end)
