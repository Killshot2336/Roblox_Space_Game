--!strict
-- Clean Clip / TikTok recording helpers. Clip Mode (K) widens FOV via
-- CameraController; stand on `ClipShot_*` pads in the hub for hero angles.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Voidline = ReplicatedStorage:WaitForChild("Voidline")
local HubLayout = require(Voidline.Modules.HubLayout)
local GameConfig = require(Voidline.Config.GameConfig)

export type Shot = {
	Id: string,
	Hint: string,
	Stand: Vector3,
	LookAt: Vector3,
	Fov: number?,
}

local ClipFramingConfig = {
	-- Default gameplay FOV is 70 in CameraController; Clip Mode uses this.
	ClipFov = 82,
	Shots = {
		{
			Id = "MonolithHero",
			Hint = "Monolith + gold seam · center frame",
			Stand = Vector3.new(0, 1.5, 78),
			LookAt = HubLayout.MonolithCenter + Vector3.new(0, 6, 0),
			Fov = 82,
		},
		{
			Id = "MonolithSplit",
			Hint = "Void Starfall split · step back",
			Stand = Vector3.new(-58, 1.5, 42),
			LookAt = HubLayout.VoidCore,
			Fov = 80,
		},
		{
			Id = "KillshotMonument",
			Hint = "Creator obelisk · readable plaque",
			Stand = HubLayout.Monument + Vector3.new(0, 1.5, 14),
			LookAt = HubLayout.Monument + Vector3.new(0, 14, 0),
			Fov = 78,
		},
		{
			Id = "PlotRing",
			Hint = "12 plots + gold orbit from hub rim",
			Stand = Vector3.new(0, 1.5, 46),
			LookAt = Vector3.new(
				math.cos(math.rad(30)) * GameConfig.PlotRingRadius,
				8,
				math.sin(math.rad(30)) * GameConfig.PlotRingRadius
			),
			Fov = 84,
		},
		{
			Id = "DeepSpaceRim",
			Hint = "Deep Space pylons + floor contrast",
			Stand = Vector3.new(62, 1.5, 62),
			LookAt = Vector3.new(0, 4, 0),
			Fov = 86,
		},
	} :: { Shot },
}

return ClipFramingConfig
