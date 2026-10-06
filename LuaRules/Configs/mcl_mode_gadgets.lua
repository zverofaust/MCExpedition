--------------------------------------------------------------------------------
-- MechCommander: Legacy major-mode gadget ownership
--
-- Central ownership manifest for gameplay gadgets whose implementations belong
-- to a specific major game mode. Shared gadgets are intentionally absent.
--
-- Authors: zvero + ChatGPT
--------------------------------------------------------------------------------

local M = {}

local mode = (Game.modShortName == "MCM") and "mercs" or "pvp"

local owners = {
	["Game - Spawn"] = "pvp",
	["Game - Beacon Manager"] = "pvp",
	["Game - Outposts"] = "pvp",
	["Game - Income"] = "pvp",
	["Game - Bot Buddy Core"] = "pvp",
	["Game - Dropships"] = "pvp",
	["Outpost - Aerofighter Control Tower"] = "pvp",
	["Outpost - C3 Array"] = "pvp",
	["Outpost - DropZone"] = "pvp",
	["Outpost - Launcher"] = "pvp",
	["Outpost - Mech Bay"] = "pvp",
	["Outpost - Salvage Yard"] = "pvp",
	["Outpost - AI Turret Control"] = "pvp",
	["Outpost - Orbital Uplink"] = "pvp",
	["Outpost - Vehicle Pad"] = "pvp",
}

function M.GetMode()
	return mode
end

function M.IsOwnedByActiveMode(gadgetName)
	local owner = owners[gadgetName]
	return owner == nil or owner == mode
end

return M
