function gadget:GetInfo()
	return {
		name      = "Game - Expedition Escalation",
		desc      = "Tracks the time-based Expedition escalation floor and level",
		author    = "zvero + ChatGPT",
		date      = "03/10/26",
		license   = "GNU GPL v2",
		layer     = 4,
		enabled   = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

local ESCALATION_DURATION = 30 * 60 * 30
local UPDATE_RATE = 15

local startFrame = 0
local escalationFloor = 0
local escalationLevel = 0

local function PublishEscalation()
	Spring.SetGameRulesParam("EXPEDITION_ESCALATION_FLOOR", escalationFloor, {public = true})
	Spring.SetGameRulesParam("EXPEDITION_ESCALATION_LEVEL", escalationLevel, {public = true})
end

function gadget:GameFrame(frame)
	if frame % UPDATE_RATE ~= 0 then
		return
	end

	escalationFloor = math.min(100, ((frame - startFrame) / ESCALATION_DURATION) * 100)

	-- For the initial implementation the level simply follows the floor.
	-- Future player activity can raise the level above the floor and decay
	-- toward it without changing the public interface.
	escalationLevel = math.max(escalationFloor, escalationLevel)

	PublishEscalation()
end

function gadget:Initialize()
	if Spring.GetGameRulesParam("gamemode") ~= "expedition" then
		gadgetHandler:RemoveGadget(self)
		return
	end

	startFrame = Spring.GetGameFrame()
	Spring.SetGameRulesParam("EXPEDITION_ESCALATION_START_FRAME", startFrame, {public = true})
	Spring.SetGameRulesParam("EXPEDITION_ESCALATION_END_FRAME", startFrame + ESCALATION_DURATION, {public = true})
	PublishEscalation()
end
