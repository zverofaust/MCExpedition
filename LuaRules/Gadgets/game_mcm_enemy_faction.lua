--------------------------------------------------------------------------------
-- MCM optional enemy-faction chooser (isolated from expedition generation)
-- Authors: zvero + ChatGPT
--------------------------------------------------------------------------------
function gadget:GetInfo()
 return {name="MCM Enemy Faction Chooser",desc="Optional enemy faction selection",author="zvero + ChatGPT",date="2026-10-11",license="GPL v2",layer=0,enabled=true}
end
if not gadgetHandler:IsSyncedCode() then return false end
local ownership=VFS.Include("LuaRules/Configs/mcl_mode_gadgets.lua")
if ownership.GetMode()~="mercs" then return false end
local defs=VFS.Include("LuaRules/Configs/mcm_expedition_defs.lua")
local allowed={}
for i=1,#defs.enemyFactions do allowed[defs.enemyFactions[i]]=true end
local function Select(request)
 if request=="RANDOM" then return defs.enemyFactions[math.random(#defs.enemyFactions)] end
 return allowed[request] and request or nil
end
local function ApplyFaction(faction)
 local team=Spring.GetGameRulesParam("mcm_enemy_team")
 if not team then return end
 local sidedata=VFS.Include("gamedata/sidedata.lua")
 local texmod="Team"
 for i=1,#sidedata do
  if sidedata[i].shortName==faction then
   texmod=(sidedata[i].texmods and sidedata[i].texmods[1]) or "Team"
   break
  end
 end
 Spring.SetGameRulesParam("mcm_enemy_faction",faction,{public=true})
 Spring.SetTeamRulesParam(team,"side",faction:lower(),{public=true})
 Spring.SetTeamRulesParam(team,"mcm_faction",faction:lower(),{public=true})
 Spring.SetTeamRulesParam(team,"mcl_texmod",texmod,{public=true})
end
function gadget:Initialize()
 Spring.SetGameRulesParam("mcm_enemy_faction_request","RANDOM",{public=true})
end
function gadget:RecvLuaMsg(msg,playerID)
 local request=msg:match("^MCMENEMYFACTION|([A-Z]+)$")
 if not request or (request~="RANDOM" and not allowed[request]) then return false end
 local _,_,spectator,team=Spring.GetPlayerInfo(playerID,false)
 if spectator or team==nil then return true end
 local active=Spring.GetGameRulesParam("mcm_contract_active")==1
 if active and not (Spring.IsCheatingEnabled and Spring.IsCheatingEnabled()) then return true end
 local merc=Spring.GetGameRulesParam("mcm_merc_team")
 if merc and team~=merc then return true end
 Spring.SetGameRulesParam("mcm_enemy_faction_request",request,{public=true})
 if active then
  local faction=Select(request)
  ApplyFaction(faction)
  Spring.Echo("[MCM Enemy Faction] Active enemy team set to "..faction.."; existing unit types remain unchanged.")
 end
 return true
end
