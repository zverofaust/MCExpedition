--------------------------------------------------------------------------------
-- MechCommander: Mercs - Expedition battlefield generation
--
-- Selects authored map locations, classifies them by strategic depth from the
-- Merc insertion point, and generates weighted military installations.
--
-- The selected-site representation is deliberately broader than "base": future
-- passes may reserve sites for patrols, salvage scenes, wrecks, ambushes and
-- other non-established points of interest without replacing this framework.
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
local campTemplates = VFS.Include("LuaRules/Configs/camp_configs.lua")
local CAMP_DECAL_ACTION = "mcl_camp_template_decal"
local TWO_PI = math.pi * 2
local GAIA_TEAM_ID = Spring.GetGaiaTeamID()
local sideData = VFS.Include("gamedata/sidedata.lua")

GG.MCMExpeditionSites = GG.MCMExpeditionSites or {}
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

			-- Camps are reserved for future transient encounters and minor POIs.
			-- Established garrison bases use only authored Beacon/resource sites
			-- and map start positions.
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

local function GetSideDefinition(shortName)
	for i = 1, #sideData do
		if sideData[i].shortName == shortName then
			return sideData[i]
		end
	end
end

local function AssignEnemyFaction(teamID)
	local faction = defs.enemyFactions[math.random(#defs.enemyFactions)]
	local side = GetSideDefinition(faction)
	local texmod = side and side.texmods and side.texmods[1] or "Team"

	Spring.SetGameRulesParam("mcm_enemy_team", teamID, {public = true})
	Spring.SetGameRulesParam("mcm_enemy_faction", faction, {public = true})
	Spring.SetTeamRulesParam(teamID, "side", faction:lower(), {public = true})
	Spring.SetTeamRulesParam(teamID, "mcm_faction", faction:lower(), {public = true})
	Spring.SetTeamRulesParam(teamID, "mcl_texmod", texmod, {public = true})

	return faction, texmod
end

local function PrepareCandidates(candidates, mercTeamID)
	local playerX, _, playerZ = Spring.GetTeamStartPosition(mercTeamID)
	if not playerX or playerX < 0 or not playerZ or playerZ < 0 then
		playerX = Game.mapSizeX * 0.5
		playerZ = Game.mapSizeZ * 0.5
	end

	local filtered = {}
	local exclusionSquared = defs.playerExclusionRadius * defs.playerExclusionRadius
	local farthest = 0

	for i = 1, #candidates do
		local candidate = candidates[i]
		local distanceSquared = DistanceSquared(candidate.x, candidate.z, playerX, playerZ)
		if distanceSquared >= exclusionSquared then
			candidate.distance = math.sqrt(distanceSquared)
			filtered[#filtered + 1] = candidate
			farthest = math.max(farthest, candidate.distance)
		end
	end

	for i = 1, #filtered do
		local normalized = farthest > 0 and filtered[i].distance / farthest or 0
		filtered[i].depth = normalized
		if normalized <= defs.distanceBands.near then
			filtered[i].band = "near"
		elseif normalized <= defs.distanceBands.operational then
			filtered[i].band = "operational"
		else
			filtered[i].band = "deep"
		end
	end

	return filtered
end

local function WeightedPick(weights, source)
	local total = 0
	local sourceWeights = source and defs.sourceWeights[source]
	for key, weight in pairs(weights) do
		total = total + weight * (sourceWeights and sourceWeights[key] or 1)
	end
	if total <= 0 then
		return
	end

	local roll = math.random() * total
	for key, weight in pairs(weights) do
		roll = roll - weight * (sourceWeights and sourceWeights[key] or 1)
		if roll <= 0 then
			return key
		end
	end
end

local function Shuffle(list)
	for i = #list, 2, -1 do
		local j = math.random(i)
		list[i], list[j] = list[j], list[i]
	end
end

local function SiteIsClear(candidate, selected, spacing)
	local spacingSquared = spacing * spacing
	for i = 1, #selected do
		if DistanceSquared(candidate.x, candidate.z, selected[i].x, selected[i].z) < spacingSquared then
			return false
		end
	end
	return true
end

local function SelectBandSites(candidates, band, count, selected)
	local pool = {}
	for i = 1, #candidates do
		if candidates[i].band == band then
			pool[#pool + 1] = candidates[i]
		end
	end
	Shuffle(pool)

	local added = 0
	for i = 1, #pool do
		if SiteIsClear(pool[i], selected, defs.minimumBaseSpacing) then
			local site = pool[i]
			site.kind = "base"
			site.archetype = WeightedPick(defs.archetypeWeights[band], site.source)
			site.strength = WeightedPick(defs.strengthWeights[band])
			selected[#selected + 1] = site
			added = added + 1
			if added >= count then
				break
			end
		end
	end

	return added
end

local function SelectSites(candidates)
	local selected = {}

	for _, band in ipairs({"near", "operational", "deep"}) do
		local target = defs.baseTargets[band]
		local count = math.random(target.min, target.max)
		SelectBandSites(candidates, band, count, selected)
	end

	-- A small map or unusual authored layout may not contain enough candidates
	-- in a requested band. Fill missing minimum slots from any remaining site,
	-- while preserving the global base-spacing rule.
	local minimum = defs.baseTargets.near.min + defs.baseTargets.operational.min + defs.baseTargets.deep.min
	if #selected < minimum then
		local remaining = {}
		for i = 1, #candidates do
			local used = false
			for j = 1, #selected do
				if candidates[i] == selected[j] then
					used = true
					break
				end
			end
			if not used then
				remaining[#remaining + 1] = candidates[i]
			end
		end
		Shuffle(remaining)

		for i = 1, #remaining do
			local site = remaining[i]
			if SiteIsClear(site, selected, defs.minimumBaseSpacing) then
				site.kind = "base"
				site.archetype = WeightedPick(defs.archetypeWeights[site.band], site.source)
				site.strength = WeightedPick(defs.strengthWeights[site.band])
				selected[#selected + 1] = site
				if #selected >= minimum then
					break
				end
			end
		end
	end

	return selected
end

local function GetLanceForceLevel(mercTeamID)
	local tonnage = 0
	local units = Spring.GetTeamUnits(mercTeamID) or {}
	for i = 1, #units do
		local unitID = units[i]
		if Spring.GetUnitRulesParam(unitID, "mcm_lance") == 1 then
			local unitDef = UnitDefs[Spring.GetUnitDefID(unitID)]
			local unitTonnage = unitDef and unitDef.customParams and tonumber(unitDef.customParams.tonnage)
			tonnage = tonnage + (unitTonnage or 0)
		end
	end

	local level = 4
	if tonnage < 100 then
		level = 1
	elseif tonnage < 200 then
		level = 2
	elseif tonnage < 300 then
		level = 3
	end

	Spring.SetGameRulesParam("mcm_lance_tonnage", tonnage, {public = true})
	Spring.SetGameRulesParam("mcm_force_level", level, {public = true})
	return level, tonnage
end

local function BuildVehiclePools(faction)
	local pools = {}
	local vehicleDefs = defs.vehicleForces
	for className, folder in pairs(vehicleDefs.folders) do
		local pool = {}
		local files = VFS.DirList(folder, "*.lua") or {}
		for i = 1, #files do
			local chassis = files[i]:match("([^/\\]+)%.lua$")
			local unitDef = chassis and UnitDefNames[(faction .. "_" .. chassis):lower()]
			if unitDef and unitDef.customParams and unitDef.customParams.baseclass == "vehicle"
				and not unitDef.customParams.support then
				pool[#pool + 1] = unitDef.name
			end
		end
		pools[className] = pool
	end
	return pools
end

local function PickVehicleClass(profile, pools, budget, assaultCount, forceLevel)
	local eligible = {}
	local total = 0
	local levelWeights = defs.vehicleForces.forceLevelWeights[forceLevel] or defs.vehicleForces.forceLevelWeights[1]
	for className, weight in pairs(profile.weights) do
		weight = weight * (levelWeights[className] or 0)
		local cost = defs.vehicleForces.classCost[className]
		local pool = pools[className]
		if cost and cost <= budget and pool and #pool > 0
			and (className ~= "assault" or assaultCount < defs.vehicleForces.maxAssault) then
			eligible[className] = weight
			total = total + weight
		end
	end
	if total <= 0 then
		return
	end
	local roll = math.random() * total
	for className, weight in pairs(eligible) do
		roll = roll - weight
		if roll <= 0 then
			return className
		end
	end
end

local function SelectVehicleForce(strengthName, pools, forceLevel)
	local profile = defs.vehicleForces[strengthName]
	if not profile then
		return {}
	end
	local force = {}
	local budget = math.random(profile.budget.min, profile.budget.max)
	local assaultCount = 0
	while budget > 0 do
		local className = PickVehicleClass(profile, pools, budget, assaultCount, forceLevel)
		if not className then
			break
		end
		local pool = pools[className]
		force[#force + 1] = {
			name = pool[math.random(#pool)],
			class = className,
		}
		budget = budget - defs.vehicleForces.classCost[className]
		if className == "assault" then
			assaultCount = assaultCount + 1
		end
	end
	return force
end

local function DegreesToRadians(degrees)
	return (tonumber(degrees) or 0) * math.pi / 180
end

local function PickBaseTemplate(buildingCount)
	local eligible = {}
	for name, template in pairs(campTemplates) do
		if type(template) == "table" and type(template.sockets) == "table" and #template.sockets >= buildingCount then
			eligible[#eligible + 1] = name
		end
	end
	if #eligible == 0 then
		return
	end
	table.sort(eligible)
	local name = eligible[math.random(#eligible)]
	return name, campTemplates[name]
end

local function TransformSocket(site, socket, rotation)
	local cosRotation = math.cos(rotation)
	local sinRotation = math.sin(rotation)
	local x = site.x + socket.x * cosRotation - socket.z * sinRotation
	local z = site.z + socket.x * sinRotation + socket.z * cosRotation
	local facingRadians = (rotation + DegreesToRadians(socket.facing)) % TWO_PI
	local facing = math.floor(facingRadians / (math.pi * 0.5) + 0.5) % 4
	return x, z, facing
end

local function SendBaseDecal(site, templateName, template, rotation)
	local tint = template.tint or {0.5, 0.5, 0.5, 0.5}
	SendToUnsynced(
		CAMP_DECAL_ACTION,
		templateName,
		site.x,
		site.z,
		template.width * 0.5,
		template.height * 0.5,
		rotation,
		tonumber(tint[1]) or 0.5,
		tonumber(tint[2]) or 0.5,
		tonumber(tint[3]) or 0.5,
		tonumber(tint[4]) or 0.5,
		tonumber(template.alpha) or 0.72
	)
end

local function SpawnUnit(unitName, x, z, facing, teamID)
	local def = UnitDefNames[unitName]
	if not def then
		Spring.Echo("[MCM Expedition] Missing UnitDef:", unitName)
		return
	end

	return Spring.CreateUnit(def.id, x, Spring.GetGroundHeight(x, z), z, facing or 0, teamID)
end

local function RegisterBaseUnit(base, unitID)
	if unitID then
		base.units[#base.units + 1] = unitID
		Spring.SetUnitRulesParam(unitID, "mcm_expedition_base", base.id, {public = true})
		Spring.SetUnitRulesParam(unitID, "mcm_expedition_strength", base.strength, {public = true})
	end
end

local function SpawnBase(site, baseNumber, teamID)
	local archetype = defs.archetypes[site.archetype]
	local strength = defs.strength[site.strength]
	if not archetype or not strength then
		Spring.Echo("[MCM Expedition] Invalid base definition:", site.archetype, site.strength)
		return
	end

	local buildingCount = 1 + math.min(strength.support, #archetype.support)
	local templateName, template = PickBaseTemplate(buildingCount)
	if not template then
		Spring.Echo("[MCM Expedition] No camp template has", buildingCount, "building sockets.")
		return
	end

	local rotation = math.random() * TWO_PI
	local sockets = {}
	for i = 1, #template.sockets do
		sockets[i] = template.sockets[i]
	end
	Shuffle(sockets)

	local base = {
		id = baseNumber,
		kind = "base",
		x = site.x,
		z = site.z,
		source = site.source,
		band = site.band,
		archetype = site.archetype,
		strength = site.strength,
		template = templateName,
		rotation = rotation,
		teamID = teamID,
		faction = Spring.GetGameRulesParam("mcm_enemy_faction"),
		units = {},
	}

	local buildings = {archetype.core}
	local supportOffset = math.random(#archetype.support)
	for i = 1, buildingCount - 1 do
		buildings[#buildings + 1] = archetype.support[((i + supportOffset - 2) % #archetype.support) + 1]
	end

	local createdBuildings = 0
	for i = 1, #buildings do
		local x, z, facing = TransformSocket(site, sockets[i], rotation)
		if x > 0 and x < Game.mapSizeX and z > 0 and z < Game.mapSizeZ and Spring.GetGroundHeight(x, z) >= 0 then
			local unitID = SpawnUnit(buildings[i], x, z, facing, teamID)
			if unitID then
				RegisterBaseUnit(base, unitID)
				createdBuildings = createdBuildings + 1
			end
		end
	end

	if createdBuildings > 0 then
		SendBaseDecal(site, templateName, template, rotation)
	end

	local turretCount = math.min(strength.turrets, #defs.turrets)
	local turretOffset = math.random(#defs.turrets)
	for i = 1, turretCount do
		local turretName = defs.turrets[((i + turretOffset - 2) % #defs.turrets) + 1]
		if not turretName:find("^mcm_garrison_turret_") then
			Spring.Echo("[MCM Expedition] Refusing non-Mercs turret UnitDef:", turretName)
		else
			local angle = rotation + (i - 1) * math.pi * 2 / math.max(turretCount, 1)
			local radius = math.max(strength.turretRadius, (template.dressingExclusionRadius or 0) + 40)
			local x = site.x + math.sin(angle) * radius
			local z = site.z + math.cos(angle) * radius
			if x > 0 and x < Game.mapSizeX and z > 0 and z < Game.mapSizeZ and Spring.GetGroundHeight(x, z) >= 0 then
				RegisterBaseUnit(base, SpawnUnit(turretName, x, z, i - 1, teamID))
			end
		end
	end

	local vehicleForce = SelectVehicleForce(site.strength, BuildVehiclePools(base.faction), Spring.GetGameRulesParam("mcm_force_level") or 1)
	local vehicleRadius = math.max(defs.vehicleForces.spawnRadius, strength.turretRadius + 85)
	for i = 1, #vehicleForce do
		local angle = rotation + (i - 1) * TWO_PI / math.max(#vehicleForce, 1)
		local radius = vehicleRadius + ((i % 2) * defs.vehicleForces.spawnSpacing)
		local x = site.x + math.sin(angle) * radius
		local z = site.z + math.cos(angle) * radius
		if x > 0 and x < Game.mapSizeX and z > 0 and z < Game.mapSizeZ and Spring.GetGroundHeight(x, z) >= 0 then
			local unitID = SpawnUnit(vehicleForce[i].name, x, z, math.floor((angle % TWO_PI) / (math.pi * 0.5) + 0.5) % 4, teamID)
			if unitID then
				RegisterBaseUnit(base, unitID)
				Spring.SetUnitRulesParam(unitID, "mcm_garrison_vehicle", 1, {public = true})
				Spring.SetUnitRulesParam(unitID, "mcm_vehicle_class", vehicleForce[i].class, {public = true})
			end
		end
	end

	GG.MCMExpeditionBases[baseNumber] = base
	GG.MCMExpeditionSites[#GG.MCMExpeditionSites + 1] = base
	Spring.Echo("[MCM Expedition] Base", baseNumber, archetype.name, "(" .. site.strength .. ")", "[" .. site.band .. "]", "template", templateName, "at", math.floor(site.x), math.floor(site.z), "from", site.source)
end

function gadget:GameFrame(frame)
	if frame ~= 10 then
		return
	end

	local mercTeamID = GetMercTeam()
	if not mercTeamID then
		Spring.Echo("[MCM Expedition] No Merc team available; battlefield generation skipped.")
		gadgetHandler:RemoveGadget(self)
		return
	end

	local forceLevel, lanceTonnage = GetLanceForceLevel(mercTeamID)
	local candidates = PrepareCandidates(LoadCandidates(), mercTeamID)
	local selected = SelectSites(candidates)
	local enemyTeamID = GetEnemyTeam(mercTeamID)
	local enemyFaction, enemyTexmod = AssignEnemyFaction(enemyTeamID)

	for i = 1, #selected do
		SpawnBase(selected[i], i, enemyTeamID)
	end

	Spring.SetGameRulesParam("mcm_expedition_base_count", #selected, {public = true})
	Spring.SetGameRulesParam("mcm_contract_active", 1, {public = true})

	Spring.Echo("[MCM Expedition] Merc Lance:", lanceTonnage .. "t", "force level", forceLevel)
	Spring.Echo("[MCM Expedition] Enemy force:", enemyFaction, "using", enemyTexmod, "paint scheme.")
	Spring.Echo("[MCM Expedition] Generated", #selected, "strategic bases from", #candidates, "usable authored sites.")
	gadgetHandler:RemoveGadget(self)
end
