local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Voidline = ReplicatedStorage:WaitForChild("Voidline")
local Remotes = require(Voidline.Remotes)
local RateLimiter = require(Voidline.Modules.RateLimiter)
local PlayerDataService = require(script.Parent.PlayerDataService)

-- 7-day streak rewards; day 7 grants 24h trial voucher for Credits2x
local DAY_REWARDS = {
	[1] = { Credits = 50 },
	[2] = { Credits = 75, VoidShards = 2 },
	[3] = { Credits = 100, VoidShards = 3 },
	[4] = { Credits = 150, VoidShards = 4 },
	[5] = { Credits = 200, VoidShards = 5 },
	[6] = { Credits = 300, VoidShards = 8 },
	[7] = { Credits = 500, VoidShards = 10, TrialPerk = "Credits2x", TrialHours = 24 },
}

local DailyStreakService = {
	_limiter = RateLimiter.new(2),
	_claimedToday = {} :: { [number]: boolean },
}

function DailyStreakService.Init()
	Remotes.Get("RedeemDaily").OnServerEvent:Connect(function(player)
		if not DailyStreakService._limiter:Allow(player.UserId) then
			return
		end
		if DailyStreakService._claimedToday[player.UserId] then
			Remotes.Get("JuiceEvent"):FireClient(player, { Kind = "DailyFail", Message = "Already claimed today" })
			return
		end
		local data = PlayerDataService.Get(player)
		if not data then
			return
		end
		local day = math.clamp(data.DailyStreak or 1, 1, 7)
		local reward = DAY_REWARDS[day]
		PlayerDataService.Mutate(player, function(d)
			d.Credits += reward.Credits or 0
			d.VoidShards += reward.VoidShards or 0
			if reward.TrialPerk then
				d.TrialVouchers[reward.TrialPerk] = os.time() + (reward.TrialHours or 24) * 3600
			end
		end)
		DailyStreakService._claimedToday[player.UserId] = true
		PlayerDataService.Save(player)
		Remotes.Get("JuiceEvent"):FireClient(player, {
			Kind = "DailySuccess",
			Day = day,
			Reward = reward,
		})
	end)
end

return DailyStreakService
