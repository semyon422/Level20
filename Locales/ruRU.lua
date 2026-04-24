local addonName, addon = ...

if GetLocale() ~= "ruRU" then
	return
end

local L = addon.L

L.LOADED_MESSAGE = "|cff00ff98Level20|r загружен. Нажмите кнопку у мини-карты или введите /level20, чтобы открыть Level20."

L.TAB_INFO = "Инфо"
L.TAB_SETTINGS = "Настройки"
L.TAB_WAYPOINTS = "Метки"
L.TAB_DUNGEON = "Подземелье"

L.UNKNOWN = "Неизвестно"
L.ACCOUNT_TYPE = "Тип учетной записи:"
L.SUBSCRIPTION = "Подписка:"
L.XP_GAIN = "Получение опыта:"
L.CHROMIE_TIME = "Время Хроми:"
L.SHADOWLANDS_STATE = "Темные Земли:"

L.ACCOUNT_TRIAL = "Пробная"
L.ACCOUNT_VETERAN = "Ветеранская"
L.ACCOUNT_STANDARD = "Обычная"
L.SUBSCRIPTION_INACTIVE = "Неактивна"
L.SUBSCRIPTION_ACTIVE = "Активна"
L.XP_DISABLED = "Отключено"
L.XP_ENABLED = "Включено"
L.CHROMIE_TIME_PRESENT = "Настоящее"

L.WAYPOINT_CHROMIE = "Хроми"
L.WAYPOINT_XP_STOP_BEHSTEN = "Отключение опыта - Бехстен"
L.WAYPOINT_XP_STOP_SLAHTZ = "Отключение опыта - Слатц"
L.WAYPOINT_LOREWALKER_CHO = "Хранитель истории Чо"
L.CLEAR_WAYPOINT = "Очистить метку"
L.CANNOT_SET_WAYPOINT = "|cff00ff98Level20|r сейчас нельзя поставить метку на этой карте."
L.WAYPOINT_SET = "|cff00ff98Level20|r метка установлена: %s (%.2f, %.2f)."
L.WAYPOINT_CLEARED = "|cff00ff98Level20|r метка удалена."

L.TALENT_FILTER_LABEL = "Фильтр талантов 20-го уровня"
L.TALENT_FILTER_TOOLTIP = "Фильтрует таланты класса/специализации и PvP для обзора, полезного на 20-м уровне."
L.SPELLBOOK_FILTER_LABEL = "Фильтр книги заклинаний 20-го уровня"
L.SPELLBOOK_FILTER_TOOLTIP = "Скрывает в книге заклинаний способности, изучаемые после 20-го уровня."
L.PLAYER_MARKS_LABEL = "Метки игроков 20-го уровня"
L.PLAYER_MARKS_TOOLTIP = "Показывает значок 20-го уровня над индикаторами видимых игроков 20-го уровня."
L.SL_PROTECTION_LABEL = "Защита Темных Земель"
L.SL_PROTECTION_TOOLTIP = "Блокирует пропуск кампании Темных Земель и предупреждает перед выбором ковенанта."
L.DEBUG_MODE_LABEL = "Режим отладки"
L.DEBUG_MODE_TOOLTIP = "Показывает метки на всех видимых игроках и принудительно отображает предупреждение об опыте."
L.DUNGEON_CHALLENGE_FRAME_LABEL = "Рамка испытания подземелья"
L.DUNGEON_CHALLENGE_FRAME_TOOLTIP = "Показывает рамку испытания в стиле Mythic+ в подземельях на 5 игроков."

L.DUNGEON_CHALLENGE_SUBTITLE = "Испытание 20-го уровня"
L.DUNGEON_CHALLENGE_AFFIX = "Level20"
L.DUNGEON_CHALLENGE_AFFIX_TOOLTIP = "Рамка испытания обычного подземелья Level20."
L.DUNGEON_CHALLENGE_UNKNOWN_DUNGEON = "Подземелье"
L.DUNGEON_CHALLENGE_ENEMY_FORCES = "Войска противника"
L.DUNGEON_CHALLENGE_STATUS_LABEL = "Испытание:"
L.DUNGEON_CHALLENGE_TIMER_LABEL = "Таймер:"
L.DUNGEON_CHALLENGE_RESET_TIMER = "Сбросить таймер"
L.DUNGEON_CHALLENGE_COMPLETION_COMMAND = "|cff00ff98Level20|r показан баннер завершения Mythic+."
L.DUNGEON_CHALLENGE_COMPLETION_ERROR = "|cffff5a5aLevel20|r ошибка баннера завершения Mythic+: %s"
L.DUNGEON_CHALLENGE_COMPLETION_FINISHED = "Подземелье завершено!"
L.DUNGEON_CHALLENGE_COMPLETION_PENDING = "Подземелье не завершено"
L.DUNGEON_CHALLENGE_COMPLETION_TIME_VALUE = "Время забега: %s"

L.MINIMAP_OPEN = "Открыть Level20"
L.MINIMAP_DRAG = "Перетащите, чтобы переместить"

L.STATE_ENABLED = "включен"
L.STATE_DISABLED = "отключен"
L.TALENT_FILTER_STATUS = "|cff00ff98Level20|r фильтр талантов 20-го уровня %s."
L.SPELLBOOK_FILTER_STATUS = "|cff00ff98Level20|r фильтр книги заклинаний 20-го уровня %s."

L.XP_WARNING = "Внимание: у вас 20-й уровень, активная подписка и включено получение опыта."

L.SL_STATE_CLEAR = "Чисто"
L.SL_STATE_CAMPAIGN = "Кампания"
L.SL_STATE_CAMPAIGN_COMPLETE = "Кампания завершена"
L.SL_STATE_THREADS = "Нити судьбы"
L.SL_STATE_THREADS_CHOOSING = "Выбор ковенанта"
L.SL_STATE_THREADS_COVENANT = "Нити + ковенант"
L.SL_STATE_COVENANT = "Ковенант выбран"
L.SL_STATE_COVENANT_CHOICE = "Выбор ковенанта"

L.SL_WARNING_TITLE = "Предупреждение Темных Земель"
L.SL_COVENANT_WARNING = "Не выбирайте ковенант и не завершайте задание Выбор цели. Это может сделать контент Темных Земель недоступным для персонажа 20-го уровня."
L.SL_CANCEL_COVENANT_QUEST = "Отменить задание"
L.SL_COVENANT_QUEST_CANCELLED = "|cff00ff98Level20|r задание Выбор цели отменено."
L.SL_COVENANT_QUEST_CANCEL_FAILED = "|cff00ff98Level20|r не удалось отменить задание Выбор цели."
L.SL_SKIP_BLOCKED_MESSAGE = "|cff00ff98Level20|r пропуск кампании Темных Земель заблокирован."
