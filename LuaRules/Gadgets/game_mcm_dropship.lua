--------------------------------------------------------------------------------
-- MechCommander: Mercs - Dropship Insertion
--
-- Creates the Merc Leopard and loads the selected four-Mech Lance as real
-- transport cargo.  MCL's proven Leopard flight/unload animation remains
-- authoritative; this gadget owns only Mercs mission coordination.
--
-- Authors: zvero + ChatGPT
--------------------------------------------------------------------------------

function gadget:GetInfo()
	return {
		name      = "MCM - Dropship Insertion",
		desc      = "Coordinates Merc Lance insertion by Leopard dropship",
		author    = "zvero + ChatGPT",
		date      = "08/10/26",
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

local LANCE_SIZE = 4
local activeDropship
local lanceUnits = {}

local function RollBack()
	for i = 1, #lanceUnits do
		local unitID = lanceUnits[i]
		if Spring.ValidUnitID(unitID) and not Spring.GetUnitIsDead(unitID) then
			Spring.DestroyUnit(unitID, false, true)
		end
	end
	lanceUnits = {}
	if activeDropship and Spring.ValidUnitID(activeDropship) and not Spring.GetUnitIsDead(activeDropship) then
		Spring.DestroyUnit(activeDropship, false, true)
	end
	activeDropship = nil
end

local function InsertionComplete()
	if Spring.GetGameRulesParam("mcm_lance_ready") == 1 then
		return
	end
	for i = 1, #lanceUnits do
		local unitID = lanceUnits[i]
		if not Spring.ValidUnitID(unitID) or Spring.GetUnitIsDead(unitID) or Spring.GetUnitTransporter(unitID) then
			return
		end
	end

	Spring.SetGameRulesParam("mcm_lance_ready", 1, {public = true})
	Spring.SetGameRulesParam("mcm_lance_size", #lanceUnits, {public = true})
	SendToUnsynced("mcm_lance_deployed", Spring.GetGameRulesParam("mcm_merc_team"))
end

function GG.MCMDeployLance(unitDefIDs)
	if activeDropship or #lanceUnits > 0 or type(unitDefIDs) ~= "table" or #unitDefIDs ~= LANCE_SIZE then
		return false
	end

	local teamID = Spring.GetGameRulesParam("mcm_merc_team")
	local beaconID = Spring.GetGameRulesParam("mcm_player_beacon")
	local x = Spring.GetGameRulesParam("mcm_player_start_x")
	local z = Spring.GetGameRulesParam("mcm_player_start_z")
	local dropshipDef = UnitDefNames.mc_dropship_leopard
	if not teamID or not beaconID or not x or not z or not dropshipDef then
		Spring.Echo("[MCM Dropship] Missing Merc team, Nav Beacon, insertion point or mc_dropship_leopard UnitDef.")
		return false
	end

	local y = Spring.GetGroundHeight(x, z)
	activeDropship = Spring.CreateUnit(dropshipDef.id, x, y, z, "s", teamID)
	if not activeDropship then
		Spring.Echo("[MCM Dropship] Failed to create insertion Leopard.")
		return false
	end

	Spring.SetUnitRulesParam(activeDropship, "mcm_insertion_dropship", 1, {public = true})
	Spring.SetGameRulesParam("mcm_insertion_dropship", activeDropship, {public = true})

	local env = Spring.UnitScript.GetScriptEnv(activeDropship)
	if not env or not env.LoadCargo then
		Spring.Echo("[MCM Dropship] Leopard LoadCargo interface unavailable.")
		RollBack()
		return false
	end

	for i = 1, LANCE_SIZE do
		local unitID = Spring.CreateUnit(unitDefIDs[i], x, y, z, "s", teamID, false, false)
		if not unitID then
			Spring.Echo("[MCM Dropship] Failed to create Lance cargo; rolling back insertion.")
			RollBack()
			return false
		end

		lanceUnits[#lanceUnits + 1] = unitID
		Spring.SetUnitRulesParam(unitID, "mcm_lance", 1, {public = true})
		Spring.SetUnitRulesParam(unitID, "mcm_lance_slot", i, {public = true})
		Spring.UnitScript.CallAsUnit(activeDropship, env.LoadCargo, unitID, beaconID, beaconID)
	end

	Spring.SetGameRulesParam("mcm_lance_size", LANCE_SIZE, {public = true})
	Spring.SetGameRulesParam("mcm_lance_inbound", 1, {public = true})
	return true
end

function gadget:GameFrame(frame)
	if activeDropship and Spring.GetGameRulesParam("mcm_lance_ready") ~= 1 then
		InsertionComplete()
	end
end

function gadget:UnitDestroyed(unitID)
	if unitID == activeDropship then
		activeDropship = nil
		Spring.SetGameRulesParam("mcm_insertion_dropship", 0, {public = true})
	end
end

function gadget:Shutdown()
	GG.MCMDeployLance = nil
end
