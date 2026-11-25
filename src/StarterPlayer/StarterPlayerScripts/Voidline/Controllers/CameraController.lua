local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Voidline = ReplicatedStorage:WaitForChild("Voidline")
local Remotes = require(Voidline.Remotes)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local CameraController = {
	_action = false,
	_baseFov = 70,
}

function CameraController.Init()
	Remotes.Get("JuiceEvent").OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" then
			return
		end
		if payload.Kind == "Laser" and payload.Formation == 2 then
			CameraController._action = true
		elseif payload.Kind == "CoreChunk" or payload.Kind == "Shatter" then
			CameraController._action = true
			task.delay(1.2, function()
				CameraController._action = false
			end)
		elseif payload.Kind == "BridgeIgnition" then
			CameraController._action = true
			task.delay(1.5, function()
				CameraController._action = false
			end)
		end
	end)

	RunService.RenderStepped:Connect(function()
		camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local target = if CameraController._action then 80 else CameraController._baseFov
		camera.FieldOfView = camera.FieldOfView + (target - camera.FieldOfView) * 0.08
	end)
end

return CameraController
