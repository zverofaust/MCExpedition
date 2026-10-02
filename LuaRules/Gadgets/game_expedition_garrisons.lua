--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  Expedition Garrisons
--
--  First playable prototype:
--      * Runs only in Expedition mode.
--      * Selects one non-Mercenary enemy faction for the expedition.
--      * Builds a common garrison-candidate pool from suitable Beacons,
--        non-player start positions, and authored camp positions.
--      * Claims up to three sites and instantiates a camp template at each.
--      * Populates template sockets with 2-3 real outposts plus civilian
--        building Features.
--      * Adds a small faction/tech-base-correct vehicle detachment and light
--        turret perimeter.
--      * Leaves unclaimed authored camps to map_metal_ruins unchanged.
--
--  Author: zvero + ChatGPT
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:GetInfo()
	return {
		name      = "Expedition Garrisons",
		desc      = "Creates prototype hostile garrisons for Expedition mode",
		author    = "zvero + ChatGPT",
		date      = "01/10/26",
		license   = "GNU GPL v2",
		layer     = -1,
		enabled   = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

local GARRISON_COUNT = 3
local GARRISON_VEHICLES = 3
local GARRISON_TURRETS = 2
local CANDIDATE_MERGE_DISTANCE = 300
local PLAYER_START_EXCLUSION = 700
local CAMP_CONFIG_PATH = "LuaRules/Configs/camp_configs.lua"
local PROFILE_PATH = "maps/flagConfig/" .. Game.mapName .. "_profile.lua"
local TWO_PI = math.pi * 2
local GARRISON_PING_INTERVAL = 90
local GARRISON_PING_COUNT = 4

local templates = VFS.Include(CAMP_CONFIG_PATH, nil, VFS.GAME) or {}
local templateNames = {}
local buildingFeatures = {}
local vehiclePools = {light = {}, medium = {}, heavy = {}, assault = {}}
local turretPool = {}
local outpostPool = {}
local selectedSites = {}
local selected = false
local spawned = false
local firstPingFrame
local pingsSent = 0
local enemyTeamID
local garrisonVehicles = {}
local enemySide
local enemyTechBase

for name, template in pairs(templates) do
	if type(name) == "string" and type(template) == "table" and type(template.sockets) == "table" and #template.sockets > 0 then
		templateNames[#templateNames + 1] = name
	end
end

table.sort(templateNames)

local function Debug(...)
	Spring.Echo("[Expedition Garrisons]", ...)
end

local function ShuffleCopy(source)
	local copy = {}
	for i = 1, #source do
		copy[i] = source[i]
	end
	for i = #copy, 2, -1 do
		local j = math.random(1, i)
		copy[i], copy[j] = copy[j], copy[i]
	end
	return copy
end

local function DistanceSquared(ax, az, bx, bz)
	local dx = ax - bx
	local dz = az - bz
	return dx * dx + dz * dz
end

local function AddCandidate(candidates, candidate)
	if type(candidate.x) ~= "number" or type(candidate.z) ~= "number" then
		return
	end
	for i = 1, #candidates do
		if DistanceSquared(candidate.x, candidate.z, candidates[i].x, candidates[i].z) < CANDIDATE_MERGE_DISTANCE * CANDIDATE_MERGE_DISTANCE then
			return
		end
	end
	candidates[#candidates + 1] = candidate
end

local function FindPlayerAndEnemyTeams()
	local playerTeam
	for _, teamID in ipairs(Spring.GetTeamList()) do
		if teamID ~= Spring.GetGaiaTeamID() and GG.teamSide and GG.teamSide[teamID] == "mc" and #Spring.GetPlayerList(teamID, true) > 0 then
			playerTeam = teamID
			break
		end
	end
	if not playerTeam then
		return nil, nil
	end

	local _, _, _, _, _, playerAllyTeam = Spring.GetTeamInfo(playerTeam, false)
	for _, teamID in ipairs(Spring.GetTeamList()) do
		if teamID ~= Spring.GetGaiaTeamID() and teamID ~= playerTeam then
			local _, _, _, _, _, allyTeam = Spring.GetTeamInfo(teamID, false)
			if allyTeam ~= playerAllyTeam then
				return playerTeam, teamID
			end
		end
	end
	return playerTeam, nil
end

local function SelectEnemyFaction()
	local sides = VFS.Include("gamedata/sidedata.lua", nil, VFS.GAME) or {}
	local choices = {}
	for i = 1, #sides do
		local shortName = sides[i].shortName and string.lower(sides[i].shortName)
		if shortName and shortName ~= "mc" then
			choices[#choices + 1] = sides[i]
		end
	end
	if #choices == 0 then
		return false
	end

	local choice = choices[math.random(1, #choices)]
	enemySide = string.lower(choice.shortName)
	enemyTechBase = string.lower(choice.techBase or "is")
	GG.teamSide[enemyTeamID] = enemySide
	Spring.SetTeamRulesParam(enemyTeamID, "side", enemySide, {allied = true, public = false})
	Spring.SetGameRulesParam("EXPEDITION_ENEMY_SIDE", enemySide)
	Spring.SetGameRulesParam("EXPEDITION_ENEMY_TECHBASE", enemyTechBase)
	Debug("Enemy faction:", choice.name, "(" .. enemySide .. ")", "tech base:", enemyTechBase)
	return true
end

local function LoadProfile()
	if not VFS.FileExists(PROFILE_PATH) then
		Debug("No flagConfig profile found for", Game.mapName)
		return {}, {}, {}
	end
	local success, beacons, _, starts, camps = pcall(VFS.Include, PROFILE_PATH)
	if not success then
		Spring.Echo("[Expedition Garrisons] ERROR: Failed to load map profile:", PROFILE_PATH, beacons)
		return {}, {}, {}
	end
	return type(beacons) == "table" and beacons or {}, type(starts) == "table" and starts or {}, type(camps) == "table" and camps or {}
end

local function BuildCandidates(playerTeam)
	local beacons, starts, camps = LoadProfile()
	local candidates = {}
	local playerStart = GG.teamStarts and GG.teamStarts[playerTeam]
	local function AwayFromPlayerStart(x, z)
		return not playerStart or DistanceSquared(x, z, playerStart.x, playerStart.z) >= PLAYER_START_EXCLUSION * PLAYER_START_EXCLUSION
	end

	for i = 1, #camps do
		local camp = camps[i]
		if type(camp) == "table" and type(camp.x) == "number" and type(camp.z) == "number" and AwayFromPlayerStart(camp.x, camp.z) then
			AddCandidate(candidates, {
				x = camp.x,
				z = camp.z,
				source = "camp",
				sourceIndex = i,
				template = camp.template,
				rotation = camp.rotation,
				tint = camp.tint,
			})
		end
	end

	for _, start in pairs(starts) do
		if type(start) == "table" and type(start.x) == "number" and type(start.z) == "number" then
			if AwayFromPlayerStart(start.x, start.z) then
				AddCandidate(candidates, {x = start.x, z = start.z, source = "start"})
			end
		end
	end

	for i = 1, #beacons do
		local beacon = beacons[i]
		if type(beacon) == "table" and type(beacon.x) == "number" and type(beacon.z) == "number" and beacon.points ~= 0 and beacon.radius == nil and beacon.radiusmult == nil and AwayFromPlayerStart(beacon.x, beacon.z) then
			AddCandidate(candidates, {x = beacon.x, z = beacon.z, source = "beacon", sourceIndex = i})
		end
	end

	return candidates
end

local function ResolveSiteTemplate(site)
	local templateName = site.template
	if not templateName or not templates[templateName] then
		if #templateNames == 0 then return false end
		templateName = templateNames[math.random(1, #templateNames)]
	end
	local template = templates[templateName]
	local rotation = type(site.rotation) == "number" and site.rotation * math.pi / 180 or math.random() * TWO_PI
	local halfDiagonal = math.sqrt(template.width * template.width + template.height * template.height) * 0.5
	if site.x - halfDiagonal < 0 or site.x + halfDiagonal > Game.mapSizeX or site.z - halfDiagonal < 0 or site.z + halfDiagonal > Game.mapSizeZ then
		return false
	end
	site.templateName = templateName
	site.templateData = template
	site.rotationRadians = rotation
	site.dressingExclusionRadius = template.dressingExclusionRadius or halfDiagonal
	return true
end

local function SelectSites(playerTeam)
	local candidates = ShuffleCopy(BuildCandidates(playerTeam))
	GG.ExpeditionGarrisonCampClaims = {}
	GG.ExpeditionGarrisonSites = {}

	for i = 1, #candidates do
		if #selectedSites >= GARRISON_COUNT then break end
		local site = candidates[i]
		if ResolveSiteTemplate(site) then
			selectedSites[#selectedSites + 1] = site
			GG.ExpeditionGarrisonSites[#GG.ExpeditionGarrisonSites + 1] = site
			if site.source == "camp" then
				GG.ExpeditionGarrisonCampClaims[site.sourceIndex] = true
			end
		end
	end

	Debug("Selected", #selectedSites, "garrison sites from", #candidates, "eligible authored anchors.")
	for i = 1, #selectedSites do
		Debug("Garrison", i, selectedSites[i].source, "at", math.floor(selectedSites[i].x), math.floor(selectedSites[i].z), "template", selectedSites[i].templateName)
	end
end

local function DiscoverBuildingFeatures()
	local files = VFS.DirList("features/buildings/", "*.lua", VFS.GAME) or {}
	local added = {}
	for i = 1, #files do
		local ok, defs = pcall(VFS.Include, files[i], nil, VFS.GAME)
		if ok and type(defs) == "table" then
			for name, def in pairs(defs) do
				name = type(name) == "string" and string.lower(name)
				if name and type(def) == "table" and FeatureDefNames[name] and not added[name] then
					added[name] = true
					buildingFeatures[#buildingFeatures + 1] = name
				end
			end
		end
	end
	table.sort(buildingFeatures)
end

local function DiscoverVehiclePool()
	for unitDefID, ud in pairs(UnitDefs) do
		local cp = ud.customParams
		local defName = string.lower(ud.name or "")
		if cp and cp.baseclass == "vehicle" and defName:sub(1, 3) == enemySide .. "_" then
			local weight = string.lower(cp.weightclass or "")
			if vehiclePools[weight] then
				vehiclePools[weight][#vehiclePools[weight] + 1] = unitDefID
			end
		end
	end
	for _, weight in ipairs({"light", "medium", "heavy", "assault"}) do
		table.sort(vehiclePools[weight])
		Debug("Discovered", #vehiclePools[weight], weight, enemySide, enemyTechBase, "vehicles.")
	end
end

local function DiscoverStaticPools()
	for unitDefID, ud in pairs(UnitDefs) do
		local cp = ud.customParams
		local name = string.lower(ud.name or "")
		local defName = string.lower(ud.unitname or UnitDefs[unitDefID].name or "")
		if cp and cp.baseclass == "outpost" and not defName:find("dropzone", 1, true) then
			outpostPool[#outpostPool + 1] = unitDefID
		elseif cp and cp.baseclass == "turret" and defName:sub(1, 7) == "turret_" then
			turretPool[#turretPool + 1] = unitDefID
		end
	end
	table.sort(outpostPool)
	table.sort(turretPool)
	Debug("Discovered", #outpostPool, "outposts and", #turretPool, "light turrets.")
end

local function TransformSocket(site, socket)
	local cosR = math.cos(site.rotationRadians)
	local sinR = math.sin(site.rotationRadians)
	local x = site.x + socket.x * cosR - socket.z * sinR
	local z = site.z + socket.x * sinR + socket.z * cosR
	local facing = ((tonumber(socket.facing) or 0) * math.pi / 180 + site.rotationRadians) % TWO_PI
	local heading = math.floor(facing / TWO_PI * 65536 + 0.5) % 65536
	return x, z, heading
end

local function SpawnUnitAt(def, x, z, heading)
	if Spring.GetGroundHeight(x, z) < 0 then return nil end
	local defName = type(def) == "number" and UnitDefs[def] and UnitDefs[def].name or def
	if not defName then return nil end
	local unitID = Spring.CreateUnit(defName, x, Spring.GetGroundHeight(x, z), z, 0, enemyTeamID)
	if unitID and heading then
		Spring.SetUnitHeadingAndUpDir(unitID, heading, 0, 1, 0)
	end
	return unitID
end

local function SpawnCivilianBuilding(x, z, heading)
	if #buildingFeatures == 0 or Spring.GetGroundHeight(x, z) < 0 then return nil end
	return Spring.CreateFeature(buildingFeatures[math.random(1, #buildingFeatures)], x, Spring.GetGroundHeight(x, z), z, heading)
end

local function FindRingPosition(site, minimumRadius, maximumRadius)
	for attempt = 1, 24 do
		local angle = math.random() * TWO_PI
		local radius = minimumRadius + math.random() * (maximumRadius - minimumRadius)
		local x = site.x + math.cos(angle) * radius
		local z = site.z + math.sin(angle) * radius
		if x > 64 and x < Game.mapSizeX - 64 and z > 64 and z < Game.mapSizeZ - 64 and Spring.GetGroundHeight(x, z) >= 0 then
			return x, z, math.floor(((angle + math.pi) % TWO_PI) / TWO_PI * 65536 + 0.5) % 65536
		end
	end
end

local function PickVehicle()
	local roll = math.random(1, 100)
	local preferred = roll <= 45 and "light" or roll <= 90 and "medium" or "heavy"
	if #vehiclePools[preferred] > 0 then
		return vehiclePools[preferred][math.random(1, #vehiclePools[preferred])]
	end
	for _, weight in ipairs({"light", "medium", "heavy"}) do
		if #vehiclePools[weight] > 0 then
			return vehiclePools[weight][math.random(1, #vehiclePools[weight])]
		end
	end
end

local function SpawnGarrison(site, number)
	local sockets = ShuffleCopy(site.templateData.sockets)
	local outpostCount = math.min(#sockets, math.random(2, 3))
	local outpostsCreated = 0
	local civiliansCreated = 0
	local vehiclesCreated = 0
	local turretsCreated = 0

	for i = 1, #sockets do
		local x, z, heading = TransformSocket(site, sockets[i])
		if i <= outpostCount and #outpostPool > 0 then
			if SpawnUnitAt(outpostPool[math.random(1, #outpostPool)], x, z, heading) then outpostsCreated = outpostsCreated + 1 end
		else
			if SpawnCivilianBuilding(x, z, heading) then civiliansCreated = civiliansCreated + 1 end
		end
	end

	for i = 1, GARRISON_VEHICLES do
		local vehicle = PickVehicle()
		local x, z, heading = FindRingPosition(site, 170, 290)
		if vehicle and x then
			local vehicleID = SpawnUnitAt(vehicle, x, z, heading)
			if vehicleID then
				garrisonVehicles[vehicleID] = true
				Spring.SetUnitRulesParam(vehicleID, "expedition_garrison", 1, {public = false})
				vehiclesCreated = vehiclesCreated + 1
			end
		end
	end

	for i = 1, GARRISON_TURRETS do
		local x, z, heading = FindRingPosition(site, 290, 390)
		if x and #turretPool > 0 and SpawnUnitAt(turretPool[math.random(1, #turretPool)], x, z, heading) then turretsCreated = turretsCreated + 1 end
	end

	if GG.SendCampTemplateDecal then
		GG.SendCampTemplateDecal(site, site.templateName, site.templateData, site.rotationRadians)
	end

	Debug("Spawned garrison", number, "- outposts:", outpostsCreated, "civilian buildings:", civiliansCreated, "vehicles:", vehiclesCreated, "turrets:", turretsCreated)
end

function gadget:GameFrame(frame)
	if frame == 4 and not selected then
		selected = true
		local playerTeam
		playerTeam, enemyTeamID = FindPlayerAndEnemyTeams()
		if not playerTeam or not enemyTeamID then
			Debug("No usable player/enemy team pair found; garrisons disabled.")
			return
		end
		if not SelectEnemyFaction() then
			Debug("No enemy faction available; garrisons disabled.")
			return
		end
		SelectSites(playerTeam)
	elseif frame == 6 and selected and not spawned and enemyTeamID and enemySide then
		spawned = true
		DiscoverBuildingFeatures()
		DiscoverVehiclePool()
		DiscoverStaticPools()
		for i = 1, #selectedSites do
			SpawnGarrison(selectedSites[i], i)
		end
		firstPingFrame = frame + 2
	elseif spawned and firstPingFrame and pingsSent < GARRISON_PING_COUNT and frame >= firstPingFrame + pingsSent * GARRISON_PING_INTERVAL then
		pingsSent = pingsSent + 1
		for i = 1, #selectedSites do
			local site = selectedSites[i]
			Spring.SpawnCEG("expedition_garrison_ping", site.x, Spring.GetGroundHeight(site.x, site.z) + 4, site.z, 0, 1, 0)
		end
	end
end

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, playerID, synced, fromLua)
	if garrisonVehicles[unitID] and fromLua and (cmdID == CMD.MOVE or cmdID == CMD.FIGHT or cmdID == CMD.PATROL) then
		return false
	end
	return true
end

function gadget:UnitDestroyed(unitID)
	garrisonVehicles[unitID] = nil
end

function gadget:Initialize()
	if Spring.GetGameRulesParam("gamemode") ~= "expedition" then
		gadgetHandler:RemoveGadget(self)
	end
end
