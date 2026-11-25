--[[
	Voidline: Deep Space — client boot
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Voidline = ReplicatedStorage:WaitForChild("Voidline")
local Remotes = require(Voidline.Remotes)

local Controllers = script.Parent.Controllers
local HUDController = require(Controllers.HUDController)
local HotbarController = require(Controllers.HotbarController)
local StoreController = require(Controllers.StoreController)
local SettingsController = require(Controllers.SettingsController)
local OnboardingController = require(Controllers.OnboardingController)
local CameraController = require(Controllers.CameraController)
local VFXController = require(Controllers.VFXController)
local StationInteractController = require(Controllers.StationInteractController)
local ThrusterCosmeticController = require(Controllers.ThrusterCosmeticController)

HUDController.Init()
StoreController.Init()
SettingsController.Init()
OnboardingController.Init()
CameraController.Init()
VFXController.Init(HUDController)
StationInteractController.Init()
ThrusterCosmeticController.Init()

HotbarController.Init({
	OpenStore = function()
		StoreController.Toggle()
	end,
	OpenSettings = function()
		SettingsController.Toggle()
	end,
	OpenSquad = function()
		-- Lightweight prompt: invite nearest player name via chat attribute
		local me = Players.LocalPlayer
		local closest, best = nil, math.huge
		for _, p in Players:GetPlayers() do
			if p ~= me and p.Character and me.Character then
				local a = p.Character:FindFirstChild("HumanoidRootPart")
				local b = me.Character:FindFirstChild("HumanoidRootPart")
				if a and b then
					local d = (a.Position - b.Position).Magnitude
					if d < best then
						best = d
						closest = p
					end
				end
			end
		end
		if closest then
			Remotes.Get("SquadInvite"):FireServer(closest.Name)
			HUDController.ShowBanner("SQUAD INVITE → " .. closest.DisplayName, 2)
		else
			HUDController.ShowBanner("NO NEARBY PLAYERS TO SQUAD", 2)
		end
	end,
	SetClipMode = function(on)
		HUDController.SetClipMode(on)
		HotbarController.SetVisible(not on)
	end,
})

Remotes.Get("DataSnapshot").OnClientEvent:Connect(function(data)
	HUDController.SetData(data)
	if data.TutorialStep then
		OnboardingController.SetStep(data.TutorialStep)
	end
end)

-- Daily redeem hint once
task.delay(8, function()
	HUDController.ShowBanner("TIP: VIP LOUNGE PAD → DAILY STREAK  |  CODES AT MONOLITH", 4)
end)

print("[Voidline] Client online")
