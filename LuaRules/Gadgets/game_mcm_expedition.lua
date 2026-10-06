--------------------------------------------------------------------------------
-- MechCommander: Mercs - Expedition battlefield generation
--
-- Prototype: selects authored map locations and creates several independent
-- Mercs bases without using PvP Beacons, Outposts, DropZones or SpamBot.
--
-- Authors: zvero + ChatGPT
--------------------------------------------------------------------------------

function gadget:GetInfo()
	return {
		name      = "MCM - Expedition",
		desc      = "Generates the Mercs Expedition battlefield",
		author    = "zvero + ChatGPT",
		date      = "06/10/26",
		license   = "GNU GPL v2",
		layer     = 5,
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

local defs = VFS.Include("LuaRules/Configs/mcm_expedition_defs.lua")
local GAIA_TEAM_ID = Spring.GetGaiaTeamID()

GG.MCMExpeditionBases = GG.MCMExpeditionBases or {}

local function DistanceSquared(x1, z1, x2, z2)
	local dx = x1 - x2
	local dz = z1 - z2
	return dx * dx + dz * dz
end

local function AddCandidate(candidates, x, z, source)
	if type(x) ~= "number" or type(z) ~= "number" then
		return
	end
	if x < 0 or x > Game.mapSizeX or z < 0 or z > Game.mapSizeZ then
		return
	end
	if Spring.GetGroundHeight(x, z) < 0 then
		return
	end

	for i = 1, #candidates do
		if DistanceSquared(x, z, candidates[i].x, candidates[i].z) < 250 * 250 then
			return
		end
	end

	candidates[#candidates + 1] = {
		x = x,
		z = z,
		source = source,
	}
end

local function LoadCandidates()
	local candidates = {}
	local profilePath = "maps/flagConfig/" .. Game.mapName .. "_profile.lua"

	if VFS.FileExists(profilePath) then
		local success, resources, _, starts, camps = pcall(VFS.Include, profilePath)
		if success then
			if type(resources) == "table" then
				for i = 1, #resources do
					local site = resources[i]
					if site.points ~= 0 then
						AddCandidate(candidates, site.x, site.z, "resource")
					end
				end
			end

			if type(camps) == "table" then
				for i = 1, #camps do
					AddCandidate(candidates, camps[i].x, camps[i].z, "camp")
				end
			end

			if type(starts) == "table" then
				for _, site in pairs(starts) do
					AddCandidate(candidates, site.x, site.z, "start")
				end
			end
		else
			Spring.Echo("[MCM Expedition] Failed to load map profile:", profilePath)
		end
	end

	return candidates
end

local function GetMercTeam()
	local teamID = Spring.GetGameRulesParam("mcm_merc_team")
	if teamID then
		return teamID
	end

	for _, candidateTeamID in ipairs(Spring.GetTeamList()) do
		if candidateTeamID ~= GAIA_TEAM_ID then
			return candidateTeamID
		end
	end
end

local function GetEnemyTeam(mercTeamID)
	local mercAllyTeam = select(6, Spring.GetTeamInfo(mercTeamID, false))

	for _, teamID in ipairs(Spring.GetTeamList()) do
		if teamID ~= mercTeamID and teamID ~= GAIA_TEAM_ID then
			local allyTeam = select(6, Spring.GetTeamInfo(teamID, false))
			if allyTeam ~= mercAllyTeam then
				return teamID
			end
		end
	end

	return GAIA_TEAM_ID
end

local function FilterPlayerArea(candidates, mercTeamID)
	local x, _, z = Spring.GetTeamStartPosition(mercTeamID)
	if not x or x < 0 or not z or z < 0 then
		x = Game.mapSizeX * 0.5
		z = Game.mapSizeZ * 0.5
	end

	local filtered = {}
	local exclusionSquared = defs.playerExclusionRadius * defs.playerExclusionRadius

	for i = 1, #candidates do
		local site = candidates[i]
		if DistanceSquared(site.x, site.z, x, z) >= exclusionSquared then
			filtered[#filtered + 1] = site
		end
	end

	return filtered, x, z
end

local function SelectSites(candidates, playerX, playerZ)
	table.sort(candidates, function(a, b)
		return DistanceSquared(a.x, a.z, playerX, playerZ) > DistanceSquared(b.x, b.z, playerX, playerZ)
	end)

	local selected = {}
	local spacingSquared = defs.minimumBaseSpacing * defs.minimumBaseSpacing
	local wanted = math.min(defs.baseCountMax, #candidates)

	for i = 1, #candidates do
		local candidate = candidates[i]
		local clear = true

		for j = 1, #selected do
			if DistanceSquared(candidate.x, candidate.z, selected[j].x, selected[j].z) < spacingSquared then
				clear = false
				break
			end
		end

		if clear then
			selected[#selected + 1] = candidate
			if #selected >= wanted then
				break
			end
		end
	end

	return selected
end

local function SpawnUnit(unitName, x, z, facing, teamID)
	local def = UnitDefNames[unitName]
	if not def then
		Spring.Echo("[MCM Expedition] Missing UnitDef:", unitName)
		return
	end

	local y = Spring.GetGroundHeight(x, z)
	return Spring.CreateUnit(def.id, x, y, z, facing or 0, teamID)
end

local function SpawnBase(site, baseNumber, teamID)
	local base = {
		id = baseNumber,
		x = site.x,
		z = site.z,
		source = site.source,
		teamID = teamID,
		units = {},
	}

	local centerID = SpawnUnit(defs.baseStructure, site.x, site.z, 0, teamID)
	if centerID then
		base.units[#base.units + 1] = centerID
		Spring.SetUnitRulesParam(centerID, "mcm_expedition_base", baseNumber, {public = true})
	end

	-- Give each prototype base a small functional-looking building cluster.
	-- These are Mercs-owned shells; their eventual contract interactions are
	-- intentionally not implemented here.
	local buildingCount = math.min(3, #defs.buildings)
	for i = 1, buildingCount do
		local angle = (i - 1) * math.pi * 2 / buildingCount + math.pi / 3
		local x = site.x + math.sin(angle) * 125
		local z = site.z + math.cos(angle) * 125
		local buildingName = defs.buildings[((baseNumber + i - 2) % #defs.buildings) + 1]
		if x > 0 and x < Game.mapSizeX and z > 0 and z < Game.mapSizeZ and Spring.GetGroundHeight(x, z) >= 0 then
			local buildingID = SpawnUnit(buildingName, x, z, i - 1, teamID)
			if buildingID then
				base.units[#base.units + 1] = buildingID
				Spring.SetUnitRulesParam(buildingID, "mcm_expedition_base", baseNumber, {public = true})
			end
		end
	end

	local turretCount = #defs.turrets
	for i = 1, turretCount do
		local angle = (i - 1) * math.pi * 2 / turretCount
		local x = site.x + math.sin(angle) * defs.turretRadius
		local z = site.z + math.cos(angle) * defs.turretRadius
		if x > 0 and x < Game.mapSizeX and z > 0 and z < Game.mapSizeZ and Spring.GetGroundHeight(x, z) >= 0 then
			local turretID = SpawnUnit(defs.turrets[i], x, z, i - 1, teamID)
			if turretID then
				base.units[#base.units + 1] = turretID
				Spring.SetUnitRulesParam(turretID, "mcm_expedition_base", baseNumber, {public = true})
			end
		end
	end

	GG.MCMExpeditionBases[baseNumber] = base
	Spring.Echo("[MCM Expedition] Base", baseNumber, "spawned at", math.floor(site.x), math.floor(site.z), "from", site.source)
end

function gadget:GameFrame(frame)
	if frame ~= 10 then
		return
	end

	local mercTeamID = GetMercTeam()
	if not mercTeamID then
		Spring.Echo("[MCM Expedition] No Merc team available; base generation skipped.")
		gadgetHandler:RemoveGadget(self)
		return
	end

	local candidates = LoadCandidates()
	local filtered, playerX, playerZ = FilterPlayerArea(candidates, mercTeamID)
	local selected = SelectSites(filtered, playerX, playerZ)
	local enemyTeamID = GetEnemyTeam(mercTeamID)

	for i = 1, #selected do
		SpawnBase(selected[i], i, enemyTeamID)
	end

	Spring.SetGameRulesParam("mcm_expedition_base_count", #selected, {public = true})
	Spring.SetGameRulesParam("mcm_contract_active", 1, {public = true})

	if #selected < defs.baseCountMin then
		Spring.Echo("[MCM Expedition] WARNING: only", #selected, "suitable authored base sites were available.")
	else
		Spring.Echo("[MCM Expedition] Generated", #selected, "prototype bases.")
	end

	gadgetHandler:RemoveGadget(self)
end
