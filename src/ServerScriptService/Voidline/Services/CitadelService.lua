--!strict
-- Citadel: every Station Tier adds structures to the pilot's plot (turrets,
-- refinery towers, warp docks, trophy halls...). The ten newest structures
-- stand on the ten plot-edge anchors, so a max-tier plot stays cheap
-- (decorative, anchored, non-colliding parts only).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Voidline = ReplicatedStorage:WaitForChild("Voidline")
local PlotLayout = require(Voidline.Modules.PlotLayout)
local CitadelRegistry = require(Voidline.Content.CitadelRegistry)

local PlayerDataService = require(script.Parent.PlayerDataService)
local PlotService = require(script.Parent.PlotService)
local EconomyService = require(script.Parent.EconomyService)
local RebirthService = require(script.Parent.RebirthService)
local MapBuilder = require(script.Parent.MapBuilder)

local CitadelService = {}

local METAL = Color3.fromRGB(30, 28, 40)
local GOLD = Color3.fromRGB(232, 186, 74)

type Piece = {
	Size: Vector3,
	Offset: CFrame,
	Material: Enum.Material,
	Color: Color3?,
	Shape: Enum.PartType?,
	Transparency: number?,
}

-- Each structure kind is a handful of primitive parts, in local space
-- (origin at the anchor, +Y up). nil Color = tier accent.
local SHAPES: { [string]: { Piece } } = {
	beacon = {
		{
			Size = Vector3.new(1.2, 12, 1.2),
			Offset = CFrame.new(0, 6, 0),
			Material = Enum.Material.Metal,
			Color = METAL,
			Shape = Enum.PartType.Cylinder,
		},
		{
			Size = Vector3.new(2.4, 2.4, 2.4),
			Offset = CFrame.new(0, 12.5, 0),
			Material = Enum.Material.Neon,
			Shape = Enum.PartType.Ball,
		},
	},
	refinery_tower = {
		{ Size = Vector3.new(4, 14, 4), Offset = CFrame.new(0, 7, 0), Material = Enum.Material.Metal, Color = METAL },
		{ Size = Vector3.new(4.4, 0.8, 4.4), Offset = CFrame.new(0, 10, 0), Material = Enum.Material.Neon },
		{ Size = Vector3.new(4.4, 0.8, 4.4), Offset = CFrame.new(0, 5, 0), Material = Enum.Material.Neon },
	},
	turret = {
		{
			Size = Vector3.new(3, 4, 4),
			Offset = CFrame.new(0, 2, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Material = Enum.Material.Metal,
			Color = METAL,
			Shape = Enum.PartType.Cylinder,
		},
		{
			Size = Vector3.new(1, 1, 6),
			Offset = CFrame.new(0, 4.6, -2) * CFrame.Angles(math.rad(25), 0, 0),
			Material = Enum.Material.Metal,
			Color = METAL,
		},
		{
			Size = Vector3.new(1.2, 1.2, 1.2),
			Offset = CFrame.new(0, 6, -4.6),
			Material = Enum.Material.Neon,
			Shape = Enum.PartType.Ball,
		},
	},
	warp_dock = {
		{ Size = Vector3.new(1, 9, 1), Offset = CFrame.new(-3, 4.5, 0), Material = Enum.Material.Metal, Color = METAL },
		{ Size = Vector3.new(1, 9, 1), Offset = CFrame.new(3, 4.5, 0), Material = Enum.Material.Metal, Color = METAL },
		{ Size = Vector3.new(7, 1, 1), Offset = CFrame.new(0, 9, 0), Material = Enum.Material.Neon },
		{
			Size = Vector3.new(5, 7, 0.2),
			Offset = CFrame.new(0, 4.5, 0),
			Material = Enum.Material.Glass,
			Transparency = 0.6,
		},
	},
	trophy_hall = {
		{
			Size = Vector3.new(8, 5, 6),
			Offset = CFrame.new(0, 2.5, 0),
			Material = Enum.Material.Marble,
			Color = Color3.fromRGB(40, 36, 52),
		},
		{
			Size = Vector3.new(8.4, 0.6, 6.4),
			Offset = CFrame.new(0, 5.3, 0),
			Material = Enum.Material.Neon,
			Color = GOLD,
		},
		{
			Size = Vector3.new(6, 2.5, 4),
			Offset = CFrame.new(0, 6.8, 0),
			Material = Enum.Material.Glass,
			Transparency = 0.4,
		},
	},
	shield_ring = {
		{
			Size = Vector3.new(0.6, 10, 10),
			Offset = CFrame.new(0, 8, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Material = Enum.Material.ForceField,
			Shape = Enum.PartType.Cylinder,
			Transparency = 0.2,
		},
		{ Size = Vector3.new(1, 6, 1), Offset = CFrame.new(0, 3, 0), Material = Enum.Material.Metal, Color = METAL },
	},
	solar_array = {
		{
			Size = Vector3.new(0.8, 6, 0.8),
			Offset = CFrame.new(0, 3, 0),
			Material = Enum.Material.Metal,
			Color = METAL,
		},
		{
			Size = Vector3.new(7, 0.3, 4),
			Offset = CFrame.new(0, 6.4, 0) * CFrame.Angles(math.rad(-30), 0, 0),
			Material = Enum.Material.Glass,
			Color = Color3.fromRGB(80, 140, 255),
			Transparency = 0.2,
		},
	},
	hangar = {
		{ Size = Vector3.new(8, 4, 8), Offset = CFrame.new(0, 2, 0), Material = Enum.Material.Metal, Color = METAL },
		{
			Size = Vector3.new(8, 3, 8),
			Offset = CFrame.new(0, 5.5, 0),
			Material = Enum.Material.Metal,
			Color = Color3.fromRGB(44, 40, 58),
			Shape = Enum.PartType.Wedge,
		},
		{ Size = Vector3.new(5, 3, 0.3), Offset = CFrame.new(0, 1.6, -4.1), Material = Enum.Material.Neon },
	},
	gravity_anchor = {
		{
			Size = Vector3.new(4, 4, 4),
			Offset = CFrame.new(0, 5, 0),
			Material = Enum.Material.Slate,
			Color = Color3.fromRGB(16, 14, 22),
			Shape = Enum.PartType.Ball,
		},
		{
			Size = Vector3.new(0.4, 7, 7),
			Offset = CFrame.new(0, 5, 0) * CFrame.Angles(math.rad(20), 0, math.rad(90)),
			Material = Enum.Material.Neon,
			Shape = Enum.PartType.Cylinder,
			Transparency = 0.3,
		},
	},
	relic_vault = {
		{
			Size = Vector3.new(5, 5, 5),
			Offset = CFrame.new(0, 2.5, 0),
			Material = Enum.Material.DiamondPlate,
			Color = METAL,
		},
		{ Size = Vector3.new(2, 3.4, 0.3), Offset = CFrame.new(0, 1.9, -2.6), Material = Enum.Material.Neon },
	},
}

local function clear(index: number)
	local plot = PlotService.Folder(index)
	local folder = plot and plot:FindFirstChild("Citadel")
	if folder then
		folder:ClearAllChildren()
	end
end

local function buildStructure(parent: Instance, kind: string, origin: CFrame, scale: number, accent: Color3)
	local pieces = SHAPES[kind] or SHAPES.beacon
	local model = Instance.new("Model")
	model.Name = kind
	for i, piece in pieces do
		local offset = piece.Offset
		MapBuilder.Part({
			Name = kind .. "_" .. i,
			Parent = model,
			Size = piece.Size * scale,
			CFrame = origin * CFrame.new(offset.Position * scale) * offset.Rotation,
			Color = piece.Color or accent,
			Material = piece.Material,
			Shape = piece.Shape,
			Transparency = piece.Transparency or 0,
			CanCollide = false,
			CanQuery = false,
		})
	end
	model.Parent = parent
end

function CitadelService.Rebuild(player: Player)
	local index = PlotService.IndexOf(player)
	local profile = PlayerDataService.Get(player)
	if not index or not profile then
		return
	end
	clear(index)
	local plot = PlotService.Folder(index)
	local folder = plot and plot:FindFirstChild("Citadel")
	if not plot or not folder then
		return
	end
	local tier = CitadelRegistry.ForTier(profile.StationTier)
	local structures = CitadelRegistry.StructuresUpTo(profile.StationTier)
	local anchors = PlotLayout.CitadelAnchors
	local first = math.max(1, #structures - #anchors + 1)
	local plotCFrame = PlotLayout.PlotCFrame(index)
	for i = first, #structures do
		local structure = structures[i]
		local anchor = anchors[i - first + 1]
		for copy = 1, math.min(structure.Count, 3) do
			local spread = (copy - (math.min(structure.Count, 3) + 1) / 2) * 5
			local localPos = anchor + Vector3.new(0, 0, spread)
			local origin = plotCFrame * CFrame.new(localPos) * CFrame.Angles(0, math.rad(180), 0)
			buildStructure(folder, structure.Kind, origin, structure.Scale, tier.Accent)
		end
	end
	plot:SetAttribute("CitadelTier", tier.Tier)
	plot:SetAttribute("CitadelName", tier.Name)
end

function CitadelService.Init()
	PlotService.OnClaimed(function(player)
		CitadelService.Rebuild(player)
	end)
	PlotService.OnReleased(function(_player, index)
		clear(index)
	end)
	EconomyService.OnUpgraded(function(player, upgradeId)
		if upgradeId == "StationTier" then
			CitadelService.Rebuild(player)
		end
	end)
	RebirthService.OnRebirth(function(player)
		CitadelService.Rebuild(player)
	end)
end

return CitadelService
