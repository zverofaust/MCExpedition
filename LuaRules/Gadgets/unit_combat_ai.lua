-- MCM Combat AI r12: general vehicle tactical movement prototype.
-- Authors: zvero + ChatGPT
-- Scope: all vehicle-class units; explicit unqueued unit Attack only.
-- Native Move/Stop/Patrol/Fight and manually set targets retain priority.
function gadget:GetInfo()
    return {
        name = "MCM Combat AI r12",
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
local diagnostics = {}
local function Debug(unitID, msg)
    if diagnostics[unitID] ~= msg then
        diagnostics[unitID] = msg
        Spring.Echo("[MCM Combat AI r12] unit " .. unitID .. ": " .. msg)
    end
end
local eligible = {}
local matched = 0

-- Repertoires are based on mobility, not chassis names.
-- Each manoeuvre is independent; the selector rotates among permitted moves.
local profileCounts = {ground = 0, hover = 0}
local repertoires = {
    ground = {"hold", "circle", "broadside"},
    hover = {"circle", "driveby"},
}
for defID, ud in pairs(UnitDefs) do
    local cp = ud.customParams or ud.customparams or {}
    if cp.baseclass == "vehicle" and ud.canMove and not ud.canFly then
        local movement = string.lower(tostring((ud.moveDef and ud.moveDef.name) or ud.movementClass or ""))
        local mobility = movement:find("hover") and "hover" or "ground"
        eligible[defID] = mobility
        profileCounts[mobility] = profileCounts[mobility] + 1
        matched = matched + 1
    end
end

-- Deterministic per-unit variation; synced-safe, no global RNG state.
local function Variation(unitID, frame, salt)
    local value = (unitID * 173 + frame * 37 + salt * 101) % 997
    return value / 997
end

local function ChooseManoeuvre(unitID, state, frame)
    local repertoire = repertoires[state.mobility]
    local options = {}
    for i = 1, #repertoire do
        if repertoire[i] ~= state.manoeuvre then
            options[#options + 1] = repertoire[i]
        end
    end
    local index = 1 + math.floor(Variation(unitID, frame, state.transitions) * #options)
    state.manoeuvre = options[index]
    state.phase = "approach"
    state.untilFrame = frame + 90 + math.floor(Variation(unitID, frame, 7) * 120)
    state.goalX, state.goalZ = nil, nil
    state.orbitAligned = false
    state.transitions = state.transitions + 1
    Debug(unitID, "selected " .. state.manoeuvre .. " (transition " .. state.transitions .. ")")
end

function gadget:Initialize()
    Spring.Echo("[MCM Combat AI r12] initialized; eligible UnitDefs=" .. matched .. " (ground=" .. profileCounts.ground .. ", hover=" .. profileCounts.hover .. ")")
    for _, unitID in ipairs(Spring.GetAllUnits()) do
        local defID = Spring.GetUnitDefID(unitID)
        if eligible[defID] then Debug(unitID, "eligible unit initialized") end
    end
end

function gadget:UnitCreated(unitID, defID)
    if eligible[defID] then Debug(unitID, "eligible unit created") end
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
        if wd and wd.range and wd.range > 0 and not wd.manualFire then
            local weight = max(1, (wd.damages and (wd.damages[0] or wd.damages[1])) or 1)
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
                mobility = eligible[defID], manoeuvre = nil,
                phase = "approach", transitions = 0,
                side = (unitID % 2 == 0) and 1 or -1,
                orbitAligned = false,
            }
            ChooseManoeuvre(unitID, states[unitID], Spring.GetGameFrame())
            Debug(unitID, "acquired " .. eligible[defID] .. " target " .. params[1] .. " at range " .. math.floor(range))
            -- Consume native Attack so it cannot override manoeuvre goals.
            return false
        end
    end
    if cmdID == CMD.ATTACK and params and #params == 1 then
        Debug(unitID, "Attack passed to engine (movestate/LOS/target/manual-target gate)")
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
                local manoeuvre = state.manoeuvre
                local finished = false

                if manoeuvre == "hold" then
                    if distance > range * 1.10 then
                        state.phase = "approach"
                        Goal(unitID, tx, ty, tz, range * 0.88)
                    elseif distance < range * 0.38 then
                        state.phase = "withdraw"
                        Goal(unitID, x - nx * range * 0.55, y, z - nz * range * 0.55, 32)
                    else
                        if state.phase ~= "hold" then Goal(unitID, x, y, z, 16) end
                        state.phase = "hold"
                        finished = frame >= state.untilFrame
                    end

                elseif manoeuvre == "circle" then
                    if distance > range * 1.30 then
                        state.phase = "approach"
                        Goal(unitID, tx, ty, tz, range * 0.75)
                    else
                        state.phase = "circle"
                        if not state.orbitAligned then
                            local heading = Spring.GetUnitHeading(unitID)
                            if heading then
                                local angle = heading * (2 * math.pi / 65536)
                                local tangentX, tangentZ = -nz * state.side, nx * state.side
                                if sin(angle) * tangentX + cos(angle) * tangentZ < 0 then
                                    state.side = -state.side
                                end
                                state.orbitAligned = true
                            end
                        end
                        local desired = range * 0.72
                        local radial = max(-0.65, min(0.65, (distance - desired) / max(desired, 1)))
                        local stride = max(110, min(240, range * 0.35))
                        Goal(unitID, x + (-nz * state.side + nx * radial) * stride,
                            y, z + (nx * state.side + nz * radial) * stride, 24)
                        finished = frame >= state.untilFrame
                    end

                elseif manoeuvre == "broadside" then
                    if distance > range * 1.15 then
                        state.phase = "approach"
                        Goal(unitID, tx, ty, tz, range * 0.80)
                    else
                        if not state.goalX then
                            local stride = max(90, min(240, range * (0.24 + Variation(unitID, frame, 3) * 0.18)))
                            local side = state.side
                            state.goalX = x - nz * side * stride + nx * (distance - range * 0.75) * 0.3
                            state.goalZ = z + nx * side * stride + nz * (distance - range * 0.75) * 0.3
                            state.phase = "broadside"
                        end
                        Goal(unitID, state.goalX, y, state.goalZ, 32)
                        finished = Distance(x, z, state.goalX, state.goalZ) < 45
                            or frame >= state.untilFrame + 90
                    end

                elseif manoeuvre == "driveby" then
                    if state.phase == "pass" and state.goalX then
                        Goal(unitID, state.goalX, y, state.goalZ, 24)
                        finished = Distance(x, z, state.goalX, state.goalZ) < 55
                            or frame >= state.untilFrame + 120
                    elseif distance < range * 0.72 then
                        local stride = max(90, min(170, range * (0.38 + Variation(unitID, frame, 5) * 0.20)))
                        state.phase = "pass"
                        state.goalX = tx + nx * stride
                        state.goalZ = tz + nz * stride
                        Goal(unitID, state.goalX, ty, state.goalZ, 24)
                    else
                        state.phase = "approach"
                        Goal(unitID, tx, ty, tz, range * 0.35)
                    end
                end

                if finished then ChooseManoeuvre(unitID, state, frame) end
                Debug(unitID, "executing " .. state.manoeuvre .. " phase " .. state.phase)
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
