--!strict
-- Code Terminal (VOIDLINE, KILLSHOT, LAUNCH). Codes are fixed strings from
-- CodesConfig; nothing a pilot types is ever shown to anyone else.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Voidline = ReplicatedStorage:WaitForChild("Voidline")
local CodesConfig = require(Voidline.Config.CodesConfig)
local ProgressionRules = require(Voidline.Rules.ProgressionRules)

local ValidateRemote = require(script.Parent.Parent.Security.ValidateRemote)
local PlayerDataService = require(script.Parent.PlayerDataService)
local JuiceService = require(script.Parent.JuiceService)
local StatService = require(script.Parent.StatService)

local CodeService = {}

function CodeService.Redeem(player: Player, raw: any): (boolean, string?)
	local ok, reason, code = false, nil :: string?, nil :: string?
	PlayerDataService.Mutate(player, function(p)
		ok, reason, code = ProgressionRules.RedeemCode(p, raw)
	end)
	if not ok then
		JuiceService.Send(player, "Code", { Ok = false, Reason = reason })
		return false, reason
	end
	local reward = CodesConfig.Codes[code :: string]
	JuiceService.Send(player, "Code", {
		Ok = true,
		Message = reward.Message,
		Credits = reward.Credits,
		Shards = reward.VoidShards,
		Title = reward.Title,
	})
	StatService.Bump(player, "CodesRedeemed", 1)
	StatService.Check(player, "LifetimeCredits", "LifetimeShards")
	task.spawn(PlayerDataService.Save, player)
	return true, nil
end

function CodeService.Init()
	ValidateRemote.Bind(
		"RedeemCode",
		{ Rate = 1.5, Burst = 3, Args = { "string" }, MaxString = 64 },
		function(player, raw)
			CodeService.Redeem(player, raw)
		end
	)
end

return CodeService
