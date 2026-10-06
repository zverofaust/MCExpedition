--------------------------------------------------------------------------------
-- MechCommander: Mercs - Garrison Turrets
--
-- Mercs garrison emplacements reuse existing turret visual and combat assets,
-- but deliberately do NOT inherit the PvP Turret base class. In particular,
-- baseclass="turret" is reserved for MCL's player-built/deployed turret system.
--
-- Authors: FLOZi (C. Lawrence) + zvero + ChatGPT
--------------------------------------------------------------------------------

local GarrisonTurret = Unit:New{
	name = "Garrison Weapon Emplacement",
	description = "Fixed military weapon emplacement",
	script = "MCM_Garrison_Turret.lua",
	category = "structure notbeacon ground",
	iconType = "turret",
	activateWhenBuilt = true,
	buildCostMetal = 1,
	maxDamage = 4000,
	mass = 5000,
	footprintX = 3,
	footprintZ = 3,
	maxSlope = 100,
	collisionVolumeType = "box",
	collisionVolumeScales = "25 25 25",
	canMove = false,
	maxVelocity = 0,
	idleAutoHeal = 0,
	buildingMask = 2,

	customparams = {
		baseclass = "mcm_turret",
		normaltex = "unittextures/normals/Turrets_Normals.dds",
		mcm_garrison_turret = true,
	},

	sounds = {
		select = "Turret",
	},
}

local AC10 = GarrisonTurret:New{
	description = "Dual AC/10",
	objectName = "Turret/Turret_AC10.s3o",
	maxDamage = 1500,

	weapons = {
		[1] = {name = "AC10", OnlyTargetCategory = "notbeacon"},
		[2] = {name = "AC10", OnlyTargetCategory = "notbeacon"},
	},

	customparams = {
		barrelrecoildist = {5, 5},
		maxammo = {ac10 = 1},
		turretturnspeed = 150,
		elevationspeed = 200,
		chainfiredelays = {[2] = 200},
		turrettype = "turret",
	},
}

local LPL = GarrisonTurret:New{
	description = "Quad Large Pulse Laser",
	objectName = "Turret/Turret_LPL.s3o",
	maxDamage = 2500,

	weapons = {
		[1] = {name = "LPL", OnlyTargetCategory = "notbeacon"},
		[2] = {name = "LPL", OnlyTargetCategory = "notbeacon"},
		[3] = {name = "LPL", OnlyTargetCategory = "notbeacon"},
		[4] = {name = "LPL", OnlyTargetCategory = "notbeacon"},
	},

	customparams = {
		turretturnspeed = 175,
		elevationspeed = 250,
		turrettype = "energy",
	},
}

local LRM = GarrisonTurret:New{
	description = "LRM-20",
	objectName = "Turret/Turret_LRM.s3o",
	maxDamage = 2000,

	weapons = {
		[1] = {name = "LRM20", OnlyTargetCategory = "notbeacon"},
	},

	customparams = {
		maxammo = {lrm = 1},
		turretturnspeed = 100,
		elevationspeed = 200,
		turrettype = "ranged",
	},
}

return lowerkeys({
	mcm_garrison_turret_ac10 = AC10,
	mcm_garrison_turret_lpl = LPL,
	mcm_garrison_turret_lrm = LRM,
})
