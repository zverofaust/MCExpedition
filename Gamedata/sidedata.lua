local sidedata = {
	{
		name = "Federated Suns",
		shortName = "FS",
		startUnit = "beacon",
		techBase = "IS",
		texmods = {"DavionGuards"},
	},
	{
		name = "Lyran Alliance",
		shortName = "LA",
		startUnit = "beacon",
		techBase = "IS",
		texmods = {"LyranGuards"},
	},
	{
		name = "Draconis Combine",
		shortName = "DC",
		startUnit = "beacon",
		techBase = "IS",
		texmods = {"SwordofLight"},
	},
	{
		name = "Capellan Confederation",
		shortName = "CC",
		startUnit = "beacon",
		techBase = "IS",
		texmods = {"DeathCommandos"},
	},
	{
		name = "Free Worlds League",
		shortName = "FW",
		startUnit = "beacon",
		techBase = "IS",
		texmods = {"MarikMilitia"},
	},
	{
		name = "Clan Wolf",
		shortName = "WF",
		startUnit = "beacon",
		techBase = "CL",
		texmods = {"WFBeta", "WolfInExile"},
	},
--[[	{
		name = "Clan Jade Falcon",
		shortName = "JF",
		startUnit = "beacon",
	},--]]
	{
		name = "Clan Smoke Jaguar",
		shortName = "SJ",
		startUnit = "beacon",
		techBase = "CL",
		texmods = {"SJAlpha"},
	},
}

-- Mercenary Outfit is a MechCommander: Mercs identity only. Insert it as the
-- first side so direct engine launches, which otherwise inherit sidedata[1],
-- default to MC rather than Federated Suns. MCL/PvP never receives this entry.
if Game and Game.modShortName == "MCM" then
	table.insert(sidedata, 1, {
		name = "Mercenary Outfit",
		shortName = "MC",
		startUnit = "",
		techBase = "merc",
		texmods = {},
	})
end

return sidedata