local Workspace = game:GetService("Workspace")
local ServerStorage = game:GetService("ServerStorage")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Voidline = ReplicatedStorage:WaitForChild("Voidline")
local GameConfig = require(Voidline.Config.GameConfig)

local MapBuilder = {}

local function part(props): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = props.CanCollide ~= false
	p.Material = props.Material or Enum.Material.SmoothPlastic
	p.Color = props.Color or GameConfig.Colors.Obsidian
	p.Size = props.Size or Vector3.new(4, 1, 4)
	p.CFrame = props.CFrame or CFrame.new()
	p.Name = props.Name or "Part"
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props.Transparency then
		p.Transparency = props.Transparency
	end
	if props.Shape then
		p.Shape = props.Shape
	end
	p.Parent = props.Parent
	return p
end

local function billboard(parent: Instance, text: string, color: Color3?)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(220, 40)
	bb.StudsOffset = Vector3.new(0, 6, 0)
	bb.AlwaysOnTop = true
	bb.Parent = parent
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = color or GameConfig.Colors.Gold
	label.Text = text
	label.Parent = bb
	return bb
end

function MapBuilder.Build()
	if Workspace:FindFirstChild("VoidlineMap") then
		return Workspace.VoidlineMap
	end

	local root = Instance.new("Folder")
	root.Name = "VoidlineMap"
	root.Parent = Workspace

	-- Hub floor
	local hub = Instance.new("Folder")
	hub.Name = "Hub"
	hub.Parent = root

	part({
		Name = "HubPad",
		Parent = hub,
		Size = Vector3.new(GameConfig.HubRadius * 2, 2, GameConfig.HubRadius * 2),
		CFrame = CFrame.new(0, 0, 0),
		Color = GameConfig.Colors.Obsidian,
		Material = Enum.Material.Metal,
	})

	-- Voidline Monolith
	local monolithFolder = Instance.new("Folder")
	monolithFolder.Name = "VoidlineMonolith"
	monolithFolder.Parent = hub

	local monolith = part({
		Name = "MonolithCore",
		Parent = monolithFolder,
		Size = Vector3.new(18, 72, 18),
		CFrame = CFrame.new(0, 37, 0),
		Color = GameConfig.Colors.Obsidian,
		Material = Enum.Material.Slate,
	})
	-- Gold trim bands
	for i = 1, 4 do
		part({
			Name = "GoldBand" .. i,
			Parent = monolithFolder,
			Size = Vector3.new(20, 1.2, 20),
			CFrame = CFrame.new(0, 10 + i * 14, 0),
			Color = GameConfig.Colors.Gold,
			Material = Enum.Material.Neon,
		})
	end
	billboard(monolith, "THE VOIDLINE MONOLITH")

	part({
		Name = "RebirthPad",
		Parent = monolithFolder,
		Size = Vector3.new(14, 1, 14),
		CFrame = CFrame.new(16, 1.5, 0),
		Color = GameConfig.Colors.Gold,
		Material = Enum.Material.Neon,
	})
	billboard(monolithFolder.RebirthPad, "VOID REBIRTH")

	part({
		Name = "ForgeAnchor",
		Parent = monolithFolder,
		Size = Vector3.new(12, 1, 12),
		CFrame = CFrame.new(-16, 1.5, 0),
		Color = GameConfig.Colors.VoidAccent,
		Material = Enum.Material.Neon,
	})
	billboard(monolithFolder.ForgeAnchor, "ARTIFACT FORGE")

	part({
		Name = "CodeTerminal",
		Parent = monolithFolder,
		Size = Vector3.new(8, 10, 2),
		CFrame = CFrame.new(0, 6, 22),
		Color = GameConfig.Colors.Obsidian,
		Material = Enum.Material.Metal,
	})
	billboard(monolithFolder.CodeTerminal, "VOIDLINE CODES")

	part({
		Name = "SummonPads",
		Parent = monolithFolder,
		Size = Vector3.new(10, 1, 10),
		CFrame = CFrame.new(0, 1.5, -22),
		Color = GameConfig.Colors.GoldBright,
		Material = Enum.Material.Neon,
	})
	billboard(monolithFolder.SummonPads, "SERVER SUMMONS")

	part({
		Name = "EventCore",
		Parent = monolithFolder,
		Size = Vector3.new(6, 6, 6),
		CFrame = CFrame.new(0, 8, 0),
		Color = GameConfig.Colors.Gold,
		Material = Enum.Material.Neon,
		Shape = Enum.PartType.Ball,
		CanCollide = false,
	})

	local boards = Instance.new("Folder")
	boards.Name = "LeaderboardAnchors"
	boards.Parent = hub
	for i, name in { "TopCredits", "TopRebirths", "CodexDiscoveries", "TopSummoners" } do
		local anchor = part({
			Name = name,
			Parent = boards,
			Size = Vector3.new(10, 14, 1),
			CFrame = CFrame.new(math.cos(i) * 28, 10, math.sin(i) * 28),
			Color = GameConfig.Colors.Obsidian,
		})
		billboard(anchor, name)
	end

	part({
		Name = "VIPLoungePad",
		Parent = hub,
		Size = Vector3.new(20, 1, 20),
		CFrame = CFrame.new(40, 1.5, 40),
		Color = GameConfig.Colors.Gold,
		Material = Enum.Material.Neon,
	})
	billboard(hub.VIPLoungePad, "VOID VIP LOUNGE")

	local monument = part({
		Name = "KillshotMonument",
		Parent = hub,
		Size = Vector3.new(6, 16, 6),
		CFrame = CFrame.new(-40, 9, 40),
		Color = GameConfig.Colors.Obsidian,
		Material = Enum.Material.Metal,
	})
	billboard(monument, "Created by Killshot2336")

	-- Deep Space zone
	local deep = Instance.new("Folder")
	deep.Name = "DeepSpace"
	deep.Parent = root
	part({
		Name = "SoftContestZone",
		Parent = deep,
		Size = Vector3.new(90, 1, 90),
		CFrame = CFrame.new(0, 0.5, 0),
		Color = Color3.fromRGB(20, 10, 40),
		Transparency = 0.35,
		CanCollide = false,
	})
	local rareSpawns = Instance.new("Folder")
	rareSpawns.Name = "RareAsteroidSpawns"
	rareSpawns.Parent = deep
	for i = 1, 8 do
		local angle = (i / 8) * math.pi * 2
		local pos = Vector3.new(math.cos(angle) * 55, 18, math.sin(angle) * 55)
		local rock = part({
			Name = "VoidAsteroid_" .. i,
			Parent = rareSpawns,
			Size = Vector3.new(10, 10, 10),
			CFrame = CFrame.new(pos),
			Color = Color3.fromRGB(40, 20, 70),
			Material = Enum.Material.Rock,
			Shape = Enum.PartType.Ball,
		})
		rock:SetAttribute("Sector", "VoidRim")
		rock:SetAttribute("MaxHealth", 5000)
		rock:SetAttribute("Health", 5000)
		rock:SetAttribute("Shared", true)
	end
	part({
		Name = "EventMeteorAnchor",
		Parent = deep,
		Size = Vector3.new(2, 2, 2),
		CFrame = CFrame.new(0, 40, 0),
		Transparency = 1,
		CanCollide = false,
	})

	-- Kyria overlook (secret)
	local kyria = Instance.new("Folder")
	kyria.Name = "KyriaOverlook"
	kyria.Parent = root
	local overlook = part({
		Name = "StarlightOverlook",
		Parent = kyria,
		Size = Vector3.new(16, 1, 16),
		CFrame = CFrame.new(180, 60, -180),
		Color = Color3.fromRGB(255, 230, 180),
		Material = Enum.Material.Neon,
	})
	overlook:SetAttribute("SecretAura", true)
	-- Quiet marker only — no Kyria branding in UI
	billboard(overlook, "…", Color3.fromRGB(255, 240, 200))

	local star = part({
		Name = "HiddenStar",
		Parent = kyria,
		Size = Vector3.new(40, 40, 40),
		CFrame = CFrame.new(220, 140, -220),
		Color = Color3.fromRGB(255, 236, 180),
		Material = Enum.Material.Neon,
		Shape = Enum.PartType.Ball,
		CanCollide = false,
	})
	star.Transparency = 0.15

	-- Plots ring
	local plotsFolder = Instance.new("Folder")
	plotsFolder.Name = "Plots"
	plotsFolder.Parent = root

	local templates = ServerStorage:FindFirstChild("Voidline")
	if not templates then
		templates = Instance.new("Folder")
		templates.Name = "Voidline"
		templates.Parent = ServerStorage
	end

	for i = 1, GameConfig.PlotCount do
		local angle = ((i - 1) / GameConfig.PlotCount) * math.pi * 2
		local center = Vector3.new(
			math.cos(angle) * GameConfig.PlotRingRadius,
			0,
			math.sin(angle) * GameConfig.PlotRingRadius
		)
		local plot = Instance.new("Folder")
		plot.Name = "Plot_" .. i
		plot.Parent = plotsFolder
		plot:SetAttribute("PlotIndex", i)
		plot:SetAttribute("Claimed", false)

		part({
			Name = "StationBase",
			Parent = plot,
			Size = Vector3.new(60, 2, 60),
			CFrame = CFrame.new(center + Vector3.new(0, 1, 0)),
			Color = GameConfig.Colors.Obsidian,
			Material = Enum.Material.Metal,
		})

		local claim = part({
			Name = "ClaimPad",
			Parent = plot,
			Size = Vector3.new(12, 1, 12),
			CFrame = CFrame.new(center + Vector3.new(0, 2.2, 18)),
			Color = GameConfig.Colors.Gold,
			Material = Enum.Material.Neon,
		})
		claim:SetAttribute("PlotIndex", i)
		billboard(claim, "CLAIM STATION " .. i)

		local station = Instance.new("Folder")
		station.Name = "Station"
		station.Parent = plot

		local refinery = part({
			Name = "Refinery",
			Parent = station,
			Size = Vector3.new(14, 8, 14),
			CFrame = CFrame.new(center + Vector3.new(-16, 5, -8)),
			Color = GameConfig.Colors.Obsidian,
			Material = Enum.Material.Metal,
		})
		billboard(refinery, "STATION REFINERY")

		local grinder = part({
			Name = "GrinderCore",
			Parent = station,
			Size = Vector3.new(12, 10, 12),
			CFrame = CFrame.new(center + Vector3.new(16, 6, -8)),
			Color = Color3.fromRGB(30, 30, 40),
			Material = Enum.Material.DiamondPlate,
		})
		billboard(grinder, "GRINDER CORE")

		local upgrades = Instance.new("Folder")
		upgrades.Name = "UpgradePads"
		upgrades.Parent = station
		local upgradeDefs = {
			{ "Drill", Vector3.new(-18, 0, 8) },
			{ "Cargo", Vector3.new(-6, 0, 8) },
			{ "DroneSlot", Vector3.new(6, 0, 8) },
			{ "StationTier", Vector3.new(18, 0, 8) },
		}
		for _, def in upgradeDefs do
			local up = part({
				Name = def[1],
				Parent = upgrades,
				Size = Vector3.new(8, 1, 8),
				CFrame = CFrame.new(center + def[2] + Vector3.new(0, 2.2, 0)),
				Color = GameConfig.Colors.Gold,
				Material = Enum.Material.Neon,
			})
			up:SetAttribute("UpgradeId", def[1])
			billboard(up, def[1])
		end

		local tuner = part({
			Name = "LaserTuner",
			Parent = station,
			Size = Vector3.new(6, 1, 6),
			CFrame = CFrame.new(center + Vector3.new(0, 2.2, -18)),
			Color = Color3.fromRGB(90, 220, 255),
			Material = Enum.Material.Neon,
		})
		billboard(tuner, "LASER COLOR")

		part({
			Name = "WarpGatePlaceholder",
			Parent = station,
			Size = Vector3.new(10, 16, 2),
			CFrame = CFrame.new(center + Vector3.new(22, 9, 16)),
			Color = Color3.fromRGB(40, 40, 60),
			Transparency = 0.4,
		})

		local relics = Instance.new("Folder")
		relics.Name = "RelicPedestals"
		relics.Parent = station

		local spawn = part({
			Name = "PlayerSpawn",
			Parent = plot,
			Size = Vector3.new(6, 1, 6),
			CFrame = CFrame.new(center + Vector3.new(0, 2.5, 10)),
			Color = GameConfig.Colors.GoldBright,
			Material = Enum.Material.Neon,
			CanCollide = false,
		})
		spawn.Transparency = 0.3

		-- Personal asteroid belt
		local belt = Instance.new("Folder")
		belt.Name = "PersonalBelt"
		belt.Parent = plot
		for a = 1, 6 do
			local aAng = (a / 6) * math.pi * 2
			local aPos = center + Vector3.new(math.cos(aAng) * 36, 10, math.sin(aAng) * 36)
			local asteroid = part({
				Name = "Asteroid_" .. a,
				Parent = belt,
				Size = Vector3.new(7, 7, 7),
				CFrame = CFrame.new(aPos),
				Color = Color3.fromRGB(70, 70, 80),
				Material = Enum.Material.Rock,
				Shape = Enum.PartType.Ball,
			})
			asteroid:SetAttribute("Sector", "Starter")
			asteroid:SetAttribute("MaxHealth", 40)
			asteroid:SetAttribute("Health", 40)
			asteroid:SetAttribute("Shared", false)
			asteroid:SetAttribute("PlotIndex", i)
		end

		-- Energy bridge path (visual beam parts)
		local bridge = Instance.new("Folder")
		bridge.Name = "BridgeAttach"
		bridge.Parent = plot
		local outward = center.Unit
		local bridgeStart = center - outward * 28
		local bridgeEnd = outward * (GameConfig.HubRadius + 4)
		local mid = (bridgeStart + bridgeEnd) / 2
		local length = (bridgeEnd - bridgeStart).Magnitude
		local beam = part({
			Name = "EnergyBridge",
			Parent = bridge,
			Size = Vector3.new(4, 0.6, length),
			CFrame = CFrame.lookAt(mid, bridgeEnd) * CFrame.new(0, 2, 0),
			Color = GameConfig.Colors.Gold,
			Material = Enum.Material.Neon,
			Transparency = 0.65,
			CanCollide = false,
		})
		beam:SetAttribute("Ignited", false)
	end

	-- Spawn location for unclaimed players near monument
	local spawnLoc = Instance.new("SpawnLocation")
	spawnLoc.Name = "VoidlineSpawn"
	spawnLoc.Anchored = true
	spawnLoc.Size = Vector3.new(12, 1, 12)
	spawnLoc.CFrame = CFrame.new(-40, 1.5, 52)
	spawnLoc.Color = GameConfig.Colors.Gold
	spawnLoc.Material = Enum.Material.Neon
	spawnLoc.Duration = 0
	spawnLoc.Parent = hub

	print("[Voidline] MapBuilder: VoidlineMap ready (12 plots)")
	return root
end

return MapBuilder
