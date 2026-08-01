local addonName, addon = ...

addon.addonName = addonName
addon.LEVEL_CAP = 20
addon.ENEMY_FORCES_MODE_DISABLED = "disabled"
addon.ENEMY_FORCES_MODE_REQUIRED = "required"
addon.ENEMY_FORCES_MODE_UNLIMITED = "unlimited"

---@alias Level20BagFolderID string
---@alias Level20ItemGUID string

---@class Level20BagFolder
---@field id Level20BagFolderID
---@field name string
---@field icon string|integer?

---@class Level20BagFoldersDB
---@field enabled boolean
---@field characters table<string, Level20BagFoldersCharacterDB>
---@field defaultIcon string|integer

---@class Level20BagFoldersCharacterDB
---@field folders Level20BagFolder[]
---@field itemFolders {[Level20ItemGUID]: Level20BagFolderID}
---@field itemPositions {[Level20ItemGUID]: integer}
---@field hiddenFolders {[Level20BagFolderID]: boolean}

---@class Level20DungeonChallengeCriteria
---@field criteriaID integer?
---@field description string?
---@field quantity integer?
---@field totalQuantity integer?
---@field completed boolean?
---@field duration integer?
---@field elapsed integer?
---@field failed boolean?
---@field isWeightedProgress boolean?
---@field isFormatted boolean?
---@field quantityString string?
---@field criteriaType integer?
---@field flags integer?
---@field assetID integer?

---@class Level20DungeonChallengeRun
---@field startedAt integer?
---@field completedAt integer?
---@field completedElapsed integer?
---@field deathCount integer?
---@field wipeCount integer?
---@field lastWipeReason string?
---@field enemyForcesCounts table<string, integer>?
---@field completionBannerShown boolean?
---@field encounterCompletionTimes {[string]: integer}?
---@field encounterCriteriaSnapshot Level20DungeonChallengeCriteria[]?

---@class Level20DB
---@field hideHighLevelTalents boolean
---@field hideHighLevelSpells boolean
---@field showPlayerMarks boolean
---@field shadowlandsProtection boolean
---@field showDungeonChallengeFrame boolean
---@field showDungeonChallengeScoreCriteria boolean
---@field enemyForcesMode string
---@field allowGuildChallengeStart boolean
---@field manageCombatLog boolean
---@field debugXPWarning boolean
---@field debugCovenantWarning boolean
---@field debugPlayerMarks boolean
---@field debugUnitTooltipValues boolean
---@field debugCompletionBannerPlayerCount integer
---@field minimapButtonAngle number
---@field smallMinimapButton boolean
---@field dungeonChallengeRuns {[string]: Level20DungeonChallengeRun}
---@field bagFolders Level20BagFoldersDB
---@field windowPoint string?
---@field windowRelativePoint string?
---@field windowXOfs number?
---@field windowYOfs number?
---@field lastSeenRemoteVersion integer?
---@field lastSeenRemoteVersionSource string?
---@field groupDataWindowPoint string?
---@field groupDataWindowRelativePoint string?
---@field groupDataWindowXOfs number?
---@field groupDataWindowYOfs number?
---@field groupDataPlayers table<string, table>?
---@field spectatorWarGameLeaderA string?
---@field spectatorWarGameLeaderB string?
---@field spectatorWarGameArenaID integer|string?

---@type Level20DB
Level20DB = Level20DB or {}

---@type Level20DB
local defaultSettings = {
	hideHighLevelTalents = true,
	hideHighLevelSpells = true,
	showPlayerMarks = true,
	shadowlandsProtection = true,
	showDungeonChallengeFrame = true,
	showDungeonChallengeScoreCriteria = false,
	enemyForcesMode = addon.ENEMY_FORCES_MODE_DISABLED,
	allowGuildChallengeStart = false,
	manageCombatLog = false,
	debugXPWarning = false,
	debugCovenantWarning = false,
	debugPlayerMarks = false,
	debugUnitTooltipValues = false,
	debugCompletionBannerPlayerCount = 5,
	minimapButtonAngle = 195,
	smallMinimapButton = false,
	dungeonChallengeRuns = {},
	bagFolders = {
		enabled = false,
		characters = {},
		defaultIcon = "Interface/Icons/Inv_misc_bag_08",
	},
	groupDataPlayers = {},
	lastSeenRemoteVersion = nil,
	lastSeenRemoteVersionSource = nil,
}

for key, value in pairs(defaultSettings) do
	if Level20DB[key] == nil then
		Level20DB[key] = value
	end
end
