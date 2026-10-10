-- MCM Vehicle ROE r18: native movement, defensive engagement prototype.
-- Authors: zvero + ChatGPT
-- Vehicle manoeuvres intentionally disabled. Native engine handles firing and aiming.
-- Only idle Hold Position vehicles are monitored in this initial validation revision.
function gadget:GetInfo()
    return {
        name = "MCM Vehicle ROE r18",
        desc = "Lightweight vehicle engagement policy; native combat movement",
        author = "zvero + ChatGPT",
        date = "2026-10-10",
        license = "GPL v2 or later",
        layer = 10,
        enabled = true,
    }
end

if not gadgetHandler:IsSyncedCode() then return false end

local Targeting = VFS.Include("LuaRules/Configs/combat_ai/targeting.lua")
local eligible, ranges, tracked, stopped = {}, {}, {}, {}
local roster, rosterIndex = {}, {}
local cursor = 1
local reported = {}
local SCAN_INTERVAL = 30
local SCAN_BATCH = 48

-- Cache effective ranges once per UnitDef, not on every acquisition pass.
local function EffectiveRange(defID)
    local entries, total = {}, 0
    for _, mount in ipairs(UnitDefs[defID].weapons or {}) do
        local wd = WeaponDefs[mount.weaponDef]
        if wd and wd.range and wd.range > 0 and not wd.manualFire then
            local weight = math.max(1, (wd.damages and (wd.damages[0] or wd.damages[1])) or 1)
            entries[#entries + 1] = {range = wd.range, weight = weight}
            total = total + weight
        end
    end
    if total == 0 then return nil end
    table.sort(entries, function(a, b) return a.range < b.range end)
    local sum = 0
    for i = 1, #entries do
        sum = sum + entries[i].weight
        if sum >= total * 0.5 then return entries[i].range end
    end
end

for defID, ud in pairs(UnitDefs) do
    local cp = ud.customParams or ud.customparams or {}
    if cp.baseclass == "vehicle" and ud.canMove and not ud.canFly then
        local range = EffectiveRange(defID)
        if range then eligible[defID], ranges[defID] = true, range end
    end
end

local function Add(unitID, defID)
    if not eligible[defID] or rosterIndex[unitID] then return end
    roster[#roster + 1] = unitID
    rosterIndex[unitID] = #roster
end

local function Remove(unitID)
    tracked[unitID], stopped[unitID], reported[unitID] = nil, nil, nil
    local index = rosterIndex[unitID]
    if not index then return end
    local last = roster[#roster]
    roster[index], roster[#roster] = last, nil
    rosterIndex[unitID] = nil
    if last ~= unitID then rosterIndex[last] = index end
    if cursor > #roster then cursor = 1 end
end

local function Idle(unitID)
    local commands = Spring.GetUnitCommands(unitID, 1)
    return commands and #commands == 0
end

local function CanMonitor(unitID)
    if Spring.GetUnitTransporter(unitID) then return false end
    if GG.turning and GG.turning[unitID] then return false end
    if Spring.MoveCtrl and Spring.MoveCtrl.IsEnabled and Spring.MoveCtrl.IsEnabled(unitID) then return false end
    local state = Spring.GetUnitStates(unitID)
    return state and state.movestate == 0
end

local function Check(unitID)
    local defID = Spring.GetUnitDefID(unitID)
    if not defID or not eligible[defID] then return end
    local state = Spring.GetUnitStates(unitID)
    local mode = state and state.movestate
    local idle = Idle(unitID)
    local manual = Targeting.HasManualTarget(unitID)
    local can = CanMonitor(unitID)
    local blocked = stopped[unitID]
    local target = Targeting.AutoTarget(unitID, ranges[defID])
    -- Diagnostic sampling: report only when a visible enemy is found, and
    -- only once per change in gate status to avoid per-frame log spam.
    if target then
        local reason = "mode=" .. tostring(mode)
            .. " idle=" .. tostring(idle)
            .. " manual=" .. tostring(not not manual)
            .. " canMonitor=" .. tostring(not not can)
            .. " stopped=" .. tostring(not not blocked)
        if reported[unitID] ~= reason then
            reported[unitID] = reason
            Spring.Echo("[MCM Vehicle ROE r18] unit " .. unitID
                .. " detected enemy " .. target .. " | " .. reason)
        end
        if not blocked and can and idle and not manual then
            tracked[unitID] = target
        else
            tracked[unitID] = nil
        end
    else
        tracked[unitID], reported[unitID] = nil, nil
    end
end

function gadget:Initialize()
    local all = Spring.GetAllUnits()
    for i = 1, #all do Add(all[i], Spring.GetUnitDefID(all[i])) end
    Spring.Echo("[MCM Vehicle ROE r18] initialized; vehicle definitions="
        .. (function() local n=0 for _ in pairs(eligible) do n=n+1 end return n end)()
        .. "; registered vehicles=" .. #roster)
end

function gadget:UnitCreated(unitID, defID)
    Add(unitID, defID)
end

function gadget:UnitDestroyed(unitID) Remove(unitID) end
function gadget:UnitTaken(unitID) tracked[unitID] = nil end
function gadget:UnitGiven(unitID) tracked[unitID] = nil end

function gadget:AllowCommand(unitID, defID, teamID, cmdID, params, opts)
    if not eligible[defID] then return true end
    opts = opts or {}
    if not opts.internal and not opts.shift then
        if cmdID == CMD.STOP then
            stopped[unitID] = true
            tracked[unitID] = nil
        elseif cmdID == CMD.MOVE_STATE then
            stopped[unitID] = nil
            tracked[unitID] = nil
        elseif cmdID == CMD.MOVE or cmdID == CMD.FIGHT
            or cmdID == CMD.PATROL or cmdID == CMD.GUARD
            or cmdID == CMD.ATTACK then
            stopped[unitID] = nil
            tracked[unitID] = nil
        end
    end
    -- Never consume or replace player commands: native engine executes them.
    return true
end

function gadget:GameFrame(frame)
    if frame % SCAN_INTERVAL ~= 0 or #roster == 0 then return end
    local batch = math.min(SCAN_BATCH, #roster)
    for _ = 1, batch do
        if cursor > #roster then cursor = 1 end
        local unitID = roster[cursor]
        cursor = cursor + 1
        Check(unitID)
    end
end

function gadget:Shutdown()
    tracked, stopped, reported = {}, {}, {}
end
