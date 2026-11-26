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
	expect(type(clip:GetAttribute("ClipHint"))).toBe("string")
end

tests["hub world labels are near-only (no billboard sludge)"] = function()
	local world = Harness.new()
	world:runScript("ServerScriptService/Voidline/Services/MapBuilder")
	local MapBuilder = world:require("ServerScriptService/Voidline/Services/MapBuilder")
	local HubLayout = world:require("ReplicatedStorage/Voidline/Modules/HubLayout")
	local root = MapBuilder.Build()
	local function maxLabelDistance(instance: any): number
		local best = 0
		local function walk(node: any)
			if node.ClassName == "BillboardGui" and node.Name == "Label" then
				local d = node.MaxDistance
				if type(d) == "number" and d > best then
					best = d
				end
			end
			for _, child in node:GetChildren() do
				walk(child)
			end
		end
		walk(instance)
		return best
	end
	expect(maxLabelDistance(root)).toBeLessThanOrEqual(48)
	expect(HubLayout.BoardRadius).toBeGreaterThanOrEqual(48)
	local forge = findDescendant(root, "ForgePad")
	local forgeLabel = forge and forge:FindFirstChild("Label")
	expect(forgeLabel ~= nil).toBe(true)
	expect(forgeLabel.MaxDistance).toBeLessThanOrEqual(18)
end

return tests
