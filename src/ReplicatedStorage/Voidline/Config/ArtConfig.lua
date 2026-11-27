--!strict
-- Single source of truth for uploaded mesh/texture/decal IDs and UI icon assets.
-- Leave AssetId / MeshId / TextureId as 0 until Studio upload; code keeps procedural fallbacks.
-- Paste rbxassetid://… from Creator Dashboard after each upload (see ART_PIPELINE.md).
local ArtConfig = {
	Version = 1,
	Meshes = {
		MonolithHalf = {
			MeshId = 0,
			TextureId = 0,
			Scale = Vector3.new(1, 1, 1),
			Notes = "Hero split monolith slab; one mesh mirrored for Left/Right.",
		},
		MonolithCrownShard = {
			MeshId = 0,
			TextureId = 0,
			Scale = Vector3.new(1, 1, 1),
			Notes = "Broken crown detrité on MonolithRight.",
		},
		HubColonnade = {
			MeshId = 0,
			TextureId = 0,
			Scale = Vector3.new(1, 1, 1),
			Notes = "Obsidian column segment (instanced around rim).",
		},
		GrinderCore = {
			MeshId = 0,
			TextureId = 0,
			Scale = Vector3.new(1, 1, 1),
			Notes = "Plot grinder hero volume.",
		},
		RefineryStack = {
			MeshId = 0,
			TextureId = 0,
			Scale = Vector3.new(1, 1, 1),
			Notes = "Refinery tower + pipe bundle.",
		},
		EnergyBridgeSegment = {
			MeshId = 0,
			TextureId = 0,
			Scale = Vector3.new(1, 1, 1),
			Notes = "Bridge deck rib (visual only; WalkPlate keeps collision).",
		},
		DeepSpaceAsteroid = {
			MeshId = 0,
			TextureId = 0,
			Scale = Vector3.new(1, 1, 1),
			Notes = "Low-poly asteroid chunk (3 variants).",
		},
	},
	Textures = {
		ObsidianPlate = { TextureId = 0, Notes = "Hub deck tile albedo." },
		GoldSeam = { TextureId = 0, Notes = "Trim/seam mask; use with Foil/Metal." },
		BridgeSpine = { TextureId = 0, Notes = "Energy bridge matte deck." },
	},
	Decals = {
		VoidlineSigil = { DecalId = 0, Notes = "Floor sigil under Monolith (subtle)." },
		PlotSectorMark = { DecalId = 0, Notes = "Plot station floor sector glyph." },
	},
	UI = {
		-- rbxasset:// placeholders until Creator upload; Hotbar/HUD resolve via ArtResolve.
		FallbackImage = "rbxasset://textures/ui/GuiImagePlaceholder.png",
		Hotbar = {
			Upgrade = { AssetId = 0, Label = "UPGRADE" },
			Formation1 = { AssetId = 0, Label = "ORBIT" },
			Formation2 = { AssetId = 0, Label = "WEDGE" },
			Formation3 = { AssetId = 0, Label = "CROWN" },
			Store = { AssetId = 0, Label = "STORE" },
			Menu = { AssetId = 0, Label = "CODEX" },
			Home = { AssetId = 0, Label = "HOME" },
			Sell = { AssetId = 0, Label = "SELL" },
			Clip = { AssetId = 0, Label = "CLIP" },
		},
		Hud = {
			Credits = { AssetId = 0 },
			Ore = { AssetId = 0 },
			Shards = { AssetId = 0 },
			Tokens = { AssetId = 0 },
		},
		Store = {
			GamePass = { AssetId = 0 },
			DevProduct = { AssetId = 0 },
			Summon = { AssetId = 0 },
		},
	},
}

return ArtConfig
