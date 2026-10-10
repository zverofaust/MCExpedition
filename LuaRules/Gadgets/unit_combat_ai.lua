-- MCM Vehicle ROE r27: native movement, defensive engagement prototype.
-- Authors: zvero + ChatGPT
-- Vehicle manoeuvres intentionally disabled. Native engine handles firing and aiming.
-- Safety rollback: disable experimental pursuit goals pending lifecycle investigation.
function gadget:GetInfo()
    return {
        name = "MCM Vehicle ROE r27",
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
local Config = VFS.Include("LuaRules/Configs/combat_ai/config.lua")
local eligible, ranges, tracked = {}, {}, {}
local engagements = {}
local roster, rosterIndex = {}, {}
local cursor = 1
local reported = {}
local SCAN_INTERVAL = 30
local SCAN_BATCH = 48
local spSetUnitTarget = Spring.SetUnitTarget
local roeNames = {[0] = "hold", [1] = "maneuver", [2] = "roam"}

-- Cache longest automatic weapon range and radar range per definition.
-- Weapon range is an engagement boundary, not a substitute for LOS/radar.
local function LongestWeaponRange(defID)
    local longest = 0
    for _, mount in ipairs(UnitDefs[defID].weapons or {}) do
        local wd = WeaponDefs[mount.weaponDef]
        if wd and wd.range and wd.range > longest and not wd.manualFire then
            longest = wd.range
        end
    end
    return longest > 0 and longest or nil
end

for defID, ud in pairs(UnitDefs) do
    local cp = ud.customParams or ud.customparams or {}
    if cp.baseclass == "vehicle" and ud.canMove and not ud.canFly then
        local weapon = LongestWeaponRange(defID)
        if weapon then
            eligible[defID] = true
            ranges[defID] = {
                weapon = weapon,
                radar = (ud.radarDistance and ud.radarDistance > 0 and ud.radarDistance)
                    or (ud.radarDistance == 0 and Config.defaultRadar)
                    or Config.defaultRadar,
            }
        end
    end
end

local function Bound(defID, mode, kind)
    local profile = Config.roe[roeNames[mode]]
    if not profile then return nil end
    local r = ranges[defID]
    if mode == 0 and kind == "leash" then return 0 end
    return math.max(r.weapon, r.radar * profile[kind])
end

local function Add(unitID, defID)
    if not eligible[defID] or rosterIndex[unitID] then return end
    roster[#roster + 1] = unitID
    rosterIndex[unitID] = #roster
end

local function Remove(unitID)
    tracked[unitID], reported[unitID], engagements[unitID] = nil, nil, nil
    local index = rosterIndex[unitID]
    if not index then return end
    local last = roster[#roster]
    roster[index], roster[#roster] = last, nil
    rosterIndex[unitID] = nil
    if last ~= unitID then rosterIndex[last] = index end
    if cursor > #roster then cursor = 1 end
end

local function FirstCommand(unitID)
    local commands = Spring.GetUnitCommands(unitID, 1)
    local command = commands and commands[1]
    return command and command.id or nil
end

local function CanMonitor(unitID)
    if Spring.GetUnitTransporter(unitID) then return false end
    if GG.turning and GG.turning[unitID] then return false end
    if Spring.MoveCtrl and Spring.MoveCtrl.IsEnabled and Spring.MoveCtrl.IsEnabled(unitID) then return false end
    local state = Spring.GetUnitStates(unitID)
    return state and roeNames[state.movestate] ~= nil
end

local function Check(unitID)
    local defID = Spring.GetUnitDefID(unitID)
    if not defID or not eligible[defID] then return end
    local state = Spring.GetUnitStates(unitID)
    local mode = state and state.movestate
    local commandID = FirstCommand(unitID)
    local manual = Targeting.HasManualTarget(unitID)
    local can = CanMonitor(unitID)
    -- STOP cancels movement orders, not automatic defensive weapon engagement.
    local blocked = false
    local acquisition = mode and Bound(defID, mode, "acquisition")
    local leash = mode and Bound(defID, mode, "leash")
    local target = acquisition and Targeting.AutoTarget(unitID, acquisition)
    local frame = Spring.GetGameFrame()
    local engagement = engagements[unitID]
    local eligibleNow = not blocked and can and not manual and roeNames[mode] ~= nil
    if engagement and (not eligibleNow or engagement.mode ~= mode) then
        engagements[unitID] = nil
        Spring.Echo("[MCM Vehicle ROE r27] unit " .. unitID
            .. " defensive engagement cancelled (control state changed)")
        engagement = nil
    elseif engagement and target then
        if engagement.contactLost then
            Spring.Echo("[MCM Vehicle ROE r27] unit " .. unitID .. " contact restored")
        end
        engagement.target = target
        engagement.lastContactFrame = frame
        engagement.contactLost = false
    elseif engagement and not target then
        if not engagement.contactLost then
            engagement.contactLost = true
            Spring.Echo("[MCM Vehicle ROE r27] unit " .. unitID .. " contact lost; holding engagement")
        end
        if frame - engagement.lastContactFrame >= Config.roe[roeNames[mode]].inactivitySeconds * 30 then
            engagements[unitID] = nil
            Spring.Echo("[MCM Vehicle ROE r27] unit " .. unitID
                .. " defensive engagement ended (contact timeout)")
            engagement = nil
        end
    end
    -- Explicitly hand off observed targets to native weapon aiming. This does not
    -- issue an ATTACK order, so no movement or pursuit is requested.
    if eligibleNow and target and spSetUnitTarget then
        if tracked[unitID] ~= target then
            spSetUnitTarget(unitID, target)
        end
    elseif tracked[unitID] and spSetUnitTarget then
        spSetUnitTarget(unitID, nil)
    end
    if target and not engagement and eligibleNow then
        local x, y, z = Spring.GetUnitPosition(unitID)
        if x then
            engagements[unitID] = {
                originX = x, originY = y, originZ = z,
                mode = mode, acquisition = acquisition, leash = leash,
                target = target, started = frame, lastContactFrame = frame,
                contactLost = false,
            }
            Spring.Echo("[MCM Vehicle ROE r27] unit " .. unitID
                .. " engagement began; ROE=" .. roeNames[mode]
                .. " acquisition=" .. math.floor(acquisition)
                .. " leash=" .. math.floor(leash) .. "; origin recorded")
        end
    end
    -- Diagnostic sampling: command queues no longer block defensive contact; report only when a visible enemy is found, and
    -- only once per change in gate status to avoid per-frame log spam.
    if target then
        local reason = "mode=" .. tostring(mode)
            .. " command=" .. tostring(commandID)
            .. " manual=" .. tostring(not not manual)
            .. " canMonitor=" .. tostring(not not can)
            .. " stopped=" .. tostring(not not blocked)
        if reported[unitID] ~= reason then
            reported[unitID] = reason
            Spring.Echo("[MCM Vehicle ROE r27] unit " .. unitID
                .. " detected enemy " .. target .. " | " .. reason)
        end
        if not blocked and can and not manual then
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
    Spring.Echo("[MCM Vehicle ROE r27] initialized; vehicle definitions="
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
            tracked[unitID], engagements[unitID] = nil, nil
        elseif cmdID == CMD.MOVE_STATE then
            tracked[unitID], engagements[unitID] = nil, nil
        elseif cmdID == CMD.MOVE or cmdID == CMD.FIGHT
            or cmdID == CMD.PATROL or cmdID == CMD.GUARD
            or cmdID == CMD.ATTACK then
            tracked[unitID], engagements[unitID] = nil, nil
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
    tracked, reported, engagements = {}, {}, {}
end
