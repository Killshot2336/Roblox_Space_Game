local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Voidline = ReplicatedStorage:WaitForChild("Voidline")
local ForgeConfig = require(Voidline.Config.ForgeConfig)
local Remotes = require(Voidline.Remotes)
local RateLimiter = require(Voidline.Modules.RateLimiter)
local PlayerDataService = require(script.Parent.PlayerDataService)

local ForgeService = {
	_limiter = RateLimiter.new(1),
	_forging = {} :: { [number]: boolean },
}

function ForgeService.Init()
	Remotes.Get("RequestForge").OnServerEvent:Connect(function(player)
		if not ForgeService._limiter:Allow(player.UserId) then
			return
		end
		if ForgeService._forging[player.UserId] then
			return
		end
		local data = PlayerDataService.Get(player)
		if not data or data.VoidShards < ForgeConfig.ShardsPerArtifact then
			return
		end
		local duration = ForgeConfig.ForgeDurationSeconds
		if data.ForgeTokensEarnedToday >= ForgeConfig.DailyTokenSoftCap then
			duration /= ForgeConfig.CoolingMultiplier
			Remotes.Get("JuiceEvent"):FireClient(player, { Kind = "ForgeCooling" })
		end
		ForgeService._forging[player.UserId] = true
		PlayerDataService.Mutate(player, function(d)
			d.VoidShards -= ForgeConfig.ShardsPerArtifact
		end)
		Remotes.Get("JuiceEvent"):FireClient(player, { Kind = "ForgeStart", Duration = duration })
		task.delay(duration, function()
			ForgeService._forging[player.UserId] = false
			PlayerDataService.Mutate(player, function(d)
				d.Artifacts = (d.Artifacts or 0) + 1
			end)
			Remotes.Get("JuiceEvent"):FireClient(player, { Kind = "ForgeComplete" })
			PlayerDataService.Save(player)
		end)
	end)

	Remotes.Get("TurnInArtifact").OnServerEvent:Connect(function(player)
		if not ForgeService._limiter:Allow(player.UserId) then
			return
		end
		local data = PlayerDataService.Get(player)
		if not data or (data.Artifacts or 0) < 1 then
			return
		end
		PlayerDataService.Mutate(player, function(d)
			d.Artifacts -= 1
			d.VoidlineTokens += ForgeConfig.TokensPerArtifact
			d.ForgeTokensEarnedToday += ForgeConfig.TokensPerArtifact
		end)
		PlayerDataService.Save(player)
		Remotes.Get("JuiceEvent"):FireClient(player, {
			Kind = "TokensGranted",
			Amount = ForgeConfig.TokensPerArtifact,
		})
	end)
end

return ForgeService
