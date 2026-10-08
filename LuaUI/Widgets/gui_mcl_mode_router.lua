--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  MechCommander: Legacy - Mode UI Router
--
--  Selects mutually exclusive, mode-owned LuaUI widgets. Shared UI widgets
--  remain outside this router and continue to load normally.
--
--  Author: zvero + ChatGPT
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
	return {
		name      = "MCL - Mode UI Router",
		desc      = "Enables and disables UI owned by the active major game mode",
		author    = "zvero + ChatGPT",
		date      = "05/10/26",
		license   = "GNU GPL v2",
		layer     = -10000,
		enabled   = true,
		handler   = true,
	}
end

local MODE_WIDGETS = {
	pvp = {
		"Unit Deck",
		"MC:L - Tickets & Resources",
	},
	mercs = {
		"MCM Unit Deck",
		"MCM Nav Beacon Zone",
	},
}

local routedMode

local function SetWidgetEnabled(name, enabled)
	local known = widgetHandler.knownWidgets[name]
	if not known then
		Spring.Echo("[Mode UI Router] Unknown widget:", name)
		return
	end

	if enabled then
		if not known.active then
			widgetHandler:EnableWidget(name)
		end
	elseif known.active then
		widgetHandler:DisableWidget(name)
	end
end

local function ApplyMode(mode)
	if not MODE_WIDGETS[mode] then
		return false
	end

	for ownerMode, widgets in pairs(MODE_WIDGETS) do
		local enabled = ownerMode == mode
		for i = 1, #widgets do
			SetWidgetEnabled(widgets[i], enabled)
		end
	end

	routedMode = mode
	Spring.Echo("[Mode UI Router] Active mode:", mode)
	return true
end

function widget:Update()
	if routedMode then
		widgetHandler:RemoveWidget(self)
		return
	end

	local mode = Spring.GetGameRulesParam("mcl_mode")
	if mode then
		ApplyMode(mode)
	end
end
