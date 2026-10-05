function widget:GetInfo()
	return {
		name      = "MCM Expedition Extraction Timer",
		desc      = "Displays the active Expedition extraction countdown",
		author    = "zvero + ChatGPT",
		date      = "01/10/26",
		license   = "GNU GPL v2",
		layer     = 0,
		enabled   = true,
	}
end

local glText = gl.Text
local glColor = gl.Color
local glRect = gl.Rect
local GetGameFrame = Spring.GetGameFrame
local GetMyTeamID = Spring.GetMyTeamID
local GetTeamRulesParam = Spring.GetTeamRulesParam

function widget:DrawScreen()
	local teamID = GetMyTeamID()
	if GetTeamRulesParam(teamID, "EXPEDITION_STATE") ~= "EXTRACTION_LANDED" then
		return
	end

	local endFrame = GetTeamRulesParam(teamID, "EXPEDITION_EXTRACTION_END_FRAME")
	if not endFrame or endFrame < 0 then
		return
	end

	local seconds = math.max(0, math.ceil((endFrame - GetGameFrame()) / 30))
	local minutes = math.floor(seconds / 60)
	local remaining = string.format("%d:%02d", minutes, seconds % 60)
	local vsx, vsy = Spring.GetViewGeometry()
	local x = vsx * 0.5
	local y = vsy * 0.68

	glColor(0, 0, 0, 0.62)
	glRect(x - 105, y - 35, x + 105, y + 36)

	glColor(1, 1, 1, 0.85)
	glText("EXTRACTION", x, y + 11, 14, "oc")

	glColor(1, 1, 1, 1)
	glText(remaining, x, y - 21, 30, "oc")
	glColor(1, 1, 1, 1)
end
