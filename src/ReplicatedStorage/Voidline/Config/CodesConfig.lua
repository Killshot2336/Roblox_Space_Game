--!strict
-- Code Terminal rewards (spec §11). Codes are case/space-insensitive and each
-- can be redeemed once per profile.
export type CodeReward = {
	Credits: number,
	VoidShards: number,
	Title: string?,
	OneTime: boolean,
	Message: string,
}

local CodesConfig = {
	Codes = {
		VOIDLINE = {
			Credits = 250,
			VoidShards = 5,
			Title = "title.code.voidline",
			OneTime = true,
			Message = "Welcome to Voidline.",
		},
		KILLSHOT = {
			Credits = 500,
			VoidShards = 10,
			Title = "title.code.killshot",
			OneTime = true,
			Message = "Created by Killshot2336.",
		},
		LAUNCH = {
			Credits = 1000,
			VoidShards = 15,
			Title = "title.code.launch",
			OneTime = true,
			Message = "Launch week boost unlocked.",
		},
	} :: { [string]: CodeReward },
	MaxLength = 20,
}

return CodesConfig
