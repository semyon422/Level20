local addonName, addon = ...

if GetLocale() ~= "ruRU" then
	return
end

local L = addon.L

L.LOADED_MESSAGE = "|cff00ff98Level20|r загружен. Нажмите кнопку у мини-карты или введите /level20, чтобы открыть Level20."

L.TAB_INFO = "Инфо"
L.TAB_SETTINGS = "Настройки"
L.TAB_WAYPOINTS = "Метки"

L.UNKNOWN = "Неизвестно"
L.ACCOUNT_TYPE = "Тип учетной записи:"
L.SUBSCRIPTION = "Подписка:"
L.XP_GAIN = "Получение опыта:"
L.CHROMIE_TIME = "Время Хроми:"

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
L.DEBUG_MODE_LABEL = "Режим отладки"
L.DEBUG_MODE_TOOLTIP = "Показывает метки на всех видимых игроках и принудительно отображает предупреждение об опыте."

L.MINIMAP_OPEN = "Открыть Level20"
L.MINIMAP_DRAG = "Перетащите, чтобы переместить"

L.STATE_ENABLED = "включен"
L.STATE_DISABLED = "отключен"
L.TALENT_FILTER_STATUS = "|cff00ff98Level20|r фильтр талантов 20-го уровня %s."
L.TALENT_FILTER_SLASH_STATUS = "|cff00ff98Level20|r фильтр талантов 20-го уровня %s. Используйте /l20 talents on или /l20 talents off."
L.SPELLBOOK_FILTER_STATUS = "|cff00ff98Level20|r фильтр книги заклинаний 20-го уровня %s."

L.XP_WARNING = "Внимание: у вас 20-й уровень, активная подписка и включено получение опыта."
