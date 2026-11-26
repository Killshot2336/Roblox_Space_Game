--!strict
-- Client-side world presentation driven by replicated Workspace attributes:
-- anomaly sky/lighting profiles, the Monolith split (halves part, the Void
-- Core is exposed), world-event tints, hazard telegraphs and the calm aura
-- at the star overlook. Gravity changes come from the server.
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Voidline = ReplicatedStorage:WaitForChild("Voidline")
local BiomeRegistry = require(Voidline.Content.BiomeRegistry)
local WorldEventRegistry = require(Voidline.Content.WorldEventRegistry)

local Client = script.Parent.Parent.Client
local Ui = require(Client.Ui)
local CameraController = require(script.Parent.CameraController)

local WorldController = {}

local SPLIT_DISTANCE = 6
local SPLIT_TILT = math.rad(6)
local SPLIT_SECONDS = 2.4
local GRADE_SECONDS = 3
local HAZARD_POOL = 4
local CALM_TINT = Color3.fromRGB(255, 244, 228)
local HAZARD_IMPULSE = 38

local player = Players.LocalPlayer
local atmosphere: Atmosphere
local grade: ColorCorrectionEffect
local bloom: BloomEffect
local hazardParts: { Part } = {}
local hazardNext = 1
local perfMode = false

local BASE = {
	Ambient = Lighting.Ambient,
	Tint = Color3.new(1, 1, 1),
	AtmosphereColor = Color3.fromRGB(70, 50, 120),
	AtmosphereDecay = Color3.fromRGB(30, 20, 60),
	Density = 0.25,
	Haze = 1,
	Glare = 0,
	Bloom = 0.6,
	Saturation = 0.05,
	Contrast = 0.05,
}

local function ensureEffects()
	atmosphere = Lighting:FindFirstChild("VoidlineAtmosphere") :: Atmosphere?
		or Ui.Make("Atmosphere", { Name = "VoidlineAtmosphere", Parent = Lighting })
	grade = Lighting:FindFirstChild("VoidlineGrade") :: ColorCorrectionEffect?
		or Ui.Make("ColorCorrectionEffect", { Name = "VoidlineGrade", Parent = Lighting })
	bloom = Lighting:FindFirstChild("VoidlineBloom") :: BloomEffect?
		or Ui.Make("BloomEffect", { Name = "VoidlineBloom", Threshold = 0.9, Size = 24, Parent = Lighting })
end

local function currentBiome(): BiomeRegistry.Biome?
	local id = Workspace:GetAttribute("AnomalyId")
	return if type(id) == "string" then BiomeRegistry.ById[id] else nil
end

local function currentEvent(): any
	local id = Workspace:GetAttribute("EventId")
	return if type(id) == "string" and id ~= "" then WorldEventRegistry.ById[id] else nil
end

-- Blends anomaly sky + event colour + calm aura into one lighting target.
local function applyGrade()
	local biome = currentBiome()
	local sky = if biome then biome.Sky else nil
	local tint = if sky then sky.Tint else BASE.Tint
	local event = currentEvent()
	if event then
		tint = tint:Lerp(event.Color, 0.2)
	end
	local calm = player:GetAttribute("CalmAura") == true
	if calm then
		tint = tint:Lerp(CALM_TINT, 0.6)
	end
	Ui.Tween(Lighting, GRADE_SECONDS, { Ambient = if sky then sky.Ambient else BASE.Ambient })
	Ui.Tween(grade, GRADE_SECONDS, {
		TintColor = tint,
		Saturation = if calm then -0.05 elseif sky then sky.Saturation else BASE.Saturation,
		Contrast = if sky then sky.Contrast else BASE.Contrast,
	})
	Ui.Tween(atmosphere, GRADE_SECONDS, {
		Color = if sky then sky.AtmosphereColor else BASE.AtmosphereColor,
		Decay = if sky then sky.AtmosphereDecay else BASE.AtmosphereDecay,
		Density = if sky then sky.Density else BASE.Density,
		Haze = if sky then sky.Haze else BASE.Haze,
		Glare = if sky then sky.Glare else BASE.Glare,
	})
	local bloomIntensity = if sky then sky.Bloom else BASE.Bloom
	Ui.Tween(bloom, GRADE_SECONDS, { Intensity = if perfMode then bloomIntensity * 0.4 else bloomIntensity })
end

-- Monolith -------------------------------------------------------------------------

local function monolith(): Instance?
	local map = Workspace:FindFirstChild("VoidlineMap")
	local hub = map and map:FindFirstChild("Hub")
	return hub and hub:FindFirstChild("VoidlineMonolith")
end

local function applySplit(split: boolean)
	local root = monolith()
	if not root then
		return
	end
	for _, half in root:GetChildren() do
		if not half:IsA("BasePart") then
			continue
		end
		local home = half:GetAttribute("HomeCFrame")
		local side = half:GetAttribute("Side")
		if typeof(home) ~= "CFrame" or type(side) ~= "number" then
			continue
		end
		local homeCFrame = home :: CFrame
		local base = homeCFrame * CFrame.new(0, -half.Size.Y / 2, 0)
		local target = if split
			then base * CFrame.new(side * SPLIT_DISTANCE, 0, 0) * CFrame.Angles(0, 0, -side * SPLIT_TILT) * CFrame.new(
				0,
				half.Size.Y / 2,
				0
			)
			else homeCFrame
		Ui.Tween(half, SPLIT_SECONDS, { CFrame = target }, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut)
		for _, band in half:GetChildren() do
			local offset = band:GetAttribute("Offset")
			if band:IsA("BasePart") and typeof(offset) == "CFrame" then
				Ui.Tween(
					band,
					SPLIT_SECONDS,
					{ CFrame = target * (offset :: CFrame) },
					Enum.EasingStyle.Quint,
					Enum.EasingDirection.InOut
				)
			end
		end
	end
	local core = root:FindFirstChild("VoidCore")
	if core and core:IsA("BasePart") then
		Ui.Tween(core, SPLIT_SECONDS, { Transparency = if split then 0.05 else 1 })
	end
	if split then
		CameraController.Shake(0.6, 1.2)
		CameraController.Punch(6, 1.6)
	end
end

-- Hazards ----------------------------------------------------------------------------

local function hazardPart(): Part
	local part = hazardParts[hazardNext]
	if not part then
		part = Ui.Make("Part", {
			Name = "HazardZone",
			Anchored = true,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
			Shape = Enum.PartType.Cylinder,
			Material = Enum.Material.Neon,
			Transparency = 1,
			Parent = Workspace,
		})
		hazardParts[hazardNext] = part
	end
	hazardNext = hazardNext % HAZARD_POOL + 1
	return part
end

local function applyImpulse(effect: string, center: Vector3, radius: number)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local offset = root.Position - center
	local flat = Vector3.new(offset.X, 0, offset.Z)
	if flat.Magnitude > radius or flat.Magnitude < 0.5 then
		return
	end
	local away = flat.Unit
	local direction = if effect == "Pull" then -away else away
	root.AssemblyLinearVelocity += direction * HAZARD_IMPULSE + Vector3.new(0, 12, 0)
end

function WorldController.Hazard(payload: { [string]: any })
	local hazard = if type(payload.Id) == "string" then BiomeRegistry.Hazards.ById[payload.Id] else nil
	local position = payload.Position
	if not hazard or typeof(position) ~= "Vector3" then
		return
	end
	local center = position :: Vector3
	local radius = if type(payload.Radius) == "number" then payload.Radius else hazard.Radius
	local seconds = if type(payload.Seconds) == "number" then payload.Seconds else 3
	local part = hazardPart()
	part.Color = hazard.Color
	part.Size = Vector3.new(0.4, radius * 2, radius * 2)
	part.CFrame = CFrame.new(center.X, 1.2, center.Z) * CFrame.Angles(0, 0, math.rad(90))
	if payload.Phase == "telegraph" then
		part.Transparency = 0.9
		Ui.Tween(part, math.max(0.2, seconds), { Transparency = 0.55 }, Enum.EasingStyle.Sine)
	else
		part.Transparency = 0.2
		Ui.Tween(part, math.max(0.3, seconds), { Transparency = 1 })
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and (root.Position - center).Magnitude <= radius + 20 then
			CameraController.Shake(0.5, 0.35)
		end
		if payload.Effect == "Pull" or payload.Effect == "Knockback" then
			applyImpulse(payload.Effect, center, radius)
		end
	end
end

function WorldController.SetPerfMode(on: boolean)
	perfMode = on
	applyGrade()
end

function WorldController.Init()
	ensureEffects()
	applyGrade()
	applySplit(Workspace:GetAttribute("MonolithSplit") == true)
	Workspace:GetAttributeChangedSignal("AnomalyId"):Connect(applyGrade)
	Workspace:GetAttributeChangedSignal("EventId"):Connect(applyGrade)
	Workspace:GetAttributeChangedSignal("MonolithSplit"):Connect(function()
		applySplit(Workspace:GetAttribute("MonolithSplit") == true)
	end)
	player:GetAttributeChangedSignal("CalmAura"):Connect(applyGrade)
end

return WorldController
