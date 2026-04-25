local addonName, addon = ...

addon.addonName = addonName
addon.LEVEL_CAP = 20

Level20DB = Level20DB or {}

local defaultSettings = {
	hideHighLevelTalents = true,
	hideHighLevelSpells = true,
	showPlayerMarks = true,
	shadowlandsProtection = true,
	showDungeonChallengeFrame = true,
	debugXPWarning = false,
	debugCovenantWarning = false,
	debugPlayerMarks = false,
	debugCompletionBannerPlayerCount = 5,
	minimapButtonAngle = 195,
	dungeonChallengeTimer = {},
}

for key, value in pairs(defaultSettings) do
	if Level20DB[key] == nil then
		Level20DB[key] = value
	end
end
