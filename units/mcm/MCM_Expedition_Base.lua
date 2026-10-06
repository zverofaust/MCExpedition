--------------------------------------------------------------------------------
-- MechCommander: Mercs - Expedition Base Structure
--
-- A deliberately mode-neutral physical structure for Mercs battlefield bases.
-- It reuses an existing MCL asset without inheriting PvP Outpost gameplay.
--
-- Authors: zvero + ChatGPT
--------------------------------------------------------------------------------

local MCM_Expedition_Base = Unit:New{
	name                  = "Expedition Base",
	description           = "Enemy field installation",
	objectName            = "Outpost/Outpost_Garrison.s3o",
	category              = "structure notbeacon ground",
	iconType              = "outpost_garrison",

	maxDamage             = 10000,
	mass                  = 10000,
	footprintX            = 8,
	footprintZ            = 8,
	maxSlope              = 30,
	canMove               = false,
	maxVelocity           = 0,
	idleAutoHeal          = 0,
	buildingMask          = 2,

	customparams = {
		baseclass = "mcm_structure",
		normaltex = "unittextures/normals/Outpost_Garrison_Normals.dds",
		mcm_expedition_structure = true,
	},
}

return lowerkeys({
	mcm_expedition_base = MCM_Expedition_Base,
})
