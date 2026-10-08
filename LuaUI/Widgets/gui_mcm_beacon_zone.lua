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
		enabled   = true,
	}
end

local GetGameRulesParam = Spring.GetGameRulesParam
local GetGroundHeight = Spring.GetGroundHeight
local GetUnitPosition = Spring.GetUnitPosition
local GetUnitTeam = Spring.GetUnitTeam
local GetTeamColor = Spring.GetTeamColor
local ValidUnitID = Spring.ValidUnitID
local IsUnitVisible = Spring.IsUnitVisible
local IsGUIHidden = Spring.IsGUIHidden

local glPushMatrix = gl.PushMatrix
local glPopMatrix = gl.PopMatrix
local glTranslate = gl.Translate
local glScale = gl.Scale
local glShape = gl.Shape
local GL_QUAD_STRIP = GL.QUAD_STRIP

local sin, cos = math.sin, math.cos
local PI = math.pi

local BEACON_RADIUS = 460
local MAX_ALPHA = 0.5
local INNER_SIZE = 0.875
local CIRCLE_DIVS = 6
local CIRCLE_INC = 2 * PI / CIRCLE_DIVS

local function DrawOwnershipBand(teamID)
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

function widget:DrawWorldPreUnit()
	if IsGUIHidden() or GetGameRulesParam("mcl_mode") ~= "mercs" then
		return
	end

	local unitID = GetGameRulesParam("mcm_player_beacon")
	if not unitID or unitID <= 0 or not ValidUnitID(unitID) then
		return
	end

	if not IsUnitVisible(unitID, BEACON_RADIUS, true) then
		return
	end

	local x, y, z = GetUnitPosition(unitID)
	if not x or y > GetGroundHeight(x, z) + 5 then
		return
	end

	local teamID = GetUnitTeam(unitID)
	if not teamID then
		return
	end

	glPushMatrix()
		glTranslate(x, y, z)
		glScale(BEACON_RADIUS, 1, BEACON_RADIUS)
		DrawOwnershipBand(teamID)
	glPopMatrix()
end
