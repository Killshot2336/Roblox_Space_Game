-- Placeholder GamePass / DevProduct IDs = 0 until Creator Dashboard wiring
local MonetizationConfig = {
	Passes = {
		{
			Id = "StarterBundle",
			Name = "Starter Bundle",
			Robux = 79,
			Tokens = 65,
			GamePassId = 0,
		},
		{
			Id = "AutoSellWarpLink",
			Name = "Auto-Sell Warp Link",
			Robux = 249,
			Tokens = 200,
			GamePassId = 0,
		},
		{
			Id = "Credits2x",
			Name = "2x Credits",
			Robux = 449,
			Tokens = 370,
			GamePassId = 0,
		},
		{
			Id = "ShardRelicLuck2x",
			Name = "2x Shard & Relic Luck",
			Robux = 499,
			Tokens = 410,
			GamePassId = 0,
		},
		{
			Id = "DroneSlots3",
			Name = "+3 Drone Slots",
			Robux = 599,
			Tokens = 490,
			GamePassId = 0,
		},
		{
			Id = "MegaSwarm5",
			Name = "+5 Mega Swarm Slots",
			Robux = 999,
			Tokens = 820,
			GamePassId = 0,
		},
		{
			Id = "LaserOverclock",
			Name = "Laser Overclock",
			Robux = 349,
			Tokens = 285,
			GamePassId = 0,
		},
		{
			Id = "DeepSpaceWarpPass",
			Name = "Deep-Space Warp Pass",
			Robux = 399,
			Tokens = 325,
			GamePassId = 0,
		},
		{
			Id = "VoidSovereignVIP",
			Name = "Void Sovereign VIP",
			Robux = 899,
			Tokens = 740,
			GamePassId = 0,
		},
		{
			Id = "EternalArchitect",
			Name = "Eternal Architect",
			Robux = 1499,
			Tokens = 1230,
			GamePassId = 0,
		},
	},
	DevProducts = {
		{ Id = "SummonVoidStarfall", Name = "Summon Void Starfall", Robux = 199, ProductId = 0 },
		{ Id = "ServerLuckSurge", Name = "Server Luck Surge", Robux = 149, ProductId = 0 },
	},
}

function MonetizationConfig.GetPass(passId: string)
	for _, pass in MonetizationConfig.Passes do
		if pass.Id == passId then
			return pass
		end
	end
	return nil
end

return MonetizationConfig
