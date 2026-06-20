local addonName, addon = ...

local challenge = addon.DungeonChallenge
local state = challenge.state

local SCORING_RULES = {
	[20] = { baseScore = 20, deathPenalty = 1, wipePenalty = 2 },
	[30] = { baseScore = 50, deathPenalty = 1, wipePenalty = 2 },
	[35] = { baseScore = 100, deathPenalty = 1, wipePenalty = 2 },
	[40] = { baseScore = 200, deathPenalty = 1, wipePenalty = 2 },
	[45] = { baseScore = 300, deathPenalty = 1, wipePenalty = 2 },
}

local DUNGEON_TIERS_BY_INSTANCE_ID = {
	[540] = 30, -- The Shattered Halls / Разрушенные залы
	[542] = 30, -- The Blood Furnace / Кузня Крови
	[555] = 30, -- Shadow Labyrinth / Темный лабиринт
	[574] = 30, -- Utgarde Keep / Крепость Утгард
	[575] = 30, -- Utgarde Pinnacle / Вершина Утгард
	[576] = 30, -- The Nexus / Нексус
	[578] = 30, -- The Oculus / Окулус
	[595] = 30, -- The Culling of Stratholme / Очищение Стратхольма
	[599] = 30, -- Halls of Stone / Чертоги Камня
	[600] = 30, -- Drak'Tharon Keep / Крепость Драк'Тарон
	[601] = 30, -- Azjol-Nerub / Азжол-Неруб
	[602] = 30, -- Halls of Lightning / Чертоги Молний
	[604] = 30, -- Gundrak / Гундрак
	[608] = 30, -- The Violet Hold / Аметистовая крепость
	[619] = 30, -- Ahn'kahet: The Old Kingdom / Ан'кахет: Старое Королевство
	[632] = 30, -- The Forge of Souls / Кузня Душ
	[650] = 30, -- Trial of the Champion / Испытание чемпиона
	[657] = 35, -- The Vortex Pinnacle / Вершина Смерча
	[658] = 30, -- Pit of Saron / Яма Сарона
	[668] = 30, -- Halls of Reflection / Залы Отражений
	[725] = 35, -- The Stonecore / Каменные Недра
	[960] = 35, -- Temple of the Jade Serpent / Храм Нефритовой Змеи
	[961] = 35, -- Stormstout Brewery / Хмелеварня Буйных Портеров
	[1175] = 40, -- Bloodmaul Slag Mines / Шлаковые шахты Кровавого Молота
	[1176] = 40, -- Shadowmoon Burial Grounds / Некрополь Призрачной Луны
	[1182] = 40, -- Auchindoun / Аукиндон
	[1195] = 40, -- Iron Docks / Железные доки
	[1208] = 40, -- Grimrail Depot / Депо Мрачных Путей
	[1209] = 40, -- Skyreach / Небесный Путь
	[1279] = 40, -- The Everbloom / Вечное Цветение
	[1358] = 40, -- Upper Blackrock Spire / Верхняя часть пика Черной горы
	[1456] = 45, -- Eye of Azshara / Око Азшары
	[1458] = 45, -- Neltharion's Lair / Логово Нелтариона
	[1466] = 45, -- Darkheart Thicket / Чаща Тёмного Сердца
	[1477] = 45, -- Halls of Valor / Чертоги Доблести
	[1492] = 45, -- Maw of Souls / Утроба Душ
	[1493] = 45, -- Vault of the Wardens / Казематы Стражей
	[1501] = 45, -- Black Rook Hold / Крепость Чёрной Ладьи
	[1516] = 45, -- The Arcway / Катакомбы Сурамара
	[1544] = 45, -- Assault on Violet Hold / Аметистовая крепость
	[1571] = 45, -- Court of Stars / Квартал Звезд
	[1651] = 45, -- Return to Karazhan / Возвращение в Каражан
	[1677] = 45, -- Cathedral of Eternal Night / Собор Вечной Ночи
	[1753] = 45, -- Seat of the Triumvirate / Престол Триумвирата
}

local function MarkDirty()
	if state.customTrackerModule then
		state.customTrackerModule:MarkDirty()
	end
end

function challenge.GetScoringRules(tier)
	return SCORING_RULES[tonumber(tier) or 0] or SCORING_RULES[20]
end

function challenge.GetTimeBonus(tier, durationSeconds)
	tier = tonumber(tier) or 20
	durationSeconds = math.max(0, tonumber(durationSeconds) or 0)

	if tier == 20 then
		if durationSeconds <= 180 then return 15 end
		if durationSeconds <= 300 then return 10 end
		return 0
	elseif tier == 30 then
		if durationSeconds <= 1500 then return 15 end
		if durationSeconds <= 2100 then return 10 end
		return 0
	elseif tier == 35 then
		if durationSeconds <= 1500 then return 10 end
		if durationSeconds <= 2100 then return 5 end
		return 0
	elseif tier == 40 then
		if durationSeconds <= 2700 then return 20 end
		if durationSeconds <= 3600 then return 10 end
		return 0
	elseif tier == 45 then
		if durationSeconds <= 7200 then return 50 end
		if durationSeconds <= 10800 then return 30 end
		return 0
	end

	return 0
end

function challenge.GetScoringTier(status)
	status = status or (challenge.GetStatus and challenge.GetStatus()) or {}
	if tonumber(status.difficultyID) == 1 then
		return 20
	end

	return DUNGEON_TIERS_BY_INSTANCE_ID[tonumber(status.instanceID) or 0] or challenge.GetChallengeLevel()
end

function challenge.GetWipeCount(run)
	run = run or challenge.GetRunRecord()
	if not run then
		return 0
	end

	return math.max(0, tonumber(run.wipeCount) or 0)
end

function challenge.RecordWipe(reason, run)
	run = run or challenge.GetRunRecord()
	if not run or not run.startedAt or run.completedAt then
		return false
	end

	if state.activeBossFight and state.activeBossFight.wipeRecorded then
		return false
	end

	run.wipeCount = challenge.GetWipeCount(run) + 1
	run.lastWipeReason = reason
	if state.activeBossFight then
		state.activeBossFight.wipeRecorded = true
	end
	MarkDirty()
	return true
end

function challenge.BeginBossFight(encounterID, encounterName)
	state.activeBossFight = {
		encounterID = encounterID,
		encounterName = encounterName,
		startedAt = challenge.GetCurrentServerTime and challenge.GetCurrentServerTime() or time(),
		wipeRecorded = false,
	}
end

function challenge.EndBossFight(success)
	if success == false or success == 0 then
		challenge.RecordWipe("encounter_failed")
	end

	state.activeBossFight = nil
	MarkDirty()
end

function challenge.GetScoreInfo(run)
	run = run or challenge.GetRunRecord()
	local status = challenge.GetStatus and challenge.GetStatus() or {}
	local tier = challenge.GetScoringTier(status)
	local rules = challenge.GetScoringRules(tier)
	local elapsed = challenge.GetElapsedTime and challenge.GetElapsedTime() or 0
	local baseScore = rules.baseScore
	local timeBonus = challenge.GetTimeBonus(tier, elapsed)
	local deathCount = challenge.GetDeathCount and challenge.GetDeathCount(run) or 0
	local wipeCount = challenge.GetWipeCount(run)
	local instanceID = tonumber(status.instanceID) or 0

	if instanceID == 601 and tier == 20 then
		wipeCount = 0
	end

	local deathPenalty = deathCount * rules.deathPenalty
	local wipePenalty = wipeCount * rules.wipePenalty
	local score = math.max(0, baseScore + timeBonus - deathPenalty - wipePenalty)

	return {
		score = score,
		tier = tier,
		instanceID = instanceID,
		baseScore = baseScore,
		timeBonus = timeBonus,
		deathCount = deathCount,
		wipeCount = wipeCount,
		deathPenalty = deathPenalty,
		wipePenalty = wipePenalty,
		deathPenaltyPerDeath = rules.deathPenalty,
		wipePenaltyPerWipe = rules.wipePenalty,
		elapsed = elapsed,
	}
end
