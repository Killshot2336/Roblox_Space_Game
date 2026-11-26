--!nocheck
local Harness = require("../harness/Harness")
local Expect = require("../harness/Expect")
local expect = Expect.expect

local tests = {}

local function findDescendant(root: any, name: string): any?
	if root.Name == name then
		return root
	end
	for _, child in root:GetChildren() do
		local hit = findDescendant(child, name)
		if hit then
			return hit
		end
	end
	return nil
end

tests["MapBuilder ships TikTok silhouette anchors"] = function()
	local world = Harness.new()
	world:runScript("ServerScriptService/Voidline/Services/MapBuilder")
	local MapBuilder = world:require("ServerScriptService/Voidline/Services/MapBuilder")
	local root = MapBuilder.Build()
	expect(root.Name).toBe("VoidlineMap")
	for _, partName in
		{
			"MonolithSplitSeam",
			"PlotOrbitRing",
			"MonumentHalo",
			"ClipShot_MonolithHero",
			"MonolithLeft",
			"MonolithRight",
		}
	do
		expect(findDescendant(root, partName) ~= nil).toBe(true)
	end
	local clip = findDescendant(root, "ClipShot_MonolithHero")
	expect(clip:GetAttribute("ClipShotId")).toBe("MonolithHero")
end

return tests
