local addonName, addon = ...

local BagFolders = addon.BagFolders or {}
addon.BagFolders = BagFolders

BagFolders.addonName = addonName
BagFolders.L = addon.L

BagFolders.DEFAULT_FOLDER_ID = "default"
BagFolders.COLUMNS = 4
BagFolders.CELL_SIZE = 37
BagFolders.CELL_SPACING = 5
BagFolders.ITEM_OFFSET_X = 7
BagFolders.ITEM_OFFSET_Y = 44
BagFolders.FRAME_WIDTH = 178
BagFolders.FRAME_PADDING_BOTTOM = 12
BagFolders.MONEY_FRAME_HEIGHT = 20
BagFolders.TOKEN_FRAME_SPACING = 3
BagFolders.CURRENCY_BOTTOM_PADDING = 8
BagFolders.CONTAINER_SPACING = 8
BagFolders.MIN_SCALE = 0.75
BagFolders.DEFAULT_FOLDER_ICON = "Interface/Icons/Inv_misc_bag_08"

BagFolders.folderFrames = BagFolders.folderFrames or {}
BagFolders.itemButtons = BagFolders.itemButtons or {}
BagFolders.emptyButtons = BagFolders.emptyButtons or {}
BagFolders.originalFunctions = BagFolders.originalFunctions or {}
BagFolders.hooksInstalled = BagFolders.hooksInstalled or false
BagFolders.hookRetryFrame = BagFolders.hookRetryFrame
BagFolders.iconSelectorPopup = BagFolders.iconSelectorPopup
BagFolders.isRefreshing = false
BagFolders.pendingDraggedItemGUID = nil

BagFolders.events = {
	"BAG_UPDATE",
	"BAG_UPDATE_DELAYED",
	"ITEM_LOCK_CHANGED",
	"BAG_UPDATE_COOLDOWN",
	"BAG_NEW_ITEMS_UPDATED",
	"CURRENCY_DISPLAY_UPDATE",
	"INVENTORY_SEARCH_UPDATE",
	"PLAYER_LOGIN",
}
