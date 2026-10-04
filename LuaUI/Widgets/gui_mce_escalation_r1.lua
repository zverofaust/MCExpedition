function widget:GetInfo()
	return {
		name      = "MCE Escalation",
		desc      = "Displays the Expedition escalation level",
		author    = "zvero + ChatGPT",
		date      = "03/10/26",
		license   = "GNU GPL v2",
		layer     = 0,
		enabled   = true,
	}
end

local glColor = gl.Color
local glRect = gl.Rect
local glText = gl.Text
local GetGameRulesParam = Spring.GetGameRulesParam

local vsx, vsy = Spring.GetViewGeometry()

function widget:Initialize()
	if GetGameRulesParam("gamemode") ~= "expedition" then
		widgetHandler:RemoveWidget(self)
	end
end

function widget:ViewResize(viewSizeX, viewSizeY)
	vsx, vsy = viewSizeX, viewSizeY
end

function widget:DrawScreen()
	local level = math.max(0, math.min(100, GetGameRulesParam("EXPEDITION_ESCALATION_LEVEL") or 0))
	local floor = math.max(0, math.min(100, GetGameRulesParam("EXPEDITION_ESCALATION_FLOOR") or 0))

	local width = math.min(460, vsx * 0.32)
	local height = 16
	local x1 = (vsx - width) * 0.5
	local x2 = x1 + width
	local y2 = vsy - 30
	local y1 = y2 - height

	glColor(0, 0, 0, 0.68)
	glRect(x1 - 2, y1 - 2, x2 + 2, y2 + 2)

	glColor(0.12, 0.12, 0.12, 0.88)
	glRect(x1, y1, x2, y2)

	-- The floor is separate so future temporary escalation above the floor
	-- can be shown without redesigning this HUD.
	glColor(0.42, 0.30, 0.08, 0.9)
	glRect(x1, y1, x1 + width * (floor / 100), y2)

	if level > floor then
		glColor(0.75, 0.18, 0.08, 0.95)
		glRect(x1 + width * (floor / 100), y1, x1 + width * (level / 100), y2)
	end

	glColor(1, 1, 1, 0.92)
	glText("ESCALATION  " .. string.format("%d%%", math.floor(level + 0.5)), vsx * 0.5, y1 + 3, 12, "oc")

	glColor(1, 1, 1, 1)
end
