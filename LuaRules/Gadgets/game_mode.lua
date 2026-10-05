--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  MechCommander: Legacy - Major Game Mode Identity
--
--  MCM fork implementation. Establishes the authoritative major-mode identity
--  without overloading contract/scenario identifiers such as "expedition".
--
--  Author: zvero + ChatGPT
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:GetInfo()
	return {
		name      = "MCL - Game Mode Identity",
		desc      = "Publishes the active major MechCommander: Legacy game mode",
		author    = "zvero + ChatGPT",
		date      = "05/10/26",
		license   = "GNU GPL v2",
		layer     = -1000,
		enabled   = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

local MODE = "mercs"

function gadget:Initialize()
	Spring.SetGameRulesParam("mcl_mode", MODE, {public = true})
end
