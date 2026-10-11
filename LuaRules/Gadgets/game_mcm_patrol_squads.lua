--------------------------------------------------------------------------------
-- MechCommander: Mercs - Leader/follower roaming vehicle patrols
-- Recoil handles navigation and fighting; this gadget manages group itinerary.
-- Authors: zvero + ChatGPT
--------------------------------------------------------------------------------

function gadget:GetInfo()
    return {
        name = "MCM - Vehicle Patrol Squads",
        desc = "Spawns mixed vehicle squads and routes them between authored sites",
        author = "zvero + ChatGPT",
        date = "11/10/26",
        license = "GNU GPL v2",
        layer = 7,
        enabled = true,
    }
end

if not gadgetHandler:IsSyncedCode() then return false end

local mode = VFS.Include("LuaRules/Configs/mcl_mode_gadgets.lua")
if mode.GetMode() ~= "mercs" then return false end

local cfg = VFS.Include("LuaRules/Configs/mcm_patrol_squads.lua")
local squads = {}
local sites = {}
local initialized = false
local TWO_PI = math.pi * 2

local function Alive(id)
    return id and Spring.ValidUnitID(id) and not Spring.GetUnitIsDead(id)
end

local function DistanceSq(x, z, xx, zz)
    return (x - xx) ^ 2 + (z - zz) ^ 2
end

local function PickTemplate(faction)
    local choices, total = {}, 0
    for i = 1, #cfg.squads do
        local t = cfg.squads[i]
        local valid = true
        for j = 1, #t.units do
            if not UnitDefNames[(faction .. "_" .. t.units[j][1]):lower()] then
                valid = false
                break
            end
        end
        if valid then
            total = total + (t.weight or 1)
            choices[#choices + 1] = {template = t, cumulative = total}
        end
    end
    if total == 0 then return end
    local roll = math.random() * total
    for i = 1, #choices do
        if roll <= choices[i].cumulative then return choices[i].template end
    end
    return choices[#choices].template
end

local function SelectDestination(squad)
    local eligible = {}
    for i = 1, #sites do
        local site = sites[i]
        if site ~= squad.destination and DistanceSq(site.x, site.z, squad.x, squad.z) >= cfg.minimumWaypointDistance ^ 2 then
            eligible[#eligible + 1] = site
        end
    end
    if #eligible == 0 then
        for i = 1, #sites do
            if sites[i] ~= squad.destination then eligible[#eligible + 1] = sites[i] end
        end
    end
    if #eligible == 0 then return end
    local target = eligible[math.random(#eligible)]
    squad.destination = target
    squad.x, squad.z = target.x, target.z
    local a = math.random() * TWO_PI
    squad.targetX = math.max(16, math.min(Game.mapSizeX - 16, target.x + math.cos(a) * cfg.waypointRadius))
    squad.targetZ = math.max(16, math.min(Game.mapSizeZ - 16, target.z + math.sin(a) * cfg.waypointRadius))
    return true
end

local function SetLeader(squad, id)
    squad.leader = id
    for i = 1, #squad.members do
        local member = squad.members[i]
        if Alive(member) and member ~= id then
            Spring.GiveOrderToUnit(member, CMD.GUARD, {id}, {})
        end
    end
    if squad.targetX then
        Spring.GiveOrderToUnit(id, CMD.FIGHT, {
            squad.targetX, Spring.GetGroundHeight(squad.targetX, squad.targetZ), squad.targetZ
        }, {})
    end
end

local function SpawnSquad(template, origin, faction, team, number)
    local members = {}
    local angle = math.random() * TWO_PI
    for j = 1, #template.units do
        local entry = template.units[j]
        local def = UnitDefNames[(faction .. "_" .. entry[1]):lower()]
        for k = 1, entry[2] do
            local n = #members + 1
            local a = angle + (n - 1) * 2.39996
            local radius = cfg.spawnRadius + math.sqrt(n) * cfg.spawnSpacing
            local x = origin.x + math.cos(a) * radius
            local z = origin.z + math.sin(a) * radius
            if def and x > 16 and z > 16 and x < Game.mapSizeX - 16 and z < Game.mapSizeZ - 16
                and Spring.GetGroundHeight(x, z) >= 0 then
                local id = Spring.CreateUnit(def.id, x, Spring.GetGroundHeight(x, z), z, math.random(0, 3), team)
                if id then
                    members[#members + 1] = id
                    Spring.SetUnitRulesParam(id, "mcm_patrol_squad", number, {public = true})
                end
            end
        end
    end
    if #members == 0 then return end
    local squad = {id = number, template = template.id, members = members, origin = origin,
        x = origin.x, z = origin.z}
    squads[#squads + 1] = squad
    if SelectDestination(squad) then SetLeader(squad, members[1]) end
end

local function LoadPatrolSites()
    local list = {}
    local profilePath = "maps/flagConfig/" .. Game.mapName .. "_profile.lua"
    if VFS.FileExists(profilePath) then
        local ok, resources, _, starts, camps = pcall(VFS.Include, profilePath)
        if ok then
            local function Add(source, site)
                if type(site) ~= "table" or type(site.x) ~= "number" or type(site.z) ~= "number" then return end
                if source == "resource" and site.points == 0 then return end
                if site.x < 16 or site.z < 16 or site.x > Game.mapSizeX - 16 or site.z > Game.mapSizeZ - 16 then return end
                if Spring.GetGroundHeight(site.x, site.z) < 0 then return end
                for i = 1, #list do
                    if DistanceSq(site.x, site.z, list[i].x, list[i].z) < 250 ^ 2 then return end
                end
                list[#list + 1] = {x = site.x, z = site.z, source = source}
            end
            if type(resources) == "table" then for _, site in pairs(resources) do Add("resource", site) end end
            if type(starts) == "table" then for _, site in pairs(starts) do Add("start", site) end end
            if type(camps) == "table" then for _, site in pairs(camps) do Add("camp", site) end end
        end
    end
    return list
end

local function Start()
    if initialized or Spring.GetGameRulesParam("mcm_contract_active") ~= 1 then return end
    initialized = true
    sites = LoadPatrolSites()
    local bases = GG.MCMExpeditionBases or {}
    local baseSites = {}
    for _, base in pairs(bases) do baseSites[#baseSites + 1] = base end
    local encounters = 0
    for i = 1, #(GG.MCMExpeditionSites or {}) do
        if GG.MCMExpeditionSites[i].kind == "encounter" then encounters = encounters + 1 end
    end
    local desired = math.min(cfg.maximumSquads, math.max(cfg.minimumSquads,
        math.floor(#baseSites / cfg.basesPerSquad + encounters / cfg.encountersPerSquad + 0.5)))
    local faction = Spring.GetGameRulesParam("mcm_enemy_faction")
    local team = Spring.GetGameRulesParam("mcm_enemy_team")
    if not faction or not team or #sites < 2 then
        Spring.Echo("[MCM Patrol] No valid enemy team, faction or route sites")
        return
    end
    local origins = {}
    for i = 1, #baseSites do origins[#origins + 1] = baseSites[i] end
    for i = 1, #sites do origins[#origins + 1] = sites[i] end
    for i = #origins, 2, -1 do
        local j = math.random(i)
        origins[i], origins[j] = origins[j], origins[i]
    end
    local px = Spring.GetGameRulesParam("mcm_player_start_x")
    local pz = Spring.GetGameRulesParam("mcm_player_start_z")
    local spawned = 0
    for i = 1, #origins do
        if spawned >= desired then break end
        local origin = origins[i]
        if not px or not pz or DistanceSq(px, pz, origin.x, origin.z) >= 1400 ^ 2 then
            local template = PickTemplate(faction)
            if template then
                local before = #squads
                SpawnSquad(template, origin, faction, team, spawned + 1)
                if #squads > before then spawned = spawned + 1 end
            end
        end
    end
    Spring.SetGameRulesParam("mcm_patrol_squad_count", spawned, {public = true})
    Spring.Echo("[MCM Patrol] Spawned ", spawned, " roaming squads")
end

local function UpdateSquad(squad, frame)
    local live = {}
    for i = 1, #squad.members do
        if Alive(squad.members[i]) then live[#live + 1] = squad.members[i] end
    end
    squad.members = live
    if #live == 0 then return end
    if not Alive(squad.leader) then
        squad.waitSince = nil
        SetLeader(squad, live[1])
    end
    local x, _, z = Spring.GetUnitPosition(squad.leader)
    if not x then return end
    if squad.targetX and DistanceSq(x, z, squad.targetX, squad.targetZ) < cfg.arrivalRadius ^ 2 then
        if SelectDestination(squad) then SetLeader(squad, squad.leader) end
        return
    end
    local farthest = 0
    for i = 1, #live do
        if live[i] ~= squad.leader then
            local fx, _, fz = Spring.GetUnitPosition(live[i])
            if fx then farthest = math.max(farthest, DistanceSq(x, z, fx, fz)) end
        end
    end
    if not squad.waitSince and farthest > cfg.cohesionRadius ^ 2 then
        squad.waitSince = frame
        Spring.GiveOrderToUnit(squad.leader, CMD.STOP, {}, {})
    elseif squad.waitSince and (farthest < cfg.cohesionReleaseRadius ^ 2
        or frame - squad.waitSince >= cfg.cohesionTimeoutFrames) then
        squad.waitSince = nil
        if squad.targetX then SetLeader(squad, squad.leader) end
    end
end

function gadget:Initialize()
    Spring.SetGameRulesParam("mcm_patrol_squad_count", 0, {public = true})
end

function gadget:GameFrame(frame)
    if not initialized then Start() end
    if not initialized or frame % cfg.updateFrames ~= 0 then return end
    for i = 1, #squads do UpdateSquad(squads[i], frame) end
end
