local _, addon = ...

local LOREWALKING_TEXTURE_KIT = "lorewalking-scenario"

function addon.IsLorewalkingActive()
	if not C_UIWidgetManager then
		return false
	end

	local widgetSetID = C_UIWidgetManager.GetBelowMinimapWidgetSetID()
	if not widgetSetID then
		return false
	end

	local widgets = C_UIWidgetManager.GetAllWidgetsBySetID(widgetSetID) or {}
	for _, widget in ipairs(widgets) do
		if widget.widgetType == Enum.UIWidgetVisualizationType.ButtonHeader then
			local widgetInfo = C_UIWidgetManager.GetButtonHeaderWidgetVisualizationInfo(widget.widgetID)
			if widgetInfo
				and widgetInfo.shownState ~= Enum.WidgetShownState.Hidden
				and widgetInfo.frameTextureKit == LOREWALKING_TEXTURE_KIT then
				for _, buttonInfo in ipairs(widgetInfo.buttons or {}) do
					if buttonInfo.enabledState == Enum.UIWidgetButtonEnabledState.Enabled then
						return true, widget.widgetID, widgetInfo
					end
				end
			end
		end
	end

	return false
end
