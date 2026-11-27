--!nocheck
local Harness = require("../harness/Harness")
local Expect = require("../harness/Expect")
local expect = Expect.expect

local tests = {}

tests["VisualBible ships obsidian-gold tokens and lighting numbers"] = function()
	local world = Harness.new()
	local VisualBibleConfig = world:require("ReplicatedStorage/Voidline/Config/VisualBibleConfig")
	expect(VisualBibleConfig.Palette.Gold).toBeTruthy()
	expect(VisualBibleConfig.Palette.Obsidian).toBeTruthy()
	expect(VisualBibleConfig.Lighting.Bloom.Intensity).toBeGreaterThan(0.25)
	expect(VisualBibleConfig.Lighting.Bloom.Intensity).toBeLessThan(0.45)
	expect(VisualBibleConfig.Lighting.HubFill.AvatarFillBrightness).toBeGreaterThan(0.3)
	expect(VisualBibleConfig.Lighting.Atmosphere.Density).toBeGreaterThan(0.2)
	expect(VisualBibleConfig.HubDeck.TileStuds).toBeGreaterThan(4)
	expect(VisualBibleConfig.MonolithSplit.GapStuds).toBeGreaterThan(4)
	expect(VisualBibleConfig.SovereignHalo.CameraFovAdd).toBeGreaterThan(0)
end

return tests
