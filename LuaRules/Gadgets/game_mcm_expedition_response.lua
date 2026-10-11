--------------------------------------------------------------------------------
-- MechCommander: Mercs - Local Garrison Response Controller
--
-- A direct attack against a garrison's units or structures mobilizes that
-- installation's own combat vehicles toward the attacking Lance Mech.
-- Responses are local: no escalation-driven mobilization or reinforcements.
-- Defenders return to their original deployment positions after contact expires.
--
-- Authors: zvero + ChatGPT
--------------------------------------------------------------------------------

function gadget:GetInfo()
    return {
        name = "MCM - Local Garrison Response",
        desc = "Directs local garrison vehicles against attacking Lance Mechs",
        author = "zvero + ChatGPT",
        date = "11/10/26",
        license = "GNU GPL v2",
        layer = 6,
        enabled = true,
    }
end

if not gadgetHandler:IsSyncedCode() then return false end

local modeOwnership = VFS.Include("LuaRules/Configs/mcl_mode_gadgets.lua")
if modeOwnership.GetMode() ~= "mercs" then return false end

local CONTACT_MEMORY_FRAMES = 15 * (Game.gameSpeed or 30)
local groups = {}
local unitToGroup = {}
local groupsBuilt = false
local enemyTeamID
local mercTeamID

local function IsAlive(unitID)
    return unitID and Spring.ValidUnitID(unitID) and not Spring.GetUnitIsDead(unitID)
end

local function IsCombatVehicle(unitID)
    if not IsAlive(unitID) then return false end
    local unitDef = UnitDefs[Spring.GetUnitDefID(unitID)]
    return unitDef and unitDef.speed > 0 and unitDef.customParams
        and unitDef.customParams.baseclass == "vehicle"
        and not unitDef.customParams.support
end

local function BuildGroups()
    if groupsBuilt or Spring.GetGameRulesParam("mcm_contract_active") ~= 1 then return end
    local bases = GG.MCMExpeditionBases or {}
    for _, base in pairs(bases) do
        local group = {site = base, units = {}, home = {}, lastContactFrame = -1, responding = false}
        for i = 1, #(base.units or {}) do
            local id = base.units[i]
            if IsAlive(id) then
                unitToGroup[id] = group
                if IsCombatVehicle(id) then
                    group.units[#group.units + 1] = id
                    local x, _, z = Spring.GetUnitPosition(id)
                    if x then group.home[id] = {x, z} end
                end
            end
        end
        if #group.units > 0 then groups[#groups + 1] = group end
    end
    groupsBuilt = true
    Spring.SetGameRulesParam("mcm_response_group_count", #groups, {public = true})
end

local function Respond(group, attackerID, frame)
    if not group or not IsAlive(attackerID) then return end
    local x, _, z = Spring.GetUnitPosition(attackerID)
    if not x then return end
    group.lastContactFrame = frame
    group.responding = true
    group.lastKnownX, group.lastKnownZ = x, z
    Spring.SetGameRulesParam("mcm_enemy_contact", 1, {public = true})
    Spring.SetGameRulesParam("mcm_enemy_contact_frame", frame, {public = true})
    Spring.SetGameRulesParam("mcm_enemy_last_known_x", x, {public = true})
    Spring.SetGameRulesParam("mcm_enemy_last_known_z", z, {public = true})
    for i = 1, #group.units do
        local id = group.units[i]
        if IsCombatVehicle(id) then
            Spring.SetUnitRulesParam(id, "mcm_response_mobilized", 1, {public = true})
            Spring.GiveOrderToUnit(id, CMD.FIGHT, {x, Spring.GetGroundHeight(x, z), z}, {})
        end
    end
end

local function ReturnHome(group)
    group.responding = false
    for i = 1, #group.units do
        local id = group.units[i]
        local home = group.home[id]
        if home and IsCombatVehicle(id) then
            Spring.SetUnitRulesParam(id, "mcm_response_mobilized", 0, {public = true})
            Spring.GiveOrderToUnit(id, CMD.MOVE, {
                home[1], Spring.GetGroundHeight(home[1], home[2]), home[2]
            }, {})
        end
    end
end

function gadget:Initialize()
    mercTeamID = Spring.GetGameRulesParam("mcm_merc_team")
    enemyTeamID = Spring.GetGameRulesParam("mcm_enemy_team")
    Spring.SetGameRulesParam("mcm_enemy_contact", 0, {public = true})
    Spring.SetGameRulesParam("mcm_enemy_contact_frame", -1, {public = true})
    Spring.SetGameRulesParam("mcm_response_group_count", 0, {public = true})
    Spring.SetGameRulesParam("mcm_response_mobilized_groups", 0, {public = true})
end

function gadget:GameFrame(frame)
    mercTeamID = mercTeamID or Spring.GetGameRulesParam("mcm_merc_team")
    enemyTeamID = enemyTeamID or Spring.GetGameRulesParam("mcm_enemy_team")
    BuildGroups()
    if frame % 15 ~= 0 then return end
    local active, mobilized = false, 0
    for i = 1, #groups do
        local group = groups[i]
        if group.responding then
            if frame - group.lastContactFrame > CONTACT_MEMORY_FRAMES then
                ReturnHome(group)
            else
                mobilized = mobilized + 1
                active = true
            end
        end
    end
    Spring.SetGameRulesParam("mcm_enemy_contact", active and 1 or 0, {public = true})
    Spring.SetGameRulesParam("mcm_response_mobilized_groups", mobilized, {public = true})
end

function gadget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)
    if not groupsBuilt or not attackerID or not mercTeamID or not enemyTeamID then return end
    -- Only a direct Lance attack on a registered garrison unit triggers that
    -- installation. Nearby fights and attacks on encounters do not mobilize it.
    if attackerTeam == mercTeamID and unitTeam == enemyTeamID
        and Spring.GetUnitRulesParam(attackerID, "mcm_lance") == 1 then
        Respond(unitToGroup[unitID], attackerID, Spring.GetGameFrame())
    end
end
