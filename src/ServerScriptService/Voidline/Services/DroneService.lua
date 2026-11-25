--!strict
-- Server-authoritative drone swarms. The server only simulates *what* each
-- swarm is mining (5 Hz) and how much damage it deals; it never creates
-- drone parts. Compact state goes out as Player attributes (count,
-- formation, target rock ids, look) and every client renders and
-- interpolates the drones, beams and tethers locally.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Voidline = ReplicatedStorage:WaitForChild("Voidline")
local DroneConfig = require(Voidline.Config.DroneConfig)
local MiningRules = require(Voidline.Rules.MiningRules)
local EconomyRules = require(Voidline.Rules.EconomyRules)
local DroneRegistry = require(Voidline.Content.DroneRegistry)

local ValidateRemote = require(script.Parent.Parent.Security.ValidateRemote)
local PlayerDataService = require(script.Parent.PlayerDataService)
local PlotService = require(script.Parent.PlotService)
local RockService = require(script.Parent.RockService)
local TowService = require(script.Parent.TowService)
local EconomyService = require(script.Parent.EconomyService)
local CodexService = require(script.Parent.CodexService)
local JuiceService = require(script.Parent.JuiceService)
local StatService = require(script.Parent.StatService)

local DroneService = {}

type SwarmState = {
	Targets: { RockService.Rock },
	NextRetarget: number,
	TargetsAttr: string,
	PausedUntil: number,
	CargoWarned: boolean,
}

local SIM_DT = 1 / DroneConfig.SimHz
local RETARGET_SECONDS = 1
local MUTATION_CHANCE_PER_EVOLUTION = 0.12
-- Beam-Link squad bonus counts linked squadmates within this range.
local LINK_RANGE = 60

local states: { [number]: SwarmState } = {}
local pausedZones: { { Center: Vector3, Radius: number, Until: number } } = {}
local rng = Random.new()

-- Set by SquadService: squadmates flying Beam-Link near `player`.
DroneService.LinkedSquadmates = function(_player: Player, _range: number): number
	return 0
end

local function stateFor(player: Player): SwarmState
	local state = states[player.UserId]
	if not state then
		state = { Targets = {}, NextRetarget = 0, TargetsAttr = "", PausedUntil = 0, CargoWarned = false }
		states[player.UserId] = state
	end
	return state
end

-- Hazards (Solar Flare, Radiation Bloom) pause every drone inside a sphere.
function DroneService.PauseZone(center: Vector3, radius: number, seconds: number)
	table.insert(pausedZones, { Center = center, Radius = radius, Until = os.clock() + seconds })
end

local function inPausedZone(position: Vector3, now: number): boolean
	for i = #pausedZones, 1, -1 do
		local zone = pausedZones[i]
		if now >= zone.Until then
			table.remove(pausedZones, i)
		elseif (position - zone.Center).Magnitude <= zone.Radius then
			return true
		end
	end
	return false
end

local function setTargets(player: Player, state: SwarmState, targets: { RockService.Rock })
	state.Targets = targets
	local ids = table.create(#targets)
	for i, rock in targets do
		ids[i] = tostring(rock.Id)
	end
	local attr = table.concat(ids, ",")
	if attr ~= state.TargetsAttr then
		state.TargetsAttr = attr
		player:SetAttribute("DroneTargets", attr)
	end
end

-- Appearance + count replicated for client rendering.
function DroneService.RefreshLook(player: Player)
	local profile = PlayerDataService.Get(player)
	if not profile then
		return
	end
	local perks = PlayerDataService.Perks(player)
	local evolution = DroneRegistry.EvolutionFor(profile.DroneTier, profile.DroneBranch)
	player:SetAttribute("DroneCount", MiningRules.DroneCount(profile, perks))
	player:SetAttribute("Formation", profile.Formation)
	player:SetAttribute("DroneEvo", evolution.Id)
	player:SetAttribute("DroneMutation", profile.Cosmetics.DroneMutation)
	player:SetAttribute("LaserColor", profile.Settings.LaserColor)
	local laser = profile.Cosmetics.LaserShader
	if laser == "" and perks.LaserOverclock then
		laser = "laser.overclock"
	end
	player:SetAttribute("LaserShader", laser)
	player:SetAttribute("HitEffect", profile.Cosmetics.HitEffect)
	player:SetAttribute("Thruster", profile.Cosmetics.Thruster)
end

local function chooseTargets(player: Player, profile: any, root: BasePart, state: SwarmState): { RockService.Rock }
	local candidates = RockService.Candidates(root.Position, player.UserId, PlotService.IsOnPlot(player))
	local space = EconomyRules.CargoSpace(profile) - TowService.PendingOre(player.UserId)
	local formation = profile.Formation
	local stats = DroneConfig.FormationStats[formation] or DroneConfig.FormationStats[1]
	local picked: { RockService.Rock } = {}
	local skippedBelt = false
	for _, rock in candidates do
		if #picked >= stats.MaxTargets then
			break
		end
		if rock.Kind == "Belt" and space <= 0 then
			skippedBelt = true
			continue
		end
		if stats.EscortRange and (rock.Position - root.Position).Magnitude > stats.EscortRange then
			continue
		end
		if rock.Kind == "Belt" then
			-- Do not split the swarm over rocks whose ore cannot fit.
			space -= MiningRules.OrePerRock(profile, rock.Ore)
		end
		table.insert(picked, rock)
	end
	if skippedBelt and #picked == 0 then
		if not state.CargoWarned then
			state.CargoWarned = true
			JuiceService.Send(player, "CargoFull", {})
		end
	else
		state.CargoWarned = false
	end
	return picked
end

local function stepPlayer(player: Player, now: number)
	local session = PlayerDataService.Session(player)
	local state = stateFor(player)
	local root = PlotService.RootPart(player)
	if not session or not root or player:GetAttribute("Afk") == true or inPausedZone(root.Position, now) then
		if #state.Targets > 0 then
			setTargets(player, state, {})
		end
		return
	end
	local profile = session.Profile
	local needRetarget = now >= state.NextRetarget or #state.Targets == 0
	for _, rock in state.Targets do
		if not rock.Alive then
			needRetarget = true
		end
	end
	if needRetarget then
		state.NextRetarget = now + RETARGET_SECONDS
		setTargets(player, state, chooseTargets(player, profile, root, state))
	end
	local targets = state.Targets
	if #targets == 0 then
		return
	end
	local linked = if profile.Formation == 2 then DroneService.LinkedSquadmates(player, LINK_RANGE) else 0
	local dps = MiningRules.SwarmDps(profile, PlayerDataService.Perks(player), profile.Formation, linked)
	local share = dps * SIM_DT / #targets
	for _, rock in targets do
		RockService.Damage(rock, player, share)
	end
end

function DroneService.Step(now: number)
	for _, player in Players:GetPlayers() do
		stepPlayer(player, now)
	end
	RockService.FlushHealth()
end

local function onUpgraded(player: Player, upgradeId: string)
	if upgradeId == "DroneTier" then
		local profile = PlayerDataService.Get(player)
		if profile then
			local evolution = DroneRegistry.EvolutionFor(profile.DroneTier, profile.DroneBranch)
			CodexService.Discover(player, evolution.Id)
			JuiceService.Send(player, "Evolution", { Id = evolution.Id })
			StatService.Check(player, "Branch:" .. profile.DroneBranch)
			if rng:NextNumber() < MUTATION_CHANCE_PER_EVOLUTION then
				local mutations = DroneRegistry.ByCategory("Mutation")
				local mutation = mutations[rng:NextInteger(1, #mutations)]
				PlayerDataService.Mutate(player, function(p)
					p.Unlocks[mutation.Id] = true
				end)
				CodexService.Discover(player, mutation.Id)
				JuiceService.Send(player, "Mutation", { Id = mutation.Id })
			end
		end
	end
	if upgradeId == "DroneTier" or upgradeId == "DroneSlot" then
		DroneService.RefreshLook(player)
	end
end

function DroneService.Init()
	ValidateRemote.Bind(
		"SetFormation",
		{ Rate = 0.3, Burst = 3, Args = { "integer" }, Range = { { 1, 3 } } },
		function(player, formation)
			PlayerDataService.Mutate(player, function(p)
				p.Formation = formation
			end)
			DroneService.RefreshLook(player)
			local state = states[player.UserId]
			if state then
				state.NextRetarget = 0
			end
		end
	)

	PlayerDataService.OnLoaded(function(player)
		DroneService.RefreshLook(player)
	end)
	EconomyService.OnUpgraded(onUpgraded)

	Players.PlayerRemoving:Connect(function(player)
		states[player.UserId] = nil
	end)

	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < SIM_DT then
			return
		end
		accumulator -= SIM_DT
		-- Never try to catch up more than one step after a hitch.
		accumulator = math.min(accumulator, SIM_DT)
		DroneService.Step(os.clock())
	end)
end

return DroneService
