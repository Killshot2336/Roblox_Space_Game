--!strict
-- Server-wide modifiers shared by mining services without making them depend
-- on each other. WorldEventService / SummonService write; everyone reads.
-- Mirrored to Workspace attributes so clients can show them.
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Voidline = ReplicatedStorage:WaitForChild("Voidline")
local MiningRules = require(Voidline.Rules.MiningRules)
local BiomeRegistry = require(Voidline.Content.BiomeRegistry)

local PlayerDataService = require(script.Parent.PlayerDataService)

local WorldState = {
	EventCreditMult = 1,
	EventLuckMult = 1,
	SurgeEndsAt = 0,
	Biome = nil :: BiomeRegistry.Biome?,
	EventId = "",
	-- Set by SquadService: true when a squadmate flies nearby.
	SquadLinked = function(_player: Player): boolean
		return false
	end,
	-- Hazard zones (LuckSurge, OreSurge, SlowTow) written by WorldEventService.
	Zones = {} :: { { Effect: string, Center: Vector3, Radius: number, Until: number } },
}

-- Multiplier from active hazard zones covering `position`.
function WorldState.ZoneMult(effect: string, position: Vector3, mult: number): number
	local now = os.clock()
	local result = 1
	for i = #WorldState.Zones, 1, -1 do
		local zone = WorldState.Zones[i]
		if now >= zone.Until then
			table.remove(WorldState.Zones, i)
		elseif zone.Effect == effect and (position - zone.Center).Magnitude <= zone.Radius then
			result = mult
		end
	end
	return result
end

function WorldState.AddZone(effect: string, center: Vector3, radius: number, seconds: number)
	table.insert(WorldState.Zones, { Effect = effect, Center = center, Radius = radius, Until = os.clock() + seconds })
end

function WorldState.SurgeActive(): boolean
	return Workspace:GetServerTimeNow() < WorldState.SurgeEndsAt
end

function WorldState.CreditBoost(): number
	local biomeMult = if WorldState.Biome then WorldState.Biome.CreditMult else 1
	return WorldState.EventCreditMult * biomeMult
end

-- Shard/relic luck for a pilot (passes, squad link, server surge, events).
function WorldState.Luck(player: Player, position: Vector3?): number
	local perks = PlayerDataService.Perks(player)
	local luck = MiningRules.LuckMultiplier(perks, WorldState.SquadLinked(player), WorldState.SurgeActive())
	luck *= WorldState.EventLuckMult
	if position then
		luck *= WorldState.ZoneMult("LuckSurge", position, 2)
	end
	return luck
end

function WorldState.RelicMult(): number
	return if WorldState.Biome then WorldState.Biome.RelicMult else 1
end

function WorldState.Publish()
	Workspace:SetAttribute("EventCreditMult", WorldState.EventCreditMult)
	Workspace:SetAttribute("EventLuckMult", WorldState.EventLuckMult)
	Workspace:SetAttribute("LuckSurgeEndsAt", WorldState.SurgeEndsAt)
end

function WorldState.Init()
	PlayerDataService.CreditBoostProvider = WorldState.CreditBoost
	WorldState.Publish()
end

return WorldState
