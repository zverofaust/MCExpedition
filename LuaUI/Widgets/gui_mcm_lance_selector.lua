--------------------------------------------------------------------------------
-- MechCommander: Mercs - Lance Selector
--
-- Simple pre-deployment selector for the four-Mech Merc Lance.
-- Left click adds a Mech, right click removes one, and Order deploys the Lance.
--
-- Authors: zvero + ChatGPT
--------------------------------------------------------------------------------

function widget:GetInfo()
	return {
		name      = "MCM Lance Selector",
		desc      = "Selects and orders the Merc four-Mech Lance",
		author    = "zvero + ChatGPT",
		date      = "07/10/26",
		license   = "GNU GPL v2",
		layer     = 4,
		enabled   = true,
	}
end

local LANCE_SIZE = 4
local MSG_PREFIX = "MCMLANCE|"
local selected = {}
local selectionQueue = {}
local selectedTotal = 0
local catalog = {}
local countLabels = {}
local orderButton
local countLabel
local selectorWindow
local Chili
local initialized = false
local waitingForDeployment = false

local function BuildCatalog()
	for unitDefID, unitDef in pairs(UnitDefs) do
		local cp = unitDef.customParams
		if cp and cp.baseclass == "mech" and unitDef.name:sub(1, 3) == "mc_" then
			catalog[#catalog + 1] = {
				id = unitDefID,
				name = unitDef.name,
				humanName = unitDef.humanName or unitDef.name,
				variant = cp.variant or "",
				tonnage = tonumber(cp.tonnage) or 0,
			}
		end
	end

	table.sort(catalog, function(a, b)
		if a.tonnage ~= b.tonnage then
			return a.tonnage < b.tonnage
		end
		if a.humanName ~= b.humanName then
			return a.humanName < b.humanName
		end
		if a.variant ~= b.variant then
			return a.variant < b.variant
		end
		return a.name < b.name
	end)
end

local function UpdateSelectionDisplay()
	countLabel:SetCaption("LANCE  " .. selectedTotal .. " / " .. LANCE_SIZE)

	for i = 1, #catalog do
		local name = catalog[i].name
		local count = selected[name] or 0
		countLabels[name]:SetCaption(count > 0 and ("x" .. count) or "")
	end

	orderButton.enabled = selectedTotal == LANCE_SIZE and not waitingForDeployment
	orderButton:SetCaption(waitingForDeployment and "ORDERING..." or "ORDER")
	orderButton:Invalidate()
end

local function ChangeSelection(name, delta)
	if waitingForDeployment then
		return
	end

	local current = selected[name] or 0
	if delta > 0 then
		if selectedTotal >= LANCE_SIZE then
			return
		end
		selected[name] = current + 1
		selectionQueue[#selectionQueue + 1] = name
		selectedTotal = selectedTotal + 1
	elseif current > 0 then
		selected[name] = current - 1
		for i = #selectionQueue, 1, -1 do
			if selectionQueue[i] == name then
				table.remove(selectionQueue, i)
				break
			end
		end
		selectedTotal = selectedTotal - 1
	end

	UpdateSelectionDisplay()
end

local function SendOrder()
	if selectedTotal ~= LANCE_SIZE or waitingForDeployment then
		return
	end

	local order = {}
	for i = 1, #selectionQueue do
		order[i] = selectionQueue[i]
	end

	if #order ~= LANCE_SIZE then
		return
	end

	waitingForDeployment = true
	UpdateSelectionDisplay()
	Spring.SendLuaRulesMsg(MSG_PREFIX .. table.concat(order, ","))
end

local function CreateSelector()
	local vsx, vsy = Spring.GetViewGeometry()
	local windowWidth = math.floor(math.min(vsx * 0.82, 1180))
	local windowHeight = math.floor(math.min(vsy * 0.82, 820))
	local cardWidth = 104
	local cardHeight = 132
	local gap = 8
	local columns = math.max(4, math.floor((windowWidth - 54) / (cardWidth + gap)))
	local rows = math.ceil(#catalog / columns)

	selectorWindow = Chili.Window:New{
		parent = Chili.Screen0,
		x = math.floor((vsx - windowWidth) * 0.5),
		y = math.floor((vsy - windowHeight) * 0.5),
		width = windowWidth,
		height = windowHeight,
		caption = "MERCENARY LANCE",
		draggable = false,
		resizable = false,
		dockable = false,
		padding = {10, 30, 10, 10},
	}

	countLabel = Chili.Label:New{
		parent = selectorWindow,
		x = 12,
		y = 8,
		width = 180,
		height = 28,
		caption = "LANCE  0 / 4",
		fontsize = 18,
	}

	orderButton = Chili.Button:New{
		parent = selectorWindow,
		right = 12,
		y = 4,
		width = 150,
		height = 32,
		caption = "ORDER",
		enabled = false,
		OnClick = {SendOrder},
	}

	local scroll = Chili.ScrollPanel:New{
		parent = selectorWindow,
		x = 8,
		y = 44,
		right = 8,
		bottom = 8,
		padding = {4, 4, 4, 4},
		horizontalScrollbar = false,
	}

	local grid = Chili.Control:New{
		parent = scroll,
		x = 0,
		y = 0,
		width = math.max(windowWidth - 52, columns * (cardWidth + gap)),
		height = rows * (cardHeight + gap) + 8,
		padding = {0, 0, 0, 0},
	}

	for i = 1, #catalog do
		local entry = catalog[i]
		local column = (i - 1) % columns
		local row = math.floor((i - 1) / columns)
		local button = Chili.Button:New{
			parent = grid,
			x = column * (cardWidth + gap),
			y = row * (cardHeight + gap),
			width = cardWidth,
			height = cardHeight,
			caption = "",
			padding = {3, 3, 3, 3},
			tooltip = entry.humanName .. (entry.variant ~= "" and ("  " .. entry.variant) or "") .. "\n" .. entry.tonnage .. " tons\nLeft click: add   Right click: remove",
			OnMouseUp = {
				function(_, _, _, mouseButton)
					if mouseButton == 3 then
						ChangeSelection(entry.name, -1)
					elseif mouseButton == 1 then
						ChangeSelection(entry.name, 1)
					end
					return true
				end
			},
		}

		Chili.Image:New{
			parent = button,
			x = 10,
			y = 6,
			right = 10,
			height = 82,
			file = "#" .. entry.id,
			keepAspect = true,
			HitTest = function() return false end,
		}

		Chili.Label:New{
			parent = button,
			left = 5,
			right = 5,
			bottom = 22,
			height = 20,
			caption = entry.humanName,
			align = "center",
			valign = "bottom",
			fontsize = 11,
			font = {outline = true, outlineWidth = 2},
			HitTest = function() return false end,
		}

		Chili.Label:New{
			parent = button,
			left = 5,
			bottom = 3,
			width = 64,
			height = 18,
			caption = entry.variant,
			align = "left",
			valign = "bottom",
			fontsize = 11,
			font = {outline = true, outlineWidth = 2},
			HitTest = function() return false end,
		}

		countLabels[entry.name] = Chili.Label:New{
			parent = button,
			right = 5,
			bottom = 4,
			width = 42,
			height = 24,
			caption = "",
			align = "right",
			valign = "bottom",
			fontsize = 18,
			font = {outline = true, outlineWidth = 3},
			HitTest = function() return false end,
		}
	end

	UpdateSelectionDisplay()
end

local function RemoveSelector()
	if selectorWindow then
		selectorWindow:Dispose()
		selectorWindow = nil
	end
	widgetHandler:RemoveWidget(self)
end

function widget:Update()
	if initialized then
		if Spring.GetGameRulesParam("mcm_lance_ready") == 1 then
			RemoveSelector()
		end
		return
	end

	local mode = Spring.GetGameRulesParam("mcl_mode")
	if not mode then
		return
	end
	if mode ~= "mercs" then
		widgetHandler:RemoveWidget(self)
		return
	end
	if Spring.GetGameRulesParam("mcm_lance_ready") == 1 then
		widgetHandler:RemoveWidget(self)
		return
	end

	Chili = WG.Chili
	if not Chili then
		return
	end

	BuildCatalog()
	if #catalog == 0 then
		Spring.Echo("[MCM Lance Selector] No Mech UnitDefs available.")
		widgetHandler:RemoveWidget(self)
		return
	end

	CreateSelector()
	initialized = true
end
