-- MCM Vehicle ROE Range Ring r1
-- Authors: zvero + ChatGPT
-- Selected vehicles only. Visualization uses radar range, not weapon range.
function widget:GetInfo()
    return {
        name = "MCM Vehicle ROE Range Ring r1",
        desc = "Purple ROE radar-based radius for selected ground vehicles",
        author = "zvero + ChatGPT",
        date = "2026-10-10",
        license = "GPL v2 or later",
        layer = 0,
        enabled = true,
    }
end

local spGetSelectedUnits = Spring.GetSelectedUnits
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitStates = Spring.GetUnitStates
local spGetUnitSensorRadius = Spring.GetUnitSensorRadius
local glColor = gl.Color
local glLineWidth = gl.LineWidth
local glDrawGroundCircle = gl.DrawGroundCircle

local DEFAULT_RADAR = 650
local CIRCLE_SEGMENTS = 96
local COLOR = {0.75, 0.25, 1.0, 0.85}
local eligible = {}

for defID, ud in pairs(UnitDefs) do
    local cp = ud.customParams or ud.customparams or {}
    if cp.baseclass == "vehicle" and ud.canMove and not ud.canFly then
        eligible[defID] = true
    end
end

local function RadarRadius(unitID, defID)
    -- Query the live radius first so modoption changes to sensor range are respected.
    local radius = spGetUnitSensorRadius and spGetUnitSensorRadius(unitID, "radar")
    if radius and radius > 0 then return radius end
    local ud = UnitDefs[defID]
    if ud and ud.radarDistance and ud.radarDistance > 0 then
        return ud.radarDistance
    end
    return DEFAULT_RADAR
end

function widget:DrawWorld()
    local selected = spGetSelectedUnits()
    if not selected or #selected == 0 then return end
    glLineWidth(2)
    glColor(COLOR)
    for i = 1, #selected do
        local unitID = selected[i]
        local defID = spGetUnitDefID(unitID)
        if defID and eligible[defID] then
            local state = spGetUnitStates(unitID)
            local mode = state and state.movestate
            local multiplier = mode == 1 and 0.75 or mode == 2 and 1.5 or nil
            if multiplier then
                local x, y, z = spGetUnitPosition(unitID)
                if x then
                    local radius = RadarRadius(unitID, defID) * multiplier
                    glDrawGroundCircle(x, y, z, radius, CIRCLE_SEGMENTS)
                end
            end
        end
    end
    glColor(1, 1, 1, 1)
    glLineWidth(1)
end
