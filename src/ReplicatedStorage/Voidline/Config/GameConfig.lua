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
	-- Owner brief: bridge ignition and +100 Credits land at ~45 s.
	TutorialTargetSeconds = 45,
	BrandCreator = "Killshot2336",
	GameDisplayName = "Voidline: Deep Space",
	-- Belt asteroids kept alive around each claimed plot.
	BeltAsteroidsPerPlot = 6,
	BeltRespawnSeconds = 1.5,
	-- Deep-space shared rocks kept alive around the Monolith.
	SharedAsteroidCount = 4,
	SharedRespawnSeconds = 20,
	LeaderboardRefreshSeconds = 90,
	Colors = {
		Obsidian = Color3.fromRGB(12, 12, 18),
		Gold = Color3.fromRGB(232, 186, 74),
		GoldBright = Color3.fromRGB(255, 220, 120),
		Nebula = Color3.fromRGB(48, 24, 96),
		VoidAccent = Color3.fromRGB(120, 80, 255),
	},
}

return GameConfig
