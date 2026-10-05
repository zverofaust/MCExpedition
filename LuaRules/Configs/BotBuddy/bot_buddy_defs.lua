--------------------------------------------------------------------------------
-- MCL Bot Buddy configuration - revision 4
--------------------------------------------------------------------------------

local defs = {
	REVISION = 4,

	-- Multiplayer/startscript option. The root modoptions.lua entry can be added
	-- separately; until then the system deliberately defaults to shadow mode.
	MODOPTION_KEY = "botbuddies",
	DEFAULT_MODE = "shadow",
	VALID_MODES = {
		off = true,
		shadow = true,
	},

	ELIMINATION_CHECK_FRAMES = 30,

	RECONSTRUCTION = {
		-- Quiet period after the most recent structure loss. Every additional loss
		-- resets this timer, giving attackers time to destroy the whole local base
		-- before the Bot Buddy begins replacing components.
		DELAY_FRAMES = 150, -- 5 seconds at 30 sim frames/sec
	},

	-- Placement/reconstruction prototype. This is intentionally a normal existing MCL unit,
	-- not a permanent Bot Buddy structure definition.
	TEST_STRUCTURE_NAME = "wall",
	TEST_STRUCTURE_COUNT = 3,
	PLACEMENT = {
		-- The exact Beacon centre remains clear for Dropship activity.
		CENTRAL_RESERVED_RADIUS = 180,

		-- Search begins just outside the reserved centre and expands only as needed.
		FIRST_SEARCH_RADIUS = 220,
		RING_STEP = 80,
		RING_COUNT = 12,
		CANDIDATES_PER_RING = 24,

		-- Pure implementation safety bound, not a gameplay base-radius rule.
		MAX_SEARCH_RADIUS = 1100,

		-- Extra open ground around the structure so early base layouts do not pack
		-- buildings tightly enough to choke vehicle movement.
		CLEARANCE = 72,
		MAP_EDGE_MARGIN = 96,

		-- Wall.lua itself accepts extremely steep ground (maxSlope = 100), so the
		-- Bot Buddy applies a much more conservative terrain-flatness test.
		TERRAIN_SAMPLE_PADDING = 24,
		MAX_TERRAIN_HEIGHT_DELTA = 18,
		MIN_GROUND_ABOVE_WATER = 2,

		-- Spring.TestBuildOrder maps a truly OPEN build square to return value 2
		-- for legacy compatibility. A reclaimable obstruction also returns 2 but
		-- supplies a featureID, which the placement module rejects separately.
		OPEN_BUILD_STATUS = 2,
		BUILD_FACING = 0,

		-- Failed bases retry occasionally so temporary mobile-unit obstruction does
		-- not permanently prevent placement.
		PLACEMENT_UPDATE_FRAMES = 15,
		RETRY_FRAMES = 90,

		-- Terrain roughness is deliberately secondary to distance from the Beacon.
		ROUGHNESS_SCORE_MULT = 8,
	},

	DEBUG = true,
}

return defs
