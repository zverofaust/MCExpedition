--------------------------------------------------------------------------------
-- MechCommander: Mercs - Nav Beacon Zone
--
-- Draws the MCL-style ownership band around the Merc Nav Beacon. This is a
-- presentation-only widget: it has no capture, territory or gameplay logic.
--
-- Authors: zvero + ChatGPT
--------------------------------------------------------------------------------

function widget:GetInfo()
	return {
		name      = "MCM Nav Beacon Zone",
		desc      = "Draws the MCL-style team-coloured Nav Beacon ownership band",
		author    = "zvero + ChatGPT",
		date      = "08/10/26",
		license   = "GNU GPL v2",
		layer     = 5,
		enabled   = false, -- selected by the mode UI router
	}
end

local GetGroundHeight = Spring.GetGroundHeight
local GetTeamUnitsByDefs = Spring.GetTeamUnitsByDefs
local GetUnitPosition = Spring.GetUnitPosition
local GetTeamColor = Spring.GetTeamColor
local IsUnitVisible = Spring.IsUnitVisible
local IsGUIHidden = Spring.IsGUIHidden

local glCallList = gl.CallList
local glPushMatrix = gl.PushMatrix
local glPopMatrix = gl.PopMatrix
local glTranslate = gl.Translate
local glScale = gl.Scale
local glShape = gl.Shape
local GL_QUAD_STRIP = GL.QUAD_STRIP

local sin, cos = math.sin, math.cos
local PI = math.pi

local BEACON_DEF_ID = UnitDefNames["mcm_navbeacon"].id
local BEACON_RADIUS = 460
local MAX_ALPHA = 0.5
local INNER_SIZE = 0.875
local CIRCLE_DIVS = 6
local CIRCLE_INC = 2 * PI / CIRCLE_DIVS

local teams = Spring.GetTeamList()
local circleLists = {}

local function DrawTeamCircle(teamID)
	local vertices = {}
	local r, g, b = GetTeamColor(teamID)

	for i = 0, CIRCLE_DIVS do
		local angle = i * CIRCLE_INC
		local ox = cos(angle)
		local oz = sin(angle)
		local ix = ox * INNER_SIZE
		local iz = oz * INNER_SIZE
		vertices[2 * i + 1] = {v = {ix, 0, iz}, c = {r, g, b, 0}}
		vertices[2 * i + 2] = {v = {ox, 0, oz}, c = {r, g, b, MAX_ALPHA}}
	end

	glShape(GL_QUAD_STRIP, vertices)
end

function widget:Initialize()
	for i = 1, #teams do
		local teamID = teams[i]
		circleLists[teamID] = gl.CreateList(DrawTeamCircle, teamID)
	end
end

function widget:Shutdown()
	for i = 1, #teams do
		local listID = circleLists[teams[i]]
		if listID then
			gl.DeleteList(listID)
		end
	end
end

function widget:DrawWorldPreUnit()
	if IsGUIHidden() then
		return
	end

	for i = 1, #teams do
		local teamID = teams[i]
		local beacons = GetTeamUnitsByDefs(teamID, BEACON_DEF_ID)

		for j = 1, #beacons do
			local unitID = beacons[j]
			if IsUnitVisible(unitID, BEACON_RADIUS, true) then
				local x, y, z = GetUnitPosition(unitID)
				if y and y <= GetGroundHeight(x, z) + 5 then
					glPushMatrix()
						glTranslate(x, y, z)
						glScale(BEACON_RADIUS, 1, BEACON_RADIUS)
						glCallList(circleLists[teamID])
					glPopMatrix()
				end
			end
		end
	end
end
