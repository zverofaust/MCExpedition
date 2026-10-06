--------------------------------------------------------------------------------
-- MechCommander: Legacy shared map environment
--
-- Publishes environmental values required by shared combat systems.
--
-- Authors: zvero + ChatGPT
--------------------------------------------------------------------------------

function gadget:GetInfo()
	return {
		name      = "API - Map Environment",
		desc      = "Publishes shared map environmental data",
		author    = "zvero + ChatGPT",
		date      = "06/10/26",
		license   = "GNU GPL v2",
		layer     = -101,
		enabled   = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

local PROFILE_PATH = "maps/" .. Game.mapName .. ".lua"

function gadget:GamePreload()
	local temps = {}

	if VFS.FileExists(PROFILE_PATH) then
		local _, profileTemps = VFS.Include(PROFILE_PATH)
		temps = profileTemps or temps
	end

	temps.ambient = temps.ambient or 20
	temps.water = temps.water or 10

	GG.MapTemperatures = temps
	Spring.SetGameRulesParam("MAP_TEMP_AMBIENT", temps.ambient)
	Spring.SetGameRulesParam("MAP_TEMP_WATER", temps.water)
end

function gadget:Initialize()
	gadget:GamePreload()
end
