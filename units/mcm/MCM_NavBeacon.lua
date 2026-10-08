--------------------------------------------------------------------------------
-- MechCommander: Mercs - Nav Beacon
--
-- Mercs-specific insertion/extraction marker. Reuses the MCL beacon model but
-- deliberately has no capture, outpost, territory or build-menu behavior.
--
-- Authors: zvero + ChatGPT
--------------------------------------------------------------------------------

local beacon = Unit:New{
	name                = "Nav Beacon",
	description         = "Mercenary Insertion Marker",
	objectName          = "beacon.s3o",
	iconType            = "beacon",
	script              = "mcm_navbeacon.lua",
	category            = "beacon",
	maxDamage           = 50000,
	mass                = 1000,
	footprintX          = 2,
	footprintZ          = 2,
	buildCostMetal      = 0,
	movementClass       = "LARGEMECH",
	canselfdestruct     = false,

	-- Keep the same indexed CEG layout as the MCL beacon script:
	-- SFX.CEG = reentry trail, +1 = impact, +2 = deployed blink.
	sfxtypes = {
		explosiongenerators = {
			"custom:reentry_fx",
			"custom:ROACHPLOSION",
			"custom:beacon",
		},
	},

	customparams = {
		ignoreatbeacon = true,
		invincible = true,
		mcmnavbeacon = true,
	},
}

return lowerkeys({
	["mcm_navbeacon"] = beacon,
})
