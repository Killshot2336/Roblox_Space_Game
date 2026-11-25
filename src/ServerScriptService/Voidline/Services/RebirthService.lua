local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Voidline = ReplicatedStorage:WaitForChild("Voidline")
local RebirthConfig = require(Voidline.Config.RebirthConfig)
local Remotes = require(Voidline.Remotes)
local RateLimiter = require(Voidline.Modules.RateLimiter)
local PlayerDataService = require(script.Parent.PlayerDataService)

local RebirthService = {
	_limiter = RateLimiter.new(2),
}

function RebirthService.Init()
	Remotes.Get("RequestRebirth").OnServerEvent:Connect(function(player)
		if not RebirthService._limiter:Allow(player.UserId) then
			return
		end
		local data = PlayerDataService.Get(player)
		if not data or data.StationTier < RebirthConfig.RequiredStationTier then
			return
		end
		local nextRebirth = data.Rebirths + 1
		local shards = RebirthConfig.ShardPayout(nextRebirth)
		PlayerDataService.Mutate(player, function(d)
			d.Rebirths = nextRebirth
			d.CreditMult = RebirthConfig.CreditMultiplier(nextRebirth)
			d.Credits = 0
			d.Ore = 0
			d.StationTier = 1
			d.DrillLevel = 1
			d.CargoLevel = 1
			-- Keep drone slots as quality-of-life; design said basic drill/cargo + pads reset
			d.VoidShards += shards
			d.Cosmetics.Title = "VOID " .. tostring(nextRebirth)
			d.GalaxyFlags.Nebula = false
			d.GalaxyFlags.VoidRim = false
			d.GalaxyFlags.Celestial = false
			d.GalaxyFlags.Starter = true
		end)
		PlayerDataService.Save(player)
		Remotes.Get("JuiceEvent"):FireAllClients({
			Kind = "RebirthShockwave",
			PlayerName = player.DisplayName,
			Rebirths = nextRebirth,
		})
	end)
end

return RebirthService
