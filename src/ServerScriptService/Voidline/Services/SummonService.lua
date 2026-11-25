--!strict
-- Robux-only server summons with a clean queue: one Void Starfall and one
-- Luck Surge can run at a time; extra purchases wait their turn and the HUD
-- shows the queue. Starfall drop odds are shown before purchase.
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Voidline = ReplicatedStorage:WaitForChild("Voidline")
local MonetizationConfig = require(Voidline.Config.MonetizationConfig)
local HubLayout = require(Voidline.Modules.HubLayout)
local OreRegistry = require(Voidline.Content.OreRegistry)

local SoftContestService = require(script.Parent.SoftContestService)
local RockService = require(script.Parent.RockService)
local JuiceService = require(script.Parent.JuiceService)
local WorldState = require(script.Parent.WorldState)

local SummonService = {}

type Entry = { Kind: string, BuyerName: string, BuyerId: number }

local STARFALL = "SummonVoidStarfall"
local SURGE = "ServerLuckSurge"
local STARFALL_METEOR_HEALTH = 3000

local queues: { [string]: { Entry } } = { [STARFALL] = {}, [SURGE] = {} }
local running: { [string]: Entry? } = {}
local rng = Random.new()

local function publishQueue()
	Workspace:SetAttribute("StarfallQueue", #queues[STARFALL])
	Workspace:SetAttribute("SurgeQueue", #queues[SURGE])
end

local function celestialOreId(): string
	local pool = OreRegistry.ByTier[5]
	return pool[rng:NextInteger(1, #pool)].Id
end

local runNext: (kind: string) -> ()

local function runStarfall(entry: Entry)
	local config = MonetizationConfig.Starfall
	local product = MonetizationConfig.GetProduct(STARFALL) :: MonetizationConfig.DevProduct
	local duration = product.DurationSeconds
	Workspace:SetAttribute("StarfallEndsAt", Workspace:GetServerTimeNow() + duration)
	JuiceService.BannerAll(("%s summoned a VOID STARFALL"):format(entry.BuyerName), "gold")
	local spawned: { RockService.Rock } = {}
	local gap = duration / (config.Meteors + 1)
	for i = 1, config.Meteors do
		task.delay(gap * (i - 1), function()
			local rock = SoftContestService.Spawn({
				Kind = "Meteor",
				Position = HubLayout.MeteorSlot(i, config.Meteors) + Vector3.new(0, 6, 0),
				Size = 7,
				Health = STARFALL_METEOR_HEALTH,
				OrePool = config.OrePerMeteor,
				ShardPool = config.ShardsPerMeteor,
				OreId = if rng:NextNumber() < config.CelestialOreChance then celestialOreId() else nil,
				RelicChance = config.RelicChancePerMeteor,
				Reach = 52,
				Priority = 3,
				Label = "Void Starfall",
				Stat = "StarfallsJoined",
			})
			table.insert(spawned, rock)
		end)
	end
	task.delay(duration, function()
		for _, rock in spawned do
			SoftContestService.Expire(rock)
		end
		Workspace:SetAttribute("StarfallEndsAt", 0)
		running[STARFALL] = nil
		runNext(STARFALL)
	end)
end

local function runSurge(entry: Entry)
	local product = MonetizationConfig.GetProduct(SURGE) :: MonetizationConfig.DevProduct
	WorldState.SurgeEndsAt = Workspace:GetServerTimeNow() + product.DurationSeconds
	WorldState.Publish()
	JuiceService.BannerAll(("%s started a SERVER LUCK SURGE · 2x finds"):format(entry.BuyerName), "gold")
	task.delay(product.DurationSeconds, function()
		running[SURGE] = nil
		runNext(SURGE)
	end)
end

function runNext(kind: string)
	publishQueue()
	if running[kind] then
		return
	end
	local entry = table.remove(queues[kind], 1)
	if not entry then
		return
	end
	running[kind] = entry
	publishQueue()
	if kind == STARFALL then
		runStarfall(entry)
	else
		runSurge(entry)
	end
end

-- Called by MonetizationService after a receipt is recorded.
function SummonService.Enqueue(productKey: string, buyer: Player): number
	local queue = queues[productKey]
	if not queue then
		return 0
	end
	table.insert(queue, { Kind = productKey, BuyerName = buyer.DisplayName, BuyerId = buyer.UserId })
	local position = #queue + (if running[productKey] then 1 else 0)
	if position > 1 then
		JuiceService.BannerAll(
			("%s queued a %s (#%d in line)"):format(
				buyer.DisplayName,
				(MonetizationConfig.GetProduct(productKey) :: any).Name,
				position
			),
			"info"
		)
	end
	runNext(productKey)
	return position
end

function SummonService.QueueLength(productKey: string): number
	local queue = queues[productKey]
	return (if queue then #queue else 0) + (if running[productKey] then 1 else 0)
end

function SummonService.Init()
	publishQueue()
	Workspace:SetAttribute("StarfallEndsAt", 0)
end

return SummonService
