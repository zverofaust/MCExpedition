--------------------------------------------------------------------------------
-- MechCommander: Mercs - Nav Beacon Unit Script
--
-- Self-contained orbital descent, impact and deployment sequence. This script
-- intentionally does not depend on the MCL Beacon Manager or capture/outpost
-- systems.
--
-- Authors: zvero + ChatGPT
--------------------------------------------------------------------------------

local base = piece("base")
local dirt = piece("dirt")
local rocket = piece("rocket")
local blink = piece("blink")

local flaps = {}
for i = 1, 4 do
	flaps[i] = piece("flap" .. i)
end

local antenna1 = piece("antenna1")
local antenna2 = piece("antenna2")
local antenna3 = piece("antenna3")

local DROP_HEIGHT = 12000
local X, _, Z = Spring.GetUnitPosition(unitID)
local GY = Spring.GetGroundHeight(X, Z)
local stage

Spring.SetUnitNanoPieces(unitID, {base})

local function Effects()
	while stage == 3 do
		EmitSfx(rocket, SFX.CEG)
		Sleep(5)
	end

	local t = 1
	while stage == 2 do
		EmitSfx(rocket, SFX.BLACK_SMOKE)
		Sleep(20 * t)
		t = t + 5
	end

	while stage == 0 do
		Sleep(1000)
		PlaySound("NavBeacon_Beep")
		EmitSfx(blink, SFX.CEG + 2)
	end
end

local function WaitForImpact()
	while true do
		local _, y = Spring.GetUnitPosition(unitID)
		local _, vy = Spring.GetUnitVelocity(unitID)
		if not y or y <= GY + 2 or (vy and math.abs(vy) < 0.01 and y < GY + 20) then
			break
		end
		Sleep(50)
	end

	Spring.MoveCtrl.Disable(unitID)
	Spring.SetUnitNoSelect(unitID, false)
	GG.RemoveGrassSquare(X, Z, 64)
	GG.SpawnDecal("decal_beacon", X, Z)
	GG.SpawnDecal("decal_beacon_zone", X, Z, 460)
	Spring.SetUnitRulesParam(unitID, "mcm_navbeacon_impact", 1, {public = true})
end

function script.Create()
	Hide(dirt)
	Spring.SetUnitNoSelect(unitID, true)
	Spring.SetUnitRulesParam(unitID, "mcm_navbeacon_deployed", 0, {public = true})

	Spring.MoveCtrl.Enable(unitID)
	local x = Spring.GetUnitPosition(unitID)
	Spring.MoveCtrl.SetPosition(unitID, x, GY + DROP_HEIGHT, Z)
	Turn(base, y_axis, unitID, 0)

	Spring.MoveCtrl.SetVelocity(unitID, 0, -50, 0)
	Spring.MoveCtrl.SetGravity(unitID, Game.gravity / 75)
	Spring.MoveCtrl.SetCollideStop(unitID, true)
	Spring.MoveCtrl.SetTrackGround(unitID, true)

	stage = 3
	StartThread(Effects)
	for i = 1, 2 do
		local _, sy = Spring.GetUnitVelocity(unitID)
		PlaySound("NavBeacon_Descend", 10, 0, sy, 0)
		Sleep(2500)
	end

	WaitForImpact()

	stage = 2
	EmitSfx(dirt, SFX.CEG + 1)
	Show(dirt)
	StopSpin(base, y_axis)
	PlaySound("NavBeacon_Land", 30)
	Sleep(5400)

	stage = 1
	Hide(rocket)
	PlaySound("NavBeacon_Pop", 15)
	Explode(rocket, SFX.FIRE + SFX.SMOKE)
	Sleep(3500)

	Turn(flaps[1], x_axis, -math.rad(80), math.rad(20))
	Turn(flaps[2], z_axis, -math.rad(80), math.rad(20))
	Turn(flaps[3], x_axis, math.rad(80), math.rad(20))
	Turn(flaps[4], z_axis, math.rad(80), math.rad(20))
	WaitForTurn(flaps[4], z_axis)
	Sleep(800)

	Move(antenna1, y_axis, 4, 2)
	WaitForMove(antenna1, y_axis)
	Move(antenna2, y_axis, 4, 2)
	WaitForMove(antenna2, y_axis)
	Sleep(500)
	Move(antenna3, y_axis, 12, 48)
	WaitForMove(antenna3, y_axis)

	stage = 0
	StartThread(Effects)
	SetUnitValue(COB.INBUILDSTANCE, 1)
	Spring.SetUnitRulesParam(unitID, "mcm_navbeacon_deployed", 1, {public = true})
end

function script.Killed(recentDamage, maxHealth)
	return 0
end
