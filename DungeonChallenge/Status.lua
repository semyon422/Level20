local addonName, addon = ...

local challenge = addon.DungeonChallenge
local state = challenge.state

function challenge.GetStatus()
	local isInInstance, instanceType = IsInInstance()
	local name, _, difficultyID, difficultyName, maxPlayers, _, _, instanceID, instanceGroupSize, lfgDungeonID = GetInstanceInfo()

	return {
		isInInstance = isInInstance,
		instanceType = instanceType,
		name = name,
		difficultyID = difficultyID,
		difficultyName = difficultyName,
		maxPlayers = maxPlayers,
		instanceID = instanceID,
		instanceGroupSize = instanceGroupSize,
		lfgDungeonID = lfgDungeonID,
	}
end

function challenge.GetDungeonDifficultyText()
	local status = challenge.GetStatus()
	if not status then
		return nil
	end

	local difficultyName
	if DifficultyUtil and DifficultyUtil.GetDifficultyName and status.difficultyID then
		difficultyName = DifficultyUtil.GetDifficultyName(status.difficultyID)
	end

	if not difficultyName or difficultyName == "" then
		difficultyName = status.difficultyName
	end

	if not difficultyName or difficultyName == "" then
		return nil
	end

	return difficultyName
end

function challenge.GetDungeonGroupSizeText()
	local status = challenge.GetStatus()
	if not status or status.instanceType ~= "raid" then
		return nil
	end

	local groupSize = tonumber(status.instanceGroupSize) or tonumber(status.maxPlayers)
	if not groupSize or groupSize <= 0 then
		return nil
	end

	return tostring(groupSize)
end

function challenge.ResetObservedDungeonLevelIfNeeded(status)
	if state.observedDungeonInstanceID ~= status.instanceID then
		state.observedDungeonInstanceID = status.instanceID
		state.observedDungeonLevel = nil
	end
end

function challenge.UpdateObservedDungeonLevel(level)
	level = tonumber(level)
	if not level or level <= 0 then
		return state.observedDungeonLevel
	end

	level = math.floor(level)
	if not state.observedDungeonLevel then
		state.observedDungeonLevel = level
		return state.observedDungeonLevel
	end

	local difference = level - state.observedDungeonLevel
	if difference >= 5 then
		state.observedDungeonLevel = level
	elseif math.abs(difference) < 5 and level % 5 == 0 then
		state.observedDungeonLevel = level
	end

	return state.observedDungeonLevel
end

function challenge.ObserveDungeonUnitLevel(unit)
	if not unit or not UnitExists(unit) or not UnitCanAttack("player", unit) then
		return nil
	end

	local level = UnitEffectiveLevel and UnitEffectiveLevel(unit)
	if not level or level <= 0 then
		level = UnitLevel(unit)
	end

	level = tonumber(level)
	if level and level > 0 then
		return challenge.UpdateObservedDungeonLevel(level)
	end

	return nil
end

function challenge.GetObservedDungeonLevel()
	local status = challenge.GetStatus()
	challenge.ResetObservedDungeonLevelIfNeeded(status)

	for _, unit in ipairs({ "target", "mouseover", "focus" }) do
		local level = challenge.ObserveDungeonUnitLevel(unit)
		if level then
			return level
		end
	end

	return state.observedDungeonLevel
end

function challenge.GetChallengeLevel()
	local status = challenge.GetStatus()
	challenge.ResetObservedDungeonLevelIfNeeded(status)

	local observedLevel = challenge.GetObservedDungeonLevel()
	if observedLevel and observedLevel > 0 then
		return observedLevel
	end

	local effectiveLevel = UnitEffectiveLevel and UnitEffectiveLevel("player")
	if effectiveLevel and effectiveLevel > 0 then
		return effectiveLevel
	end

	local level = UnitLevel("player")
	if level and level > 0 then
		return level
	end

	return addon.LEVEL_CAP
end

function challenge.GetChallengeLevelDisplayText()
	local levelText = CHALLENGE_MODE_POWER_LEVEL:format(challenge.GetChallengeLevel())
	local difficultyText = challenge.GetDungeonDifficultyText()
	if not difficultyText then
		return levelText
	end

	return string.format("%s |cff9d9d9d%s|r", levelText, difficultyText)
end

function challenge.IsRealChallengeModeActive()
	if C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive then
		return C_ChallengeMode.IsChallengeModeActive()
	end

	return false
end

function challenge.IsSupportedInstanceType(instanceType)
	return instanceType == "party" or instanceType == "raid"
end

function challenge.IsGarrisonInstance(instanceID)
	return challenge.constants.GARRISON_INSTANCE_IDS[tonumber(instanceID) or 0] == true
end

function challenge.ShouldUse()
	if not Level20DB.showDungeonChallengeFrame or challenge.IsRealChallengeModeActive() then
		return false
	end

	local status = challenge.GetStatus()
	return status.isInInstance
		and challenge.IsSupportedInstanceType(status.instanceType)
		and not challenge.IsGarrisonInstance(status.instanceID)
end
