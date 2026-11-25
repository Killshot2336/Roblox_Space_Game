local EconomyConfig = {
	StarterCargoCapacity = 10,
	StarterOrePerAsteroid = 10,
	FirstSellCredits = 30, -- refining 10 starter ore
	CreditsPerOreBase = 3,

	StarterUpgrades = {
		{ Id = "Drill", Label = "+Drill Power", Cost = 20, Stat = "DrillLevel", Amount = 1 },
		{ Id = "Cargo", Label = "+Cargo Capacity", Cost = 35, Stat = "CargoLevel", Amount = 1 },
		{ Id = "Drone2", Label = "+2nd Drone Slot", Cost = 50, Stat = "DroneSlots", Amount = 1 },
	},

	-- Exponential curve after starter hooks
	DrillCost = function(level: number): number
		return math.floor(20 * (1.55 ^ math.max(0, level - 1)))
	end,
	CargoCost = function(level: number): number
		return math.floor(35 * (1.55 ^ math.max(0, level - 1)))
	end,
	DroneSlotCost = function(slots: number): number
		return math.floor(50 * (1.75 ^ math.max(0, slots - 1)))
	end,
	StationTierCost = function(tier: number): number
		return math.floor(150 * (1.85 ^ math.max(0, tier - 1)))
	end,

	CargoCapacityForLevel = function(level: number): number
		return 10 + (level - 1) * 8
	end,

	OreValueBySector = {
		Starter = 3,
		Nebula = 8,
		VoidRim = 22,
		Celestial = 55,
	},
}

return EconomyConfig
