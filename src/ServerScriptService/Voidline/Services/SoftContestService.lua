--!strict
-- Soft contests: shared deep-space rocks, boss meteors and event cores.
-- Anyone in range can mine them; nobody can "steal" them. On break (or when
-- an event ends) the ore and shard pools are split by damage dealt:
-- qualify at >= 5%, 40% bonus to the top contributor + 60% proportional.
-- Every qualifier's share is towed home as a chunk to their Grinder Core.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Voidline = ReplicatedStorage:WaitForChild("Voidline")
local GameConfig = require(Voidline.Config.GameConfig)
local EconomyConfig = require(Voidline.Config.EconomyConfig)
local HubLayout = require(Voidline.Modules.HubLayout)
local ContributionSplit = require(Voidline.Modules.ContributionSplit)
local MiningRules = require(Voidline.Rules.MiningRules)
local OreRegistry = require(Voidline.Content.OreRegistry)
local Remotes = require(Voidline.Remotes)

local PlayerDataService = require(script.Parent.PlayerDataService)
local PlotService = require(script.Parent.PlotService)
local RockService = require(script.Parent.RockService)
local TowService = require(script.Parent.TowService)
local EconomyService = require(script.Parent.EconomyService)
local StatService = require(script.Parent.StatService)
local RelicService = require(script.Parent.RelicService)
local JuiceService = require(script.Parent.JuiceService)
local WorldState = require(script.Parent.WorldState)

local SoftContestService = {}

export type ContestSpec = {
	Kind: string, -- "Shared" | "Meteor" | "Core"
	Position: Vector3,
	Size: number,
	Health: number,
	OrePool: number,
	ShardPool: number,
	OreId: string?,
	Bias: { [number]: number }?,
	RelicChance: number?,
	Reach: number?,
	Priority: number?,
	Label: string?,
	Stat: string?, -- extra stat bumped for qualifiers (e.g. "StarfallsJoined")
	OnResolved: ((RockService.Rock) -> ())?,
}

local UPDATE_INTERVAL = 0.5
local DEEP_SPACE_SECTOR = 3

local rng = Random.new()
local contests: { [number]: { Rock: RockService.Rock, Spec: ContestSpec, LastSent: number } } = {}
local sharedSlots: { [number]: RockService.Rock | false } = {}

local function rollOre(bias: { [number]: number }?): string
	local ore = OreRegistry.Roll(rng, DEEP_SPACE_SECTOR, 1, bias)
	return ore.Id
end

-- Splits a contest and tows each qualifier's share home. `fraction` scales
-- the pools (1 = destroyed; less when an event ended before the break).
function SoftContestService.Resolve(rock: RockService.Rock, spec: ContestSpec, fraction: number)
	local shares = ContributionSplit.Compute(rock.Damage)
	local orePayouts = ContributionSplit.Allocate(shares, spec.OrePool * fraction)
	local shardPayouts = ContributionSplit.Allocate(shares, spec.ShardPool * fraction)
	local topId = ContributionSplit.TopContributor(shares)
	for userId, share in shares do
		local player = Players:GetPlayerByUserId(userId)
		if not player or not PlayerDataService.IsLoaded(player) then
			continue
		end
		local profile = PlayerDataService.Get(player) :: any
		local surge = WorldState.ZoneMult("OreSurge", rock.Position, 1.5)
		local ore = MiningRules.OrePerRock(profile, (orePayouts[userId] or 0) * surge)
		local shards = shardPayouts[userId] or 0
		local isTop = userId == topId
		local luck = WorldState.Luck(player, rock.Position)
		local baseChance = spec.RelicChance or 0
		local guaranteed = isTop and baseChance >= 1
		local relicChance = if isTop
			then baseChance * luck * WorldState.RelicMult()
			else math.min(0.25, baseChance * 0.1 * luck)
		local function payout()
			if ore > 0 then
				EconomyService.GrantOre(player, rock.OreId, ore, { Overflow = "refine", Source = spec.Kind })
			end
			if shards > 0 then
				EconomyService.AddShards(player, shards, spec.Kind)
			end
			if guaranteed then
				RelicService.Grant(player, spec.Kind)
			else
				RelicService.TryFind(player, relicChance, spec.Kind)
			end
		end
		JuiceService.Send(player, "ContestShare", {
			Kind = spec.Kind,
			Label = spec.Label,
			Share = share,
			Ore = ore,
			Shards = shards,
			Top = isTop,
		})
		if spec.Kind ~= "Shared" then
			StatService.Bump(player, "MeteorsContested", 1)
			if isTop then
				StatService.Bump(player, "MeteorTops", 1)
			end
		end
		if spec.Stat then
			StatService.Bump(player, spec.Stat, 1)
		end
		local grinder = PlotService.GrinderPosition(player)
		if grinder then
			local perks = PlayerDataService.Perks(player)
			local duration = MiningRules.TowSeconds(profile, perks, (grinder - rock.Position).Magnitude)
			TowService.StartChunk(player, rock.OreId, rock.Position, grinder, duration, payout)
		else
			payout()
		end
	end
	if spec.OnResolved then
		spec.OnResolved(rock)
	end
end

local function sendUpdate(entry: { Rock: RockService.Rock, Spec: ContestSpec, LastSent: number }, final: boolean)
	local rock = entry.Rock
	local top = {}
	for _, row in RockService.TopContributors(rock, 3) do
		local player = Players:GetPlayerByUserId(row.UserId)
		table.insert(top, { Name = if player then player.DisplayName else "Pilot", Share = row.Share })
	end
	Remotes.GetUnreliable("SoftContestUpdate"):FireAllClients({
		Id = rock.Id,
		Label = entry.Spec.Label or entry.Spec.Kind,
		Health = math.ceil(rock.Health),
		Max = rock.MaxHealth,
		Top = top,
		Done = final,
	})
end

function SoftContestService.Spawn(spec: ContestSpec): RockService.Rock
	local entry: { Rock: RockService.Rock, Spec: ContestSpec, LastSent: number }
	local rock = RockService.Create({
		Kind = spec.Kind,
		Position = spec.Position,
		Size = spec.Size,
		OreId = spec.OreId or rollOre(spec.Bias or (if WorldState.Biome then WorldState.Biome.TierBias else nil)),
		Health = spec.Health,
		Reach = spec.Reach or 42,
		Priority = spec.Priority or 2,
		Name = spec.Kind,
		OnBreak = function(broken, _killer)
			contests[broken.Id] = nil
			sendUpdate(entry, true)
			RockService.ReleasePart(broken.Part)
			SoftContestService.Resolve(broken, spec, 1)
		end,
	})
	entry = { Rock = rock, Spec = spec, LastSent = 0 }
	contests[rock.Id] = entry
	return rock
end

-- Ends a contest early (event over): pays out the share of health removed.
function SoftContestService.Expire(rock: RockService.Rock)
	local entry = contests[rock.Id]
	if not entry or not rock.Alive then
		return
	end
	contests[rock.Id] = nil
	local fraction = 1 - rock.Health / rock.MaxHealth
	sendUpdate(entry, true)
	RockService.Remove(rock)
	if fraction > 0 then
		SoftContestService.Resolve(rock, entry.Spec, fraction)
	elseif entry.Spec.OnResolved then
		entry.Spec.OnResolved(rock)
	end
end

local function spawnShared(slot: number)
	local pool = EconomyConfig.SharedAsteroid
	local rock = SoftContestService.Spawn({
		Kind = "Shared",
		Position = HubLayout.SharedRockSlot(slot, GameConfig.SharedAsteroidCount),
		Size = 9,
		Health = pool.Health,
		OrePool = pool.OrePool,
		ShardPool = pool.ShardPool,
		RelicChance = 0.02,
		Reach = 48,
		Priority = 2,
		Label = "Deep-Space Rock",
		OnResolved = function()
			sharedSlots[slot] = false
			task.delay(GameConfig.SharedRespawnSeconds, function()
				if sharedSlots[slot] == false then
					spawnShared(slot)
				end
			end)
		end,
	})
	sharedSlots[slot] = rock
end

function SoftContestService.Init()
	for slot = 1, GameConfig.SharedAsteroidCount do
		spawnShared(slot)
	end
	task.spawn(function()
		while true do
			task.wait(UPDATE_INTERVAL)
			for _, entry in contests do
				if entry.Rock.Alive and entry.Rock.Health ~= entry.LastSent and next(entry.Rock.Damage) then
					entry.LastSent = entry.Rock.Health
					sendUpdate(entry, false)
				end
			end
		end
	end)
end

return SoftContestService
