local addonName, addon = ...

addon.addonName = addonName
addon.LEVEL_CAP = 20

Level20DB = Level20DB or {}
Level20DB.hideHighLevelTalents = Level20DB.hideHighLevelTalents ~= false
Level20DB.hideHighLevelSpells = Level20DB.hideHighLevelSpells ~= false
Level20DB.showMinimapButton = Level20DB.showMinimapButton ~= false
Level20DB.minimapButtonAngle = Level20DB.minimapButtonAngle or 195
