-- MCM Combat AI r2: limited vehicle tactical movement prototype.
-- Authors: zvero + ChatGPT
-- Scope: Mars, Pegasus and Savannah Master only; explicit unqueued unit Attack only.
-- Native Move/Stop/Patrol/Fight and manually set targets retain priority.
function gadget:GetInfo()
    return {
        name = "MCM Combat AI r2",
        desc = "Experimental weapon-aware vehicle engagement manoeuvres",
        author = "zvero + ChatGPT",
        date = "2026-10-08",
        license = "GPL v2 or later",
        layer = 10,
        enabled = true,
    }
end

if not gadgetHandler:IsSyncedCode() then return false end

local sqrt, abs, max, min = math.sqrt, math.abs, math.max, math.min
local sin, cos, atan2 = math.sin, math.cos, math.atan2
local UPDATE = 15
local states = {}
local eligible = {}

for defID, ud in pairs(UnitDefs) do
    local cp = ud.customParams or {}
    local name = (ud.name or ""):lower()
    if cp.baseclass == "vehicle" and ud.canMove and ud.canAttack and not ud.canFly then
        if name == "mars" then eligible[defID] = "hold"
        elseif name == "pegasus" then eligible[defID] = "circle"
        elseif name == "savannah master" then eligible[defID] = "pass" end
    end
end

local function Distance(x, z, tx, tz)
    local dx, dz = tx - x, tz - z
    return sqrt(dx * dx + dz * dz), dx, dz
end

local function Clear(unitID, clearTarget)
    if states[unitID] then
        states[unitID] = nil
        if clearTarget then Spring.SetUnitTarget(unitID, nil) end
    end
end

local function SeenEnemy(unitID, targetID)
    if not Spring.ValidUnitID(targetID) or Spring.GetUnitIsDead(targetID) then return false end
    local teamA, teamB = Spring.GetUnitTeam(unitID), Spring.GetUnitTeam(targetID)
    if not teamA or not teamB or Spring.AreTeamsAllied(teamA, teamB) then return false end
    local allyTeam = Spring.GetUnitAllyTeam(unitID)
    local los = allyTeam and Spring.GetUnitLosState(targetID, allyTeam, true)
    return los and (los % 4 ~= 0)
end

local function CanSteer(unitID)
    if Spring.GetUnitTransporter(unitID) then return false end
    if GG.turning and GG.turning[unitID] then return false end
    if Spring.MoveCtrl and Spring.MoveCtrl.IsEnabled and Spring.MoveCtrl.IsEnabled(unitID) then return false end
    local s = Spring.GetUnitStates(unitID)
    return s and s.movestate == 1
end

-- Effective range is a weighted central range of compatible, automatically
-- fired weapons, rather than the longest-range weapon on the chassis.
local function EffectiveRange(unitID, defID, targetID)
    local entries, total = {}, 0
    for slot, mount in ipairs(UnitDefs[defID].weapons or {}) do
        local wd = WeaponDefs[mount.weaponDef]
        if wd and wd.range and wd.range > 0 and not wd.manualFire
            and Spring.GetUnitWeaponTestTarget(unitID, slot, targetID) then
            local weight = max(1, (wd.damages and wd.damages[0]) or 1)
            entries[#entries + 1] = {range = wd.range, weight = weight}
            total = total + weight
        end
    end
    if total == 0 then return nil end
    table.sort(entries, function(a, b) return a.range < b.range end)
    local accumulated = 0
    for i = 1, #entries do
        accumulated = accumulated + entries[i].weight
        if accumulated >= total * 0.5 then return entries[i].range end
    end
    return entries[#entries].range
end

local function Goal(unitID, x, y, z, radius)
    Spring.SetUnitMoveGoal(unitID, x, y, z, radius or 24)
end

local function HasManualTarget(unitID)
    local list = GG.getUnitTargetList and GG.getUnitTargetList(unitID)
    return list and #list > 0
end

function gadget:AllowCommand(unitID, defID, teamID, cmdID, params, opts)
    if not eligible[defID] then return true end
    opts = opts or {}
    if cmdID == CMD.MOVE_STATE then
        if params and params[1] ~= 1 then Clear(unitID, true) end
        return true
    end
    -- Never interpret engine/internal commands or queued waypoints as fresh
    -- tactical orders. A player's direct orders revoke the tactical objective.
    if opts.internal or opts.shift then return true end
    if cmdID == CMD.ATTACK and params and #params == 1 and CanSteer(unitID)
        and SeenEnemy(unitID, params[1]) and not HasManualTarget(unitID) then
        local range = EffectiveRange(unitID, defID, params[1])
        if range then
            states[unitID] = {
                target = params[1], range = range,
                profile = eligible[defID], phase = "approach",
                side = (unitID % 2 == 0) and 1 or -1,
                passX = nil, passZ = nil,
            }
            -- Consume native Attack so it cannot override manoeuvre goals.
            return false
        end
    end
    if cmdID == CMD.MOVE or cmdID == CMD.STOP or cmdID == CMD.ATTACK
        or cmdID == CMD.FIGHT or cmdID == CMD.PATROL or cmdID == CMD.GUARD
        or cmdID == CMD.LOAD_ONTO or cmdID == CMD.LOAD_UNITS then
        Clear(unitID, true)
    end
    return true
end

function gadget:GameFrame(frame)
    if frame % UPDATE ~= 0 then return end
    for unitID, state in pairs(states) do
        local defID = Spring.GetUnitDefID(unitID)
        if not defID or Spring.GetUnitIsDead(unitID)
            or not SeenEnemy(unitID, state.target) then
            Clear(unitID, true)
        elseif CanSteer(unitID) and not HasManualTarget(unitID) then
            local x, y, z = Spring.GetUnitPosition(unitID)
            local tx, ty, tz = Spring.GetUnitPosition(state.target)
            if x and tx then
                local distance, dx, dz = Distance(x, z, tx, tz)
                local range = state.range
                local nx, nz = dx / max(distance, 1), dz / max(distance, 1)
                local profile = state.profile

                if profile == "hold" then
                    -- Mars: enter preferred range, then hold; reverse only when
                    -- the opponent is dangerously close. Native movement handles
                    -- hull rotation and obstacles.
                    if distance > range * 1.10 then
                        state.phase = "approach"
                        Goal(unitID, tx, ty, tz, range * 0.88)
                    elseif distance < range * 0.38 then
                        state.phase = "withdraw"
                        Goal(unitID, x - nx * range * 0.55, y, z - nz * range * 0.55, 32)
                    elseif state.phase ~= "hold" then
                        state.phase = "hold"
                        Goal(unitID, x, y, z, 16)
                    end

                elseif profile == "circle" then
                    -- Pegasus: orbit the target with a small radial correction.
                    -- Tangential goals change gradually, using native hover pathing.
                    if distance > range * 1.30 then
                        state.phase = "approach"
                        Goal(unitID, tx, ty, tz, range * 0.75)
                    else
                        state.phase = "circle"
                        local desired = range * 0.72
                        local radial = max(-0.65, min(0.65, (distance - desired) / max(desired, 1)))
                        local stride = max(110, min(240, range * 0.35))
                        Goal(unitID,
                            x + (-nz * state.side + nx * radial) * stride,
                            y,
                            z + (nx * state.side + nz * radial) * stride,
                            24)
                    end

                elseif profile == "pass" then
                    -- Savannah Master: commit to a forward pass beyond the
                    -- target, then extend and reacquire for another approach.
                    local stride = max(170, min(360, range * 0.95))
                    if state.phase == "pass" and state.passX then
                        local remaining = Distance(x, z, state.passX, state.passZ)
                        if remaining < 65 then
                            state.phase = "extend"
                            state.passX, state.passZ = nil, nil
                        else
                            Goal(unitID, state.passX, y, state.passZ, 24)
                        end
                    end
                    if state.phase == "extend" then
                        if distance > range * 1.20 then state.phase = "approach" end
                        if state.phase == "extend" then
                            Goal(unitID, x - nx * stride, y, z - nz * stride, 32)
                        end
                    end
                    if state.phase == "approach" then
                        if distance < range * 0.72 then
                            state.phase = "pass"
                            state.passX = tx + nx * stride
                            state.passZ = tz + nz * stride
                            Goal(unitID, state.passX, ty, state.passZ, 24)
                        else
                            Goal(unitID, tx, ty, tz, range * 0.35)
                        end
                    end
                end
                Spring.SetUnitTarget(unitID, state.target, false, true)
            end
        end
    end
end

function gadget:UnitDestroyed(unitID) Clear(unitID, false) end
function gadget:UnitTaken(unitID) Clear(unitID, true) end
function gadget:UnitGiven(unitID) Clear(unitID, true) end
function gadget:Shutdown()
    for unitID in pairs(states) do Clear(unitID, true) end
end
