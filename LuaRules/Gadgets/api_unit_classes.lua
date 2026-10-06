--------------------------------------------------------------------------------
-- MechCommander: Legacy shared unit classification
--
-- Unit-class caches are combat/gameplay infrastructure and must not be owned
-- by a mode-specific system such as the PvP DropZone.
--
-- Authors: zvero + ChatGPT
--------------------------------------------------------------------------------

function gadget:GetInfo()
	return {
		name      = "API - Unit Classes",
		desc      = "Publishes shared UnitDef classification caches",
		author    = "zvero + ChatGPT",
		date      = "06/10/26",
		license   = "GNU GPL v2",
		layer     = -100,
		enabled   = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

GG.mechCache = {}

for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.customParams.baseclass == "mech" then
		GG.mechCache[unitDefID] = unitDef.customParams.menu
	end
end
