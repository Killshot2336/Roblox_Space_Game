--!strict
-- Personal asteroid belt around each claimed plot. Only the owner's drones
-- mine it; broken rocks are tethered home to the Grinder Core and pay out
-- on arrival. During onboarding every rock is the same starter ore so the
-- tutorial is exactly 10 ore -> 30 Credits.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Voidline = ReplicatedStorage:WaitForChild("Voidline")
local GameConfig = require(Voidline.Config.GameConfig)
local EconomyConfig = require(Voidline.Config.EconomyConfig)
local GalaxyConfig = require(Voidline.Config.GalaxyConfig)
local PlotLayout = require(Voidline.Modules.PlotLayout)
local EconomyRules = require(Voidline.Rules.EconomyRules)
local MiningRules = require(Voidline.Rules.MiningRules)
local OreRegistry = require(Voidline.Content.OreRegistry)

local PlayerDataService = require(script.Parent.PlayerDataService)
local PlotService = require(script.Parent.PlotService)
local RockService = require(script.Parent.RockService)
local TowService = require(script.Parent.TowService)
local EconomyService = require(script.Parent.EconomyService)
local StatService = require(script.Parent.StatService)
local RelicService = require(script.Parent.RelicService)
local WorldState = require(script.Parent.WorldState)

local BeltService = {}

type Belt = {
	Owner: Player,
	Index: number,
	Slots: { [number]: RockService.Rock | false },
	Generation: number,
	Sector: string,
}

local belts: { [number]: Belt } = {}
local rng = Random.new()

local function sectorIndex(sectorId: string): number
	for i, sector in GalaxyConfig.Sectors do
		if sector.Id == sectorId then
			return i
		end
	end
	return 1
end

local function rollOre(player: Player, profile: any): OreRegistry.Ore
	if not profile.TutorialComplete then
		return OreRegistry.ById[OreRegistry.TutorialOreId]
	end
	local index = sectorIndex(EconomyRules.ActiveSector(profile))
	return OreRegistry.Roll(rng, index, WorldState.Luck(player), nil)
end

local spawnSlot: (belt: Belt, slot: number) -> ()

local function onBreak(belt: Belt, slot: number, generation: number)
	return function(rock: RockService.Rock, _killer: Player?)
		if belts[belt.Index] ~= belt or belt.Generation ~= generation then
			RockService.ReleasePart(rock.Part)
			return
		end
		belt.Slots[slot] = false
		task.delay(GameConfig.BeltRespawnSeconds, function()
			if belts[belt.Index] == belt and belt.Generation == generation and belt.Slots[slot] == false then
				spawnSlot(belt, slot)
			end
		end)

		local owner = belt.Owner
		local profile = PlayerDataService.Get(owner)
		local grinder = PlotService.GrinderPosition(owner)
		if not profile or not grinder then
			RockService.ReleasePart(rock.Part)
			return
		end
		local perks = PlayerDataService.Perks(owner)
		local amount = MiningRules.OrePerRock(profile, rock.Ore)
		local duration = MiningRules.TowSeconds(profile, perks, (grinder - rock.Position).Magnitude)
		local oreId = rock.OreId
		local tutorial = not profile.TutorialComplete
		TowService.Start({
			Player = owner,
			Part = rock.Part,
			From = rock.Position,
			To = grinder,
			Duration = duration,
			Ore = amount,
			OnArrive = function()
				EconomyService.GrantOre(owner, oreId, amount, { Position = grinder, Source = "belt" })
				StatService.Bump(owner, "RocksMined", 1)
				local current = PlayerDataService.Get(owner)
				if current then
					StatService.Bump(owner, "Formation:" .. tostring(current.Formation), 1)
				end
				if tutorial then
					return
				end
				local ore = OreRegistry.ById[oreId]
				local luck = WorldState.Luck(owner)
				if ore and rng:NextNumber() < ore.ShardChance * luck then
					EconomyService.AddShards(owner, 1, "belt")
				end
				if ore then
					RelicService.TryFind(owner, ore.RelicChance * luck, "belt")
				end
			end,
		})
	end
end

function spawnSlot(belt: Belt, slot: number)
	local profile = PlayerDataService.Get(belt.Owner)
	if not profile then
		return
	end
	local sectorId = EconomyRules.ActiveSector(profile)
	local stats = EconomyConfig.BeltAsteroid[sectorId] or EconomyConfig.BeltAsteroid.Starter
	local ore = rollOre(belt.Owner, profile)
	local count = GameConfig.BeltAsteroidsPerPlot
	local wobble = rng:NextNumber(-3, 3)
	local generation = belt.Generation
	local rock = RockService.Create({
		Kind = "Belt",
		Position = PlotLayout.BeltSlot(belt.Index, slot, count, wobble),
		Size = 3.4 + ore.TierIndex * 0.35 + rng:NextNumber(0, 0.8),
		OreId = ore.Id,
		Health = stats.Health,
		Ore = stats.Ore,
		OwnerUserId = belt.Owner.UserId,
		Priority = 1,
		OnBreak = onBreak(belt, slot, generation),
		Data = { PlotIndex = belt.Index, Slot = slot },
		Name = "BeltRock",
	})
	belt.Slots[slot] = rock
end

local function clear(index: number)
	local belt = belts[index]
	if not belt then
		return
	end
	belt.Generation += 1
	for slot, rock in belt.Slots do
		if rock then
			RockService.Remove(rock :: RockService.Rock)
		end
		belt.Slots[slot] = false
	end
	belts[index] = nil
end

-- Respawns the whole belt (after a rebirth resets the sector, for example).
function BeltService.Reset(player: Player)
	local index = PlotService.IndexOf(player)
	if not index then
		return
	end
	clear(index)
	local profile = PlayerDataService.Get(player)
	local belt: Belt = {
		Owner = player,
		Index = index,
		Slots = {},
		Generation = 0,
		Sector = if profile then EconomyRules.ActiveSector(profile) else "Starter",
	}
	belts[index] = belt
	for slot = 1, GameConfig.BeltAsteroidsPerPlot do
		spawnSlot(belt, slot)
	end
end

function BeltService.Rocks(player: Player): { RockService.Rock }
	local out: { RockService.Rock } = {}
	local index = PlotService.IndexOf(player)
	local belt = index and belts[index]
	if belt then
		for _, rock in belt.Slots do
			if rock then
				table.insert(out, rock :: RockService.Rock)
			end
		end
	end
	return out
end

function BeltService.Init()
	PlotService.OnClaimed(function(player)
		BeltService.Reset(player)
	end)
	PlotService.OnReleased(function(_player, index)
		clear(index)
	end)
	-- Reaching a new sector rerolls the belt so richer rocks appear at once.
	EconomyService.OnUpgraded(function(player, upgradeId)
		if upgradeId ~= "StationTier" and upgradeId ~= "DroneTier" then
			return
		end
		local index = PlotService.IndexOf(player)
		local belt = index and belts[index]
		local profile = PlayerDataService.Get(player)
		if belt and profile and belt.Sector ~= EconomyRules.ActiveSector(profile) then
			BeltService.Reset(player)
		end
	end)
end

return BeltService
