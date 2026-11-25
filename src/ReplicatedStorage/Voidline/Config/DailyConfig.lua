--!strict
-- 7-day login streak (spec §12). The cycle restarts after day 7 so the 24 h
-- pass trial voucher stays a weekly treat rather than a permanent free pass.
local DailyConfig = {}

export type DayReward = {
	Credits: number,
	VoidShards: number,
	TrialPerk: string?,
	TrialHours: number?,
}

DailyConfig.CycleLength = 7

DailyConfig.Rewards = {
	[1] = { Credits = 50, VoidShards = 0 },
	[2] = { Credits = 75, VoidShards = 2 },
	[3] = { Credits = 100, VoidShards = 3 },
	[4] = { Credits = 150, VoidShards = 4 },
	[5] = { Credits = 200, VoidShards = 5 },
	[6] = { Credits = 300, VoidShards = 8 },
	[7] = { Credits = 500, VoidShards = 10, TrialPerk = "Credits2x", TrialHours = 24 },
} :: { [number]: DayReward }

return DailyConfig
