-- MCM Combat AI targeting r1
-- Authors: zvero + ChatGPT
-- Pure targeting/eligibility queries; never issues movement orders.
local Targeting = {}
function Targeting.SeenEnemy(unitID, targetID)
    if not Spring.ValidUnitID(targetID) or Spring.GetUnitIsDead(targetID) then return false end
    local teamA, teamB = Spring.GetUnitTeam(unitID), Spring.GetUnitTeam(targetID)
    if not teamA or not teamB or Spring.AreTeamsAllied(teamA, teamB) then return false end
    local allyTeam = Spring.GetUnitAllyTeam(unitID)
    local los = allyTeam and Spring.GetUnitLosState(targetID, allyTeam, true)
    return los and (los % 4 ~= 0)
end
function Targeting.AutoTarget(unitID, range)
    local x, _, z = Spring.GetUnitPosition(unitID)
    if not x then return nil end
    local nearest, nearestDistance = nil, range * range
    local candidates = Spring.GetUnitsInCylinder(x, z, range)
    for i = 1, #candidates do
        local enemy = candidates[i]
        if enemy ~= unitID and Targeting.SeenEnemy(unitID, enemy) then
            local ex, _, ez = Spring.GetUnitPosition(enemy)
            if ex then
                local dx, dz = ex - x, ez - z
                local d = dx * dx + dz * dz
                if d < nearestDistance then
                    nearest, nearestDistance = enemy, d
                end
            end
        end
    end
    return nearest
end
function Targeting.HasManualTarget(unitID)
    local list = GG.getUnitTargetList and GG.getUnitTargetList(unitID)
    return list and #list > 0
end
return Targeting
