local addonName, addon = ...

addon.addonName = addonName
addon.LEVEL_CAP = 20

Level20DB = Level20DB or {}

local enabledByDefault = {
	hideHighLevelTalents = true,
	hideHighLevelSpells = true,
	showPlayerMarks = true,
	shadowlandsProtection = true,
	showDungeonChallengeFrame = true,
}

for key, value in pairs(enabledByDefault) do
	if Level20DB[key] == nil then
		Level20DB[key] = value
	end
end

Level20DB.debugMode = Level20DB.debugMode or false
Level20DB.minimapButtonAngle = Level20DB.minimapButtonAngle or 195
