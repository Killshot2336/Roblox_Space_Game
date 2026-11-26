--!strict
-- Engine-bundled Roblox sounds (rbxasset://). These play in Studio/live without
-- Creator Dashboard uploads. Optional: replace any AssetId with your own
-- rbxassetid://… from the Toolbox / uploaded audio.
local AudioConfig = {
	MasterVolume = 1,
	AmbientVolume = 0.08,
	Sounds = {
		-- Core loop
		Mine = { AssetId = "rbxasset://sounds/hit.mp3", Volume = 0.32 },
		Sell = { AssetId = "rbxasset://sounds/electronicpingshort.mp3", Volume = 0.5 },
		Upgrade = { AssetId = "rbxasset://sounds/button.mp3", Volume = 0.48 },
		TowArrive = { AssetId = "rbxasset://sounds/Kerplunk.mp3", Volume = 0.42 },
		BridgeIgnite = { AssetId = "rbxasset://sounds/flashbulb.mp3", Volume = 0.65 },
		Starfall = { AssetId = "rbxasset://sounds/collide.mp3", Volume = 0.55 },
		MonolithSplit = { AssetId = "rbxasset://sounds/impact_water.mp3", Volume = 0.58 },
		Rebirth = { AssetId = "rbxasset://sounds/victory.mp3", Volume = 0.55 },
		StoreSuccess = { AssetId = "rbxasset://sounds/electronicpingshort.mp3", Volume = 0.45 },
		-- Extra juice
		Click = { AssetId = "rbxasset://sounds/switch.mp3", Volume = 0.28 },
		Formation = { AssetId = "rbxasset://sounds/snap.mp3", Volume = 0.35 },
		Warp = { AssetId = "rbxasset://sounds/swordlunge.mp3", Volume = 0.4 },
		Forge = { AssetId = "rbxasset://sounds/bass.mp3", Volume = 0.5 },
		Achievement = { AssetId = "rbxasset://sounds/victory.mp3", Volume = 0.4 },
		Warn = { AssetId = "rbxasset://sounds/button.mp3", Volume = 0.3 },
		Relic = { AssetId = "rbxasset://sounds/flashbulb.mp3", Volume = 0.45 },
		Codex = { AssetId = "rbxasset://sounds/electronicpingshort.mp3", Volume = 0.3 },
		-- Soft Deep Space bed (looped quietly)
		Ambient = { AssetId = "rbxasset://sounds/bass.mp3", Volume = 0.12, Loop = true },
	},
}

return AudioConfig
