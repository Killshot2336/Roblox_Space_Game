-- Central sound placeholders for the audio pass. Leave AssetId as "" until
-- the owner drops real rbxassetid values in from the Creator Dashboard / library.
-- AudioController skips any entry with an empty AssetId (no errors in Studio).
local AudioConfig = {
	MasterVolume = 1,
	Sounds = {
		Mine = { AssetId = "", Volume = 0.35 },
		Sell = { AssetId = "", Volume = 0.55 },
		Upgrade = { AssetId = "", Volume = 0.5 },
		TowArrive = { AssetId = "", Volume = 0.45 },
		BridgeIgnite = { AssetId = "", Volume = 0.7 },
		Starfall = { AssetId = "", Volume = 0.65 },
		Rebirth = { AssetId = "", Volume = 0.6 },
		StoreSuccess = { AssetId = "", Volume = 0.5 },
	},
}

return AudioConfig
