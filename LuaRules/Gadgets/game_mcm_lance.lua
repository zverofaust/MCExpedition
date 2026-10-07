--------------------------------------------------------------------------------
-- MechCommander: Mercs - Lance Controller
--
-- Owns the player's active four-Mech Lance.  The first implementation handles
-- pre-contract Lance selection and deployment; this gadget is intentionally
-- kept separate so later Mercs work can extend it into the persistent Lance
-- controller.
--
-- Authors: zvero + ChatGPT
--------------------------------------------------------------------------------

function gadget:GetInfo()
	return {
		name      = "MCM - Lance Controller",
		desc      = "Validates, deploys and tracks the Merc four-Mech Lance",
		author    = "zvero + ChatGPT",
		date      = "07/10/26",
		license   = "GNU GPL v2",
		layer     = 2,
		enabled   = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

local modeOwnership = VFS.Include("LuaRules/Configs/mcl_mode_gadgets.lua")
if modeOwnership.GetMode() ~= "mercs" then
	return false
end

local MSG_PREFIX = "MCMLANCE|"
local LANCE_SIZE = 4
local mercTeamID
local ordered = false
local canonicalMechs = {}

local function BuildMercCatalog()
	for unitDefID, unitDef in pairs(UnitDefs) do
		local cp = unitDef.customParams
		if cp and cp.baseclass == "mech" and unitDef.name:sub(1, 3) == "mc_" then
			canonicalMechs[unitDef.name] = unitDefID
		end
	end
end

local function GetDeploymentPosition(teamID)
	local x, _, z = Spring.GetTeamStartPosition(teamID)
	if not x or x < 0 or not z or z < 0 then
		x = Game.mapSizeX * 0.5
		z = Game.mapSizeZ * 0.5
	end
	return x, z
end

local function ParseOrder(msg)
	if type(msg) ~= "string" or msg:sub(1, #MSG_PREFIX) ~= MSG_PREFIX then
		return
	end

	local payload = msg:sub(#MSG_PREFIX + 1)
	local names = {}
	for name in payload:gmatch("[^,]+") do
		if #names >= LANCE_SIZE or name:find("[^%w_]") then
			return false
		end
		names[#names + 1] = name
	end

	if #names ~= LANCE_SIZE then
		return false
	end
	return names
end

local function SpawnLance(names)
	local x, z = GetDeploymentPosition(mercTeamID)
	local spacing = 96
	local offsets = {
		{-spacing, -spacing},
		{ spacing, -spacing},
		{-spacing,  spacing},
		{ spacing,  spacing},
	}

	for i = 1, LANCE_SIZE do
		local unitDefID = canonicalMechs[names[i]]
		if not unitDefID then
			return false
		end
	end

	local created = {}
	for i = 1, LANCE_SIZE do
		local ox, oz = offsets[i][1], offsets[i][2]
		local ux, uz = x + ox, z + oz
		local unitID = Spring.CreateUnit(
			canonicalMechs[names[i]],
			ux,
			Spring.GetGroundHeight(ux, uz),
			uz,
			"s",
			mercTeamID
		)
		if not unitID then
			for j = 1, #created do
				Spring.DestroyUnit(created[j], false, true)
			end
			Spring.Echo("[MCM Lance] Lance deployment failed; rolled back partial deployment.")
			return false
		end

		created[#created + 1] = unitID
		Spring.SetUnitRulesParam(unitID, "mcm_lance", 1, {public = true})
		Spring.SetUnitRulesParam(unitID, "mcm_lance_slot", i, {public = true})
	end

	ordered = true
	Spring.SetGameRulesParam("mcm_lance_ready", 1, {public = true})
	Spring.SetGameRulesParam("mcm_lance_size", LANCE_SIZE, {public = true})
	SendToUnsynced("mcm_lance_deployed", mercTeamID)
	Spring.Echo("[MCM Lance] Deployed ordered four-Mech Lance for team", mercTeamID)
	return true
end

function gadget:Initialize()
	mercTeamID = Spring.GetGameRulesParam("mcm_merc_team")
	BuildMercCatalog()
	Spring.SetGameRulesParam("mcm_lance_ready", 0, {public = true})
	Spring.SetGameRulesParam("mcm_lance_size", 0, {public = true})
end

function gadget:GameFrame(frame)
	if not mercTeamID then
		mercTeamID = Spring.GetGameRulesParam("mcm_merc_team")
	end
end

function gadget:RecvLuaMsg(msg, playerID)
	if ordered then
		return false
	end

	local names = ParseOrder(msg)
	if names == nil then
		return false
	end
	if names == false then
		return true
	end

	local _, active, spectator, teamID = Spring.GetPlayerInfo(playerID, false)
	if not active or spectator or not mercTeamID or teamID ~= mercTeamID then
		return true
	end

	SpawnLance(names)
	return true
end
