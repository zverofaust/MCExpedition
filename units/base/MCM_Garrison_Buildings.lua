--------------------------------------------------------------------------------
-- MechCommander: Mercs - Garrison Base Structures
--
-- Temporary Mercs structures using existing MCL Outpost visual assets.
-- These definitions intentionally inherit directly from Unit rather than Outpost
-- and use the mcm_base_* namespace so PvP Outpost systems do not own them.
--
-- Authors: zvero + ChatGPT
--------------------------------------------------------------------------------

local GarrisonBuilding = Unit:New{
	name                  = "Garrison Structure",
	description           = "Military field installation",
	category              = "structure ground notbeacon",
	iconType              = "outpost",
	explodeAs             = "outpostexplode",
	activateWhenBuilt     = false,
	footprintX            = 4,
	footprintZ            = 4,
	collisionVolumeScales = [[75 75 75]],
	buildCostEnergy       = 0,
	buildCostMetal        = 1,
	canMove               = false,
	maxVelocity           = 0,
	idleAutoHeal          = 0,
	maxSlope              = 100,
	cantbetransported     = true,

	customparams = {
		baseclass = "mcm_structure",
		mcm_garrison_structure = true,
	},
}

local CommandPost = GarrisonBuilding:New{
	name = "Garrison Command Post",
	description = "Local command and coordination facility",
	objectName = "Outpost/Outpost_C3Array.s3o",
	iconType = "outpost_c3array",
	maxDamage = 5200,
	mass = 10000,
	customparams = {
		normaltex = "unittextures/normals/Outpost_C3Array_Normals.dds",
	},
}

local RepairBay = GarrisonBuilding:New{
	name = "Garrison Repair Bay",
	description = "BattleMech and vehicle servicing facility",
	objectName = "Outpost/Outpost_Mechbay.s3o",
	iconType = "outpost_mechbay",
	maxDamage = 5500,
	mass = 9000,
	customparams = {
		normaltex = "unittextures/normals/Outpost_Mechbay_Normals.dds",
	},
}

local CommunicationsRelay = GarrisonBuilding:New{
	name = "Garrison Communications Relay",
	description = "Long-range military communications facility",
	objectName = "Outpost/Outpost_Uplink.s3o",
	iconType = "outpost_uplink",
	maxDamage = 5500,
	mass = 5000,
	customparams = {
		normaltex = "unittextures/normals/Outpost_Uplink_Normals.dds",
	},
}

local SensorPost = GarrisonBuilding:New{
	name = "Garrison Sensor Post",
	description = "Long-range battlefield sensor installation",
	objectName = "Outpost/Outpost_Sensor.s3o",
	iconType = "outpost_sensor",
	maxDamage = 5000,
	mass = 5000,
	sightDistance = 1000,
	radarDistance = 2500,
	customparams = {
		normaltex = "unittextures/normals/Outpost_Sensor_Normals.dds",
	},
}

local EWARPost = GarrisonBuilding:New{
	name = "Garrison EWAR Post",
	description = "Electronic-warfare field installation",
	objectName = "Outpost/Outpost_Ewar.s3o",
	iconType = "outpost_ewar",
	maxDamage = 5000,
	mass = 5000,
	customparams = {
		normaltex = "unittextures/normals/Outpost_Ewar_Normals.dds",
	},
}

local TurretControl = GarrisonBuilding:New{
	name = "Garrison Defense Control",
	description = "Local defensive emplacement control facility",
	objectName = "Outpost/Outpost_TurretControl.s3o",
	iconType = "outpost_turretcontrol",
	maxDamage = 7000,
	mass = 5000,
	customparams = {
		normaltex = "unittextures/normals/Outpost_TurretControl_Normals.dds",
	},
}

local LandingPad = GarrisonBuilding:New{
	name = "Garrison Landing Pad",
	description = "Military vehicle and transport landing facility",
	objectName = "Outpost/Outpost_VehiclePad.s3o",
	iconType = "outpost_vehiclepad",
	maxDamage = 5500,
	mass = 5000,
	footprintX = 8,
	footprintZ = 8,
	collisionVolumeOffsets = [[0 12 0]],
	collisionVolumeScales = [[70 36 70]],
	collisionVolumeType = "cylY",
	customparams = {
		normaltex = "unittextures/normals/Outpost_VehiclePad_Normals.dds",
	},
}

local AirControl = GarrisonBuilding:New{
	name = "Garrison Air Control",
	description = "Local aerospace coordination facility",
	objectName = "Outpost/Outpost_Aircon.s3o",
	iconType = "outpost_aircon",
	maxDamage = 7000,
	mass = 5000,
	footprintX = 8,
	footprintZ = 8,
	collisionVolumeOffsets = [[0 -14 0]],
	collisionVolumeScales = [[70 88 70]],
	collisionVolumeType = "cylY",
	customparams = {
		normaltex = "unittextures/normals/Outpost_Aircon_Normals.dds",
	},
}

local SupplyDepot = GarrisonBuilding:New{
	name = "Garrison Supply Depot",
	description = "Stores ammunition, spares and field supplies",
	objectName = "Outpost/Outpost_SalvageYard.s3o",
	iconType = "outpost_salvageyard",
	maxDamage = 7000,
	mass = 9000,
}

local Bunker = GarrisonBuilding:New{
	name = "Garrison Bunker",
	description = "Fortified military installation",
	objectName = "Outpost/Outpost_Garrison.s3o",
	iconType = "outpost_garrison",
	maxDamage = 10000,
	mass = 10000,
	customparams = {
		normaltex = "unittextures/normals/Outpost_Garrison_Normals.dds",
	},
}

return lowerkeys({
	mcm_base_command_post = CommandPost,
	mcm_base_repair_bay = RepairBay,
	mcm_base_comms_relay = CommunicationsRelay,
	mcm_base_sensor_post = SensorPost,
	mcm_base_ewar_post = EWARPost,
	mcm_base_defense_control = TurretControl,
	mcm_base_landing_pad = LandingPad,
	mcm_base_air_control = AirControl,
	mcm_base_supply_depot = SupplyDepot,
	mcm_base_bunker = Bunker,
})
