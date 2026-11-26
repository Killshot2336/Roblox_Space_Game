--!strict
-- Artifact Forge: 25 Void Shards -> 1 artifact (timed job that survives a
-- rejoin) -> 40 Voidline Tokens. After 500 tokens in a UTC day the forge
-- "cools" (slower jobs) instead of hard-capping.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Voidline = ReplicatedStorage:WaitForChild("Voidline")
local ProgressionRules = require(Voidline.Rules.ProgressionRules)

local ValidateRemote = require(script.Parent.Parent.Security.ValidateRemote)
local PlayerDataService = require(script.Parent.PlayerDataService)
local JuiceService = require(script.Parent.JuiceService)
local StatService = require(script.Parent.StatService)

local ForgeService = {}

function ForgeService.Start(player: Player): (boolean, string?)
	local ok, reason, duration = false, nil :: string?, 0
	PlayerDataService.Mutate(player, function(p)
		ok, reason, duration = ProgressionRules.StartForge(p, os.time())
	end)
	if ok then
		local profile = PlayerDataService.Get(player) :: any
		JuiceService.Send(player, "Forge", {
			Phase = "start",
			Seconds = duration,
			Cooling = ProgressionRules.ForgeCooling(profile),
		})
		task.delay(duration + 0.05, function()
			ForgeService.Collect(player)
		end)
	else
		JuiceService.Send(player, "Forge", { Phase = "fail", Reason = reason })
	end
	return ok, reason
end

function ForgeService.Collect(player: Player): boolean
	local collected = false
	PlayerDataService.Mutate(player, function(p)
		collected = ProgressionRules.CollectForge(p, os.time())
	end)
	if collected then
		JuiceService.Send(player, "Forge", { Phase = "done" })
		StatService.Bump(player, "ArtifactsForged", 1)
	end
	return collected
end

function ForgeService.TurnIn(player: Player): boolean
	local ok, tokens = false, 0
	PlayerDataService.Mutate(player, function(p)
		ok, tokens = ProgressionRules.TurnInArtifact(p, os.time())
	end)
	if ok then
		JuiceService.Send(player, "Tokens", { Amount = tokens })
		StatService.Check(player, "LifetimeTokens")
		task.spawn(PlayerDataService.Save, player)
	else
		JuiceService.Send(player, "Forge", { Phase = "fail", Reason = "artifacts" })
	end
	return ok
end

function ForgeService.Init()
	ValidateRemote.Bind("RequestForge", { Rate = 0.5, Burst = 3 }, function(player)
		local profile = PlayerDataService.Get(player)
		if not profile then
			return
		end
		if profile.ForgeJobEndsAt > 0 then
			if not ForgeService.Collect(player) then
				JuiceService.Send(player, "Forge", { Phase = "busy", EndsAt = profile.ForgeJobEndsAt })
			end
		else
			ForgeService.Start(player)
		end
	end)
	ValidateRemote.Bind("TurnInArtifact", { Rate = 0.3, Burst = 3 }, function(player)
		ForgeService.TurnIn(player)
	end)

	local map = Workspace:FindFirstChild("VoidlineMap")
	local hub = map and map:FindFirstChild("Hub")
	local pad = hub and hub:FindFirstChild("ForgePad")
	if pad then
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Forge"
		prompt.ObjectText = "Artifact Forge · 25 Shards"
		prompt.HoldDuration = 0.5
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Parent = pad
		prompt.Triggered:Connect(function(player)
			local profile = PlayerDataService.Get(player)
			if not profile then
				return
			end
			if profile.Artifacts > 0 then
				ForgeService.TurnIn(player)
			elseif profile.ForgeJobEndsAt > 0 then
				ForgeService.Collect(player)
			else
				ForgeService.Start(player)
			end
		end)
	end

	-- Finish jobs that completed while the pilot was offline.
	PlayerDataService.OnLoaded(function(player, profile)
		if profile.ForgeJobEndsAt > 0 then
			local remaining = profile.ForgeJobEndsAt - os.time()
			task.delay(math.max(0, remaining) + 0.05, function()
				ForgeService.Collect(player)
			end)
		end
	end)
end

return ForgeService
