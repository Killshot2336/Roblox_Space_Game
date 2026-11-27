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
local VisualBibleConfig = require(Voidline.Config.VisualBibleConfig)
local ClipFramingConfig = require(Voidline.Config.ClipFramingConfig)
local PlotLayout = require(Voidline.Modules.PlotLayout)
local HubLayout = require(Voidline.Modules.HubLayout)
local ArtResolve = require(Voidline.Modules.ArtResolve)

local MapBuilder = {}

local COLORS = GameConfig.Colors
local PALETTE = VisualBibleConfig.Palette
local DECK = VisualBibleConfig.HubDeck
local HUB_FILL = VisualBibleConfig.Lighting.HubFill
local MAX_GOLD_SEAM = DECK.MaxGoldSeamStuds

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

-- Invisible collision under matte bridge decks (neon is trim-only, CanCollide=false).
local function walkPlate(props: PartProps): Part
	local plate = part({
		Name = props.Name,
		Parent = props.Parent,
		Size = props.Size,
		CFrame = props.CFrame,
		Color = props.Color or COLORS.Obsidian,
		Material = props.Material or Enum.Material.Slate,
		Transparency = if props.Transparency ~= nil then props.Transparency else 1,
		CanCollide = true,
		CanQuery = false,
	})
	plate:SetAttribute("Walkable", true)
	return plate
end

local function folder(name: string, parent: Instance): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

-- World labels are near-only. Long MaxDistance + hub density caused a gold
-- billboard wall at the Monolith (unreadable in Studio playtests).
local function label(parent: Instance, text: string, height: number, maxDistance: number, color: Color3?): BillboardGui
	local bb = Instance.new("BillboardGui")
	bb.Name = "Label"
	bb.Size = UDim2.fromOffset(160, 28)
	bb.StudsOffset = Vector3.new(0, height, 0)
	bb.AlwaysOnTop = false
	bb.MaxDistance = maxDistance
	bb.SizeOffset = Vector2.new(0, 0.5)
	bb.LightInfluence = 0
	bb.Parent = parent
	local text_ = Instance.new("TextLabel")
	text_.Name = "Text"
	text_.BackgroundTransparency = 0.45
	text_.BackgroundColor3 = COLORS.Obsidian
	text_.Size = UDim2.fromScale(1, 1)
	text_.Font = Enum.Font.GothamBold
	text_.TextScaled = true
	text_.TextColor3 = color or COLORS.Gold
	text_.Text = text
	text_.Parent = bb
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = text_
	local stroke = Instance.new("UIStroke")
	stroke.Color = COLORS.Gold
	stroke.Transparency = 0.65
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = text_
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 6)
	padding.PaddingRight = UDim.new(0, 6)
	padding.Parent = text_
	return bb
end
MapBuilder.Label = label

local function goldSeam(parent: Instance, cframe: CFrame, size: Vector3, name: string?, shape: Enum.PartType?)
	-- Neon only on thin ≤2-stud inlays; wide cylinder trims were bloom pancakes.
	local maxDim = math.max(size.X, size.Y, size.Z)
	local thinLip = maxDim <= MAX_GOLD_SEAM + 0.08 and shape ~= Enum.PartType.Cylinder
	local seam = part({
		Name = name or "GoldSeam",
		Parent = parent,
		Size = size,
		CFrame = cframe,
		Color = PALETTE.Gold,
		Material = if thinLip then Enum.Material.Neon else Enum.Material.Foil,
		Transparency = if thinLip then 0.48 else 0.1,
		CanCollide = false,
		CanQuery = false,
		Shape = shape,
	})
	seam:SetAttribute("GoldSeam", true)
	return seam
end

-- Thin gold inlay on matte lip (seam cross-section ≤ MaxGoldSeamStuds).
local function goldTrim(parent: Instance, base: CFrame, size: Vector3)
	local half = size / 2
	local lip = math.min(0.35, MAX_GOLD_SEAM)
	local seamT = DECK.SeamThickness
	local edges = {
		{ Vector3.new(0, half.Y + DECK.SeamLift, -half.Z + lip / 2), Vector3.new(size.X - lip * 2, seamT, lip) },
		{ Vector3.new(0, half.Y + DECK.SeamLift, half.Z - lip / 2), Vector3.new(size.X - lip * 2, seamT, lip) },
		{ Vector3.new(-half.X + lip / 2, half.Y + DECK.SeamLift, 0), Vector3.new(lip, seamT, size.Z - lip * 2) },
		{ Vector3.new(half.X - lip / 2, half.Y + DECK.SeamLift, 0), Vector3.new(lip, seamT, size.Z - lip * 2) },
	}
	for i, edge in edges do
		goldSeam(parent, base * CFrame.new(edge[1]), edge[2], "GoldTrim" .. i)
	end
end

local function attachFillLight(parent: Part, color: Color3, brightness: number, range: number)
	local light = Instance.new("PointLight")
	light.Brightness = brightness
	light.Range = range
	light.Color = color
	light.Shadows = false
	light.Parent = parent
end

local function buildHubFillLights(hub: Instance, hubCFrame: CFrame, walkTop: number)
	local lights = folder("HubFillLights", hub)
	local y = walkTop + 6
	local offsets = {
		Vector3.new(28, y, 14),
		Vector3.new(-22, y, -18),
		Vector3.new(14, y, -30),
		Vector3.new(-32, y, 22),
		Vector3.new(8, y + 4, 32),
		Vector3.new(-10, y + 3, -28),
		Vector3.new(36, y - 2, -8),
	}
	for i, pos in offsets do
		local anchor = part({
			Name = "FillAnchor" .. i,
			Parent = lights,
			Size = Vector3.new(0.6, 0.6, 0.6),
			CFrame = CFrame.new(pos),
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
		})
		attachFillLight(
			anchor,
			if i % 2 == 0 then Color3.fromRGB(210, 188, 148) else Color3.fromRGB(168, 182, 220),
			HUB_FILL.FillBrightness,
			HUB_FILL.Range
		)
	end
	local rim = part({
		Name = "MonolithRimFill",
		Parent = lights,
		Size = Vector3.new(1, 1, 1),
		CFrame = CFrame.new(HubLayout.MonolithCenter + Vector3.new(0, 8, -14)),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	})
	attachFillLight(rim, Color3.fromRGB(255, 218, 140), HUB_FILL.RimBrightness, HUB_FILL.Range * 0.75)
end

local function cableRun(parent: Instance, a: Vector3, b: Vector3, name: string)
	local p0 = part({
		Name = name .. "A",
		Parent = parent,
		Size = Vector3.new(0.45, 0.45, 0.45),
		CFrame = CFrame.new(a),
		Color = PALETTE.ObsidianLift,
		Material = Enum.Material.Metal,
		CanCollide = false,
		CanQuery = false,
	})
	local p1 = part({
		Name = name .. "B",
		Parent = parent,
		Size = Vector3.new(0.45, 0.45, 0.45),
		CFrame = CFrame.new(b),
		Color = PALETTE.ObsidianLift,
		Material = Enum.Material.Metal,
		CanCollide = false,
		CanQuery = false,
	})
	local a0 = Instance.new("Attachment")
	a0.Parent = p0
	local a1 = Instance.new("Attachment")
	a1.Parent = p1
	local beam = Instance.new("Beam")
	beam.Name = name .. "Beam"
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.Width0 = 0.12
	beam.Width1 = 0.12
	beam.Color = ColorSequence.new(PALETTE.Gold)
	beam.Transparency = NumberSequence.new(0.35)
	beam.FaceCamera = true
	beam.LightEmission = 0.55
	beam.Parent = parent
end

local function buildHubCathedralDressing(hub: Instance, hubCFrame: CFrame, walkTop: number)
	local dress = folder("HubCathedralDressing", hub)
	part({
		Name = "OffsetSpireEast",
		Parent = dress,
		Size = Vector3.new(4.5, 26, 4.5),
		CFrame = hubCFrame * CFrame.new(36, walkTop + 13, -11) * CFrame.Angles(0, math.rad(18), math.rad(4)),
		Color = Color3.fromRGB(16, 14, 22),
		Material = Enum.Material.Slate,
		CastShadow = true,
	})
	part({
		Name = "OffsetSpireNorthwest",
		Parent = dress,
		Size = Vector3.new(3.2, 19, 3.2),
		CFrame = hubCFrame * CFrame.new(-30, walkTop + 9.5, 20) * CFrame.Angles(math.rad(-6), math.rad(-22), 0),
		Color = Color3.fromRGB(14, 12, 20),
		Material = Enum.Material.Metal,
	})
	part({
		Name = "AsymmetricCatwalk",
		Parent = dress,
		Size = Vector3.new(18, 0.35, 3.2),
		CFrame = hubCFrame * CFrame.new(22, walkTop + 3.2, -26) * CFrame.Angles(0, math.rad(31), math.rad(2)),
		Color = Color3.fromRGB(20, 18, 26),
		Material = Enum.Material.DiamondPlate,
		CanCollide = false,
	})
	part({
		Name = "AsymmetricBannerArm",
		Parent = dress,
		Size = Vector3.new(0.45, 12, 0.45),
		CFrame = hubCFrame * CFrame.new(-18, walkTop + 8, -32) * CFrame.Angles(math.rad(8), math.rad(-14), 0),
		Color = Color3.fromRGB(18, 16, 24),
		Material = Enum.Material.Slate,
		CanCollide = false,
	})
	goldSeam(dress, hubCFrame * CFrame.new(36, walkTop + 25.5, -11), Vector3.new(0.18, 4.2, 0.18), "SpireEastCrownSeam")
	for i = 1, 7 do
		local ribZ = -38 + i * 6.5 + (i % 2) * 1.2
		part({
			Name = "HubRibbing" .. i,
			Parent = dress,
			Size = Vector3.new(HubLayout.HubSize.X * 0.92, 1.8, 0.55),
			CFrame = hubCFrame * CFrame.new(0, walkTop - 0.2, ribZ),
			Color = Color3.fromRGB(20, 18, 26),
			Material = Enum.Material.DiamondPlate,
			CanCollide = false,
		})
		if i % 2 == 0 then
			goldSeam(
				dress,
				hubCFrame * CFrame.new(0, walkTop + 0.12, ribZ),
				Vector3.new(18 + i * 3, DECK.SeamThickness, 0.35),
				"HubRibSeam" .. i
			)
		end
	end
	local under = folder("UnderHubGantry", dress)
	for i = 1, 3 do
		part({
			Name = "GantryBeam" .. i,
			Parent = under,
			Size = Vector3.new(HubLayout.HubSize.X - 8 - i * 4, 0.9, 1.2),
			CFrame = hubCFrame * CFrame.new(i * 3 - 5, walkTop - 3.2 - i * 0.6, -8 + i * 9),
			Color = Color3.fromRGB(22, 20, 28),
			Material = Enum.Material.CorrodedMetal,
			CanCollide = false,
		})
	end
	cableRun(
		dress,
		hubCFrame.Position + Vector3.new(30, walkTop + 22, -8),
		hubCFrame.Position + Vector3.new(8, walkTop + 4, 28),
		"CableA"
	)
	cableRun(
		dress,
		hubCFrame.Position + Vector3.new(-26, walkTop + 16, 14),
		hubCFrame.Position + Vector3.new(-6, walkTop - 2.5, -32),
		"CableB"
	)
	for ci = 1, 9 do
		local spread = (ci - 5) * 5.2 + (ci % 3) * 2.1
		cableRun(
			dress,
			hubCFrame.Position + Vector3.new(34, walkTop + 6 + ci * 1.2, spread),
			hubCFrame.Position + Vector3.new(-20 + ci, walkTop - 1.5, -spread * 0.6),
			"CableForest" .. ci
		)
	end
end

local function buildHubColonnades(hub: Instance, hubCFrame: CFrame, walkTop: number)
	local ring = folder("HubColonnadeRing", hub)
	local count = 18
	for i = 1, count do
		local bias = if i % 5 == 0 then 1.35 elseif i % 3 == 0 then 0.82 else 1
		local angle = (i - 0.5) / count * math.pi * 2 + math.rad(11 * (i % 4))
		local radius = 40 + (i % 4) * 2.5
		local pos = Vector3.new(math.cos(angle) * radius, walkTop, math.sin(angle) * radius)
		local height = 14 * bias + (i % 3) * 2.5
		local col = part({
			Name = "HubColonnade" .. i,
			Parent = ring,
			Size = Vector3.new(1.8 * bias, height, 1.8 * bias),
			CFrame = hubCFrame * CFrame.new(pos + Vector3.new(0, height / 2, 0)),
			Color = Color3.fromRGB(14, 12, 20),
			Material = Enum.Material.Slate,
			CanCollide = false,
			CastShadow = true,
		})
		goldSeam(
			ring,
			col.CFrame * CFrame.new(0, height / 2 - 0.8, 0),
			Vector3.new(1.4, DECK.SeamThickness, 0.32),
			"ColonnadeCap" .. i
		)
		if i % 7 == 0 then
			part({
				Name = "ColonnadeLintel" .. i,
				Parent = ring,
				Size = Vector3.new(10, 0.55, 2.2),
				CFrame = hubCFrame
					* CFrame.new(pos + Vector3.new(0, height + 0.4, 0))
					* CFrame.Angles(0, angle + math.rad(90), 0),
				Color = Color3.fromRGB(18, 16, 24),
				Material = Enum.Material.Metal,
				CanCollide = false,
			})
		end
	end
end

local function buildHubUpperDecks(hub: Instance, hubCFrame: CFrame, walkTop: number)
	local decks = folder("HubUpperDecks", hub)
	local layouts = {
		{
			Name = "EastGallery",
			Size = Vector3.new(28, 0.45, 8),
			Offset = Vector3.new(30, 4.2, -6),
			Rot = math.rad(14),
		},
		{
			Name = "NorthwestBalcony",
			Size = Vector3.new(16, 0.4, 12),
			Offset = Vector3.new(-26, 3.1, 22),
			Rot = math.rad(-18),
		},
		{
			Name = "SouthUnderlook",
			Size = Vector3.new(22, 0.38, 6),
			Offset = Vector3.new(4, 2.4, -34),
			Rot = math.rad(6),
		},
	}
	for _, lay in layouts do
		local deckPlate = part({
			Name = lay.Name,
			Parent = decks,
			Size = lay.Size,
			CFrame = hubCFrame * CFrame.new(lay.Offset + Vector3.new(0, walkTop, 0)) * CFrame.Angles(0, lay.Rot, 0),
			Color = PALETTE.ObsidianLift,
			Material = Enum.Material.DiamondPlate,
			CanCollide = false,
		})
		goldTrim(decks, deckPlate.CFrame, lay.Size)
		part({
			Name = lay.Name .. "Rail",
			Parent = decks,
			Size = Vector3.new(lay.Size.X, 1.2, 0.35),
			CFrame = deckPlate.CFrame * CFrame.new(0, lay.Size.Y / 2 + 0.55, -lay.Size.Z / 2 + 0.2),
			Color = Color3.fromRGB(20, 18, 26),
			Material = Enum.Material.Metal,
			CanCollide = false,
		})
	end
	part({
		Name = "HubUpperDeck",
		Parent = decks,
		Size = Vector3.new(12, 0.42, 12),
		CFrame = hubCFrame * CFrame.new(-8, walkTop + 6.5, -10) * CFrame.Angles(0, math.rad(-22), math.rad(2)),
		Color = PALETTE.Obsidian,
		Material = Enum.Material.Slate,
		CanCollide = false,
	})
end

local function buildHubCathedralArches(hub: Instance, hubCFrame: CFrame, walkTop: number)
	local arches = folder("HubCathedralArches", hub)
	for i = 1, 6 do
		local angle = (i - 0.5) / 6 * math.pi * 2 + math.rad(8)
		local radius = 34 + (i % 2) * 3
		local base = Vector3.new(math.cos(angle) * radius, walkTop, math.sin(angle) * radius)
		local pillarL = part({
			Name = "ArchPillarL" .. i,
			Parent = arches,
			Size = Vector3.new(1.6, 16 + (i % 3) * 2, 1.6),
			CFrame = hubCFrame * CFrame.new(base + Vector3.new(-2.2, 8, 0)) * CFrame.Angles(0, angle, 0),
			Color = Color3.fromRGB(14, 12, 20),
			Material = Enum.Material.Slate,
			CanCollide = false,
		})
		part({
			Name = "ArchPillarR" .. i,
			Parent = arches,
			Size = pillarL.Size,
			CFrame = hubCFrame * CFrame.new(base + Vector3.new(2.2, 8, 0)) * CFrame.Angles(0, angle, 0),
			Color = Color3.fromRGB(14, 12, 20),
			Material = Enum.Material.Slate,
			CanCollide = false,
		})
		part({
			Name = "ArchLinte" .. i,
			Parent = arches,
			Size = Vector3.new(6.8, 1.2, 2.4),
			CFrame = hubCFrame
				* CFrame.new(base + Vector3.new(0, pillarL.Size.Y / 2 + 7.8, 0))
				* CFrame.Angles(0, angle + math.rad(90), math.rad(3 * (i % 2))),
			Color = PALETTE.ObsidianLift,
			Material = Enum.Material.DiamondPlate,
			CanCollide = false,
		})
		if i % 2 == 0 then
			goldSeam(
				arches,
				hubCFrame * CFrame.new(base + Vector3.new(0, 12, 0)),
				Vector3.new(4.8, DECK.SeamThickness, 0.3),
				"ArchKeystone" .. i
			)
		end
	end
end

local function buildHubLightWells(hub: Instance, hubCFrame: CFrame, walkTop: number)
	local wells = folder("HubLightWells", hub)
	local spots = {
		Vector3.new(18, 0, 12),
		Vector3.new(-16, 0, -14),
		Vector3.new(6, 0, -28),
	}
	for wi, offset in spots do
		local shaft = part({
			Name = "HubLightWell" .. wi,
			Parent = wells,
			Size = Vector3.new(3.2, 18, 3.2),
			CFrame = hubCFrame * CFrame.new(offset + Vector3.new(0, walkTop - 7, 0)),
			Color = Color3.fromRGB(8, 6, 14),
			Material = Enum.Material.Slate,
			Transparency = 0.08,
			CanCollide = false,
			CanQuery = false,
		})
		local wellLight = Instance.new("PointLight")
		wellLight.Brightness = 0.38
		wellLight.Range = 22
		wellLight.Color = Color3.fromRGB(200, 188, 255)
		wellLight.Shadows = false
		wellLight.Parent = shaft
		goldSeam(
			wells,
			shaft.CFrame * CFrame.new(0, 8.2, 0),
			Vector3.new(2.8, DECK.SeamThickness, 0.32),
			"WellLip" .. wi
		)
	end
end

-- Procedural obsidian-gold plated deck: inset tiles, edge lights, trim rings.
local function buildPlatedHubDeck(hub: Instance, hubCFrame: CFrame)
	local deck = folder("HubPlatedDeck", hub)
	local tile = DECK.TileStuds
	local gap = DECK.Gap
	local halfX = HubLayout.HubSize.X / 2
	local halfZ = HubLayout.HubSize.Z / 2
	local baseY = hubCFrame.Position.Y
	local walkTop = baseY + HubLayout.HubSize.Y / 2
	local tileCount = 0
	for ix = 0, math.floor((HubLayout.HubSize.X - gap) / tile) - 1 do
		for iz = 0, math.floor((HubLayout.HubSize.Z - gap) / tile) - 1 do
			local cx = -halfX + gap + tile / 2 + ix * tile
			local cz = -halfZ + gap + tile / 2 + iz * tile
			local inset = (ix + iz) % 2 == 0
			local thickness = if inset then DECK.PlateThickness - DECK.InsetDepth else DECK.PlateThickness
			local y = walkTop - thickness / 2
			local deckTile = part({
				Name = if inset then "DeckTileInset" else "DeckTile",
				Parent = deck,
				Size = Vector3.new(tile - gap, thickness, tile - gap),
				CFrame = CFrame.new(cx, y, cz),
				Color = if inset then PALETTE.ObsidianLift else PALETTE.Obsidian,
				Material = if inset then Enum.Material.DiamondPlate else Enum.Material.Slate,
			})
			deckTile:SetAttribute("Walkable", true)
			if inset then
				goldSeam(
					deck,
					CFrame.new(cx, y + thickness / 2 + DECK.SeamLift, cz + (tile - gap) / 2 - 0.2),
					Vector3.new(tile - gap * 2, DECK.SeamThickness, 0.35),
					"DeckInsetSeam"
				)
			end
			tileCount += 1
		end
	end
	deck:SetAttribute("TileCount", tileCount)
	for ri, radius in DECK.TrimRingRadii do
		part({
			Name = "HubTrimRing" .. ri,
			Parent = deck,
			Size = Vector3.new(DECK.TrimRingHeight, radius * 2, radius * 2),
			CFrame = hubCFrame * CFrame.new(0, 0.22 + ri * 0.02, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Shape = Enum.PartType.Cylinder,
			Color = Color3.fromRGB(14, 12, 18),
			Material = Enum.Material.Metal,
			Transparency = 0.15,
			CanCollide = false,
			CanQuery = false,
		})
	end
	local padThickness = 0.55
	walkPlate({
		Name = "HubWalkCollision",
		Parent = deck,
		Size = Vector3.new(HubLayout.HubSize.X, padThickness, HubLayout.HubSize.Z),
		CFrame = CFrame.new(0, walkTop - padThickness / 2, 0),
		Material = Enum.Material.Basalt,
		Color = PALETTE.Obsidian,
	})
	part({
		Name = "HubPad",
		Parent = hub,
		Size = Vector3.new(HubLayout.HubSize.X, 0.4, HubLayout.HubSize.Z),
		CFrame = hubCFrame * CFrame.new(0, walkTop - 0.2, 0),
		Color = PALETTE.Obsidian,
		Material = Enum.Material.Basalt,
	})
end

local function buildHub(root: Instance)
	local hub = folder("Hub", root)
	local hubCFrame = CFrame.new(0, 0, 0)
	local walkTop = HubLayout.HubSize.Y / 2
	buildPlatedHubDeck(hub, hubCFrame)
	goldTrim(hub, hubCFrame, HubLayout.HubSize)
	buildHubCathedralDressing(hub, hubCFrame, walkTop)
	buildHubColonnades(hub, hubCFrame, walkTop)
	buildHubUpperDecks(hub, hubCFrame, walkTop)
	buildHubLightWells(hub, hubCFrame, walkTop)
	buildHubCathedralArches(hub, hubCFrame, walkTop)
	buildHubFillLights(hub, hubCFrame, walkTop)

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
				Size = Vector3.new(halfSize.X + 0.8, 1.35, halfSize.Z + 0.8),
				CFrame = half.CFrame * CFrame.new(0, -size.Y / 2 + 10 + i * 13, 0),
				Color = COLORS.Gold,
				Material = Enum.Material.Foil,
				CanCollide = false,
				CanQuery = false,
			})
			band:SetAttribute("Offset", half.CFrame:ToObjectSpace(band.CFrame))
		end
		local edge = part({
			Name = "SplitEdge" .. side,
			Parent = half,
			Size = Vector3.new(0.5, size.Y * 0.92, halfSize.Z * 0.85),
			CFrame = half.CFrame * CFrame.new(-sign * (halfSize.X / 2 - 0.2), 0, 0),
			Color = COLORS.GoldBright,
			Material = Enum.Material.Foil,
			Transparency = 0.15,
			CanCollide = false,
			CanQuery = false,
		})
		edge:SetAttribute("Offset", half.CFrame:ToObjectSpace(edge.CFrame))
		ArtResolve.ApplyMeshPart(half, "MonolithHalf", monolith)
	end
	part({
		Name = "MonolithSplitSeam",
		Parent = monolith,
		Size = Vector3.new(0.4, size.Y, size.Z * 0.9),
		CFrame = CFrame.new(HubLayout.MonolithCenter),
		Color = COLORS.GoldBright,
		Material = Enum.Material.Foil,
		Transparency = 0.2,
		CanCollide = false,
		CanQuery = false,
	})
	local core = part({
		Name = "VoidCore",
		Parent = monolith,
		Size = Vector3.new(7, 7, 7),
		CFrame = CFrame.new(HubLayout.VoidCore),
		Color = PALETTE.GoldCore,
		Material = Enum.Material.Neon,
		Shape = Enum.PartType.Ball,
		CanCollide = false,
		Transparency = 1,
	})
	core:SetAttribute("Exposed", false)
	local heroKey = part({
		Name = "MonolithHeroKey",
		Parent = monolith,
		Size = Vector3.new(1, 1, 1),
		CFrame = CFrame.new(HubLayout.MonolithCenter + Vector3.new(0, size.Y * 0.38, 18)),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	})
	local heroSpot = Instance.new("SpotLight")
	heroSpot.Name = "MonolithHeroSpot"
	heroSpot.Brightness = 1.35
	heroSpot.Range = 130
	heroSpot.Angle = 48
	heroSpot.Color = Color3.fromRGB(255, 228, 168)
	heroSpot.Face = Enum.NormalId.Back
	heroSpot.Shadows = false
	heroSpot.Parent = heroKey
	local heroRim = Instance.new("PointLight")
	heroRim.Name = "MonolithRim"
	heroRim.Brightness = 0.55
	heroRim.Range = 72
	heroRim.Color = Color3.fromRGB(200, 170, 255)
	heroRim.Parent = heroKey
	label(monolith:FindFirstChild("MonolithLeft") :: Instance, "THE VOIDLINE MONOLITH", 42, 48)
	local monolithHalfSize = Vector3.new(size.X / 2, size.Y, size.Z)
	for side, sign in sides do
		local half = monolith:FindFirstChild("Monolith" .. side)
		if half and half:IsA("BasePart") then
			local crownH = if side == "Right" then 9.5 else 4.5
			part({
				Name = "SpireCrown",
				Parent = half,
				Size = Vector3.new(monolithHalfSize.X * 0.32, crownH, monolithHalfSize.Z * 0.32),
				CFrame = half.CFrame
					* CFrame.new(0, size.Y / 2 + crownH / 2, 0)
					* CFrame.Angles(0, 0, sign * math.rad(5)),
				Color = Color3.fromRGB(16, 14, 22),
				Material = Enum.Material.Slate,
				CanCollide = false,
				CastShadow = true,
			})
			goldSeam(
				half,
				half.CFrame * CFrame.new(0, size.Y / 2 + crownH - 0.2, 0),
				Vector3.new(monolithHalfSize.X * 0.34, DECK.SeamThickness, 0.28),
				"SpireCrownSeam"
			)
			if side == "Right" then
				local shard = part({
					Name = "BrokenCrownShard",
					Parent = half,
					Size = Vector3.new(2.2, 6, 1.4),
					CFrame = half.CFrame
						* CFrame.new(monolithHalfSize.X * 0.22, size.Y / 2 + 11, 0.6)
						* CFrame.Angles(math.rad(14), math.rad(20), math.rad(32)),
					Color = Color3.fromRGB(18, 16, 24),
					Material = Enum.Material.Metal,
					CanCollide = false,
				})
				ArtResolve.ApplyMeshPart(shard, "MonolithCrownShard", half)
			end
			part({
				Name = "SpireFin",
				Parent = half,
				Size = Vector3.new(1.2, 14, 1.2),
				CFrame = half.CFrame
					* CFrame.new(sign * (monolithHalfSize.X * 0.28), size.Y / 2 + 9, 0)
					* CFrame.Angles(0, 0, sign * math.rad(8)),
				Color = COLORS.VoidAccent,
				Material = Enum.Material.Glass,
				Transparency = 0.15,
				CanCollide = false,
				CanQuery = false,
			})
		end
	end
	for _, lip in { { Label = "North", Sign = -1 }, { Label = "South", Sign = 1 } } do
		local sign = lip.Sign
		part({
			Name = "HubDeckLip" .. lip.Label,
			Parent = hub,
			Size = Vector3.new(HubLayout.HubSize.X * 0.96, 0.22, 0.55),
			CFrame = hubCFrame * CFrame.new(0, walkTop + 0.08, sign * (HubLayout.HubSize.Z / 2 - 0.35)),
			Color = Color3.fromRGB(12, 10, 16),
			Material = Enum.Material.Metal,
			CanCollide = false,
		})
		goldSeam(
			hub,
			hubCFrame * CFrame.new(0, walkTop + 0.14, sign * (HubLayout.HubSize.Z / 2 - 0.35)),
			Vector3.new(24, DECK.SeamThickness, 0.35),
			"HubDeckLipSeam" .. lip.Label
		)
	end

	local function hubPad(name: string, position: Vector3, padSize: Vector3, text: string, style: string)
		local p = part({
			Name = name,
			Parent = hub,
			Size = padSize,
			CFrame = CFrame.new(position),
			Color = PALETTE.ObsidianLift,
			Material = Enum.Material.DiamondPlate,
		})
		p:SetAttribute("Walkable", true)
		goldTrim(hub, p.CFrame, padSize)
		if style == "forge" then
			part({
				Name = name .. "Chimney",
				Parent = hub,
				Size = Vector3.new(3.5, 14, 3.5),
				CFrame = p.CFrame * CFrame.new(4, 7.5, -3),
				Color = Color3.fromRGB(20, 18, 26),
				Material = Enum.Material.CorrodedMetal,
				CanCollide = false,
			})
			part({
				Name = name .. "Anvil",
				Parent = hub,
				Size = Vector3.new(4, 2, 3),
				CFrame = p.CFrame * CFrame.new(-2, 1.5, 2),
				Color = Color3.fromRGB(28, 26, 34),
				Material = Enum.Material.Metal,
				CanCollide = false,
			})
			goldSeam(
				hub,
				p.CFrame * CFrame.new(-2, 2.35, 2),
				Vector3.new(2.2, DECK.SeamThickness, 0.35),
				"ForgeAnvilSeam"
			)
		elseif style == "summon" then
			part({
				Name = name .. "ArchL",
				Parent = hub,
				Size = Vector3.new(1.2, 11, 1.2),
				CFrame = p.CFrame * CFrame.new(-4.5, 6, 0),
				Color = Color3.fromRGB(16, 14, 22),
				Material = Enum.Material.Slate,
				CanCollide = false,
			})
			part({
				Name = name .. "ArchR",
				Parent = hub,
				Size = Vector3.new(1.2, 11, 1.2),
				CFrame = p.CFrame * CFrame.new(4.5, 6, 0),
				Color = Color3.fromRGB(16, 14, 22),
				Material = Enum.Material.Slate,
				CanCollide = false,
			})
			part({
				Name = name .. "ArchLintel",
				Parent = hub,
				Size = Vector3.new(10, 1, 1.6),
				CFrame = p.CFrame * CFrame.new(0, 11.2, 0),
				Color = COLORS.VoidAccent,
				Material = Enum.Material.Glass,
				Transparency = 0.35,
				CanCollide = false,
			})
		end
		label(p, text, 3.2, 16)
		return p
	end
	hubPad("RebirthPad", HubLayout.RebirthPad, Vector3.new(12, 1, 12), "VOID REBIRTH", "ritual")
	hubPad("ForgePad", HubLayout.ForgePad, Vector3.new(12, 1, 12), "ARTIFACT FORGE", "forge")
	hubPad("SummonPad", HubLayout.SummonPad, Vector3.new(12, 1, 12), "SERVER SUMMONS", "summon")
	hubPad("VipLounge", HubLayout.VipLounge, Vector3.new(18, 1, 18), "VOID SOVEREIGN LOUNGE", "ritual")
	hubPad("OverlookGate", HubLayout.OverlookGate, Vector3.new(10, 1, 10), "STAR OVERLOOK", "ritual")
	hubPad("RiftGate", HubLayout.RiftGate, Vector3.new(10, 1, 10), "VOID RIFT", "ritual")

	local terminal = part({
		Name = "CodeTerminal",
		Parent = hub,
		Size = Vector3.new(8, 10, 2),
		CFrame = CFrame.lookAt(HubLayout.CodeTerminal, Vector3.new(0, HubLayout.CodeTerminal.Y, 0)),
		Material = Enum.Material.Metal,
	})
	label(terminal, "CODE TERMINAL", 6, 14)

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
		Material = Enum.Material.Foil,
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
	-- Plaque SurfaceGui is the readable credit; no floating billboard (was stacking at hub).
	part({
		Name = "MonumentHalo",
		Parent = monument,
		Size = Vector3.new(14, 0.35, 14),
		CFrame = plinth.CFrame * CFrame.new(0, 2.5, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Shape = Enum.PartType.Cylinder,
		Color = Color3.fromRGB(22, 20, 28),
		Material = Enum.Material.Metal,
		Transparency = 0.25,
		CanCollide = false,
		CanQuery = false,
	})

	local clipShots = folder("ClipShots", hub)
	for _, shot in ClipFramingConfig.Shots do
		local pad = part({
			Name = "ClipShot_" .. shot.Id,
			Parent = clipShots,
			Size = Vector3.new(5, 0.15, 5),
			CFrame = CFrame.new(shot.Stand),
			Color = PALETTE.ObsidianLift,
			Material = Enum.Material.SmoothPlastic,
			Transparency = 0.94,
			CanCollide = false,
			CanQuery = false,
		})
		pad:SetAttribute("ClipShotId", shot.Id)
		pad:SetAttribute("LookAt", shot.LookAt)
		pad:SetAttribute("ClipHint", shot.Hint)
		if shot.Fov then
			pad:SetAttribute("ClipFov", shot.Fov)
		end
		-- No world label — ClipShot pads are framing marks; hints stay on attributes.
	end

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
	spawnLocation.Color = PALETTE.ObsidianLift
	spawnLocation.Material = Enum.Material.SmoothPlastic
	spawnLocation.Duration = 0
	spawnLocation.Transparency = 0.92
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

local function buildVoidStarDressing(parent: Instance)
	local stars = folder("VoidStarDressing", parent)
	local rng = Random.new(4217)
	for i = 1, 48 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local radius = rng:NextNumber(HubLayout.ZoneRadius * 0.35, HubLayout.ZoneRadius * 1.15)
		local y = rng:NextNumber(-12, 42)
		local pos = Vector3.new(math.cos(angle) * radius, y, math.sin(angle) * radius)
		local shard = part({
			Name = "StarShard" .. i,
			Parent = stars,
			Size = Vector3.new(rng:NextNumber(0.35, 1.2), rng:NextNumber(0.15, 0.55), rng:NextNumber(0.35, 1.2)),
			CFrame = CFrame.new(pos) * CFrame.Angles(rng:NextNumber(), rng:NextNumber(), rng:NextNumber()),
			Color = Color3.fromRGB(198, 204, 228),
			Material = Enum.Material.Slate,
			CanCollide = false,
			CanQuery = false,
			Transparency = rng:NextNumber(0.15, 0.55),
		})
		if i % 9 == 0 then
			local glint = Instance.new("PointLight")
			glint.Brightness = 0.12
			glint.Range = 12
			glint.Color = Color3.fromRGB(220, 230, 255)
			glint.Shadows = false
			glint.Parent = shard
		end
	end
	for i = 1, 14 do
		local chunk = part({
			Name = "DebrisChunk" .. i,
			Parent = stars,
			Size = Vector3.new(rng:NextNumber(1.2, 3.5), rng:NextNumber(0.4, 1.1), rng:NextNumber(1.2, 3.8)),
			CFrame = CFrame.new(
				rng:NextNumber(-HubLayout.ZoneRadius, HubLayout.ZoneRadius),
				rng:NextNumber(-8, 22),
				rng:NextNumber(-HubLayout.ZoneRadius, HubLayout.ZoneRadius)
			) * CFrame.Angles(rng:NextNumber(), rng:NextNumber(), rng:NextNumber()),
			Color = Color3.fromRGB(16, 14, 22),
			Material = if i % 3 == 0 then Enum.Material.CorrodedMetal else Enum.Material.Metal,
			CanCollide = false,
			CanQuery = false,
		})
		chunk:SetAttribute("VoidDressing", true)
	end
end

local function buildAsteroidField(parent: Instance)
	local field = folder("DeepSpaceAsteroidField", parent)
	local rng = Random.new(8819)
	local count = 0
	for i = 1, 92 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local band = if i % 4 == 0 then 1.35 elseif i % 7 == 0 then 0.55 else 0.85
		local radius = rng:NextNumber(HubLayout.ZoneRadius * 0.25, HubLayout.ZoneRadius * 1.25) * band
		local y = rng:NextNumber(-28, 95)
		local sizeMul = rng:NextNumber(0.7, 2.8)
		local asteroid = part({
			Name = "Asteroid" .. i,
			Parent = field,
			Size = Vector3.new(
				rng:NextNumber(2.2, 5.5) * sizeMul,
				rng:NextNumber(1.4, 4.2) * sizeMul,
				rng:NextNumber(2.0, 5.8) * sizeMul
			),
			CFrame = CFrame.new(math.cos(angle) * radius, y, math.sin(angle) * radius)
				* CFrame.Angles(rng:NextNumber(), rng:NextNumber(), rng:NextNumber()),
			Color = Color3.fromRGB(22 + rng:NextInteger(0, 12), 20, 28 + rng:NextInteger(0, 10)),
			Material = if rng:NextNumber() > 0.65 then Enum.Material.Basalt else Enum.Material.Slate,
			CanCollide = false,
			CanQuery = false,
		})
		asteroid:SetAttribute("ParallaxLayer", if radius > HubLayout.ZoneRadius then 2 else 1)
		count += 1
		if ArtResolve.HasUploadedMesh("DeepSpaceAsteroid") and i % 3 == 0 then
			ArtResolve.ApplyMeshPart(asteroid, "DeepSpaceAsteroid", field)
		end
	end
	field:SetAttribute("AsteroidCount", count)
end

local function buildParallaxBodies(parent: Instance)
	local parallax = folder("DeepSpaceParallax", parent)
	local bodies = {
		{ Name = "ParallaxBodyDwarf", Pos = Vector3.new(420, 40, -260), Size = 48, Color = Color3.fromRGB(28, 26, 34) },
		{ Name = "ParallaxBodyGas", Pos = Vector3.new(-380, 120, 310), Size = 72, Color = Color3.fromRGB(42, 36, 58) },
		{ Name = "ParallaxBodyIce", Pos = Vector3.new(180, -20, 520), Size = 36, Color = Color3.fromRGB(32, 38, 48) },
	}
	for _, body in bodies do
		part({
			Name = body.Name,
			Parent = parallax,
			Size = Vector3.new(body.Size, body.Size, body.Size),
			CFrame = CFrame.new(body.Pos),
			Shape = Enum.PartType.Ball,
			Color = body.Color,
			Material = Enum.Material.Slate,
			Transparency = 0.12,
			CanCollide = false,
			CanQuery = false,
		})
	end
	for i = 1, 4 do
		part({
			Name = "ParallaxBody" .. i,
			Parent = parallax,
			Size = Vector3.new(22 + i * 6, 22 + i * 6, 22 + i * 6),
			CFrame = CFrame.new(math.cos(i * 1.7) * (520 + i * 40), 30 + i * 18, math.sin(i * 1.7) * (520 + i * 40)),
			Shape = Enum.PartType.Ball,
			Color = Color3.fromRGB(20, 18, 26),
			Material = Enum.Material.Basalt,
			Transparency = 0.22,
			CanCollide = false,
			CanQuery = false,
		})
	end
end

local function buildDeepSpaceFogVolumes(parent: Instance)
	local fog = folder("DeepSpaceFogVolumes", parent)
	local rng = Random.new(3301)
	for i = 1, 8 do
		local angle = i / 8 * math.pi * 2
		local radius = HubLayout.ZoneRadius * rng:NextNumber(0.45, 1.05)
		part({
			Name = "FogVolume" .. i,
			Parent = fog,
			Size = Vector3.new(rng:NextNumber(40, 90), rng:NextNumber(12, 32), rng:NextNumber(40, 90)),
			CFrame = CFrame.new(math.cos(angle) * radius, rng:NextNumber(-6, 24), math.sin(angle) * radius),
			Color = Color3.fromRGB(24, 18, 38),
			Material = Enum.Material.Glass,
			Transparency = 0.93,
			CanCollide = false,
			CanQuery = false,
		})
	end
end

local function buildDeepSpace(root: Instance)
	local deep = folder("DeepSpace", root)
	buildVoidStarDressing(deep)
	buildAsteroidField(deep)
	buildParallaxBodies(deep)
	buildDeepSpaceFogVolumes(deep)
	part({
		Name = "ZoneRing",
		Parent = deep,
		Size = Vector3.new(1, HubLayout.ZoneRadius * 2, HubLayout.ZoneRadius * 2),
		CFrame = CFrame.new(0, -6, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Shape = Enum.PartType.Cylinder,
		Color = Color3.fromRGB(12, 10, 18),
		Material = Enum.Material.Metal,
		Transparency = 0.65,
		CanCollide = false,
		CanQuery = false,
	})
	-- Thumbnail-readable Deep Space rim: tall neon pylons between hub and plot ring.
	for i = 1, 12 do
		local angle = (i - 0.5) / 12 * math.pi * 2
		local rim = (HubLayout.ZoneRadius + GameConfig.PlotRingRadius) * 0.52
		local pos = Vector3.new(math.cos(angle) * rim, 6, math.sin(angle) * rim)
		local pylon = part({
			Name = "DeepSpacePylon" .. i,
			Parent = deep,
			Size = Vector3.new(1.4, 22, 1.4),
			CFrame = CFrame.new(pos),
			Color = Color3.fromRGB(14, 12, 20),
			Material = Enum.Material.Slate,
			Transparency = 0,
			CanCollide = false,
			CanQuery = false,
		})
		goldSeam(
			deep,
			pylon.CFrame * CFrame.new(0, 10.5, 0),
			Vector3.new(1.6, DECK.SeamThickness, 0.35),
			"PylonSeam" .. i
		)
	end
	part({
		Name = "DeepSpaceFloor",
		Parent = deep,
		Size = Vector3.new(HubLayout.ZoneRadius * 1.85, 0.6, HubLayout.ZoneRadius * 1.85),
		CFrame = CFrame.new(0, -8, 0),
		Color = Color3.fromRGB(8, 6, 14),
		Material = Enum.Material.Slate,
		CanCollide = false,
		CanQuery = false,
	})
	part({
		Name = "PlotOrbitRing",
		Parent = deep,
		Size = Vector3.new(1.2, GameConfig.PlotRingRadius * 2.02, GameConfig.PlotRingRadius * 2.02),
		CFrame = CFrame.new(0, 3, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Shape = Enum.PartType.Cylinder,
		Color = Color3.fromRGB(16, 14, 22),
		Material = Enum.Material.Metal,
		Transparency = 0.2,
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
		Color = Color3.fromRGB(28, 24, 36),
		Material = Enum.Material.Marble,
		CanCollide = false,
		Transparency = 0,
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
	local stationBase = part({
		Name = "StationBase",
		Parent = plot,
		Size = PlotLayout.BaseSize,
		CFrame = baseCFrame,
		Material = Enum.Material.Basalt,
		Color = COLORS.Obsidian,
	})
	stationBase:SetAttribute("Walkable", true)
	goldTrim(plot, baseCFrame, PlotLayout.BaseSize)
	local half = PlotLayout.BaseSize / 2
	local pylonOffsets = {
		Vector3.new(-half.X + 2, 2, -half.Z + 2),
		Vector3.new(half.X - 2, 2, -half.Z + 2),
		Vector3.new(-half.X + 2, 2, half.Z - 2),
		Vector3.new(half.X - 2, 2, half.Z - 2),
	}
	for i, offset in pylonOffsets do
		local pylon = part({
			Name = "PlotPylon" .. i,
			Parent = plot,
			Size = Vector3.new(1.4, 7, 1.4),
			CFrame = plotCFrame * CFrame.new(offset),
			Color = Color3.fromRGB(16, 14, 22),
			Material = Enum.Material.Slate,
			CanCollide = false,
			CanQuery = false,
		})
		goldSeam(
			plot,
			pylon.CFrame * CFrame.new(0, 3.2, 0),
			Vector3.new(1.5, DECK.SeamThickness, 0.35),
			"PlotPylonSeam" .. i
		)
	end

	local spawnMarker = part({
		Name = "PlayerSpawn",
		Parent = plot,
		Size = Vector3.new(6, 0.2, 6),
		CFrame = plotCFrame * CFrame.new(PlotLayout.Spawn),
		Color = PALETTE.ObsidianLift,
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
		Transparency = 0.88,
	})
	spawnMarker:SetAttribute("Spawn", true)

	local station = folder("Station", plot)
	local refinery = part({
		Name = "Refinery",
		Parent = station,
		Size = PlotLayout.RefinerySize,
		CFrame = plotCFrame * CFrame.new(PlotLayout.Refinery),
		Color = Color3.fromRGB(22, 20, 28),
		Material = Enum.Material.Metal,
	})
	goldSeam(
		station,
		plotCFrame * CFrame.new(PlotLayout.Refinery + Vector3.new(0, PlotLayout.RefinerySize.Y / 2 + 0.08, 0)),
		Vector3.new(PlotLayout.RefinerySize.X - 1, DECK.SeamThickness, 0.35),
		"RefineryDeckSeam"
	)
	label(refinery, "REFINERY", 3.5, 14)
	local machine = folder("PlotMachineShell", plot)
	part({
		Name = "MachineHousing",
		Parent = machine,
		Size = Vector3.new(PlotLayout.BaseSize.X * 0.82, 5.5, PlotLayout.BaseSize.Z * 0.62),
		CFrame = plotCFrame * CFrame.new(0, PlotLayout.SurfaceY + 1.8, 4),
		Color = Color3.fromRGB(18, 16, 24),
		Material = Enum.Material.CorrodedMetal,
		CanCollide = false,
	})
	for pi = 1, 4 do
		part({
			Name = "MachinePipe" .. pi,
			Parent = machine,
			Size = Vector3.new(1.1, 6 + pi * 1.4, 1.1),
			CFrame = plotCFrame
				* CFrame.new(-10 + pi * 5.5, PlotLayout.SurfaceY + 5, -8)
				* CFrame.Angles(math.rad(12 + pi * 4), 0, 0),
			Color = Color3.fromRGB(24, 22, 30),
			Material = Enum.Material.Metal,
			CanCollide = false,
		})
	end
	part({
		Name = "MachineFunnel",
		Parent = machine,
		Size = Vector3.new(7, 4, 7),
		CFrame = plotCFrame * CFrame.new(PlotLayout.Grinder.X, PlotLayout.SurfaceY + 6, PlotLayout.Grinder.Z),
		Color = Color3.fromRGB(22, 20, 28),
		Material = Enum.Material.DiamondPlate,
		CanCollide = false,
	})
	local grinder = part({
		Name = "GrinderCore",
		Parent = station,
		Size = Vector3.new(9, 9, 9),
		CFrame = plotCFrame * CFrame.new(PlotLayout.Grinder) * CFrame.Angles(math.rad(45), math.rad(45), 0),
		Color = Color3.fromRGB(30, 28, 44),
		Material = Enum.Material.DiamondPlate,
	})
	ArtResolve.ApplyMeshPart(grinder, "GrinderCore", station)
	local refineryTower = part({
		Name = "RefineryTower",
		Parent = station,
		Size = Vector3.new(8, 12, 6),
		CFrame = plotCFrame * CFrame.new(PlotLayout.RefineryTower),
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(26, 24, 34),
	})
	ArtResolve.ApplyMeshPart(refineryTower, "RefineryStack", station)
	part({
		Name = "GrinderGlow",
		Parent = grinder,
		Size = Vector3.new(2.8, 2.8, 2.8),
		CFrame = grinder.CFrame,
		Color = COLORS.GoldBright,
		Material = Enum.Material.Foil,
		CanCollide = false,
		CanQuery = false,
	})
	label(grinder, "GRINDER CORE", 5, 14)

	local pads = folder("UpgradePads", station)
	for upgradeId, offset in PlotLayout.Pads do
		local pad = part({
			Name = upgradeId,
			Parent = pads,
			Size = PlotLayout.PadSize,
			CFrame = plotCFrame * CFrame.new(offset),
			Color = PALETTE.ObsidianLift,
			Material = Enum.Material.DiamondPlate,
			Transparency = 0,
		})
		pad:SetAttribute("UpgradeId", upgradeId)
		pad:SetAttribute("Walkable", true)
		goldSeam(
			pads,
			pad.CFrame * CFrame.new(0, PlotLayout.PadSize.Y / 2 + DECK.SeamLift, 0),
			Vector3.new(PlotLayout.PadSize.X * 0.5, DECK.SeamThickness, 0.28),
			upgradeId .. "Seam"
		)
	end

	local tuner = part({
		Name = "LaserTuner",
		Parent = station,
		Size = Vector3.new(6, 1, 6),
		CFrame = plotCFrame * CFrame.new(PlotLayout.LaserTuner),
		Color = Color3.fromRGB(26, 24, 34),
		Material = Enum.Material.Metal,
	})
	goldSeam(
		station,
		plotCFrame * CFrame.new(PlotLayout.LaserTuner + Vector3.new(0, 0.65, 0)),
		Vector3.new(3.2, DECK.SeamThickness, 0.35),
		"TunerSeam"
	)
	label(tuner, "LASER TUNER", 2.8, 12)

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
		local segmentCFrame = CFrame.lookAt(center, center + span)
		local segment = part({
			Name = "Segment" .. i,
			Parent = bridge,
			Size = Vector3.new(7, 0.8, segmentLength + 0.05),
			CFrame = segmentCFrame,
			Color = Color3.fromRGB(18, 16, 24),
			Material = Enum.Material.Slate,
			Transparency = 0,
			CanCollide = false,
			CanQuery = false,
		})
		segment:SetAttribute("SegmentIndex", i)
		walkPlate({
			Name = "WalkPlate" .. i,
			Parent = bridge,
			Size = Vector3.new(7.2, 1.1, segmentLength + 0.12),
			CFrame = segmentCFrame,
			Material = Enum.Material.DiamondPlate,
			Color = PALETTE.ObsidianLift,
		})
		goldSeam(
			bridge,
			segment.CFrame * CFrame.new(0, 0.52, 0),
			Vector3.new(0.35, DECK.SeamThickness, segmentLength * 0.94),
			"Spine" .. i
		)
		part({
			Name = "Rail" .. i,
			Parent = bridge,
			Size = Vector3.new(0.35, 2.2, segmentLength * 0.92),
			CFrame = segment.CFrame * CFrame.new(3.4, 1.2, 0),
			Color = Color3.fromRGB(120, 200, 255),
			Material = Enum.Material.Glass,
			Transparency = 0.35,
			CanCollide = false,
			CanQuery = false,
		})
		part({
			Name = "RailL" .. i,
			Parent = bridge,
			Size = Vector3.new(0.35, 2.2, segmentLength * 0.92),
			CFrame = segment.CFrame * CFrame.new(-3.4, 1.2, 0),
			Color = Color3.fromRGB(120, 200, 255),
			Material = Enum.Material.Glass,
			Transparency = 0.35,
			CanCollide = false,
			CanQuery = false,
		})
		if i % 2 == 1 then
			for rib = 1, 3 do
				part({
					Name = "BridgeRib" .. i .. "_" .. rib,
					Parent = bridge,
					Size = Vector3.new(6.8, 0.28, 0.55),
					CFrame = segment.CFrame * CFrame.new(0, -0.35 - rib * 0.22, (rib - 2) * (segmentLength * 0.28)),
					Color = Color3.fromRGB(16, 14, 22),
					Material = Enum.Material.Metal,
					CanCollide = false,
					CanQuery = false,
				})
			end
		end
		if i == 1 then
			ArtResolve.ApplyMeshPart(segment, "EnergyBridgeSegment", bridge)
		end
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
