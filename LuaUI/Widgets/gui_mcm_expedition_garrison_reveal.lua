--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  Expedition Garrison Reveal
--
--  Draws the opening enemy-garrison location pulses in screen space so the
--  custom world FOW compositor cannot obscure them.
--
--  Author: zvero + ChatGPT
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
	return {
		name      = "MCM - Expedition Garrison Reveal",
		desc      = "Shows opening map-scale enemy garrison location pulses",
		author    = "zvero + ChatGPT",
		date      = "01/10/26",
		license   = "GNU GPL v2",
		layer     = 100,
		enabled   = true,
	}
end

local PULSE_INTERVAL = 90
local PULSE_DURATION = 60
local PULSE_COUNT = 4
local START_RADIUS = 120
local END_RADIUS = {
	light = 650,
	moderate = 900,
	heavy = 1150,
}
local SEGMENTS = 96

local sites = {}
local revealFrame
local initialized = false

local function LoadSites()
	local count = Spring.GetGameRulesParam("expedition_garrison_count")
	local frame = Spring.GetGameRulesParam("expedition_garrison_reveal_frame")
	if not count or count < 1 or not frame then
		return false
	end

	sites = {}
	for i = 1, count do
		local x = Spring.GetGameRulesParam("expedition_garrison_" .. i .. "_x")
		local z = Spring.GetGameRulesParam("expedition_garrison_" .. i .. "_z")
		if x and z then
			sites[#sites + 1] = {
				x = x,
				z = z,
				strength = Spring.GetGameRulesParam("expedition_garrison_" .. i .. "_strength") or "moderate",
			}
		end
	end

	if #sites == 0 then
		return false
	end

	revealFrame = frame
	initialized = true
	return true
end

local function DrawProjectedRing(site, radius, alpha)
	gl.Color(1, 0.16, 0.04, alpha)
	gl.LineWidth(5)

	gl.BeginEnd(GL.LINE_LOOP, function()
		for i = 0, SEGMENTS - 1 do
			local angle = i / SEGMENTS * math.pi * 2
			local x = site.x + math.cos(angle) * radius
			local z = site.z + math.sin(angle) * radius
			local y = Spring.GetGroundHeight(x, z) + 20
			local sx, sy = Spring.WorldToScreenCoords(x, y, z)
			gl.Vertex(sx, sy)
		end
	end)

	gl.LineWidth(1)
	gl.Color(1, 1, 1, 1)
end

function widget:Initialize()
	if Spring.GetGameRulesParam("mcl_mode") ~= "mercs" then
		widgetHandler:RemoveWidget(self)
	end
end

function widget:GameFrame()
	if not initialized then
		LoadSites()
	end
end

function widget:DrawScreen()
	if not initialized or Spring.IsGUIHidden() then
		return
	end

	local frame = Spring.GetGameFrame()
	local elapsed = frame - revealFrame
	if elapsed < 0 or elapsed > (PULSE_COUNT - 1) * PULSE_INTERVAL + PULSE_DURATION then
		return
	end

	for pulse = 0, PULSE_COUNT - 1 do
		local age = elapsed - pulse * PULSE_INTERVAL
		if age >= 0 and age <= PULSE_DURATION then
			local progress = age / PULSE_DURATION
			local alpha = 0.95 * (1 - progress)
			for i = 1, #sites do
				local endRadius = END_RADIUS[sites[i].strength] or END_RADIUS.moderate
				local radius = START_RADIUS + (endRadius - START_RADIUS) * progress
				DrawProjectedRing(sites[i], radius, alpha)
			end
		end
	end
end
