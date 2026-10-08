--------------------------------------------------------------------------------
-- MechCommander: Mercs - Expedition Response Controller
--
-- Tracks combat contact with the Merc Lance and progressively releases existing
-- Expedition vehicle groups as escalation rises. Mobilized groups move toward
-- the Lance's last known position; losing contact does not grant omniscience.
--
-- Authors: zvero + ChatGPT
--------------------------------------------------------------------------------

function gadget:GetInfo()
	return {
		name      = "MCM - Expedition Response",
		desc      = "Coordinates escalation-driven enemy response forces",
		author    = "zvero + ChatGPT",
		date      = "08/10/26",
		license   = "GNU GPL v2",
		layer     = 6,
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

local CONTACT_MEMORY_FRAMES = 15 * (Game.gameSpeed or 30)
local UPDATE_INTERVAL = 15
local responseGroups = {}
local mobilizedGroups = {}
local lastContactFrame = -1
local lastKnownX
local lastKnownZ
local enemyTeamID
local mercTeamID
local groupsBuilt = false

local function IsAlive(unitID)
	return unitID and Spring.ValidUnitID(unitID) and not Spring.GetUnitIsDead(unitID)
end

local function IsCombatVehicle(unitID)
	if not IsAlive(unitID) then
		return false
	end
	local unitDef = UnitDefs[Spring.GetUnitDefID(unitID)]
	return unitDef and unitDef.speed > 0 and unitDef.customParams
		and unitDef.customParams.baseclass == "vehicle"
		and not unitDef.customParams.support
end

local function BuildResponseGroups()
	if groupsBuilt or Spring.GetGameRulesParam("mcm_contract_active") ~= 1 then
		return
	end

	responseGroups = {}
	local sites = GG.MCMExpeditionSites or {}
	for i = 1, #sites do
		local site = sites[i]
		local units = {}
		for j = 1, #(site.units or {}) do
			if IsCombatVehicle(site.units[j]) then
				units[#units + 1] = site.units[j]
			end
		end
		if #units > 0 then
			responseGroups[#responseGroups + 1] = {
				site = site,
				units = units,
				mobilized = false,
			}
		end
	end
	groupsBuilt = true
	Spring.SetGameRulesParam("mcm_response_group_count", #responseGroups, {public = true})
end

local function SetContact(unitID, frame)
	local x, _, z = Spring.GetUnitPosition(unitID)
	if not x then
		return
	end

	lastKnownX = x
	lastKnownZ = z
	lastContactFrame = frame
	Spring.SetGameRulesParam("mcm_enemy_contact", 1, {public = true})
	Spring.SetGameRulesParam("mcm_enemy_contact_frame", frame, {public = true})
	Spring.SetGameRulesParam("mcm_enemy_last_known_x", x, {public = true})
	Spring.SetGameRulesParam("mcm_enemy_last_known_z", z, {public = true})

	for i = 1, #mobilizedGroups do
		local group = mobilizedGroups[i]
		for j = 1, #group.units do
			local responder = group.units[j]
			if IsCombatVehicle(responder) then
				Spring.GiveOrderToUnit(responder, CMD.FIGHT, {x, Spring.GetGroundHeight(x, z), z}, {})
			end
		end
	end
end

local function GroupDistanceSquared(group)
	local dx = group.site.x - lastKnownX
	local dz = group.site.z - lastKnownZ
	return dx * dx + dz * dz
end

local function MobilizeGroup(group)
	group.mobilized = true
	mobilizedGroups[#mobilizedGroups + 1] = group
	for i = 1, #group.units do
		local unitID = group.units[i]
		if IsCombatVehicle(unitID) then
			Spring.SetUnitRulesParam(unitID, "mcm_response_mobilized", 1, {public = true})
			Spring.GiveOrderToUnit(unitID, CMD.FIGHT, {
				lastKnownX,
				Spring.GetGroundHeight(lastKnownX, lastKnownZ),
				lastKnownZ,
			}, {})
		end
	end
end

local function DesiredGroupCount(level)
	if level >= 100 then
		return #responseGroups
	elseif level >= 75 then
		return math.min(4, #responseGroups)
	elseif level >= 50 then
		return math.min(2, #responseGroups)
	elseif level >= 25 then
		return math.min(1, #responseGroups)
	end
	return 0
end

local function UpdateResponse()
	if not groupsBuilt or not lastKnownX then
		return
	end

	local level = Spring.GetGameRulesParam("EXPEDITION_ESCALATION_LEVEL") or 0
	local desired = DesiredGroupCount(level)
	while #mobilizedGroups < desired do
		local best
		local bestDistance
		for i = 1, #responseGroups do
			local group = responseGroups[i]
			if not group.mobilized then
				local distance = GroupDistanceSquared(group)
				if not bestDistance or distance < bestDistance then
					best = group
					bestDistance = distance
				end
			end
		end
		if not best then
			break
		end
		MobilizeGroup(best)
	end

	Spring.SetGameRulesParam("mcm_response_mobilized_groups", #mobilizedGroups, {public = true})
end

function gadget:Initialize()
	mercTeamID = Spring.GetGameRulesParam("mcm_merc_team")
	enemyTeamID = Spring.GetGameRulesParam("mcm_enemy_team")
	Spring.SetGameRulesParam("mcm_enemy_contact", 0, {public = true})
	Spring.SetGameRulesParam("mcm_enemy_contact_frame", -1, {public = true})
	Spring.SetGameRulesParam("mcm_response_group_count", 0, {public = true})
	Spring.SetGameRulesParam("mcm_response_mobilized_groups", 0, {public = true})
end

function gadget:GameFrame(frame)
	if not mercTeamID then
		mercTeamID = Spring.GetGameRulesParam("mcm_merc_team")
	end
	if not enemyTeamID then
		enemyTeamID = Spring.GetGameRulesParam("mcm_enemy_team")
	end

	BuildResponseGroups()

	if lastContactFrame >= 0 and frame - lastContactFrame > CONTACT_MEMORY_FRAMES
			and Spring.GetGameRulesParam("mcm_enemy_contact") == 1 then
		Spring.SetGameRulesParam("mcm_enemy_contact", 0, {public = true})
	end

	if frame % UPDATE_INTERVAL == 0 then
		UpdateResponse()
	end
end

function gadget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)
	if not groupsBuilt or not attackerID or not mercTeamID or not enemyTeamID then
		return
	end

	-- Combat involving the Lance reveals the Lance's current position. Damage to
	-- an enemy records the attacking Mech; damage to a Lance Mech records the
	-- damaged Mech. Other fighting does not provide strategic contact.
	if attackerTeam == mercTeamID and unitTeam == enemyTeamID
			and Spring.GetUnitRulesParam(attackerID, "mcm_lance") == 1 then
		SetContact(attackerID, Spring.GetGameFrame())
	elseif attackerTeam == enemyTeamID and unitTeam == mercTeamID
			and Spring.GetUnitRulesParam(unitID, "mcm_lance") == 1 then
		SetContact(unitID, Spring.GetGameFrame())
	end
end
