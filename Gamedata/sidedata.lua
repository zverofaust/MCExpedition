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

-- Mercenary Outfit belongs to the MCM game package itself. Gamedata is parsed
-- while the engine is constructing game metadata, before runtime Game globals
-- are reliable, so do not gate this entry on Game.modShortName. The separate
-- MCL package retains its own sidedata and therefore never advertises MC.
table.insert(sidedata, 1, {
	name = "Mercenary Outfit",
	shortName = "MC",
	startUnit = "",
	techBase = "merc",
	texmods = {},
})

return sidedata