--!strict
-- Builds the static world from PlotLayout / HubLayout: hub with the Voidline
-- Monolith (two halves so it can split), pads, monument, leaderboard boards,
-- the Void Rift spiral, the quiet star overlook and 12 obsidian-gold plots
-- with segmented Energy Bridges. Dynamic pieces (belt rocks, citadel,
-- pedestals, prompts) are added by their services.
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Voidline = ReplicatedStorage:WaitForChild("Voidline")
local GameConfig = require(Voidline.Config.GameConfig)
local PlotLayout = require(Voidline.Modules.PlotLayout)
local HubLayout = require(Voidline.Modules.HubLayout)

local MapBuilder = {}

local COLORS = GameConfig.Colors

type PartProps = {
	Name: string?,
	Parent: Instance?,
	Size: Vector3?,
	CFrame: CFrame?,
	Color: Color3?,
	Material: Enum.Material?,
	Transparency: number?,
	CanCollide: boolean?,
	CanQuery: boolean?,
	Shape: Enum.PartType?,
	CastShadow: boolean?,
}

local function part(props: PartProps): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = props.CanCollide ~= false
	p.CanQuery = props.CanQuery ~= false
	p.CanTouch = false
	p.CastShadow = props.CastShadow == true
	p.Material = props.Material or Enum.Material.SmoothPlastic
	p.Color = props.Color or COLORS.Obsidian
	p.Size = props.Size or Vector3.new(4, 1, 4)
	p.CFrame = props.CFrame or CFrame.new()
	p.Name = props.Name or "Part"
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Transparency = props.Transparency or 0
	if props.Shape then
		p.Shape = props.Shape
	end
	p.Parent = props.Parent
	return p
end
MapBuilder.Part = part

local function folder(name: string, parent: Instance): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function label(parent: Instance, text: string, height: number, maxDistance: number, color: Color3?): BillboardGui
	local bb = Instance.new("BillboardGui")
	bb.Name = "Label"
	bb.Size = UDim2.fromOffset(200, 34)
	bb.StudsOffset = Vector3.new(0, height, 0)
	bb.AlwaysOnTop = false
	bb.MaxDistance = maxDistance
	bb.LightInfluence = 0
	bb.Parent = parent
	local text_ = Instance.new("TextLabel")
	text_.Name = "Text"
	text_.BackgroundTransparency = 0.3
	text_.BackgroundColor3 = COLORS.Obsidian
	text_.Size = UDim2.fromScale(1, 1)
	text_.Font = Enum.Font.GothamBold
	text_.TextScaled = true
	text_.TextColor3 = color or COLORS.Gold
	text_.Text = text
	text_.Parent = bb
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = text_
	local stroke = Instance.new("UIStroke")
	stroke.Color = COLORS.Gold
	stroke.Transparency = 0.5
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = text_
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 8)
	padding.Parent = text_
	return bb
end
MapBuilder.Label = label

local function goldTrim(parent: Instance, base: CFrame, size: Vector3)
	local half = size / 2
	local edges = {
		{ Vector3.new(0, half.Y, -half.Z), Vector3.new(size.X, 0.4, 0.6) },
		{ Vector3.new(0, half.Y, half.Z), Vector3.new(size.X, 0.4, 0.6) },
		{ Vector3.new(-half.X, half.Y, 0), Vector3.new(0.6, 0.4, size.Z) },
		{ Vector3.new(half.X, half.Y, 0), Vector3.new(0.6, 0.4, size.Z) },
	}
	for i, edge in edges do
		part({
			Name = "GoldTrim" .. i,
			Parent = parent,
			Size = edge[2],
			CFrame = base * CFrame.new(edge[1]),
			Color = COLORS.Gold,
			Material = Enum.Material.Neon,
			CanCollide = false,
			CanQuery = false,
		})
	end
end

local function buildHub(root: Instance)
	local hub = folder("Hub", root)
	local hubCFrame = CFrame.new(0, 0, 0)
	part({
		Name = "HubPad",
		Parent = hub,
		Size = HubLayout.HubSize,
		CFrame = hubCFrame,
		Material = Enum.Material.Basalt,
	})
	goldTrim(hub, hubCFrame, HubLayout.HubSize)

	-- Monolith: two halves (split along X) plus gold bands and the Void Core.
	local monolith = folder("VoidlineMonolith", hub)
	local size = HubLayout.MonolithSize
	local sides: { [string]: number } = { Left = -1, Right = 1 }
	for side, sign in sides do
		local halfSize = Vector3.new(size.X / 2, size.Y, size.Z)
		local half = part({
			Name = "Monolith" .. side,
			Parent = monolith,
			Size = halfSize,
			CFrame = CFrame.new(HubLayout.MonolithCenter + Vector3.new(sign * size.X / 4, 0, 0)),
			Material = Enum.Material.Slate,
			Color = Color3.fromRGB(14, 12, 20),
			CastShadow = true,
		})
		half:SetAttribute("Side", sign)
		half:SetAttribute("HomeCFrame", half.CFrame)
		for i = 1, 4 do
			local band = part({
				Name = "GoldBand" .. i,
				Parent = half,
				Size = Vector3.new(halfSize.X + 0.6, 1.2, halfSize.Z + 0.6),
				CFrame = half.CFrame * CFrame.new(0, -size.Y / 2 + 10 + i * 13, 0),
				Color = COLORS.Gold,
				Material = Enum.Material.Neon,
				CanCollide = false,
				CanQuery = false,
			})
			band:SetAttribute("Offset", half.CFrame:ToObjectSpace(band.CFrame))
		end
	end
	local core = part({
		Name = "VoidCore",
		Parent = monolith,
		Size = Vector3.new(7, 7, 7),
		CFrame = CFrame.new(HubLayout.VoidCore),
		Color = COLORS.VoidAccent,
		Material = Enum.Material.Neon,
		Shape = Enum.PartType.Ball,
		CanCollide = false,
		Transparency = 1,
	})
	core:SetAttribute("Exposed", false)
	label(monolith:FindFirstChild("MonolithLeft") :: Instance, "THE VOIDLINE MONOLITH", 42, 160)

	local function pad(name: string, position: Vector3, padSize: Vector3, color: Color3, text: string)
		local p = part({
			Name = name,
			Parent = hub,
			Size = padSize,
			CFrame = CFrame.new(position),
			Color = color,
			Material = Enum.Material.Neon,
		})
		label(p, text, 4, 70)
		return p
	end
	pad("RebirthPad", HubLayout.RebirthPad, Vector3.new(12, 1, 12), COLORS.Gold, "VOID REBIRTH")
	pad("ForgePad", HubLayout.ForgePad, Vector3.new(12, 1, 12), COLORS.VoidAccent, "ARTIFACT FORGE")
	pad("SummonPad", HubLayout.SummonPad, Vector3.new(12, 1, 12), COLORS.GoldBright, "SERVER SUMMONS")
	pad("VipLounge", HubLayout.VipLounge, Vector3.new(18, 1, 18), COLORS.Gold, "VOID SOVEREIGN LOUNGE")
	pad("OverlookGate", HubLayout.OverlookGate, Vector3.new(10, 1, 10), Color3.fromRGB(255, 236, 190), "STAR OVERLOOK")
	pad("RiftGate", HubLayout.RiftGate, Vector3.new(10, 1, 10), Color3.fromRGB(190, 120, 255), "VOID RIFT")

	local terminal = part({
		Name = "CodeTerminal",
		Parent = hub,
		Size = Vector3.new(8, 10, 2),
		CFrame = CFrame.lookAt(HubLayout.CodeTerminal, Vector3.new(0, HubLayout.CodeTerminal.Y, 0)),
		Material = Enum.Material.Metal,
	})
	label(terminal, "CODE TERMINAL", 7, 60)

	-- "Created by Killshot2336" monument: obsidian plinth, gold obelisk, plaque.
	local monument = folder("CreatorMonument", hub)
	local plinth = part({
		Name = "Plinth",
		Parent = monument,
		Size = Vector3.new(10, 2, 10),
		CFrame = CFrame.new(HubLayout.Monument + Vector3.new(0, 1, 0)),
		Material = Enum.Material.Marble,
		Color = Color3.fromRGB(20, 18, 26),
	})
	part({
		Name = "Obelisk",
		Parent = monument,
		Size = Vector3.new(3, 18, 3),
		CFrame = plinth.CFrame * CFrame.new(0, 10, 0),
		Material = Enum.Material.Foil,
		Color = COLORS.Gold,
	})
	part({
		Name = "Crown",
		Parent = monument,
		Size = Vector3.new(4, 4, 4),
		CFrame = plinth.CFrame * CFrame.new(0, 21, 0) * CFrame.Angles(math.rad(45), 0, math.rad(45)),
		Material = Enum.Material.Neon,
		Color = COLORS.GoldBright,
		CanCollide = false,
	})
	local plaque = part({
		Name = "Plaque",
		Parent = monument,
		Size = Vector3.new(8, 3, 0.4),
		CFrame = CFrame.lookAt(plinth.Position + Vector3.new(0, 2.5, 5.2), Vector3.new(0, 3.5, 0)),
		Material = Enum.Material.Metal,
	})
	local surface = Instance.new("SurfaceGui")
	surface.Name = "PlaqueGui"
	surface.Face = Enum.NormalId.Front
	surface.LightInfluence = 0
	surface.PixelsPerStud = 40
	surface.Parent = plaque
	local plaqueText = Instance.new("TextLabel")
	plaqueText.BackgroundTransparency = 1
	plaqueText.Size = UDim2.fromScale(1, 1)
	plaqueText.Font = Enum.Font.GothamBlack
	plaqueText.TextScaled = true
	plaqueText.TextColor3 = COLORS.Gold
	plaqueText.Text = "Created by " .. GameConfig.BrandCreator
	plaqueText.Parent = surface
	label(plinth, "Created by " .. GameConfig.BrandCreator, 26, 120)

	-- Leaderboard frames; LeaderboardService draws the holographic lists.
	local boards = folder("Leaderboards", hub)
	for _, def in HubLayout.Boards do
		local board = part({
			Name = def.Id,
			Parent = boards,
			Size = Vector3.new(12, 15, 0.6),
			CFrame = HubLayout.BoardCFrame(def.Angle),
			Color = Color3.fromRGB(20, 16, 34),
			Material = Enum.Material.Glass,
			Transparency = 0.35,
		})
		board:SetAttribute("Title", def.Title)
	end

	local spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Name = "VoidlineSpawn"
	spawnLocation.Anchored = true
	spawnLocation.Size = Vector3.new(10, 1, 10)
	spawnLocation.CFrame = CFrame.new(HubLayout.Spawn)
	spawnLocation.Color = COLORS.Gold
	spawnLocation.Material = Enum.Material.Neon
	spawnLocation.Duration = 0
	spawnLocation.Transparency = 0.6
	spawnLocation.Parent = hub

	-- Void Rift spiral: faint and solid only while the Rift event is open.
	local rift = folder("VoidRift", hub)
	for i = 1, HubLayout.RiftPlatforms do
		local p = part({
			Name = "RiftShard" .. i,
			Parent = rift,
			Size = Vector3.new(6, 1, 6),
			CFrame = CFrame.new(HubLayout.RiftPlatform(i)) * CFrame.Angles(0, i * 0.7, 0),
			Color = Color3.fromRGB(190, 120, 255),
			Material = Enum.Material.Neon,
			Transparency = 0.85,
			CanCollide = false,
		})
		p:SetAttribute("RiftIndex", i)
	end
	local cache = part({
		Name = "RiftCache",
		Parent = rift,
		Size = Vector3.new(8, 1, 8),
		CFrame = CFrame.new(HubLayout.RiftCache),
		Color = COLORS.GoldBright,
		Material = Enum.Material.Neon,
		Transparency = 0.85,
		CanCollide = false,
	})
	cache:SetAttribute("RiftIndex", HubLayout.RiftPlatforms + 1)
	return hub
end

local function buildDeepSpace(root: Instance)
	local deep = folder("DeepSpace", root)
	part({
		Name = "ZoneRing",
		Parent = deep,
		Size = Vector3.new(1, HubLayout.ZoneRadius * 2, HubLayout.ZoneRadius * 2),
		CFrame = CFrame.new(0, -6, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Shape = Enum.PartType.Cylinder,
		Color = Color3.fromRGB(30, 14, 60),
		Material = Enum.Material.Neon,
		Transparency = 0.9,
		CanCollide = false,
		CanQuery = false,
	})
	folder("SharedRocks", deep)
	folder("EventTargets", deep)
	folder("Hazards", deep)
end

local function buildOverlook(root: Instance)
	local overlook = folder("StarOverlook", root)
	local platform = part({
		Name = "OverlookPlatform",
		Parent = overlook,
		Size = Vector3.new(22, 1.5, 22),
		CFrame = CFrame.new(HubLayout.Overlook),
		Color = Color3.fromRGB(28, 24, 36),
		Material = Enum.Material.Marble,
	})
	goldTrim(overlook, platform.CFrame, platform.Size)
	local aura = part({
		Name = "AuraZone",
		Parent = overlook,
		Size = Vector3.new(22, 10, 22),
		CFrame = platform.CFrame * CFrame.new(0, 5.5, 0),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	})
	aura:SetAttribute("CalmAura", true)
	local star = part({
		Name = "QuietStar",
		Parent = overlook,
		Size = Vector3.new(36, 36, 36),
		CFrame = CFrame.new(HubLayout.Overlook + Vector3.new(60, 70, -60)),
		Color = Color3.fromRGB(255, 236, 190),
		Material = Enum.Material.Neon,
		Shape = Enum.PartType.Ball,
		CanCollide = false,
		CanQuery = false,
	})
	star.Transparency = 0.1
	local spawnPad = part({
		Name = "ArrivalPad",
		Parent = overlook,
		Size = Vector3.new(6, 0.2, 6),
		CFrame = platform.CFrame * CFrame.new(0, 0.85, 6),
		Color = Color3.fromRGB(255, 236, 190),
		Material = Enum.Material.Neon,
		CanCollide = false,
		Transparency = 0.5,
	})
	spawnPad:SetAttribute("Arrival", true)
end

local function buildPlot(plots: Instance, index: number)
	local plotCFrame = PlotLayout.PlotCFrame(index)
	local plot = folder("Plot_" .. index, plots)
	plot:SetAttribute("PlotIndex", index)
	plot:SetAttribute("OwnerUserId", 0)
	plot:SetAttribute("OwnerName", "")
	plot:SetAttribute("BridgeIgnited", false)

	local baseCFrame = plotCFrame * CFrame.new(0, PlotLayout.SurfaceY - 1, 0)
	part({
		Name = "StationBase",
		Parent = plot,
		Size = PlotLayout.BaseSize,
		CFrame = baseCFrame,
		Material = Enum.Material.Basalt,
		Color = COLORS.Obsidian,
	})
	goldTrim(plot, baseCFrame, PlotLayout.BaseSize)

	local spawnMarker = part({
		Name = "PlayerSpawn",
		Parent = plot,
		Size = Vector3.new(6, 0.2, 6),
		CFrame = plotCFrame * CFrame.new(PlotLayout.Spawn),
		Color = COLORS.GoldBright,
		Material = Enum.Material.Neon,
		CanCollide = false,
		Transparency = 0.6,
	})
	spawnMarker:SetAttribute("Spawn", true)

	local station = folder("Station", plot)
	local refinery = part({
		Name = "Refinery",
		Parent = station,
		Size = PlotLayout.RefinerySize,
		CFrame = plotCFrame * CFrame.new(PlotLayout.Refinery),
		Color = COLORS.Gold,
		Material = Enum.Material.Neon,
	})
	label(refinery, "REFINERY", 4, 60)
	part({
		Name = "RefineryTower",
		Parent = station,
		Size = Vector3.new(8, 12, 6),
		CFrame = plotCFrame * CFrame.new(PlotLayout.RefineryTower),
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(26, 24, 34),
	})
	local grinder = part({
		Name = "GrinderCore",
		Parent = station,
		Size = Vector3.new(9, 9, 9),
		CFrame = plotCFrame * CFrame.new(PlotLayout.Grinder) * CFrame.Angles(math.rad(45), math.rad(45), 0),
		Color = Color3.fromRGB(30, 28, 44),
		Material = Enum.Material.DiamondPlate,
	})
	part({
		Name = "GrinderGlow",
		Parent = grinder,
		Size = Vector3.new(4, 4, 4),
		CFrame = grinder.CFrame,
		Color = COLORS.GoldBright,
		Material = Enum.Material.Neon,
		Shape = Enum.PartType.Ball,
		CanCollide = false,
		CanQuery = false,
	})
	label(grinder, "GRINDER CORE", 7, 60)

	local pads = folder("UpgradePads", station)
	for upgradeId, offset in PlotLayout.Pads do
		local pad = part({
			Name = upgradeId,
			Parent = pads,
			Size = PlotLayout.PadSize,
			CFrame = plotCFrame * CFrame.new(offset),
			Color = COLORS.Gold,
			Material = Enum.Material.Neon,
			Transparency = 0.1,
		})
		pad:SetAttribute("UpgradeId", upgradeId)
	end

	local tuner = part({
		Name = "LaserTuner",
		Parent = station,
		Size = Vector3.new(6, 1, 6),
		CFrame = plotCFrame * CFrame.new(PlotLayout.LaserTuner),
		Color = Color3.fromRGB(90, 220, 255),
		Material = Enum.Material.Neon,
	})
	label(tuner, "LASER TUNER", 3, 40)

	folder("Pedestals", plot)
	folder("Citadel", plot)
	folder("Belt", plot)

	-- Energy Bridge: segments from the plot's front edge to the hub ring.
	local bridge = folder("EnergyBridge", plot)
	local startPos = plotCFrame:PointToWorldSpace(PlotLayout.BridgeStart)
	local endPos = PlotLayout.BridgeEnd(index)
	local span = endPos - startPos
	local count = PlotLayout.BridgeSegments
	local segmentLength = span.Magnitude / count
	for i = 1, count do
		local center = startPos + span * ((i - 0.5) / count)
		local segment = part({
			Name = "Segment" .. i,
			Parent = bridge,
			Size = Vector3.new(7, 0.8, segmentLength + 0.05),
			CFrame = CFrame.lookAt(center, center + span),
			Color = COLORS.Gold,
			Material = Enum.Material.Neon,
			Transparency = 0.85,
			CanCollide = false,
		})
		segment:SetAttribute("SegmentIndex", i)
	end
	return plot
end

function MapBuilder.Build(): Instance
	local existing = Workspace:FindFirstChild("VoidlineMap")
	if existing then
		return existing
	end
	local root = Instance.new("Folder")
	root.Name = "VoidlineMap"
	buildHub(root)
	buildDeepSpace(root)
	buildOverlook(root)
	local plots = folder("Plots", root)
	for i = 1, GameConfig.PlotCount do
		buildPlot(plots, i)
	end
	root.Parent = Workspace
	print(("[Voidline] MapBuilder: VoidlineMap ready (%d plots)"):format(GameConfig.PlotCount))
	return root
end

return MapBuilder
