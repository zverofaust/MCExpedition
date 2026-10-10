-- MCM Combat AI configuration r1
-- Authors: zvero + ChatGPT
-- ROE values are provisional; behavioural integration follows the module refactor.
local Config = {
    updateFrames = 15,
    repertoires = {
        ground = {"hold", "circle", "broadside", "approach"},
        hover = {"circle", "driveby"},
    },
    roe = {
        hold = {acquisition = 1.0, leash = 0.5, inactivitySeconds = 5, pursue = false, search = false, interruptReturn = false},
        maneuver = {acquisition = 1.5, leash = 2.0, inactivitySeconds = 10, pursue = true, search = false, interruptReturn = false},
        roam = {acquisition = 2.5, leash = 4.0, inactivitySeconds = 15, pursue = true, search = true, interruptReturn = true},
    },
}
return Config
