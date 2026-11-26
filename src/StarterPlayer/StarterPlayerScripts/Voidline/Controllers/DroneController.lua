--!strict
-- Renders every pilot's drone swarm from the compact state the server
-- replicates as Player attributes (count, formation, target rock ids, look).
-- Drones are pooled local parts moved with BulkMoveTo; lasers and tow tethers
-- are Beams; thruster Trails and hit sparks are cut in Performance Mode.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Voidline = ReplicatedStorage:WaitForChild("Voidline")
local DroneConfig = require(Voidline.Config.DroneConfig)
local DroneRegistry = require(Voidline.Content.DroneRegistry)

local Client = script.Parent.Parent.Client
local Ui = require(Client.Ui)
local TowController = require(script.Parent.TowController)

local DroneController = {}

type Drone = {
	Body: Part,
	Fin: Part,
	Attach: Attachment,
	Laser: Beam,
	Tether: Beam,
	Trail: Trail,
	Position: Vector3,
	Index: number,
}

type Fleet = {
	Player: Player,
	Drones: { Drone },
	Links: { Beam },
	LookKey: string,
	LaserColor: Color3,
	LaserWidth: number,
	LaserStyle: string,
	HitColor: Color3,
	Seed: number,
}

local HIDDEN = CFrame.new(0, -1000, 0)
local ROCK_TAG = "VoidRock"
local LASER_RANGE = 46
local FOLLOW_RATE = 6
local SNAP_DISTANCE = 220
local FAR_DISTANCE = 260
local OTHER_PILOT_CAP_PERF = 3
local LINK_POOL_MAX = 14
local GOLDEN_ANGLE = 2.39996

local MUTATION_MATERIAL: { [string]: Enum.Material } = {
	["drone.mut.shiny"] = Enum.Material.Glass,
	["drone.mut.golden"] = Enum.Material.Foil,
	["drone.mut.void_corrupted"] = Enum.Material.ForceField,
	["drone.mut.starforged"] = Enum.Material.Neon,
	["drone.mut.crystalline"] = Enum.Material.Glass,
	["drone.mut.obsidian"] = Enum.Material.Basalt,
}

local folder: Folder
local pool: { Drone } = {}
local linkPool: { Beam } = {}
local fleets: { [Player]: Fleet } = {}
local rockById: { [number]: BasePart } = {}
local aimAttachments: { [BasePart]: Attachment } = {}
local hitEmitters: { [BasePart]: ParticleEmitter } = {}
local perfMode = false

-- Rocks -----------------------------------------------------------------------

local function indexRock(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	local part = instance :: BasePart
	local function update()
		for id, known in rockById do
			if known == part then
				rockById[id] = nil
			end
		end
		local id = part:GetAttribute("RockId")
		if type(id) == "number" then
			rockById[id] = part
		end
	end
	part:GetAttributeChangedSignal("RockId"):Connect(update)
	update()
end

local function aimAttachment(part: BasePart): Attachment
	local existing = aimAttachments[part]
	if existing and existing.Parent then
		return existing
	end
	local attachment = Ui.Make("Attachment", { Name = "VoidlineAim", Parent = part }) :: Attachment
	aimAttachments[part] = attachment
	return attachment
end

local function hitEmitter(part: BasePart): ParticleEmitter
	local existing = hitEmitters[part]
	if existing and existing.Parent then
		return existing
	end
	local emitter = Ui.Make("ParticleEmitter", {
		Name = "VoidlineHit",
		Enabled = false,
		Rate = 18,
		Lifetime = NumberRange.new(0.25, 0.45),
		Speed = NumberRange.new(6, 12),
		SpreadAngle = Vector2.new(180, 180),
		Size = NumberSequence.new(0.35, 0),
		LightEmission = 1,
		LightInfluence = 0,
		Parent = aimAttachment(part),
	}) :: ParticleEmitter
	hitEmitters[part] = emitter
	return emitter
end

local function parseTargets(value: any): { BasePart }
	local out = {}
	if type(value) ~= "string" or value == "" then
		return out
	end
	for _, token in string.split(value, ",") do
		local id = tonumber(token)
		local part = if id then rockById[id] else nil
		if part and part.Parent and part:GetAttribute("Hidden") ~= true then
			table.insert(out, part)
		end
	end
	return out
end

-- Pools -------------------------------------------------------------------------

local function newDrone(): Drone
	local body = Ui.Make("Part", {
		Name = "Drone",
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Shape = Enum.PartType.Ball,
		Material = Enum.Material.Metal,
		Size = Vector3.new(1.3, 1.3, 1.3),
		CFrame = HIDDEN,
		Parent = folder,
	}) :: Part
	local fin = Ui.Make("Part", {
		Name = "Fin",
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Material = Enum.Material.Neon,
		Size = Vector3.new(2.2, 0.12, 0.5),
		CFrame = HIDDEN,
		Parent = folder,
	}) :: Part
	local attach = Ui.Make("Attachment", { Name = "Emitter", Position = Vector3.new(0, 0, -0.6), Parent = body })
	local tail0 = Ui.Make("Attachment", { Name = "Tail0", Position = Vector3.new(0, 0.2, 0.6), Parent = body })
	local tail1 = Ui.Make("Attachment", { Name = "Tail1", Position = Vector3.new(0, -0.2, 0.6), Parent = body })
	local laser = Ui.Make("Beam", {
		Name = "Laser",
		Attachment0 = attach,
		Enabled = false,
		FaceCamera = true,
		LightEmission = 1,
		LightInfluence = 0,
		Segments = 1,
		Width0 = 0.25,
		Width1 = 0.15,
		Parent = body,
	}) :: Beam
	local tether = Ui.Make("Beam", {
		Name = "Tether",
		Attachment0 = attach,
		Enabled = false,
		FaceCamera = true,
		LightEmission = 1,
		LightInfluence = 0,
		Segments = 10,
		CurveSize0 = 1.5,
		CurveSize1 = -1.5,
		Width0 = 0.35,
		Width1 = 0.35,
		Color = ColorSequence.new(Color3.fromRGB(150, 230, 255), Color3.fromRGB(255, 230, 150)),
		Transparency = NumberSequence.new(0.2, 0.5),
		Parent = body,
	}) :: Beam
	local trail = Ui.Make("Trail", {
		Name = "Thruster",
		Attachment0 = tail0,
		Attachment1 = tail1,
		Enabled = false,
		Lifetime = 0.35,
		LightEmission = 1,
		LightInfluence = 0,
		Transparency = NumberSequence.new(0.3, 1),
		WidthScale = NumberSequence.new(1, 0),
		Parent = body,
	}) :: Trail
	return {
		Body = body,
		Fin = fin,
		Attach = attach,
		Laser = laser,
		Tether = tether,
		Trail = trail,
		Position = HIDDEN.Position,
		Index = 0,
	}
end

local function acquireDrone(): Drone
	return table.remove(pool) or newDrone()
end

local function releaseDrone(drone: Drone)
	drone.Laser.Enabled = false
	drone.Tether.Enabled = false
	drone.Trail.Enabled = false
	drone.Body.CFrame = HIDDEN
	drone.Fin.CFrame = HIDDEN
	drone.Position = HIDDEN.Position
	table.insert(pool, drone)
end

local function acquireLink(): Beam
	local beam = table.remove(linkPool)
	if beam then
		return beam
	end
	return Ui.Make("Beam", {
		Name = "Link",
		Enabled = false,
		FaceCamera = true,
		LightEmission = 1,
		LightInfluence = 0,
		Segments = 1,
		Width0 = 0.18,
		Width1 = 0.18,
		Transparency = NumberSequence.new(0.35),
		Parent = folder,
	})
end

local function releaseLinks(fleet: Fleet)
	for _, beam in fleet.Links do
		beam.Enabled = false
		beam.Attachment0 = nil
		beam.Attachment1 = nil
		table.insert(linkPool, beam)
	end
	table.clear(fleet.Links)
end

-- Look --------------------------------------------------------------------------

local function laserStyleWidth(style: string): (number, number, number, number)
	-- width0, width1, curve0, curve1
	if style == "Helix" then
		return 0.22, 0.22, 2, -2
	elseif style == "Ribbon" then
		return 0.6, 0.12, 0, 0
	elseif style == "Needle" then
		return 0.08, 0.08, 0, 0
	elseif style == "Flare" then
		return 0.15, 0.9, 0, 0
	elseif style == "Overclock" then
		return 0.4, 0.25, 0, 0
	end
	return 0.25, 0.15, 0, 0
end

local function applyLook(fleet: Fleet)
	local player = fleet.Player
	local evoId = player:GetAttribute("DroneEvo")
	local evolution = if type(evoId) == "string" then DroneRegistry.ById[evoId] else nil
	evolution = evolution or DroneRegistry.EvolutionFor(1, "")
	local mutationId = player:GetAttribute("DroneMutation")
	local mutation = if type(mutationId) == "string" and mutationId ~= "" then DroneRegistry.ById[mutationId] else nil
	local shaderId = player:GetAttribute("LaserShader")
	local shader = if type(shaderId) == "string" and shaderId ~= "" then DroneRegistry.ById[shaderId] else nil
	local hitId = player:GetAttribute("HitEffect")
	local hit = if type(hitId) == "string" and hitId ~= "" then DroneRegistry.ById[hitId] else nil
	local thrusterId = player:GetAttribute("Thruster")
	local thruster = if type(thrusterId) == "string" and thrusterId ~= "" then DroneRegistry.ById[thrusterId] else nil
	local colorName = player:GetAttribute("LaserColor")
	local baseLaser = DroneConfig.LaserColors[if type(colorName) == "string" then colorName else "Gold"]
		or DroneConfig.LaserColors.Gold

	fleet.LaserColor = if shader then shader.Color else baseLaser
	fleet.LaserStyle = if shader then shader.Style else "Plain"
	fleet.LaserWidth = 1 + (evolution.Stage - 1) * 0.06
	fleet.HitColor = if hit then hit.Color else fleet.LaserColor

	local bodyColor = if mutation then mutation.Color else evolution.Color
	local finColor = if mutation then mutation.Accent else evolution.Glow
	local material = if mutation then MUTATION_MATERIAL[mutation.Id] or Enum.Material.Metal else Enum.Material.Metal
	local scale = evolution.BodyScale
	local w0, w1, c0, c1 = laserStyleWidth(fleet.LaserStyle)
	local laserColor = ColorSequence.new(fleet.LaserColor, if shader then shader.Accent else fleet.LaserColor)
	local trailColor = if thruster
		then ColorSequence.new(thruster.Color, thruster.Accent)
		else ColorSequence.new(evolution.Glow, evolution.Color)
	for _, drone in fleet.Drones do
		drone.Body.Color = bodyColor
		drone.Body.Material = material
		drone.Body.Size = Vector3.new(1.3, 1.3, 1.3) * scale
		drone.Fin.Color = finColor
		drone.Fin.Size = Vector3.new(1.4 + 0.12 * evolution.FinCount, 0.12, 0.5) * scale
		drone.Laser.Color = laserColor
		drone.Laser.Width0 = w0 * fleet.LaserWidth
		drone.Laser.Width1 = w1 * fleet.LaserWidth
		drone.Laser.CurveSize0 = c0
		drone.Laser.CurveSize1 = c1
		drone.Trail.Color = trailColor
	end
end

local function lookKey(player: Player, count: number): string
	return table.concat({
		tostring(count),
		tostring(player:GetAttribute("DroneEvo")),
		tostring(player:GetAttribute("DroneMutation")),
		tostring(player:GetAttribute("LaserShader")),
		tostring(player:GetAttribute("LaserColor")),
		tostring(player:GetAttribute("HitEffect")),
		tostring(player:GetAttribute("Thruster")),
	}, "|")
end

-- Fleets ------------------------------------------------------------------------

local function fleetFor(player: Player): Fleet
	local fleet = fleets[player]
	if fleet then
		return fleet
	end
	local created: Fleet = {
		Player = player,
		Drones = {},
		Links = {},
		LookKey = "",
		LaserColor = DroneConfig.LaserColors.Gold,
		LaserWidth = 1,
		LaserStyle = "Plain",
		HitColor = DroneConfig.LaserColors.Gold,
		Seed = (player.UserId % 997) * 0.37,
	}
	fleets[player] = created
	return created
end

local function disposeFleet(player: Player)
	local fleet = fleets[player]
	if not fleet then
		return
	end
	for _, drone in fleet.Drones do
		releaseDrone(drone)
	end
	releaseLinks(fleet)
	fleets[player] = nil
end

local function desiredCount(player: Player): number
	local count = player:GetAttribute("DroneCount")
	local n = if type(count) == "number" then math.clamp(math.floor(count), 0, DroneConfig.MaxDrones) else 0
	if perfMode and player ~= Players.LocalPlayer then
		n = math.min(n, OTHER_PILOT_CAP_PERF)
	end
	return n
end

local function resize(fleet: Fleet, n: number)
	while #fleet.Drones > n do
		local drone = table.remove(fleet.Drones)
		if drone then
			releaseDrone(drone)
		end
	end
	while #fleet.Drones < n do
		local drone = acquireDrone()
		drone.Index = #fleet.Drones + 1
		table.insert(fleet.Drones, drone)
	end
	for i, drone in fleet.Drones do
		drone.Index = i
	end
end

-- Positions -------------------------------------------------------------------------

local function radiusOf(part: BasePart): number
	return part.Size.X / 2
end

local function idlePoint(center: Vector3, i: number, n: number, t: number, slow: boolean): Vector3
	local speed = if slow then 0.25 else 0.6
	local angle = t * speed + (i / math.max(1, n)) * math.pi * 2
	local radius = DroneConfig.IdleOrbitRadius * (if i % 2 == 0 then 0.75 else 1)
	return center + Vector3.new(math.cos(angle) * radius, 3 + math.sin(t + i) * 0.6, math.sin(angle) * radius)
end

local function stepFleet(
	fleet: Fleet,
	dt: number,
	t: number,
	cameraPos: Vector3,
	parts: { BasePart },
	cframes: { CFrame },
	hitParts: { [BasePart]: Color3 }
)
	local player = fleet.Player
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local n = #fleet.Drones
	if not root or n == 0 then
		for _, drone in fleet.Drones do
			drone.Laser.Enabled = false
			drone.Tether.Enabled = false
			drone.Trail.Enabled = false
			table.insert(parts, drone.Body)
			table.insert(cframes, HIDDEN)
			table.insert(parts, drone.Fin)
			table.insert(cframes, HIDDEN)
		end
		releaseLinks(fleet)
		return
	end
	local anchor = root.Position
	local far = (anchor - cameraPos).Magnitude > FAR_DISTANCE
	local afk = player:GetAttribute("Afk") == true
	local formation = player:GetAttribute("Formation")
	local targets = if afk then {} else parseTargets(player:GetAttribute("DroneTargets"))
	local tows = TowController.ForUser(player.UserId)
	local isLocal = player == Players.LocalPlayer
	local follow = 1 - math.exp(-dt * FOLLOW_RATE)
	local towCount = math.min(#tows, math.max(0, n - 1), 3)
	local miners = n - towCount
	local tseed = t + fleet.Seed

	for i, drone in fleet.Drones do
		local desired: Vector3
		local aim: BasePart? = nil
		local tow = if i > miners then tows[i - miners] else nil
		if tow then
			local toward = tow.To - tow.Position
			local dir = if toward.Magnitude > 0.1 then toward.Unit else Vector3.new(0, 1, 0)
			desired = tow.Position + dir * (radiusOf(tow.Part) + 2.5) + Vector3.new(0, 1.2, 0)
		elseif #targets > 0 and formation == 2 then
			local target = targets[1]
			local angle = tseed * 0.6 + (i / miners) * math.pi * 2
			local radius = radiusOf(target) + 4
			desired = target.Position
				+ Vector3.new(math.cos(angle) * radius, 2 + math.sin(tseed + i) * 0.4, math.sin(angle) * radius)
			aim = target
		elseif formation == 3 then
			local angle = tseed * 1.2 + (i / n) * math.pi * 2
			local radius = 2.8 + 0.15 * n
			desired = anchor + Vector3.new(math.cos(angle) * radius, 3.4, math.sin(angle) * radius)
			aim = targets[1]
		elseif #targets > 0 then
			local target = targets[(i - 1) % #targets + 1]
			local angle = tseed * 0.9 + i * GOLDEN_ANGLE
			local radius = radiusOf(target) + 3 + (i % 3) * 0.8
			desired = target.Position
				+ Vector3.new(math.cos(angle) * radius, 1.5 + math.sin(tseed * 1.7 + i), math.sin(angle) * radius)
			aim = target
		else
			desired = idlePoint(anchor, i, n, tseed, afk)
		end

		if (drone.Position - desired).Magnitude > SNAP_DISTANCE then
			drone.Position = desired
		else
			drone.Position = drone.Position:Lerp(desired, follow)
		end
		local lookAt = if aim then aim.Position elseif tow then tow.To else anchor + Vector3.new(0, 3, 0)
		local cf = if (lookAt - drone.Position).Magnitude > 0.05
			then CFrame.lookAt(drone.Position, lookAt)
			else CFrame.new(drone.Position)
		table.insert(parts, drone.Body)
		table.insert(cframes, cf)
		table.insert(parts, drone.Fin)
		table.insert(cframes, cf * CFrame.new(0, 0, 0.15))

		local laserOn = aim ~= nil and not far and (aim.Position - drone.Position).Magnitude <= LASER_RANGE
		if laserOn and aim then
			drone.Laser.Attachment1 = aimAttachment(aim)
			if fleet.LaserStyle == "Pulse" then
				drone.Laser.Transparency = NumberSequence.new(0.25 + 0.25 * math.sin(t * 12 + i))
			end
			if not perfMode or isLocal then
				hitParts[aim] = fleet.HitColor
			end
		end
		drone.Laser.Enabled = laserOn
		if tow and not far then
			drone.Tether.Attachment1 = aimAttachment(tow.Part)
			drone.Tether.Enabled = true
		else
			drone.Tether.Enabled = false
		end
		drone.Trail.Enabled = not far and not perfMode and (isLocal or (drone.Position - cameraPos).Magnitude < 120)
	end

	-- Orbital Beam-Link: chain the ring of drones around the shared target.
	local linkCount = if formation == 2 and #targets > 0 and miners >= 3 and not far then miners else 0
	while #fleet.Links > linkCount do
		local beam = table.remove(fleet.Links)
		if beam then
			beam.Enabled = false
			table.insert(linkPool, beam)
		end
	end
	while #fleet.Links < linkCount and #fleet.Links < LINK_POOL_MAX do
		table.insert(fleet.Links, acquireLink())
	end
	for i, beam in fleet.Links do
		local a = fleet.Drones[i]
		local b = fleet.Drones[i % miners + 1]
		beam.Attachment0 = a.Attach
		beam.Attachment1 = b.Attach
		beam.Color = ColorSequence.new(fleet.LaserColor)
		beam.Enabled = true
	end
end

local function step(dt: number)
	local camera = Workspace.CurrentCamera
	local cameraPos = if camera then camera.CFrame.Position else Vector3.zero
	local t = os.clock()
	local parts: { BasePart } = {}
	local cframes: { CFrame } = {}
	local hitParts: { [BasePart]: Color3 } = {}
	for _, player in Players:GetPlayers() do
		local fleet = fleetFor(player)
		local n = desiredCount(player)
		if #fleet.Drones ~= n then
			resize(fleet, n)
			fleet.LookKey = ""
		end
		local key = lookKey(player, n)
		if key ~= fleet.LookKey then
			fleet.LookKey = key
			applyLook(fleet)
		end
		stepFleet(fleet, dt, t, cameraPos, parts, cframes, hitParts)
	end
	if #parts > 0 then
		Workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end
	for part, emitter in hitEmitters do
		if not part.Parent then
			hitEmitters[part] = nil
			continue
		end
		if hitParts[part] then
			emitter.Enabled = true
			emitter.Color = ColorSequence.new(hitParts[part])
			emitter.Rate = if perfMode then 6 else 18
		else
			emitter.Enabled = false
		end
	end
	for part in hitParts do
		if not hitEmitters[part] then
			local emitter = hitEmitter(part)
			emitter.Color = ColorSequence.new(hitParts[part])
			emitter.Enabled = true
		end
	end
end

function DroneController.SetPerfMode(on: boolean)
	perfMode = on
end

-- World position of a pilot's first drone (VFX anchor), if rendered.
function DroneController.LeadPosition(player: Player): Vector3?
	local fleet = fleets[player]
	local drone = fleet and fleet.Drones[1]
	return if drone then drone.Position else nil
end

function DroneController.Init()
	folder = Ui.Make("Folder", { Name = "VoidlineDrones", Parent = Workspace })
	CollectionService:GetInstanceAddedSignal(ROCK_TAG):Connect(indexRock)
	for _, part in CollectionService:GetTagged(ROCK_TAG) do
		indexRock(part)
	end
	Players.PlayerRemoving:Connect(disposeFleet)
	RunService.RenderStepped:Connect(step)
end

return DroneController
