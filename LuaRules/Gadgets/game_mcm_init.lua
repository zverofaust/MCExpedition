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
end
