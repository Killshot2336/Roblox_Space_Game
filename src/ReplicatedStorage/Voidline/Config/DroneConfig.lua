--!strict
local DroneConfig = {
	StarterSlots = 1,
	MaxBaseSlots = 6,
	Formations = {
		[1] = "Scatter",
		[2] = "OrbitalBeamLink",
		[3] = "SovereignHalo",
	},
	FormationLabels = {
		[1] = "SCATTER",
		[2] = "ORBITAL BEAM-LINK",
		[3] = "SOVEREIGN HALO",
	},
	-- Scatter splits drones over up to 3 rocks; Beam-Link focuses one rock
	-- harder (+10% more per linked squadmate); Halo escorts the pilot and only
	-- chips at rocks close to them, trading income for presence.
	FormationStats = {
		[1] = { DamageMult = 1.0, MaxTargets = 3 },
		[2] = { DamageMult = 1.35, MaxTargets = 1, SquadLinkBonus = 0.10 },
		[3] = { DamageMult = 0.5, MaxTargets = 1, EscortRange = 30 },
	},
	IdleOrbitRadius = 8,
	MineRange = 42,
	TowSpeed = 28,
	-- Hauler branch and Warp Pass shorten tows.
	TowMinSeconds = 0.9,
	TowMaxSeconds = 4.5,
	BaseDamagePerSecond = 8,
	DamagePerDrillLevel = 4,
	-- Each drone evolution stage adds 12% laser damage.
	DamagePerDroneTier = 0.12,
	LaserOverclockMult = 1.35,
	-- Server mining simulation rate (Hz). Clients interpolate visuals.
	SimHz = 5,
	-- Hard cap on rendered drones per pilot (6 base + 3 + 5 passes).
	MaxDrones = 14,
	-- Stage 6 is the branch point of the evolution tree.
	BranchStage = 6,
	Branches = {
		Miner = { Label = "Miner", DamageMult = 1.2, TowMult = 1.0, OreMult = 1.0 },
		Hauler = { Label = "Hauler", DamageMult = 1.0, TowMult = 1.5, OreMult = 1.15 },
		Swarm = { Label = "Swarm", DamageMult = 0.95, TowMult = 1.1, OreMult = 1.0, ExtraDronesPerStages = 3 },
	},
	BranchOrder = { "Miner", "Hauler", "Swarm" },
	LaserColors = {
		Gold = Color3.fromRGB(255, 210, 90),
		Cyan = Color3.fromRGB(90, 220, 255),
		Void = Color3.fromRGB(170, 110, 255),
		Crimson = Color3.fromRGB(255, 90, 110),
		Emerald = Color3.fromRGB(90, 255, 160),
	},
	LaserColorOrder = { "Gold", "Cyan", "Void", "Crimson", "Emerald" },
	DefaultLaserColor = "Gold",
}

return DroneConfig
