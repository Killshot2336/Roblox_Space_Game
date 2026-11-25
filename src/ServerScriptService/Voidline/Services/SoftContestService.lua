local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Voidline = ReplicatedStorage:WaitForChild("Voidline")
local ContributionSplit = require(Voidline.Modules.ContributionSplit)
local Remotes = require(Voidline.Remotes)
local PlayerDataService = require(script.Parent.PlayerDataService)
local EconomyService = require(script.Parent.EconomyService)

local SoftContestService = {
	_damage = {} :: { [BasePart]: { [number]: number } },
}

function SoftContestService.AddDamage(target: BasePart, player: Player, amount: number)
	local map = SoftContestService._damage[target]
	if not map then
		map = {}
		SoftContestService._damage[target] = map
	end
	map[player.UserId] = (map[player.UserId] or 0) + amount
	Remotes.Get("SoftContestUpdate"):FireAllClients({
		Target = target,
		Damage = map,
	})
end

function SoftContestService.Resolve(target: BasePart)
	local map = SoftContestService._damage[target] or {}
	local shares = ContributionSplit.Compute(map)
	local poolOre = 80
	local topId = nil
	local topShare = -1
	for userId, share in shares do
		if share > topShare then
			topShare = share
			topId = userId
		end
	end
	for userId, share in shares do
		local player = Players:GetPlayerByUserId(userId)
		if player then
			local ore = math.max(1, math.floor(poolOre * share))
			local shards = if share >= 0.2 then 2 else 1
			if PlayerDataService.HasPerk(player, "ShardRelicLuck2x") then
				shards *= 2
			end
			EconomyService.AddOre(player, ore)
			PlayerDataService.Mutate(player, function(d)
				d.VoidShards += shards
			end)
			Remotes.Get("JuiceEvent"):FireClient(player, {
				Kind = "CoreChunk",
				Position = target.Position,
				Ore = ore,
				IsTop = userId == topId,
			})
		end
	end
	SoftContestService._damage[target] = nil
	local maxHp = target:GetAttribute("MaxHealth") or 5000
	-- Respawn timer
	target.Transparency = 0.8
	task.delay(20, function()
		if target and target.Parent then
			target:SetAttribute("Health", maxHp)
			target.Transparency = 0
		end
	end)
end

function SoftContestService.Init()
	-- no remotes; driven by DroneService
end

return SoftContestService
