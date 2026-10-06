--------------------------------------------------------------------------------
-- MechCommander: Mercs - Garrison Structure Script
--
-- Minimal script for temporary Mercs garrison buildings. Contract-specific
-- behaviour belongs in Mercs gadgets rather than the PvP Outpost script.
--
-- Authors: zvero + ChatGPT
--------------------------------------------------------------------------------

function script.Create()
end

function script.Killed(recentDamage, maxHealth)
	return 1
end
