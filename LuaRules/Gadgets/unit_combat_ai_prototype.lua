-- MCM Combat AI prototype r1
-- Authors: zvero + ChatGPT
-- Experimental: only Mars, Pegasus and Savannah Master, and only explicit Attack.
-- Deliberately leaves Patrol/Fight, aircraft, scripted movement and other units alone.
function gadget:GetInfo()
    return {
        name = "MCM Combat AI Prototype",
        desc = "Opt-in hybrid Attack engagement test for three vehicle chassis",
        author = "zvero + ChatGPT",
        date = "2026-10-08",
        license = "GPL v2 or later",
        layer = 10,
        enabled = true,
    }
end

if not gadgetHandler:IsSyncedCode() then return false end

local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitTeam = Spring.GetUnitTeam
local spGetUnitStates = Spring.GetUnitStates
local spGetUnitIsDead = Spring.GetUnitIsDead
local spGetUnitTransporter = Spring.GetUnitTransporter
local spGetUnitLosState = Spring.GetUnitLosState
local spSetUnitTarget = Spring.SetUnitTarget
local spSetUnitMoveGoal = Spring.SetUnitMoveGoal
local spGetUnitWeaponTestTarget = Spring.GetUnitWeaponTestTarget
local spAreTeamsAllied = Spring.AreTeamsAllied
local sqrt = math.sqrt

local UPDATE_FRAMES = 15
local RANGE_IN = 0.90
local RANGE_OUT = 1.05
local targets = {}
local eligible = {}

for unitDefID, ud in pairs(UnitDefs) do
    local name = (ud.name or ""):lower()
    local cp = ud.customParams or {}
    -- Exact chassis whitelist; variants share their displayed chassis name.
    if cp.baseclass == "vehicle"
        and (name == "mars" or name == "pegasus" or name == "savannah master")
        and ud.canMove and ud.canAttack and not ud.canFly then
        eligible[unitDefID] = true
    end
end

local function Clear(unitID, clearWeaponTarget)
    if targets[unitID] then
        targets[unitID] = nil
        if clearWeaponTarget then spSetUnitTarget(unitID, nil) end
    end
end

local function WeaponRange(unitID, unitDefID, targetID)
    local ud = UnitDefs[unitDefID]
    local best = 0
    for weaponNum, mount in ipairs(ud.weapons or {}) do
        local wd = WeaponDefs[mount.weaponDef]
        if wd and wd.range and wd.range > best
            and spGetUnitWeaponTestTarget(unitID, weaponNum, targetID) then
            best = wd.range
        end
    end
    return best
end

local function ValidTarget(unitID, targetID)
    if not Spring.ValidUnitID(targetID) or spGetUnitIsDead(targetID) then return false end
    local teamA, teamB = spGetUnitTeam(unitID), spGetUnitTeam(targetID)
    if not teamA or not teamB or spAreTeamsAllied(teamA, teamB) then return false end
    local allyTeam = Spring.GetUnitAllyTeam(unitID)
    local los = allyTeam and spGetUnitLosState(targetID, allyTeam, true)
    return los and (los % 4 ~= 0)
end

local function MayControl(unitID)
    if spGetUnitTransporter(unitID) then return false end
    if GG.turning and GG.turning[unitID] then return false end
    if Spring.MoveCtrl and Spring.MoveCtrl.IsEnabled and Spring.MoveCtrl.IsEnabled(unitID) then return false end
    local states = spGetUnitStates(unitID)
    -- Hold Position (0) and Roam (2) remain native in this first prototype.
    return states and states.movestate == 1
end

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, params, opts)
    if not eligible[unitDefID] then return true end
    if cmdID == CMD.MOVE_STATE then
        if params and params[1] ~= 1 then Clear(unitID, true) end
        return true
    end
    if cmdID == CMD.ATTACK and params and #params == 1
        and not (opts and (opts.shift or opts.internal))
        and MayControl(unitID) and ValidTarget(unitID, params[1]) then
        local range = WeaponRange(unitID, unitDefID, params[1])
        if range > 0 then
            targets[unitID] = { target = params[1], range = range, approaching = false }
            -- Attack becomes a retained tactical objective, not a native attack command.
            return false
        end
    end
    -- Every explicit non-queued navigation command revokes our temporary movement authority.
    if cmdID == CMD.MOVE or cmdID == CMD.STOP or cmdID == CMD.PATROL
        or cmdID == CMD.FIGHT or cmdID == CMD.ATTACK or cmdID == CMD.GUARD
        or cmdID == CMD.LOAD_ONTO or cmdID == CMD.LOAD_UNITS then
        if not (opts and (opts.shift or opts.internal)) then Clear(unitID, true) end
    end
    return true
end

function gadget:GameFrame(frame)
    if frame % UPDATE_FRAMES ~= 0 then return end
    for unitID, state in pairs(targets) do
        local unitDefID = spGetUnitDefID(unitID)
        if not unitDefID or spGetUnitIsDead(unitID) or not ValidTarget(unitID, state.target) then
            Clear(unitID, true)
        elseif MayControl(unitID) then
            -- Existing manually assigned Set Target has priority over this prototype.
            local manual = GG.getUnitTargetList and GG.getUnitTargetList(unitID)
            if not manual or #manual == 0 then
                local x, y, z = spGetUnitPosition(unitID)
                local tx, ty, tz = spGetUnitPosition(state.target)
                if x and tx then
                    local dx, dz = tx - x, tz - z
                    local dist = sqrt(dx * dx + dz * dz)
                    if state.approaching then
                        if dist <= state.range * RANGE_IN then state.approaching = false end
                    elseif dist > state.range * RANGE_OUT then
                        state.approaching = true
                    end
                    if state.approaching then
                        -- Keep native ground steering, collisions and pathfinding.
                        spSetUnitMoveGoal(unitID, tx, ty, tz, state.range * RANGE_IN)
                    else
                        -- No independent hull rotation yet: weapon tracking is native.
                        spSetUnitMoveGoal(unitID, x, y, z, 16)
                    end
                    spSetUnitTarget(unitID, state.target, false, true)
                end
            end
        end
    end
end

function gadget:UnitDestroyed(unitID) Clear(unitID, false) end
function gadget:UnitTaken(unitID) Clear(unitID, true) end
function gadget:UnitGiven(unitID) Clear(unitID, true) end
function gadget:Shutdown()
    for unitID in pairs(targets) do Clear(unitID, true) end
end
