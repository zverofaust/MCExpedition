--------------------------------------------------------------------------------
-- MechCommander: Mercs - Expedition generation definitions
--
-- Authors: zvero + ChatGPT
--------------------------------------------------------------------------------

return {
	baseCountMin = 3,
	baseCountMax = 4,

	playerExclusionRadius = 1400,
	minimumBaseSpacing = 1200,

	baseStructure = "mcm_base_command_post",

	buildings = {
		"mcm_base_repair_bay",
		"mcm_base_comms_relay",
		"mcm_base_sensor_post",
		"mcm_base_defense_control",
		"mcm_base_supply_depot",
		"mcm_base_bunker",
	},

	turrets = {
		"mcm_garrison_turret_ac10",
		"mcm_garrison_turret_lpl",
		"mcm_garrison_turret_lrm",
	},

	turretRadius = 230,
}
