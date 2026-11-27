--!strict
-- Dashboard IDs are wired. An ID of 0 means "not wired": the Robux button is
-- hidden for that item and nothing is ever granted for it.
--
-- Dashboard name (must match exactly)     | Config `Id` / field              | R$
-- ----------------------------------------|----------------------------------|----
-- Starter Bundle                          | Passes.StarterBundle.GamePassId  |  79
-- Auto-Sell Warp Link                     | Passes.AutoSellWarpLink          | 249
-- 2x Credits                              | Passes.Credits2x                 | 449
-- 2x Shard & Relic Luck                   | Passes.ShardRelicLuck2x          | 499
-- +3 Drone Slots                          | Passes.DroneSlots3               | 599
-- +5 Mega Swarm Slots                     | Passes.MegaSwarm5                | 999
-- Laser Overclock                         | Passes.LaserOverclock            | 349
-- Deep-Space Warp Pass                    | Passes.DeepSpaceWarpPass         | 399
-- Void Sovereign VIP                      | Passes.VoidSovereignVIP          | 899
-- Eternal Architect                       | Passes.EternalArchitect          | 1499
-- Summon Void Starfall (Dev Product)      | DevProducts.SummonVoidStarfall   | 199
-- Server Luck Surge (Dev Product)         | DevProducts.ServerLuckSurge      | 149
-- Token prices stay 15-20% below Robux. There are deliberately no Robux shard
-- packs: Void Shards are find-only and Voidline Tokens are earn-only.
local MonetizationConfig = {}

export type Pass = {
	Id: string,
	Name: string,
	Robux: number,
	Tokens: number,
	GamePassId: number,
	Blurb: string,
}

export type DevProduct = {
	Id: string,
	Name: string,
	Robux: number,
	ProductId: number,
	Blurb: string,
	RandomOutcome: boolean,
	DurationSeconds: number,
}

MonetizationConfig.Passes = {
	{
		Id = "StarterBundle",
		Name = "Starter Bundle",
		Robux = 79,
		Tokens = 65,
		GamePassId = 2102231833,
		Blurb = "+500 Credits once, Gold Comet thruster and the PIONEER title.",
	},
	{
		Id = "AutoSellWarpLink",
		Name = "Auto-Sell Warp Link",
		Robux = 249,
		Tokens = 200,
		GamePassId = 2102231834,
		Blurb = "Full cargo warps to your refinery and sells itself.",
	},
	{
		Id = "Credits2x",
		Name = "2x Credits",
		Robux = 449,
		Tokens = 370,
		GamePassId = 2099034650,
		Blurb = "Every sale pays double.",
	},
	{
		Id = "ShardRelicLuck2x",
		Name = "2x Shard & Relic Luck",
		Robux = 499,
		Tokens = 410,
		GamePassId = 2099004700,
		Blurb = "Double the chance to find Void Shards and relics.",
	},
	{
		Id = "DroneSlots3",
		Name = "+3 Drone Slots",
		Robux = 599,
		Tokens = 490,
		GamePassId = 2099880676,
		Blurb = "Three extra drones join your swarm.",
	},
	{
		Id = "MegaSwarm5",
		Name = "+5 Mega Swarm Slots",
		Robux = 999,
		Tokens = 820,
		GamePassId = 2099454780,
		Blurb = "Five extra drones join your swarm.",
	},
	{
		Id = "LaserOverclock",
		Name = "Laser Overclock",
		Robux = 349,
		Tokens = 285,
		GamePassId = 2099112722,
		Blurb = "+35% laser damage and the Overclock laser shader.",
	},
	{
		Id = "DeepSpaceWarpPass",
		Name = "Deep-Space Warp Pass",
		Robux = 399,
		Tokens = 325,
		GamePassId = 2100246702,
		Blurb = "Warp to the Monolith, Overlook and Rift from anywhere; faster tows.",
	},
	{
		Id = "VoidSovereignVIP",
		Name = "Void Sovereign VIP",
		Robux = 899,
		Tokens = 740,
		GamePassId = 2102105843,
		Blurb = "VIP Lounge access, +10% Credits and the VOID SOVEREIGN title.",
	},
	{
		Id = "EternalArchitect",
		Name = "Eternal Architect",
		Robux = 1499,
		Tokens = 1230,
		GamePassId = 2099928725,
		Blurb = "Station Tier upgrades 10% cheaper and the ETERNAL ARCHITECT title.",
	},
} :: { Pass }

MonetizationConfig.DevProducts = {
	{
		Id = "SummonVoidStarfall",
		Name = "Summon Void Starfall",
		Robux = 199,
		ProductId = 3736719622,
		Blurb = "A meteor shower rains rich rocks on the whole server for 90 s.",
		RandomOutcome = true,
		DurationSeconds = 90,
	},
	{
		Id = "ServerLuckSurge",
		Name = "Server Luck Surge",
		Robux = 149,
		ProductId = 3736719712,
		Blurb = "Everyone in the server finds shards and relics 2x as often for 10 min.",
		RandomOutcome = false,
		DurationSeconds = 600,
	},
} :: { DevProduct }

-- Void Starfall contents. These numbers drive the actual drops (SummonService)
-- and are shown to the buyer before purchase (paid random outcome disclosure).
MonetizationConfig.Starfall = {
	Meteors = 6,
	OrePerMeteor = 60,
	ShardsPerMeteor = 3,
	RelicChancePerMeteor = 0.08,
	CelestialOreChance = 0.25,
}

function MonetizationConfig.StarfallOdds(): { { Label: string, Chance: number } }
	local s = MonetizationConfig.Starfall
	return {
		{ Label = ("%d meteors, %d ore each (split by contribution)"):format(s.Meteors, s.OrePerMeteor), Chance = 1 },
		{ Label = ("%d Void Shards per meteor (split by contribution)"):format(s.ShardsPerMeteor), Chance = 1 },
		{ Label = "Celestial ore variant per meteor", Chance = s.CelestialOreChance },
		{ Label = "Relic per meteor, top contributor (base, before luck boosts)", Chance = s.RelicChancePerMeteor },
		{
			Label = "Relic per meteor, other qualifiers (base, before luck boosts)",
			Chance = s.RelicChancePerMeteor * 0.1,
		},
	}
end

-- Tokens earned through the Forge are the only token source.
MonetizationConfig.StarterBundleCredits = 500

function MonetizationConfig.GetPass(passId: string): Pass?
	for _, pass in MonetizationConfig.Passes do
		if pass.Id == passId then
			return pass
		end
	end
	return nil
end

function MonetizationConfig.GetProduct(productKey: string): DevProduct?
	for _, product in MonetizationConfig.DevProducts do
		if product.Id == productKey then
			return product
		end
	end
	return nil
end

function MonetizationConfig.PassByGamePassId(gamePassId: number): Pass?
	if gamePassId == 0 then
		return nil
	end
	for _, pass in MonetizationConfig.Passes do
		if pass.GamePassId == gamePassId then
			return pass
		end
	end
	return nil
end

function MonetizationConfig.ProductByProductId(productId: number): DevProduct?
	if productId == 0 then
		return nil
	end
	for _, product in MonetizationConfig.DevProducts do
		if product.ProductId == productId then
			return product
		end
	end
	return nil
end

return MonetizationConfig
