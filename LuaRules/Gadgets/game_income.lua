function gadget:GetInfo()
	return {
		name		= "Game - Income",
		desc		= "Damage Income",
		author		= "FLOZi (C. Lawrence), zvero + ChatGPT",
		date		= "26/07/20",
		license 	= "GNU GPL v2",
		layer		= 3,
		enabled	= true,
	}
end

if gadgetHandler:IsSyncedCode() then
--	SYNCED

local modOptions = Spring.GetModOptions()

-- localisations
--SyncedRead
local AreTeamsAllied		= Spring.AreTeamsAllied
-- Constants
local DAMAGE_REWARD_MULT = (modOptions and tonumber(modOptions.income_damage)) or 0.1
local EXPEDITION_DAMAGE_REWARD_MULT = 0.25
Spring.SetGameRulesParam("damage_reward_mult", DAMAGE_REWARD_MULT)
Spring.SetGameRulesParam("expedition_damage_reward_mult", EXPEDITION_DAMAGE_REWARD_MULT)

local MELTDOWN = WeaponDefNames["meltdown"].id

function gadget:UnitDamaged(unitID, unitDefID, teamID, damage, paralyzer, weaponID,  projectileID, attackerID, attackerDefID, attackerTeam)
	if attackerID and attackerDefID and attackerTeam and not AreTeamsAllied(teamID, attackerTeam) then
		if GG.mechCache[attackerDefID] then -- only mechs generate income
			-- don't allow income from nukes
			if not (weaponID and weaponID == MELTDOWN) then		
				local expeditionMode = Spring.GetGameRulesParam("gamemode") == "expedition"
				local reward = damage * (expeditionMode and EXPEDITION_DAMAGE_REWARD_MULT or DAMAGE_REWARD_MULT)
				if expeditionMode then
					local earned = (Spring.GetTeamRulesParam(attackerTeam, "EXPEDITION_CBILLS_EARNED") or 0) + reward
					Spring.SetTeamRulesParam(attackerTeam, "EXPEDITION_CBILLS_EARNED", earned, {public = true})
				else
					GG.ChangeTeamResource(attackerTeam, "cbills", reward)
				end
			end
		end
	end
end

function gadget:AllowResourceLevel(teamID, res, amount)
	if res == "e" then 
		return false 
	end
	return true
end

function gadget:AllowResourceTransfer(oldTeamID, newTeamID, res, amount)
	if res == "e" then 
		return false 
	end
	return true
end

function gadget:Initialize()
	if Spring.GetGameRulesParam("gamemode") == "expedition" then
		for _, teamID in ipairs(Spring.GetTeamList()) do
			Spring.SetTeamRulesParam(teamID, "EXPEDITION_CBILLS_EARNED", 0, {public = true})
		end
	end
end

else
--	UNSYNCED
return false end