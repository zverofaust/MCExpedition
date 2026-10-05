function widget:GetInfo()
	return {
		name      = "MCM Unit Deck",
		desc      = "Displays the Merc outfit lance and support units.",
		author    = "Smoth + zvero + ChatGPT",
		date      = "Oct, 2026",
		license   = "PD",
		layer     = 5,
		enabled   = false  -- selected by the mode UI router
	}
end

-- spring stuffs
local spGetUnitDefID		= Spring.GetUnitDefID
local spGetUnitHealth		= Spring.GetUnitHealth
local spSendCommands		= Spring.SendCommands

local green		= {0.0, 1.0, 0.0, 1.0}
local white		= {1.0, 1.0, 1.0, 1.0}
local grey		= {0.4, 0.4, 0.4, 1.0}
local black		= {0.0, 0.0, 0.0, 1.0}
local clear		= {0.0, 0.0, 0.0, 0.0}
local red		= {1.0, 0.1, 0.1, 1.0}

local deckWindow
local setWindow
local deckSets = {}
local deckButtons = {}
local units = {}
local unitIdCache = {}
local lanceUnits = {}
local supportUnits = {}
local currentSet = 1
local noUnit = ":cl:bitmaps/ui/infocard/no_unit.png"
local setNames = {"LANCE", "SUPPORT"}

local vsx = gl.GetViewSizes()
local fontSizes = {
	large = vsx / 87.27272727272727,
	medium = vsx / 160,
	small = vsx / 240,
}

local MY_TEAM = Spring.GetMyTeamID()
local MECH_DEFIDS = {}
local Chili

local function CreateWindows()
	deckWindow = Chili.Window:New{
		parent = Chili.Screen0;
		right = "0%";
		y = "75%";
		width = "15%";
		height = "25%";
		color = clear;
		draggable = false;
		dockable = false;
		resizable = false;
		padding = {0,0,0,0};
	}

	setWindow = Chili.Window:New{
		parent = deckWindow;
		right = "0%";
		y = "15%";
		width = "100%";
		height = "85%";
		color = grey;
		draggable = false;
		dockable = false;
		resizable = false;
		padding = {0,0,0,0};
	}
end

local function UpdateButton(setNumber, backgroundColor, textColor)
	deckButtons[setNumber].backgroundColor = backgroundColor
	deckButtons[setNumber].font.color = textColor
	deckButtons[setNumber]:Invalidate()
end

local function SelectSet(setNumber)
	if currentSet == setNumber then
		return
	end
	setWindow:RemoveChild(deckSets[currentSet])
	UpdateButton(currentSet, black, grey)
	currentSet = setNumber
	setWindow:AddChild(deckSets[currentSet])
	UpdateButton(currentSet, green, white)
end

local function InitializeSetView()
	for setNumber = 1, 2 do
		deckSets[setNumber] = Chili.ScrollPanel:New{
			name = "mercs unit list #" .. setNumber;
			padding = {0,0,0,0};
			width = "100%";
			height = "100%";
			dockable = false;
			draggable = false;
			resizable = false;
			backgroundColor = grey;
		}

		deckButtons[setNumber] = Chili.Button:New{
			tiles = {10,10,10,10};
			parent = deckWindow;
			name = "mercs deck #" .. setNumber;
			caption = setNames[setNumber];
			fontsize = fontSizes.large;
			fontShadow = false;
			font = {outline = true; outlineWidth = 5;};
			textColor = grey;
			x = ((setNumber - 1) * 50) .. "%";
			width = "50%";
			height = "15%";
			backgroundColor = black;
			OnMouseUp = {
				function()
					SelectSet(setNumber)
					local selected = setNumber == 1 and lanceUnits or supportUnits
					Spring.SelectUnitArray(selected)
				end
			};
			OnDblClick = {
				function()
					spSendCommands("viewselection")
				end
			};
		}

		units[setNumber] = {}
		unitIdCache[setNumber] = {}
		local unitNumber = 1
		for counterY = 0, 1 do
			for counterX = 0, 1 do
				local myIndex = unitNumber
				units[setNumber][unitNumber] = Chili.Window:New{
					parent = deckSets[setNumber];
					x = (counterX * 48 + 2) .. "%";
					y = (counterY * 48 + 2) .. "%";
					width = "50%";
					height = "50%";
					draggable = false;
					dockable = false;
					resizable = false;
					color = clear;
					padding = {0,0,0,0};
					children = {
						Chili.Button:New{
							caption = "";
							fontsize = fontSizes.medium;
							x = 0;
							y = 0;
							width = "100%";
							height = "100%";
							backgroundColor = clear;
							OnMouseUp = {
								function()
									local unitID = unitIdCache[setNumber][myIndex]
									if not unitID then return end
									WG.currentUnitId = unitID
									local transport = Spring.GetUnitTransporter(unitID)
									spSendCommands("selectunits clear +" .. (transport or unitID))
								end
							};
							OnDblClick = {
								function()
									spSendCommands("viewselection")
									spSendCommands("track")
								end
							};
						};
						Chili.Label:New{
							caption = "-- Absent --";
							valign = "top";
							y = "20%";
							x = "10%";
							fontsize = fontSizes.medium;
						};
						Chili.Progressbar:New{
							color = green;
							backgroundColor = black;
							font = {outline = true; outlineWidth = 6;};
							fontsize = fontSizes.medium;
							x = "5%";
							height = "20%";
							width = "90%";
						};
						Chili.Image:New{
							file = noUnit;
							x = "10%";
							y = "10%";
							width = "80%";
							height = "80%";
							keepAspect = true;
							color = grey;
						};
					};
				}
				unitNumber = unitNumber + 1
			end
		end
	end

	setWindow:AddChild(deckSets[currentSet])
	UpdateButton(currentSet, green, white)
end

local function CleanLance(unitID, lance)
	for slot = 1, #lanceUnits do
		if lanceUnits[slot] == unitID then
			table.remove(lanceUnits, slot)
			return
		end
	end
end

local function SetLance(unitID, lanceNum)
	if lanceNum ~= 1 or not unitID then
		return
	end
	for i = 1, #lanceUnits do
		if lanceUnits[i] == unitID then
			return
		end
	end
	lanceUnits[#lanceUnits + 1] = unitID
end

-- Mercs currently presents one four-Mech lance. Keep the Classic callbacks registered so
-- outpost_c3Array.lua can retain its existing unsynced interface unchanged.
local function SetMaxLance(newMaxLance)
	return
end

local function SetSupportLance(yesOrNo)
	return
end

local function RebuildTeamUnits()
	lanceUnits = {}
	supportUnits = {}
	local allTheUnits = Spring.GetTeamUnitsSorted(MY_TEAM)
	for unitDefID, unitTable in pairs(allTheUnits) do
		local ud = UnitDefs[unitDefID]
		local cp = ud and ud.customParams
		if MECH_DEFIDS[unitDefID] then
			for _, unitID in pairs(unitTable) do
				lanceUnits[#lanceUnits + 1] = unitID
			end
		elseif cp and (cp.baseclass == "vehicle" or cp.baseclass == "vtol") then
			for _, unitID in pairs(unitTable) do
				supportUnits[#supportUnits + 1] = unitID
			end
		end
	end
	table.sort(lanceUnits)
	table.sort(supportUnits)
end

local function UpdateSet(setNumber, setUnits)
	for unitNumber = 1, 4 do
		deckSets[setNumber]:RemoveChild(units[setNumber][unitNumber])
		unitIdCache[setNumber][unitNumber] = nil
	end

	for unitNumber = 1, math.min(#setUnits, 4) do
		local unitID = setUnits[unitNumber]
		local unitDefID = spGetUnitDefID(unitID)
		local currentDef = unitDefID and UnitDefs[unitDefID]
		local health, maxHealth = spGetUnitHealth(unitID)
		if currentDef and health and maxHealth and maxHealth > 0 then
			local unitPreview = units[setNumber][unitNumber].children
			unitIdCache[setNumber][unitNumber] = unitID
			deckSets[setNumber]:AddChild(units[setNumber][unitNumber])
			unitPreview[2]:SetCaption(currentDef.humanName)
			unitPreview[3]:SetValue(health / maxHealth * 100)
			unitPreview[3]:SetCaption(math.floor(health))
			unitPreview[4].file = "#" .. unitDefID
			unitPreview[4].color = Spring.GetUnitTransporter(unitID) and red or white
			unitPreview[4]:Invalidate()
		end
	end
end

function widget:Initialize()

	MY_TEAM = Spring.GetMyTeamID()
	for unitDefID, ud in pairs(UnitDefs) do
		if ud.customParams and ud.customParams.baseclass == "mech" then
			MECH_DEFIDS[unitDefID] = true
		end
	end
	WG.MECH_DEFIDS = MECH_DEFIDS

	widgetHandler:RegisterGlobal("SetLance", SetLance)
	widgetHandler:RegisterGlobal("CleanLance", CleanLance)
	widgetHandler:RegisterGlobal("SetMaxLance", SetMaxLance)
	widgetHandler:RegisterGlobal("SetSupportLance", SetSupportLance)

	Chili = WG.Chili
	if not Chili then
		widgetHandler:RemoveWidget()
		return
	end

	CreateWindows()
	InitializeSetView()
	RebuildTeamUnits()
end

function widget:Update()
	RebuildTeamUnits()
	UpdateSet(1, lanceUnits)
	UpdateSet(2, supportUnits)
end

function widget:PlayerChanged()
	local teamID = Spring.GetMyTeamID()
	if teamID ~= MY_TEAM then
		MY_TEAM = teamID
		RebuildTeamUnits()
	end
end
