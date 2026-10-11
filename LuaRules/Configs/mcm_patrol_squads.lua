--------------------------------------------------------------------------------
-- MechCommander: Mercs - Patrol squad templates and settings
-- Authors: zvero + ChatGPT
--------------------------------------------------------------------------------

return {
    squads = {
        {id = "scorpion", name = "Scorpion Patrol", units = {{"Scorpion", 4}}, weight = 3},
        {id = "hover", name = "Hover Patrol", units = {{"Pegasus", 2}, {"Savannah", 3}}, weight = 3},
        {id = "combined", name = "Combined Arms Patrol", units = {{"Vedette", 2}, {"Manticore", 2}, {"LRMCarrier", 1}}, weight = 2},
    },
    -- One patrol per two authored bases, plus one per three encounter sites.
    basesPerSquad = 2,
    encountersPerSquad = 3,
    minimumSquads = 2,
    maximumSquads = 8,
    spawnRadius = 240,
    spawnSpacing = 45,
    waypointRadius = 210,
    arrivalRadius = 290,
    cohesionRadius = 500,
    cohesionReleaseRadius = 310,
    cohesionTimeoutFrames = 30 * 12,
    updateFrames = 30,
    minimumWaypointDistance = 800,
}
