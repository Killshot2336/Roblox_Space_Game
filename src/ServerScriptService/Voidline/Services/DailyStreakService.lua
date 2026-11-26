--!strict
-- 7-day login streak. Day 7 adds a 24 h pass trial voucher; the cycle then
-- restarts so the voucher stays a weekly treat.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Voidline = ReplicatedStorage:WaitForChild("Voidline")
local ProgressionRules = require(Voidline.Rules.ProgressionRules)

local ValidateRemote = require(script.Parent.Parent.Security.ValidateRemote)
local PlayerDataService = require(script.Parent.PlayerDataService)
local JuiceService = require(script.Parent.JuiceService)
local StatService = require(script.Parent.StatService)

local DailyStreakService = {}

function DailyStreakService.Claim(player: Player): boolean
	local ok, reward, day = false, nil, 0
	PlayerDataService.Mutate(player, function(p)
		ok, reward, day = ProgressionRules.ClaimDaily(p, os.time())
	end)
	if not ok or not reward then
		JuiceService.Send(player, "Daily", { Ok = false })
		return false
	end
	JuiceService.Send(player, "Daily", {
		Ok = true,
		Day = day,
		Credits = reward.Credits,
		Shards = reward.VoidShards,
		Trial = reward.TrialPerk,
	})
	StatService.Bump(player, "DailyClaims", 1)
	StatService.Check(player, "LifetimeCredits", "LifetimeShards")
	task.spawn(PlayerDataService.Save, player)
	return true
end

function DailyStreakService.Init()
	PlayerDataService.OnLoaded(function(player, profile)
		ProgressionRules.OnLogin(profile, os.time())
		PlayerDataService.MarkDirty(player)
		if ProgressionRules.CanClaimDaily(profile, os.time()) then
			JuiceService.Send(player, "DailyReady", { Day = profile.DailyStreak })
		end
	end)
	ValidateRemote.Bind("RedeemDaily", { Rate = 1, Burst = 2 }, function(player)
		DailyStreakService.Claim(player)
	end)
end

return DailyStreakService
