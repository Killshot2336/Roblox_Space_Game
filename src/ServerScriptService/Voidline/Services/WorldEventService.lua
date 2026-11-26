--!strict
-- Deep-space rotation, keyed to UTC so every server shows the same thing:
--   * every 6 min a new anomaly biome rolls in (sky, gravity, ore bias,
--     hazards every ~20-30 s);
--   * halfway through each slot a 90 s world event runs (Monolith Split,
--     boss meteors, Titan wreck, modifiers, Void Rift).
-- State is mirrored to Workspace attributes for the client HUD/lighting.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Voidline = ReplicatedStorage:WaitForChild("Voidline")
local GameConfig = require(Voidline.Config.GameConfig)
local HubLayout = require(Voidline.Modules.HubLayout)
local BiomeRegistry = require(Voidline.Content.BiomeRegistry)
local WorldEventRegistry = require(Voidline.Content.WorldEventRegistry)

local PlayerDataService = require(script.Parent.PlayerDataService)
local RockService = require(script.Parent.RockService)
local SoftContestService = require(script.Parent.SoftContestService)
local DroneService = require(script.Parent.DroneService)
local RiftService = require(script.Parent.RiftService)
local CodexService = require(script.Parent.CodexService)
local StatService = require(script.Parent.StatService)
local JuiceService = require(script.Parent.JuiceService)
local WorldState = require(script.Parent.WorldState)

local WorldEventService = {}

local SLOT_SECONDS = GameConfig.WorldEventIntervalSeconds
local EVENT_OFFSET = math.floor(SLOT_SECONDS / 2)
local BASE_GRAVITY = Workspace.Gravity

type ActiveEvent = {
	Event: WorldEventRegistry.WorldEvent,
	Slot: number,
	EndsAt: number,
	Rocks: { RockService.Rock },
	Participants: { [number]: boolean },
}

local currentSlot = -1
local eventSlotDone = -1
local active: ActiveEvent? = nil
local nextHazardAt = math.huge
local witnessed: { [number]: { [string]: boolean } } = {}
local rng = Random.new()

local function inZone(player: Player): (boolean, Vector3?)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return false, nil
	end
	local p = root.Position
	return Vector3.new(p.X, 0, p.Z).Magnitude <= HubLayout.ZoneRadius, p
end

local function applyGravity()
	local mult = if WorldState.Biome then WorldState.Biome.GravityMult else 1
	if active then
		mult *= active.Event.GravityMult
	end
	Workspace.Gravity = BASE_GRAVITY * mult
end

local function startAnomaly(slot: number)
	currentSlot = slot
	local biome = BiomeRegistry.ForSlot(slot)
	WorldState.Biome = biome
	Workspace:SetAttribute("AnomalyId", biome.Id)
	Workspace:SetAttribute("AnomalyEndsAt", (slot + 1) * SLOT_SECONDS)
	Workspace:SetAttribute("NextEventAt", slot * SLOT_SECONDS + EVENT_OFFSET)
	applyGravity()
	nextHazardAt = os.time() + biome.HazardInterval
	JuiceService.BannerAll(("ANOMALY · %s (%s)"):format(biome.ArchetypeName, biome.IntensityName), "void")
end

local function fireHazard()
	local biome = WorldState.Biome
	if not biome or #biome.HazardIds == 0 then
		return
	end
	local hazard = BiomeRegistry.Hazards.ById[biome.HazardIds[rng:NextInteger(1, #biome.HazardIds)]]
	if not hazard then
		return
	end
	local angle = rng:NextNumber(0, math.pi * 2)
	local radius = rng:NextNumber(20, 80)
	local center = Vector3.new(math.cos(angle) * radius, 6, math.sin(angle) * radius)
	JuiceService.All("Hazard", {
		Id = hazard.Id,
		Phase = "telegraph",
		Position = center,
		Radius = hazard.Radius,
		Seconds = hazard.TelegraphSeconds,
		Effect = hazard.Effect,
	})
	task.delay(hazard.TelegraphSeconds, function()
		local effect = hazard.Effect
		if effect == "DronePause" then
			DroneService.PauseZone(center, hazard.Radius, hazard.Duration)
		elseif effect == "StrikeBonus" then
			RockService.DamageInRadius(center, hazard.Radius, 0.15)
		elseif effect == "LuckSurge" or effect == "OreSurge" or effect == "SlowTow" then
			WorldState.AddZone(effect, center, hazard.Radius, hazard.Duration)
		end
		-- Pull / Knockback are applied by each client to its own character.
		JuiceService.All("Hazard", {
			Id = hazard.Id,
			Phase = "strike",
			Position = center,
			Radius = hazard.Radius,
			Seconds = hazard.Duration,
			Effect = effect,
		})
		for _, player in Players:GetPlayers() do
			local ok, position = inZone(player)
			if ok and position and (position - center).Magnitude <= hazard.Radius + 10 then
				StatService.Bump(player, "HazardsSurvived", 1)
				CodexService.Discover(player, hazard.Id)
			end
		end
	end)
end

local function contestSpec(
	event: WorldEventRegistry.WorldEvent,
	kind: string,
	position: Vector3,
	health: number,
	size: number
): SoftContestService.ContestSpec
	local bias: { [number]: number }? = nil
	if event.CelestialBias > 1 then
		bias = { [5] = event.CelestialBias, [6] = event.CelestialBias }
	end
	return {
		Kind = kind,
		Position = position,
		Size = size,
		Health = health,
		OrePool = math.floor(health / 40),
		ShardPool = math.floor(health / 600),
		OreId = nil,
		RelicChance = if event.RelicGuaranteed then 1 else 0.12,
		Reach = if kind == "Core" then 80 else 52,
		Priority = 3,
		Label = event.Name,
		Bias = bias,
	}
end

local function startEvent(event: WorldEventRegistry.WorldEvent, slot: number)
	local now = os.time()
	local state: ActiveEvent = {
		Event = event,
		Slot = slot,
		EndsAt = now + event.Duration,
		Rocks = {},
		Participants = {},
	}
	active = state
	eventSlotDone = slot
	WorldState.EventId = event.Id
	WorldState.EventCreditMult = event.CreditMult
	WorldState.EventLuckMult = event.LuckMult
	WorldState.Publish()
	Workspace:SetAttribute("EventId", event.Id)
	Workspace:SetAttribute("EventEndsAt", state.EndsAt)
	applyGravity()
	JuiceService.BannerAll(event.Banner, "gold")
	JuiceService.All("WorldEvent", { Id = event.Id, Phase = "start", EndsAt = state.EndsAt })

	if event.Kind == "Monolith" then
		Workspace:SetAttribute("MonolithSplit", true)
		table.insert(
			state.Rocks,
			SoftContestService.Spawn(contestSpec(event, "Core", HubLayout.VoidCore, event.CoreHealth, 7))
		)
	elseif event.Kind == "Shower" then
		for i = 1, event.Meteors do
			local spec = contestSpec(event, "Meteor", HubLayout.MeteorSlot(i, event.Meteors), event.MeteorHealth, 8)
			table.insert(state.Rocks, SoftContestService.Spawn(spec))
		end
	elseif event.Kind == "Contest" then
		local spec = contestSpec(event, "Core", Vector3.new(0, 24, -62), event.CoreHealth, 16)
		table.insert(state.Rocks, SoftContestService.Spawn(spec))
	elseif event.Kind == "Rift" then
		RiftService.Open()
	end
end

local function endEvent()
	local state = active
	if not state then
		return
	end
	active = nil
	for _, rock in state.Rocks do
		SoftContestService.Expire(rock)
	end
	if state.Event.Kind == "Monolith" then
		Workspace:SetAttribute("MonolithSplit", false)
	elseif state.Event.Kind == "Rift" then
		RiftService.Close()
	end
	WorldState.EventId = ""
	WorldState.EventCreditMult = 1
	WorldState.EventLuckMult = 1
	WorldState.Publish()
	Workspace:SetAttribute("EventId", "")
	Workspace:SetAttribute("EventEndsAt", 0)
	applyGravity()
	JuiceService.All("WorldEvent", { Id = state.Event.Id, Phase = "end" })
	for userId in state.Participants do
		local player = Players:GetPlayerByUserId(userId)
		if player then
			StatService.Bump(player, "EventsJoined", 1)
			CodexService.Discover(player, state.Event.Id)
		end
	end
end

-- Witness tracking: being in the deep-space zone during an anomaly/event.
local function trackWitnesses()
	local biome = WorldState.Biome
	for _, player in Players:GetPlayers() do
		if not PlayerDataService.IsLoaded(player) then
			continue
		end
		local ok = inZone(player)
		if not ok then
			continue
		end
		if active then
			active.Participants[player.UserId] = true
		end
		if biome then
			local seen = witnessed[player.UserId]
			if not seen then
				seen = {}
				witnessed[player.UserId] = seen
			end
			if not seen[biome.Id] then
				seen[biome.Id] = true
				StatService.Bump(player, "AnomaliesSeen", 1)
				StatService.Bump(player, "Archetype:" .. biome.Archetype, 1)
				CodexService.Discover(player, biome.Id)
			end
		end
	end
end

function WorldEventService.Active(): WorldEventRegistry.WorldEvent?
	return if active then active.Event else nil
end

-- Studio-only: force an event now (Workspace attribute VoidlineForceEvent).
function WorldEventService.Force(eventId: string): boolean
	local event = WorldEventRegistry.ById[eventId]
	if not event then
		return false
	end
	endEvent()
	startEvent(event, currentSlot)
	return true
end

function WorldEventService.Tick(now: number)
	local slot = math.floor(now / SLOT_SECONDS)
	if slot ~= currentSlot then
		if active then
			endEvent()
		end
		startAnomaly(slot)
	end
	local eventStart = slot * SLOT_SECONDS + EVENT_OFFSET
	if not active and eventSlotDone ~= slot and now >= eventStart then
		local event = WorldEventRegistry.ForSlot(slot)
		if now < eventStart + event.Duration then
			startEvent(event, slot)
		else
			eventSlotDone = slot
		end
	end
	if active and now >= active.EndsAt then
		endEvent()
	end
	if now >= nextHazardAt and WorldState.Biome then
		nextHazardAt = now + WorldState.Biome.HazardInterval
		fireHazard()
	end
	trackWitnesses()
end

function WorldEventService.Init()
	Players.PlayerRemoving:Connect(function(player)
		witnessed[player.UserId] = nil
	end)
	if RunService:IsStudio() then
		Workspace:GetAttributeChangedSignal("VoidlineForceEvent"):Connect(function()
			local id = Workspace:GetAttribute("VoidlineForceEvent")
			if type(id) == "string" and id ~= "" then
				WorldEventService.Force(id)
				Workspace:SetAttribute("VoidlineForceEvent", nil)
			end
		end)
	end
	task.spawn(function()
		while true do
			WorldEventService.Tick(os.time())
			task.wait(1)
		end
	end)
end

return WorldEventService
