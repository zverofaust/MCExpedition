--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  MechCommander: Mercs - Mercs Initialization
--
--  Establishes the minimal tactical state shared by Mercs contracts.
--  Contract-specific deployment, objectives, enemies, extraction, economy and
--  persistence belong to contract controllers rather than this gadget.
--
--  Authors: zvero + ChatGPT
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:GetInfo()
	return {
		name      = "MCM - Mercs Initialization",
		desc      = "Establishes the Merc team and foundation test Lance",
		author    = "zvero + ChatGPT",
		date      = "06/10/26",
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

local TEST_LANCE = {
	"la_commando_com2d",
	"fs_hunchback_hbk4g",
	"fs_warhammer_whm6d",
	"fs_atlas_as7d",
}

local GAIA_TEAM_ID = Spring.GetGaiaTeamID()
local mercTeamID

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

local function GetDeploymentPosition(teamID)
	local x, y, z = Spring.GetTeamStartPosition(teamID)
	if not x or x < 0 or not z or z < 0 then
		x = Game.mapSizeX * 0.5
		z = Game.mapSizeZ * 0.5
	end
	y = Spring.GetGroundHeight(x, z)
	return x, y, z
end

local function SpawnFoundationLance(teamID)
	local x, y, z = GetDeploymentPosition(teamID)
	local spacing = 96
	local offsets = {
		{-spacing, -spacing},
		{ spacing, -spacing},
		{-spacing,  spacing},
		{ spacing,  spacing},
	}

	for i = 1, #TEST_LANCE do
		local unitName = TEST_LANCE[i]
		local unitDef = UnitDefNames[unitName]
		if unitDef then
			local ox, oz = offsets[i][1], offsets[i][2]
			local ux, uz = x + ox, z + oz
			local uy = Spring.GetGroundHeight(ux, uz)
			local unitID = Spring.CreateUnit(unitDef.id, ux, uy, uz, "s", teamID)
			if unitID then
				Spring.SetUnitRulesParam(unitID, "mcm_lance", 1, {public = true})
				Spring.SetUnitRulesParam(unitID, "mcm_lance_slot", i, {public = true})
			end
		else
			Spring.Echo("[MCM Init] Missing foundation Lance UnitDef:", unitName)
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

end

function gadget:GameStart()
	if mercTeamID then
		SpawnFoundationLance(mercTeamID)
	end
end
