function gadget:GetInfo()
	return {
		name      = "Game - Expedition",
		desc      = "Controls the Expedition match lifecycle and extraction",
		author    = "zvero + ChatGPT",
		date      = "01/10/26",
		license   = "GNU GPL v2",
		layer     = 4,
		enabled   = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

local EXTRACTION_TIME = 60 * 30
local CMD_EXTRACTION = GG.CustomCommands.GetCmdID("CMD_EXPEDITION_EXTRACTION")
local extractionCmdDesc = {
	id      = CMD_EXTRACTION,
	type    = CMDTYPE.ICON,
	name    = "Extraction",
	action  = "expedition_extraction",
	tooltip = "Call your dropship for extraction. Once called, extraction cannot be cancelled.",
	texture = "bitmaps/ui/submit.png",
}

local expeditionMode = false
local teamStates = {}
local extractionDropships = {}

local function SetState(teamID, state)
	teamStates[teamID] = state
	Spring.SetTeamRulesParam(teamID, "EXPEDITION_STATE", state, {public = true})
end

local function IsDropZone(unitDefID)
	return GG.DROPZONE_IDS and GG.DROPZONE_IDS[unitDefID]
end

local function AddExtractionCommand(unitID, unitDefID, teamID)
	if expeditionMode and IsDropZone(unitDefID) and not Spring.FindUnitCmdDesc(unitID, CMD_EXTRACTION) then
		Spring.InsertUnitCmdDesc(unitID, extractionCmdDesc)
		if not teamStates[teamID] then
			SetState(teamID, "ACTIVE")
		end
	end
end

local function BeginExtraction(dropZoneID, teamID)
	if teamStates[teamID] ~= "ACTIVE" then
		return false
	end
	local beaconID = GG.dropZoneBeaconIDs and GG.dropZoneBeaconIDs[teamID]
	if not beaconID or not Spring.ValidUnitID(beaconID) or Spring.GetUnitIsDead(beaconID) then
		Spring.SendMessageToTeam(teamID, "Extraction unavailable: no active DropZone beacon.")
		return false
	end
	if not GG.DropshipExtraction then
		Spring.SendMessageToTeam(teamID, "Extraction unavailable: dropship system is not ready.")
		return false
	end
	local side = GG.teamSide and GG.teamSide[teamID]
	local dropshipDef = side and UnitDefNames[side .. "_dropship_leopard"]
	if not dropshipDef then
		Spring.SendMessageToTeam(teamID, "Extraction unavailable: no dropship definition for this team.")
		return false
	end
	SetState(teamID, "EXTRACTION_INBOUND")
	Spring.SetTeamRulesParam(teamID, "EXPEDITION_EXTRACTION_END_FRAME", -1, {public = true})
	Spring.SendMessageToTeam(teamID, "Extraction requested. Dropship inbound.")
	local dropshipID = GG.DropshipExtraction(beaconID, dropZoneID, teamID, dropshipDef.id)
	if not dropshipID then
		SetState(teamID, "ACTIVE")
		Spring.SendMessageToTeam(teamID, "Extraction request failed.")
		return false
	end
	extractionDropships[dropshipID] = teamID
	return true
end

function GG.ExpeditionDropshipLanded(dropshipID, teamID)
	if not expeditionMode or extractionDropships[dropshipID] ~= teamID or teamStates[teamID] ~= "EXTRACTION_INBOUND" then
		return
	end
	local endFrame = Spring.GetGameFrame() + EXTRACTION_TIME
	SetState(teamID, "EXTRACTION_LANDED")
	Spring.SetTeamRulesParam(teamID, "EXPEDITION_EXTRACTION_END_FRAME", endFrame, {public = true})
	Spring.SendMessageToTeam(teamID, "Dropship landed. Extraction departs in 60 seconds.")
end

local function FinishExtraction(teamID, dropshipID)
	local beaconID = GG.dropZoneBeaconIDs and GG.dropZoneBeaconIDs[teamID]
	local dropZoneID = GG.teamDropZones and GG.teamDropZones[teamID]
	if not beaconID or not dropZoneID then return end
	local x, _, z = Spring.GetUnitPosition(dropZoneID)
	if not x then return end
	local radius = Spring.GetUnitRulesParam(beaconID, "BEACON_CAP_RADIUS") or 460
	local extracted = {}
	local extractedSet = {}
	for _, unitID in ipairs(Spring.GetUnitsInCylinder(x, z, radius, teamID)) do
		local unitDefID = Spring.GetUnitDefID(unitID)
		local cp = unitDefID and UnitDefs[unitDefID].customParams
		if cp and cp.baseclass == "mech" then
			extracted[#extracted + 1] = unitID
			extractedSet[unitID] = true
		end
	end
	local leftBehind = {}
	for _, unitID in ipairs(Spring.GetTeamUnits(teamID)) do
		local unitDefID = Spring.GetUnitDefID(unitID)
		local cp = unitDefID and UnitDefs[unitDefID].customParams
		if cp and cp.baseclass == "mech" and not extractedSet[unitID] then
			leftBehind[#leftBehind + 1] = unitID
		end
	end
	Spring.Echo("[MCE Expedition] EXPEDITION COMPLETE - team", teamID)
	Spring.Echo("[MCE Expedition] Extracted units:", #extracted, "Left behind:", #leftBehind, "Radius:", radius)
	for _, unitID in ipairs(extracted) do
		Spring.Echo("[MCE Expedition] Extracted:", UnitDefs[Spring.GetUnitDefID(unitID)].name, unitID)
	end
	for _, unitID in ipairs(leftBehind) do
		Spring.Echo("[MCE Expedition] Left Behind:", UnitDefs[Spring.GetUnitDefID(unitID)].name, unitID)
	end
	Spring.SendMessageToTeam(teamID, "EXPEDITION COMPLETE - Extracted: " .. #extracted .. "  Left Behind: " .. #leftBehind)
	SetState(teamID, "EXTRACTION_DEPARTING")
	Spring.SetTeamRulesParam(teamID, "EXPEDITION_EXTRACTED_COUNT", #extracted, {public = true})
	Spring.SetTeamRulesParam(teamID, "EXPEDITION_LEFT_BEHIND_COUNT", #leftBehind, {public = true})
	local env = Spring.UnitScript.GetScriptEnv(dropshipID)
	if env and env.ExtractionTakeOff then
		Spring.UnitScript.CallAsUnit(dropshipID, env.ExtractionTakeOff)
	end
end

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID)
	if expeditionMode and cmdID == CMD_EXTRACTION and IsDropZone(unitDefID) then
		BeginExtraction(unitID, teamID)
		return false
	end
	return true
end

function gadget:UnitCreated(unitID, unitDefID, teamID)
	AddExtractionCommand(unitID, unitDefID, teamID)
end

function gadget:UnitDestroyed(unitID, unitDefID, teamID)
	if extractionDropships[unitID] then
		if teamStates[teamID] ~= "EXTRACTION_DEPARTING" then
			SetState(teamID, "ACTIVE")
			Spring.SetTeamRulesParam(teamID, "EXPEDITION_EXTRACTION_END_FRAME", -1, {public = true})
			Spring.SendMessageToTeam(teamID, "Extraction dropship lost. Extraction reset for prototype testing.")
		else
			SetState(teamID, "COMPLETE")
		end
		extractionDropships[unitID] = nil
	end
end

function gadget:GameFrame(frame)
	if not expeditionMode then return end
	for dropshipID, teamID in pairs(extractionDropships) do
		if teamStates[teamID] == "EXTRACTION_LANDED" then
			local endFrame = Spring.GetTeamRulesParam(teamID, "EXPEDITION_EXTRACTION_END_FRAME")
			if endFrame and endFrame >= 0 and frame >= endFrame then
				FinishExtraction(teamID, dropshipID)
			end
		end
	end
end

function gadget:Initialize()
	expeditionMode = Spring.GetGameRulesParam("gamemode") == "expedition"
	if not expeditionMode then
		gadgetHandler:RemoveGadget(self)
		return
	end
	for _, unitID in ipairs(Spring.GetAllUnits()) do
		AddExtractionCommand(unitID, Spring.GetUnitDefID(unitID), Spring.GetUnitTeam(unitID))
	end
end
