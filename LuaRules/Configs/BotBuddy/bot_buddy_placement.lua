--------------------------------------------------------------------------------
-- MCL Bot Buddy terrain-aware placement helper - revision 2
--
-- Finds a legal, reasonably flat, dry, uncluttered build position near a
-- Beacon. This module has no knowledge of Bot Buddy progression or economy.
--------------------------------------------------------------------------------

local placement = {}

local abs                  = math.abs
local cos                  = math.cos
local max                  = math.max
local min                  = math.min
local pi                   = math.pi
local sin                  = math.sin
local sqrt                 = math.sqrt

local GetFeaturesInRectangle = Spring.GetFeaturesInRectangle
local GetGroundHeight        = Spring.GetGroundHeight
local GetUnitPosition        = Spring.GetUnitPosition
local GetUnitsInRectangle    = Spring.GetUnitsInRectangle
local GetWaterPlaneLevel     = Spring.GetWaterPlaneLevel
local Pos2BuildPos           = Spring.Pos2BuildPos
local TestBuildOrder         = Spring.TestBuildOrder

local MAP_SIZE_X = Game.mapSizeX
local MAP_SIZE_Z = Game.mapSizeZ
local TWO_PI = 2 * pi

local function Distance2D(x1, z1, x2, z2)
	local dx = x2 - x1
	local dz = z2 - z1
	return sqrt(dx * dx + dz * dz)
end

local function GetFootprintHalfExtents(unitDefID, facing)
	local ud = UnitDefs[unitDefID]
	if not ud then
		return nil, nil
	end

	-- UnitDef xsize/zsize are in 8-elmo map squares. Rotate rectangular
	-- footprints for east/west facings.
	local xsize = ud.xsize or 1
	local zsize = ud.zsize or 1
	if facing == 1 or facing == 3 then
		xsize, zsize = zsize, xsize
	end

	return xsize * 4, zsize * 4
end

local function IsInsideMap(x, z, halfX, halfZ, cfg)
	local marginX = halfX + cfg.MAP_EDGE_MARGIN
	local marginZ = halfZ + cfg.MAP_EDGE_MARGIN
	return x >= marginX and z >= marginZ
		and x <= (MAP_SIZE_X - marginX)
		and z <= (MAP_SIZE_Z - marginZ)
end

local function SampleTerrain(x, z, halfX, halfZ, cfg)
	local sx = halfX + cfg.TERRAIN_SAMPLE_PADDING
	local sz = halfZ + cfg.TERRAIN_SAMPLE_PADDING
	local samples = {
		{x,      z},
		{x - sx, z},
		{x + sx, z},
		{x,      z - sz},
		{x,      z + sz},
		{x - sx, z - sz},
		{x + sx, z - sz},
		{x - sx, z + sz},
		{x + sx, z + sz},
	}

	local minHeight = math.huge
	local maxHeight = -math.huge
	for i = 1, #samples do
		local h = GetGroundHeight(samples[i][1], samples[i][2])
		if not h then
			return nil
		end
		minHeight = min(minHeight, h)
		maxHeight = max(maxHeight, h)
	end

	return maxHeight - minHeight, GetGroundHeight(x, z)
end

local function HasClearance(x, z, halfX, halfZ, beaconID, cfg)
	local x1 = x - halfX - cfg.CLEARANCE
	local z1 = z - halfZ - cfg.CLEARANCE
	local x2 = x + halfX + cfg.CLEARANCE
	local z2 = z + halfZ + cfg.CLEARANCE

	local units = GetUnitsInRectangle(x1, z1, x2, z2) or {}
	for i = 1, #units do
		if units[i] ~= beaconID then
			return false, "unit_clearance"
		end
	end

	local features = GetFeaturesInRectangle(x1, z1, x2, z2) or {}
	if #features > 0 then
		return false, "feature_clearance"
	end

	return true
end

local function EvaluateCandidate(beaconID, beaconX, beaconZ, unitDefID, rawX, rawZ, cfg)
	local facing = cfg.BUILD_FACING
	local rawY = GetGroundHeight(rawX, rawZ)
	local x, y, z = Pos2BuildPos(unitDefID, rawX, rawY, rawZ, facing)
	if not x or not y or not z then
		return nil, "snap"
	end

	local halfX, halfZ = GetFootprintHalfExtents(unitDefID, facing)
	if not halfX then
		return nil, "unitdef"
	end

	if not IsInsideMap(x, z, halfX, halfZ, cfg) then
		return nil, "map_edge"
	end

	local distance = Distance2D(beaconX, beaconZ, x, z)
	local structureRadius = sqrt(halfX * halfX + halfZ * halfZ)
	if distance < cfg.CENTRAL_RESERVED_RADIUS + structureRadius then
		return nil, "central_reserve"
	end
	if distance > cfg.MAX_SEARCH_RADIUS then
		return nil, "search_limit"
	end

	local terrainDelta, groundY = SampleTerrain(x, z, halfX, halfZ, cfg)
	if not terrainDelta or terrainDelta > cfg.MAX_TERRAIN_HEIGHT_DELTA then
		return nil, "terrain"
	end

	local waterLevel = GetWaterPlaneLevel and GetWaterPlaneLevel() or 0
	if groundY <= waterLevel + cfg.MIN_GROUND_ABOVE_WATER then
		return nil, "water"
	end

	local clear, clearReason = HasClearance(x, z, halfX, halfZ, beaconID, cfg)
	if not clear then
		return nil, clearReason
	end

	local buildStatus, blockingFeatureID = TestBuildOrder(unitDefID, x, y, z, facing)
	if buildStatus ~= cfg.OPEN_BUILD_STATUS or blockingFeatureID then
		return nil, "build_order"
	end

	return {
		x = x,
		y = y,
		z = z,
		facing = facing,
		distance = distance,
		terrainDelta = terrainDelta,
		score = distance + terrainDelta * cfg.ROUGHNESS_SCORE_MULT,
	}
end

function placement.FindBuildPosition(beaconID, unitDefID, cfg, placementIndex)
	local beaconX, _, beaconZ = GetUnitPosition(beaconID)
	if not beaconX or not beaconZ then
		return nil, {invalidBeacon = 1, tested = 0, valid = 0}
	end

	local stats = {
		tested = 0,
		valid = 0,
		rejected = {},
	}
	local best

	-- Derive the search phase from the Beacon's world position as well as its ID.
	-- Using position avoids multiple bases developing the same relative layout
	-- merely because their unitIDs happen to produce similar phases. The optional
	-- placementIndex deliberately rotates successive structures around one base.
	placementIndex = placementIndex or 1
	local bx = math.floor(beaconX / 16)
	local bz = math.floor(beaconZ / 16)
	local hash = (bx * 73856093 + bz * 19349663 + beaconID * 83492791) % 1000003
	local basePhase = (hash / 1000003) * TWO_PI
	local structurePhase = ((placementIndex - 1) * 0.3819660112501051 % 1) * TWO_PI
	local angularOffset = basePhase + structurePhase

	for ring = 1, cfg.RING_COUNT do
		local radius = cfg.FIRST_SEARCH_RADIUS + (ring - 1) * cfg.RING_STEP
		if radius > cfg.MAX_SEARCH_RADIUS then
			break
		end

		for candidate = 1, cfg.CANDIDATES_PER_RING do
			local angle = angularOffset + (candidate - 1) * TWO_PI / cfg.CANDIDATES_PER_RING
			local rawX = beaconX + cos(angle) * radius
			local rawZ = beaconZ + sin(angle) * radius
			stats.tested = stats.tested + 1

			local result, reason = EvaluateCandidate(
				beaconID,
				beaconX,
				beaconZ,
				unitDefID,
				rawX,
				rawZ,
				cfg
			)

			if result then
				stats.valid = stats.valid + 1
				if not best or result.score < best.score then
					best = result
				end
			else
				stats.rejected[reason or "unknown"] = (stats.rejected[reason or "unknown"] or 0) + 1
			end
		end
	end

	return best, stats
end

return placement
