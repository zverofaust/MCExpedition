--------------------------------------------------------------------------------
-- MechCommander: Mercs - Garrison Turrets
--
-- Separate Mercs UnitDefs reuse the existing turret assets and combat data but
-- use a pre-emplaced script instead of the player turret orbital insertion.
--
-- Authors: FLOZi (C. Lawrence) + zvero + ChatGPT
--------------------------------------------------------------------------------

local GarrisonTurret = Turret:New{
	name = "Garrison Weapon Emplacement",
	script = "MCM_Garrison_Turret.lua",

	customparams = {
		ignoreatbeacon = true,
		baseclass = "turret",
		slotcost = 1,
		normaltex = "unittextures/normals/Turrets_Normals.dds",
		mcm_garrison_turret = true,
	},
}

local AC10 = GarrisonTurret:New{
	description = "Dual AC/10",
	objectName = "Turret/Turret_AC10.s3o",
	buildCostMetal = 3500,
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
	buildCostMetal = 3500,
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
	buildCostMetal = 4200,
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
