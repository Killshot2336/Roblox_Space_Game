--!strict
-- Void Rebirth: at Station Tier 10, reset credits/tiers/drill/cargo for a
-- permanent credit multiplier and a shard payout. Passes, tokens, relics,
-- Codex, cosmetics, drone slots/evolution and discovered sectors are kept.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Voidline = ReplicatedStorage:WaitForChild("Voidline")
local RebirthConfig = require(Voidline.Config.RebirthConfig)
local ProgressionRules = require(Voidline.Rules.ProgressionRules)

local ValidateRemote = require(script.Parent.Parent.Security.ValidateRemote)
local PlayerDataService = require(script.Parent.PlayerDataService)
local JuiceService = require(script.Parent.JuiceService)
local StatService = require(script.Parent.StatService)

local RebirthService = {}

local rebirthCallbacks: { (Player) -> () } = {}

function RebirthService.OnRebirth(callback: (Player) -> ())
	table.insert(rebirthCallbacks, callback)
end

function RebirthService.Rebirth(player: Player): boolean
	local profile = PlayerDataService.Get(player)
	if not profile or not ProgressionRules.CanRebirth(profile) then
		JuiceService.Send(player, "Rebirth", {
			Ok = false,
			Required = RebirthConfig.RequiredStationTier,
		})
		return false
	end
	local n, shards = 0, 0
	PlayerDataService.Mutate(player, function(p)
		n, shards = ProgressionRules.Rebirth(p)
	end)
	JuiceService.Send(player, "Rebirth", {
		Ok = true,
		Count = n,
		Shards = shards,
		Multiplier = RebirthConfig.CreditMultiplier(n),
	})
	StatService.Check(player, "Rebirths", "LifetimeShards")
	for _, callback in rebirthCallbacks do
		task.spawn(callback, player)
	end
	task.spawn(PlayerDataService.Save, player)
	return true
end

function RebirthService.Init()
	ValidateRemote.Bind("RequestRebirth", { Rate = 2, Burst = 1 }, function(player)
		RebirthService.Rebirth(player)
	end)
	local map = Workspace:FindFirstChild("VoidlineMap")
	local hub = map and map:FindFirstChild("Hub")
	local pad = hub and hub:FindFirstChild("RebirthPad")
	if pad then
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Rebirth"
		prompt.ObjectText = ("Void Rebirth · Station Tier %d"):format(RebirthConfig.RequiredStationTier)
		prompt.HoldDuration = 1.5
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Parent = pad
		prompt.Triggered:Connect(function(player)
			RebirthService.Rebirth(player)
		end)
	end
end

return RebirthService
