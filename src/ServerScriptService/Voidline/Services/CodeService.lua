local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Voidline = ReplicatedStorage:WaitForChild("Voidline")
local CodesConfig = require(Voidline.Config.CodesConfig)
local Remotes = require(Voidline.Remotes)
local RateLimiter = require(Voidline.Modules.RateLimiter)
local PlayerDataService = require(script.Parent.PlayerDataService)

local CodeService = {
	_limiter = RateLimiter.new(1),
}

function CodeService.Init()
	Remotes.Get("RedeemCode").OnServerEvent:Connect(function(player, code)
		if not CodeService._limiter:Allow(player.UserId) then
			return
		end
		if typeof(code) ~= "string" or #code > 32 then
			return
		end
		local stripped = string.gsub(code, "%s+", "")
		code = string.upper(stripped)
		local reward = CodesConfig.Codes[code]
		local data = PlayerDataService.Get(player)
		if not reward or not data then
			Remotes.Get("JuiceEvent"):FireClient(player, { Kind = "CodeFail", Message = "Invalid code" })
			return
		end
		if reward.OneTime and data.RedeemedCodes[code] then
			Remotes.Get("JuiceEvent"):FireClient(player, { Kind = "CodeFail", Message = "Already redeemed" })
			return
		end
		PlayerDataService.Mutate(player, function(d)
			d.RedeemedCodes[code] = true
			d.Credits += reward.Credits or 0
			d.VoidShards += reward.VoidShards or 0
		end)
		PlayerDataService.Save(player)
		Remotes.Get("JuiceEvent"):FireClient(player, {
			Kind = "CodeSuccess",
			Message = reward.Message,
			Credits = reward.Credits,
			VoidShards = reward.VoidShards,
		})
	end)
end

return CodeService
