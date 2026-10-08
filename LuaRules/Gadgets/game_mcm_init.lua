--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  MechCommander: Mercs - Mercs Initialization
--
--  Establishes the minimal tactical state shared by Mercs contracts.
--  Contract-specific deployment, objectives, enemies, extraction, economy and
--  persistence belong to their dedicated controllers.
--
--  Authors: zvero + ChatGPT
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:GetInfo()
	return {
		name      = "MCM - Mercs Initialization",
		desc      = "Establishes the Merc team and shared Mercs state",
		author    = "zvero + ChatGPT",
		date      = "07/10/26",
		license   = "GNU GPL v2",
		layer     = 1,
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

local GAIA_TEAM_ID = Spring.GetGaiaTeamID()
local mercTeamID
local playerStartX
local playerStartZ

local function ChoosePlayerStart()
	local profilePath = "maps/flagConfig/" .. Game.mapName .. "_profile.lua"
	local starts = {}

	if VFS.FileExists(profilePath) then
		local success, _, _, profileStarts = pcall(VFS.Include, profilePath)
		if success and type(profileStarts) == "table" then
			for _, start in pairs(profileStarts) do
				if type(start) == "table" and type(start.x) == "number" and type(start.z) == "number" then
					starts[#starts + 1] = {
						x = start.x,
						z = start.z,
					}
				end
			end
		end
	end

	if #starts > 0 then
		local selected = starts[math.random(#starts)]
		return selected.x, selected.z
	end

	local x, _, z = Spring.GetTeamStartPosition(mercTeamID)
	if not x or x < 0 or not z or z < 0 then
		x = Game.mapSizeX * 0.5
		z = Game.mapSizeZ * 0.5
	end
	return x, z
end

local function SpawnPlayerBeacon()
	local beaconDef = UnitDefNames.beacon
	if not beaconDef then
		Spring.Echo("[MCM Init] Nav Beacon UnitDef 'beacon' is unavailable")
		return
	end

	local y = Spring.GetGroundHeight(playerStartX, playerStartZ)
	local beaconID = Spring.CreateUnit(beaconDef.id, playerStartX, y, playerStartZ, 0, mercTeamID)
	if not beaconID then
		Spring.Echo("[MCM Init] Failed to create player Nav Beacon")
		return
	end

	Spring.SetUnitRulesParam(beaconID, "mcm_player_beacon", 1, {public = true})
	Spring.SetGameRulesParam("mcm_player_beacon", beaconID, {public = true})
end

local function FindMercTeam()
	local teams = Spring.GetTeamList()
	for i = 1, #teams do
		local teamID = teams[i]
		if teamID ~= GAIA_TEAM_ID then
			local players = Spring.GetPlayerList(teamID, true)
			if players and #players > 0 then
				return teamID
			end
		end
	end

	for i = 1, #teams do
		if teams[i] ~= GAIA_TEAM_ID then
			return teams[i]
		end
	end
end

function gadget:Initialize()
	mercTeamID = FindMercTeam()
	if not mercTeamID then
		Spring.Echo("[MCM Init] No non-Gaia team available for Merc initialization")
		return
	end

	Spring.SetGameRulesParam("mcm_merc_team", mercTeamID, {public = true})
	Spring.SetGameRulesParam("mcm_contract_active", 0, {public = true})
	Spring.SetTeamRulesParam(mercTeamID, "mcm_merc_team", 1, {public = true})
	Spring.SetTeamRulesParam(mercTeamID, "side", "mc", {public = true})
	Spring.SetTeamRulesParam(mercTeamID, "mcm_faction", "mc", {public = true})

	playerStartX, playerStartZ = ChoosePlayerStart()
	Spring.SetGameRulesParam("mcm_player_start_x", playerStartX, {public = true})
	Spring.SetGameRulesParam("mcm_player_start_z", playerStartZ, {public = true})
	SpawnPlayerBeacon()
end
