local _, addon = ...

local groupData = addon.GroupData

function groupData.BuildRosterOrder()
	local players = {}

	if UnitExists("player") then
		players[#players + 1] = {
			key = groupData.GetPlayerKey(GetUnitName("player", true)),
			displayName = GetUnitName("player", false),
		}
	end

	if IsInRaid() then
		for index = 1, GetNumGroupMembers() do
			local unit = "raid" .. index
			if UnitExists(unit) and UnitIsPlayer(unit) and not UnitIsUnit(unit, "player") then
				players[#players + 1] = {
					key = groupData.GetPlayerKey(GetUnitName(unit, true)),
					displayName = GetUnitName(unit, false),
				}
			end
		end
	elseif IsInGroup() then
		for index = 1, GetNumSubgroupMembers() do
			local unit = "party" .. index
			if UnitExists(unit) and UnitIsPlayer(unit) then
				players[#players + 1] = {
					key = groupData.GetPlayerKey(GetUnitName(unit, true)),
					displayName = GetUnitName(unit, false),
				}
			end
		end
	end

	return players
end

function groupData.GetSortedPlayers()
	local rosterOrder = groupData.BuildRosterOrder()
	local indexed = {}

	for orderIndex, rosterEntry in ipairs(rosterOrder) do
		if rosterEntry and rosterEntry.key then
			indexed[rosterEntry.key] = orderIndex
		end
	end

	local results = {}
	for _, rosterEntry in ipairs(rosterOrder) do
		local data = rosterEntry.key and groupData.state.players[rosterEntry.key] or nil
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
