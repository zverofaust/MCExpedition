--------------------------------------------------------------------------------
-- MechCommander: Mercs - Expedition generation definitions
--
-- Authored map sites are classified by strategic depth from the Merc insertion
-- point, then assigned a weighted installation archetype and strength.
-- The site framework is intentionally generic so future non-base POIs can share
-- the same candidate/spacing system without being treated as installations.
--
-- Authors: zvero + ChatGPT
--------------------------------------------------------------------------------

return {
	playerExclusionRadius = 1400,
	minimumSiteSpacing = 900,
	minimumBaseSpacing = 1200,

	-- Expedition opponents are limited to Inner Sphere successor-state forces.
	-- Mercenary Outfit and Clan factions are deliberately excluded.
	enemyFactions = {
		"FS",
		"LA",
		"DC",
		"CC",
		"FW",
	},

	-- Distance bands are fractions of the farthest usable authored site on the
	-- current map. This scales naturally between small and large battlefields.
	distanceBands = {
		near = 0.38,
		operational = 0.72,
	},

	baseTargets = {
		near = {min = 1, max = 2},
		operational = {min = 2, max = 3},
		deep = {min = 1, max = 1},
	},

	-- Encounters occupy otherwise-unused authored camps, Beacon/resource sites
	-- and starts. They contain only a small parked vehicle force: no structures,
	-- turrets, base decal or opening enemy-presence ping.
	encounterTargets = {min = 5, max = 10},
	encounterForces = {
		near = {
			count = {min = 3, max = 4},
			weights = {light = 75, medium = 25, heavy = 0, assault = 0},
		},
		operational = {
			count = {min = 3, max = 4},
			weights = {light = 40, medium = 45, heavy = 15, assault = 0},
		},
		deep = {
			count = {min = 3, max = 4},
			weights = {light = 20, medium = 40, heavy = 35, assault = 5},
		},
	},

	sourceWeights = {
		camp = {
			checkpoint = 1.50,
			sensor_post = 1.35,
			comms_relay = 1.30,
			supply_depot = 0.80,
			forward_base = 0.90,
			strongpoint = 0.70,
			command_garrison = 0.35,
		},
		resource = {
			checkpoint = 0.85,
			sensor_post = 1.00,
			comms_relay = 1.00,
			supply_depot = 1.25,
			forward_base = 1.20,
			strongpoint = 1.20,
			command_garrison = 1.00,
		},
		start = {
			checkpoint = 0.45,
			sensor_post = 0.75,
			comms_relay = 0.85,
			supply_depot = 1.10,
			forward_base = 1.30,
			strongpoint = 1.50,
			command_garrison = 1.75,
		},
	},

	archetypeWeights = {
		near = {
			checkpoint = 50,
			sensor_post = 25,
			comms_relay = 10,
			supply_depot = 5,
			forward_base = 10,
		},
		operational = {
			checkpoint = 10,
			sensor_post = 15,
			comms_relay = 20,
			supply_depot = 15,
			forward_base = 20,
			strongpoint = 15,
			command_garrison = 5,
		},
		deep = {
			sensor_post = 5,
			comms_relay = 10,
			supply_depot = 10,
			forward_base = 15,
			strongpoint = 30,
			command_garrison = 30,
		},
	},

	strengthWeights = {
		near = {light = 75, moderate = 25},
		operational = {light = 15, moderate = 65, heavy = 20},
		deep = {moderate = 30, heavy = 70},
	},

	strength = {
		light = {support = 1, turrets = 1, supportRadius = 105, turretRadius = 185},
		moderate = {support = 2, turrets = 2, supportRadius = 125, turretRadius = 220},
		heavy = {support = 3, turrets = 3, supportRadius = 145, turretRadius = 255},
	},


	-- Mobile garrison defenders are drawn directly from the faction-prefixed
	-- UnitDefs represented by the existing Inner Sphere vehicle class folders.
	-- Higher classes consume composition weight rather than simply inflating
	-- unit count. Assault vehicles are additionally hard-capped at one per base.
	vehicleForces = {
		folders = {
			light = "units/is/Vehicles/Light",
			medium = "units/is/Vehicles/Medium",
			heavy = "units/is/Vehicles/Heavy",
			assault = "units/is/Vehicles/Assault",
		},
		classCost = {
			light = 1,
			medium = 2,
			heavy = 3,
			assault = 5,
		},
		light = {
			budget = {min = 4, max = 6},
			weights = {light = 80, medium = 20},
		},
		moderate = {
			budget = {min = 7, max = 10},
			weights = {light = 35, medium = 45, heavy = 20},
		},
		heavy = {
			budget = {min = 11, max = 15},
			weights = {light = 15, medium = 40, heavy = 38, assault = 7},
		},
		spawnRadius = 340,
		spawnSpacing = 72,
		maxAssault = 1,

		-- Lance tonnage modifies class availability/weighting without changing
		-- the installation's own light/moderate/heavy strength classification.
		-- Level boundaries are <100, <200, <300, otherwise level 4.
		forceLevelWeights = {
			[1] = {light = 1.35, medium = 0.65, heavy = 0.10, assault = 0.00},
			[2] = {light = 1.15, medium = 1.00, heavy = 0.55, assault = 0.00},
			[3] = {light = 0.90, medium = 1.05, heavy = 1.00, assault = 0.65},
			[4] = {light = 0.65, medium = 1.00, heavy = 1.25, assault = 1.50},
		},
	},

	archetypes = {
		checkpoint = {
			name = "Checkpoint",
			core = "mcm_base_bunker",
			support = {"mcm_base_sensor_post", "mcm_base_supply_depot"},
		},
		sensor_post = {
			name = "Sensor Post",
			core = "mcm_base_sensor_post",
			support = {"mcm_base_comms_relay", "mcm_base_bunker", "mcm_base_supply_depot"},
		},
		comms_relay = {
			name = "Communications Relay",
			core = "mcm_base_comms_relay",
			support = {"mcm_base_sensor_post", "mcm_base_bunker", "mcm_base_supply_depot"},
		},
		supply_depot = {
			name = "Supply Depot",
			core = "mcm_base_supply_depot",
			support = {"mcm_base_repair_bay", "mcm_base_bunker", "mcm_base_defense_control"},
		},
		forward_base = {
			name = "Forward Base",
			core = "mcm_base_command_post",
			support = {"mcm_base_repair_bay", "mcm_base_supply_depot", "mcm_base_sensor_post", "mcm_base_bunker"},
		},
		strongpoint = {
			name = "Strongpoint",
			core = "mcm_base_defense_control",
			support = {"mcm_base_bunker", "mcm_base_sensor_post", "mcm_base_supply_depot", "mcm_base_command_post"},
		},
		command_garrison = {
			name = "Command Garrison",
			core = "mcm_base_command_post",
			support = {"mcm_base_defense_control", "mcm_base_comms_relay", "mcm_base_sensor_post", "mcm_base_repair_bay", "mcm_base_bunker"},
		},
	},

	turrets = {
		"mcm_garrison_turret_ac10",
		"mcm_garrison_turret_lpl",
		"mcm_garrison_turret_lrm",
	},
}
