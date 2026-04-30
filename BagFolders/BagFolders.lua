local addonName, addon = ...

local BagFolders = addon.BagFolders or {}
addon.BagFolders = BagFolders

BagFolders.addonName = addonName
BagFolders.L = addon.L

BagFolders.DEFAULT_FOLDER_ID = "default"
BagFolders.COLUMNS = 4

-- Values mirror Blizzard_UIPanels_Game/Mainline/ContainerFrame.lua and ContainerFrame.xml.
BagFolders.CELL_SIZE = 37
BagFolders.CELL_SPACING = 5
BagFolders.ITEM_OFFSET_X = 7
BagFolders.ITEM_OFFSET_Y = 44
BagFolders.DEFAULT_FOLDER_CONTROLS_HEIGHT = 30
BagFolders.FRAME_WIDTH = 178
BagFolders.FRAME_PADDING_BOTTOM = 12
BagFolders.MONEY_FRAME_HEIGHT = 20
BagFolders.TOKEN_FRAME_SPACING = 3
BagFolders.CURRENCY_BOTTOM_PADDING = 8
BagFolders.CONTAINER_SPACING = 8
BagFolders.TOP_SCREEN_PADDING = 8
BagFolders.MIN_SCALE = 0.75

BagFolders.DEFAULT_FOLDER_ICON = "Interface/Icons/Inv_misc_bag_08"

BagFolders.folderFrames = BagFolders.folderFrames or {}
BagFolders.itemButtons = BagFolders.itemButtons or {}
BagFolders.emptyButtons = BagFolders.emptyButtons or {}
BagFolders.originalFunctions = BagFolders.originalFunctions or {}
BagFolders.hooksInstalled = BagFolders.hooksInstalled or false
BagFolders.hookRetryFrame = BagFolders.hookRetryFrame
BagFolders.eventFrame = BagFolders.eventFrame
BagFolders.iconSelectorPopup = BagFolders.iconSelectorPopup
BagFolders.isRefreshing = false
BagFolders.refreshQueued = false
BagFolders.needsRefresh = false
BagFolders.reagentAnchorHookInstalled = BagFolders.reagentAnchorHookInstalled or false
BagFolders.layoutAnchorFrame = BagFolders.layoutAnchorFrame
BagFolders.layoutScale = BagFolders.layoutScale
BagFolders.sessionClosedFolders = BagFolders.sessionClosedFolders or {}
BagFolders.pendingDraggedItemGUID = nil
BagFolders.pendingEquippedReservationGUID = nil
BagFolders.pendingEquippedReservationButton = nil
BagFolders.pendingExternalItemGUIDs = BagFolders.pendingExternalItemGUIDs or {}
BagFolders.lastVisibleGUIDs = BagFolders.lastVisibleGUIDs

BagFolders.events = {
	"BAG_UPDATE",
	"BAG_UPDATE_DELAYED",
	"ITEM_LOCK_CHANGED",
	"BAG_UPDATE_COOLDOWN",
	"BAG_NEW_ITEMS_UPDATED",
	"CURRENCY_DISPLAY_UPDATE",
	"INVENTORY_SEARCH_UPDATE",
	"PLAYER_EQUIPMENT_CHANGED",
	"PLAYER_LOGIN",
}
