--!nocheck
-- Locked-spec economy invariants (GAME_DESIGN.md §4, owner brief tutorial).
local Harness = require("../harness/Harness")
local Expect = require("../harness/Expect")
local expect = Expect.expect

local tests = {}

local function load()
	local world = Harness.new()
	return {
		world = world,
		EconomyConfig = world:require("ReplicatedStorage/Voidline/Config/EconomyConfig"),
		GameConfig = world:require("ReplicatedStorage/Voidline/Config/GameConfig"),
		OreMath = world:require("ReplicatedStorage/Voidline/Modules/OreMath"),
	}
end

tests["starter cargo holds 10 ore and sells for 30 credits"] = function()
	local m = load()
	expect(m.EconomyConfig.StarterCargoCapacity).toBe(10)
	expect(m.OreMath.CargoCap(1)).toBe(10)
	expect(m.OreMath.SellValue(10, "Starter", 1, false)).toBe(30)
	expect(m.EconomyConfig.FirstSellCredits).toBe(30)
end

tests["first three upgrades cost 20 / 35 / 50"] = function()
	local m = load()
	expect(m.EconomyConfig.DrillCost(1)).toBe(20)
	expect(m.EconomyConfig.CargoCost(1)).toBe(35)
	expect(m.EconomyConfig.DroneSlotCost(1)).toBe(50)
	local costs = {}
	for _, upgrade in m.EconomyConfig.StarterUpgrades do
		costs[upgrade.Id] = upgrade.Cost
	end
	expect(costs.Drill).toBe(20)
	expect(costs.Cargo).toBe(35)
	expect(costs.Drone2).toBe(50)
end

tests["tutorial completion awards exactly +100 credits"] = function()
	local m = load()
	expect(m.GameConfig.TutorialCompleteBonusCredits).toBe(100)
end

tests["upgrade cost curves are finite and strictly increasing"] = function()
	local m = load()
	for _, curve in { "DrillCost", "CargoCost", "DroneSlotCost", "StationTierCost" } do
		local fn = m.EconomyConfig[curve]
		local previous = -1
		for level = 1, 40 do
			local cost = fn(level)
			expect(cost).toBeFinite()
			expect(cost).toBeGreaterThan(previous)
			previous = cost
		end
	end
end

tests["sell value scales with credit multiplier and 2x pass"] = function()
	local m = load()
	expect(m.OreMath.SellValue(10, "Starter", 1.25, false)).toBe(37)
	expect(m.OreMath.SellValue(10, "Starter", 1, true)).toBe(60)
	expect(m.OreMath.SellValue(0, "Starter", 1, true)).toBe(0)
end

return tests
