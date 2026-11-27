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

tests["hub ships procedural plated deck tiles"] = function()
	local world = Harness.new()
	world:runScript("ServerScriptService/Voidline/Services/MapBuilder")
	local MapBuilder = world:require("ServerScriptService/Voidline/Services/MapBuilder")
	local root = MapBuilder.Build()
	local deck = findDescendant(root, "HubPlatedDeck")
	expect(deck ~= nil).toBe(true)
	expect((deck :: any):GetAttribute("TileCount")).toBeGreaterThan(40)
	expect(findDescendant(root, "HubTrimRing1") ~= nil).toBe(true)
	expect(findDescendant(root, "DeckTileInset") ~= nil).toBe(true)
end

tests["walk surfaces use matte decks not neon slabs"] = function()
	local world = Harness.new()
	world:runScript("ServerScriptService/Voidline/Services/MapBuilder")
	local MapBuilder = world:require("ServerScriptService/Voidline/Services/MapBuilder")
	local root = MapBuilder.Build()
	local neonWalk = 0
	local function walk(node: any)
		if node.ClassName == "BasePart" and node:GetAttribute("Walkable") == true then
			if node.Material == Enum.Material.Neon then
				neonWalk += 1
			end
		end
		for _, child in node:GetChildren() do
			walk(child)
		end
	end
	walk(root)
	expect(neonWalk).toBe(0)
	local plot = findDescendant(root, "Plot_1")
	local bridge = plot and plot:FindFirstChild("EnergyBridge")
	if bridge then
		for _, child in bridge:GetChildren() do
			if child.ClassName == "BasePart" and string.sub(child.Name, 1, 7) == "Segment" then
				expect(child.Material ~= Enum.Material.Neon).toBe(true)
			end
		end
	end
	expect(findDescendant(root, "HubCathedralDressing") ~= nil).toBe(true)
	expect(findDescendant(root, "HubColonnadeRing") ~= nil).toBe(true)
	expect(findDescendant(root, "HubUpperDecks") ~= nil).toBe(true)
	expect(findDescendant(root, "HubLightWell1") ~= nil).toBe(true)
	expect(findDescendant(root, "HubCathedralArches") ~= nil).toBe(true)
	expect(findDescendant(root, "ArchLinte1") ~= nil).toBe(true)
	expect(findDescendant(root, "HubFillLights") ~= nil).toBe(true)
	expect(findDescendant(root, "BrokenCrownShard") ~= nil).toBe(true)
	local asteroids = findDescendant(root, "DeepSpaceAsteroidField")
	expect(asteroids ~= nil).toBe(true)
	expect((asteroids :: any):GetAttribute("AsteroidCount")).toBeGreaterThan(60)
	expect(findDescendant(root, "DeepSpaceParallax") ~= nil).toBe(true)
	expect(findDescendant(root, "PlotMachineShell") ~= nil).toBe(true)
	expect(findDescendant(root, "BridgeRib1_1") ~= nil).toBe(true)
end

tests["walkable map surfaces have solid collision under neon visuals"] = function()
	local world = Harness.new()
	world:runScript("ServerScriptService/Voidline/Services/MapBuilder")
	local MapBuilder = world:require("ServerScriptService/Voidline/Services/MapBuilder")
	local HubLayout = world:require("ReplicatedStorage/Voidline/Modules/HubLayout")
	local PlotLayout = world:require("ReplicatedStorage/Voidline/Modules/PlotLayout")
	local root = MapBuilder.Build()
	local hubCollision = findDescendant(root, "HubWalkCollision")
	expect(hubCollision ~= nil).toBe(true)
	expect(hubCollision.CanCollide).toBe(true)
	expect(hubCollision:GetAttribute("Walkable")).toBe(true)
	expect(string.find(tostring(hubCollision.Material), "Neon") == nil).toBe(true)
	local hubTop = hubCollision.Position.Y + hubCollision.Size.Y / 2
	expect(math.abs(hubTop - HubLayout.HubSize.Y / 2) < 0.05).toBe(true)

	local plot = findDescendant(root, "Plot_1")
	local base = plot and plot:FindFirstChild("StationBase")
	expect(base ~= nil).toBe(true)
	expect(base.CanCollide).toBe(true)
	expect(base:GetAttribute("Walkable")).toBe(true)

	local bridge = plot and plot:FindFirstChild("EnergyBridge")
	expect(bridge ~= nil).toBe(true)
	local walkPlates = 0
	for _, child in bridge:GetChildren() do
		if string.sub(child.Name, 1, 9) == "WalkPlate" then
			walkPlates += 1
			expect(child.CanCollide).toBe(true)
			expect(child:GetAttribute("Walkable")).toBe(true)
		elseif child.ClassName == "BasePart" and string.sub(child.Name, 1, 7) == "Segment" then
			expect(child.CanCollide).toBe(false)
			expect(child.Material ~= Enum.Material.Neon).toBe(true)
		end
	end
	expect(walkPlates).toBe(PlotLayout.BridgeSegments)

	expect(findDescendant(root, "HubSilhouetteRing")).toBeNil()
	expect(findDescendant(root, "HubDeckLipNorth") ~= nil).toBe(true)
	expect(findDescendant(root, "VoidStarDressing") ~= nil).toBe(true)
	expect(findDescendant(root, "MonolithHeroKey") ~= nil).toBe(true)
end

tests["hub has no oversized neon gold seams"] = function()
	local world = Harness.new()
	world:runScript("ServerScriptService/Voidline/Services/MapBuilder")
	local MapBuilder = world:require("ServerScriptService/Voidline/Services/MapBuilder")
	local root = MapBuilder.Build()
	local offenders = 0
	local function walk(node: any)
		if node.ClassName == "BasePart" and node:GetAttribute("GoldSeam") == true then
			if node.Material == Enum.Material.Neon then
				local maxDim = math.max(node.Size.X, node.Size.Y, node.Size.Z)
				if maxDim > 2.5 then
					offenders += 1
				end
			end
		end
		for _, child in node:GetChildren() do
			walk(child)
		end
	end
	walk(root)
	expect(offenders).toBe(0)
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
