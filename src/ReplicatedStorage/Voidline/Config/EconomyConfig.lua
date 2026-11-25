--!strict
local EconomyConfig = {}

-- Spec §4: starter cargo 10 ore, first sell 30 credits (10 x 3).
EconomyConfig.StarterCargoCapacity = 10
EconomyConfig.StarterOrePerAsteroid = 10
EconomyConfig.FirstSellCredits = 30
EconomyConfig.CreditsPerOreBase = 3

-- How close (studs, beyond the pad's half-size) a pilot must be to their own
-- Station Refinery to sell by hand. Auto-Sell Warp Link skips this.
EconomyConfig.SellRange = 18

-- Spec §4 first upgrades: +Drill 20, +Cargo 35, +2nd Drone 50.
EconomyConfig.StarterUpgrades = {
	{ Id = "Drill", Label = "+Drill Power", Cost = 20, Stat = "DrillLevel", Amount = 1 },
	{ Id = "Cargo", Label = "+Cargo Capacity", Cost = 35, Stat = "CargoLevel", Amount = 1 },
	{ Id = "Drone2", Label = "+2nd Drone Slot", Cost = 50, Stat = "DroneSlots", Amount = 1 },
}

function EconomyConfig.DrillCost(level: number): number
	return math.floor(20 * (1.55 ^ math.max(0, level - 1)))
end

function EconomyConfig.CargoCost(level: number): number
	return math.floor(35 * (1.55 ^ math.max(0, level - 1)))
end

function EconomyConfig.DroneSlotCost(slots: number): number
	return math.floor(50 * (1.75 ^ math.max(0, slots - 1)))
end

function EconomyConfig.StationTierCost(tier: number): number
	return math.floor(150 * (1.85 ^ math.max(0, tier - 1)))
end

function EconomyConfig.DroneTierCost(tier: number): number
	return math.floor(400 * (2.2 ^ math.max(0, tier - 1)))
end

function EconomyConfig.CargoCapacityForLevel(level: number): number
	return 10 + (level - 1) * 8
end

export type UpgradeDef = {
	Id: string,
	Label: string,
	Stat: string,
	Max: number,
	Cost: (number) -> number,
}

-- Upgrade pads / Quick-Upgrade. `Cost` receives the current stat value.
EconomyConfig.Upgrades = {
	Drill = { Id = "Drill", Label = "+Drill Power", Stat = "DrillLevel", Max = 120, Cost = EconomyConfig.DrillCost },
	Cargo = { Id = "Cargo", Label = "+Cargo Capacity", Stat = "CargoLevel", Max = 120, Cost = EconomyConfig.CargoCost },
	DroneSlot = {
		Id = "DroneSlot",
		Label = "+Drone Slot",
		Stat = "DroneSlots",
		Max = 6,
		Cost = EconomyConfig.DroneSlotCost,
	},
	StationTier = {
		Id = "StationTier",
		Label = "Station Tier",
		Stat = "StationTier",
		Max = 30,
		Cost = EconomyConfig.StationTierCost,
	},
	DroneTier = {
		Id = "DroneTier",
		Label = "Drone Evolution",
		Stat = "DroneTier",
		Max = 12,
		Cost = EconomyConfig.DroneTierCost,
	},
} :: { [string]: UpgradeDef }

-- Order used by Quick-Upgrade (U) and the upgrade pads on each station.
EconomyConfig.UpgradeOrder = { "Drill", "Cargo", "DroneSlot", "StationTier", "DroneTier" }

-- Per-unit ore value by galaxy sector (before ore-variant multipliers).
EconomyConfig.OreValueBySector = {
	Starter = 3,
	Nebula = 8,
	VoidRim = 22,
	Celestial = 55,
}

-- Personal-belt asteroid stats by sector. Starter matches the tutorial pacing:
-- 40 HP at 8 dps = 5 s per rock, 3.3 s after the first Drill upgrade.
EconomyConfig.BeltAsteroid = {
	Starter = { Health = 40, Ore = 10 },
	Nebula = { Health = 140, Ore = 14 },
	VoidRim = { Health = 520, Ore = 20 },
	Celestial = { Health = 1900, Ore = 28 },
}

-- Deep-space shared rocks (soft contest) and how much ore their pool splits.
EconomyConfig.SharedAsteroid = { Health = 5000, OrePool = 80, ShardPool = 6 }

return EconomyConfig
