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

-- Mercenary Outfit is a MechCommander: Mercs identity only. Keeping this
-- conditional at engine-facing sidedata prevents MCL/PvP lobbies and faction
-- selectors from ever advertising or selecting the Merc side after integration.
if Game and Game.modShortName == "MCM" then
	sidedata[#sidedata + 1] = {
		name = "Mercenary Outfit",
		shortName = "MC",
		startUnit = "",
		techBase = "merc",
		texmods = {},
	}
end

return sidedata