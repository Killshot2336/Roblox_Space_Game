--!strict
-- Camera feel layered on top of the default camera: a smooth FOV pullback
-- while the Orbital Beam-Link is engaged, short FOV punches and small,
-- quickly decaying shakes. Reduced Motion turns shakes off and halves FOV moves.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Client = script.Parent.Parent.Client
local Ui = require(Client.Ui)

local TowController = require(script.Parent.TowController)

local CameraController = {}

local BASE_FOV = 70
local BEAM_LINK_FOV = 8
local TOW_FOV = 5
local HALO_FOV = 4
local FOV_RATE = 4
local MAX_SHAKE = 1.2

local player = Players.LocalPlayer
local currentFov = BASE_FOV
local punch = 0
local punchUntil = 0
local shakeAmount = 0
local shakeUntil = 0
local shakeDuration = 1

local function beamLinkEngaged(): boolean
	local targets = player:GetAttribute("DroneTargets")
	return player:GetAttribute("Formation") == 2 and type(targets) == "string" and targets ~= ""
end

local function sovereignHalo(): boolean
	return player:GetAttribute("Formation") == 3
end

local function localTowActive(): boolean
	for _, tow in TowController.ForUser(player.UserId) do
		if tow.Alpha < 0.98 then
			return true
		end
	end
	return false
end

function CameraController.Punch(fovDelta: number, seconds: number)
	punch = fovDelta * (if Ui.ReducedMotion then 0.5 else 1)
	punchUntil = os.clock() + seconds
end

function CameraController.Shake(intensity: number, seconds: number)
	if Ui.ReducedMotion then
		return
	end
	shakeAmount = math.min(MAX_SHAKE, math.max(shakeAmount, intensity))
	shakeDuration = math.max(0.05, seconds)
	shakeUntil = os.clock() + shakeDuration
end

local function step(dt: number)
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local now = os.clock()
	local target = BASE_FOV
	local motion = if Ui.ReducedMotion then 0.5 else 1
	if beamLinkEngaged() then
		target += BEAM_LINK_FOV * motion
	elseif sovereignHalo() then
		target += HALO_FOV * motion
	end
	if localTowActive() then
		target += TOW_FOV * motion
	end
	if now < punchUntil then
		target += punch
	end
	currentFov += (target - currentFov) * (1 - math.exp(-dt * FOV_RATE))
	camera.FieldOfView = currentFov
	if now < shakeUntil then
		local fade = (shakeUntil - now) / shakeDuration
		local amount = math.rad(shakeAmount * fade)
		camera.CFrame *= CFrame.Angles(
			(math.random() - 0.5) * amount,
			(math.random() - 0.5) * amount,
			(math.random() - 0.5) * amount * 0.5
		)
	else
		shakeAmount = 0
	end
end

function CameraController.Init()
	RunService:BindToRenderStep("VoidlineCamera", Enum.RenderPriority.Camera.Value + 1, step)
end

return CameraController
