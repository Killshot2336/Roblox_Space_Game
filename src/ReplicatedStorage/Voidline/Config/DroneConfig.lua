local DroneConfig = {
	StarterSlots = 1,
	MaxBaseSlots = 6,
	Formations = {
		[1] = "Scatter",
		[2] = "OrbitalBeamLink",
		[3] = "SovereignHalo",
	},
	IdleOrbitRadius = 8,
	MineRange = 42,
	TowSpeed = 28,
	BaseDamagePerSecond = 8,
	DamagePerDrillLevel = 4,
	LaserColors = {
		Gold = Color3.fromRGB(255, 210, 90),
		Cyan = Color3.fromRGB(90, 220, 255),
		Void = Color3.fromRGB(170, 110, 255),
		Crimson = Color3.fromRGB(255, 90, 110),
		Emerald = Color3.fromRGB(90, 255, 160),
	},
	DefaultLaserColor = "Gold",
}

return DroneConfig
