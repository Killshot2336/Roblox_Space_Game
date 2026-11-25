-- Voidline: Deep Space — global game constants
local GameConfig = {
	MaxPlayers = 12,
	PlotCount = 12,
	PlotRingRadius = 220,
	HubRadius = 48,
	AutosaveSeconds = 60,
	AfkIdleSeconds = 8 * 60,
	WorldEventIntervalSeconds = 6 * 60,
	WorldEventDurationSeconds = 90,
	BridgeIgnitionTutorialStep = 4,
	TutorialCompleteBonusCredits = 100,
	BrandCreator = "Killshot2336",
	GameDisplayName = "Voidline: Deep Space",
	Colors = {
		Obsidian = Color3.fromRGB(12, 12, 18),
		Gold = Color3.fromRGB(232, 186, 74),
		GoldBright = Color3.fromRGB(255, 220, 120),
		Nebula = Color3.fromRGB(48, 24, 96),
		VoidAccent = Color3.fromRGB(120, 80, 255),
	},
}

return GameConfig
