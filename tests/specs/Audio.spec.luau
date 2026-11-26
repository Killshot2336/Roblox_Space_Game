--!nocheck
-- AudioConfig must ship playable engine paths (no empty AssetIds for core SFX).
local Harness = require("../harness/Harness")
local Expect = require("../harness/Expect")
local expect = Expect.expect

local tests = {}

local REQUIRED = {
	"Mine",
	"Sell",
	"Upgrade",
	"TowArrive",
	"BridgeIgnite",
	"Starfall",
	"Rebirth",
	"StoreSuccess",
	"Click",
	"Formation",
	"Warp",
	"Forge",
	"Ambient",
}

tests["AudioConfig core SFX use non-empty rbxasset paths"] = function()
	local world = Harness.new()
	local AudioConfig = world:require("ReplicatedStorage/Voidline/Config/AudioConfig")
	expect(AudioConfig.MasterVolume).toBeGreaterThan(0)
	for _, key in REQUIRED do
		local spec = AudioConfig.Sounds[key]
		expect(spec).toBeTruthy()
		expect(type(spec.AssetId)).toBe("string")
		expect(#spec.AssetId > 0).toBe(true)
		expect(string.find(spec.AssetId, "rbxasset") ~= nil).toBe(true)
	end
	expect(AudioConfig.Sounds.Ambient.Loop).toBe(true)
end

return tests
