-- MCM Combat AI configuration r2
-- Authors: zvero + ChatGPT
-- ROE acquisition and displacement limits use the greater of longest
-- automatically fired weapon range and a fraction of the vehicle radar range.
local Config = {
    updateFrames = 15,
    defaultRadar = 650,
    repertoires = {
        ground = {"hold", "circle", "broadside", "approach"},
        hover = {"circle", "driveby"},
    },
    roe = {
        hold = {acquisition = 1.0, leash = 0, inactivitySeconds = 5, pursue = false, search = false, interruptReturn = false},
        maneuver = {acquisition = 0.75, leash = 0.75, inactivitySeconds = 10, pursue = true, search = false, interruptReturn = false},
        roam = {acquisition = 1.5, leash = 1.5, inactivitySeconds = 15, pursue = true, search = true, interruptReturn = true},
    },
}
return Config
