--!nocheck
-- Store invariants: 10 passes at the owner's Robux prices, Token prices 15-20%
-- cheaper, Robux-only summons, zero shard packs, launch codes present.
local Harness = require("../harness/Harness")
local Expect = require("../harness/Expect")
local expect = Expect.expect

local tests = {}

local EXPECTED_PASSES = {
	StarterBundle = 79,
	AutoSellWarpLink = 249,
	Credits2x = 449,
	ShardRelicLuck2x = 499,
	DroneSlots3 = 599,
	MegaSwarm5 = 999,
	LaserOverclock = 349,
	DeepSpaceWarpPass = 399,
	VoidSovereignVIP = 899,
	EternalArchitect = 1499,
}

tests["exactly ten passes at the brief's Robux prices"] = function()
	local world = Harness.new()
	local MonetizationConfig = world:require("ReplicatedStorage/Voidline/Config/MonetizationConfig")
	local count = 0
	for _, pass in MonetizationConfig.Passes do
		count += 1
		expect(EXPECTED_PASSES[pass.Id]).toBe(pass.Robux)
	end
	expect(count).toBe(10)
end

tests["token prices are 15-20% cheaper than Robux"] = function()
	local world = Harness.new()
	local MonetizationConfig = world:require("ReplicatedStorage/Voidline/Config/MonetizationConfig")
	for _, pass in MonetizationConfig.Passes do
		local discount = 1 - pass.Tokens / pass.Robux
		expect(discount).toBeGreaterThanOrEqual(0.15)
		expect(discount).toBeLessThanOrEqual(0.20)
	end
end

tests["dev products are the two Robux-only summons and no shard packs"] = function()
	local world = Harness.new()
	local MonetizationConfig = world:require("ReplicatedStorage/Voidline/Config/MonetizationConfig")
	local prices = {}
	for _, product in MonetizationConfig.DevProducts do
		prices[product.Id] = product.Robux
		expect(product.Tokens).toBeNil()
		expect(string.find(string.lower(product.Id), "pack", 1, true)).toBeNil()
	end
	expect(prices.SummonVoidStarfall).toBe(199)
	expect(prices.ServerLuckSurge).toBe(149)
	local n = 0
	for _ in prices do
		n += 1
	end
	expect(n).toBe(2)
end

tests["game pass and summon product ids are wired from Creator Dashboard"] = function()
	local world = Harness.new()
	local MonetizationConfig = world:require("ReplicatedStorage/Voidline/Config/MonetizationConfig")
	local seenPasses = {}
	for _, pass in MonetizationConfig.Passes do
		expect(pass.GamePassId).toBeGreaterThan(0)
		expect(seenPasses[pass.GamePassId]).toBeNil()
		seenPasses[pass.GamePassId] = true
		expect(MonetizationConfig.PassByGamePassId(pass.GamePassId)).toBe(pass)
	end
	local byId = {}
	for _, product in MonetizationConfig.DevProducts do
		expect(product.ProductId).toBeGreaterThan(0)
		expect(byId[product.ProductId]).toBeNil()
		byId[product.ProductId] = product.Id
		expect(MonetizationConfig.ProductByProductId(product.ProductId)).toBe(product)
	end
	expect(byId[3736719622]).toBe("SummonVoidStarfall")
	expect(byId[3736719712]).toBe("ServerLuckSurge")
	expect(MonetizationConfig.PassByGamePassId(0)).toBeNil()
	expect(MonetizationConfig.ProductByProductId(0)).toBeNil()
end

tests["launch codes VOIDLINE, KILLSHOT, LAUNCH are one-time"] = function()
	local world = Harness.new()
	local CodesConfig = world:require("ReplicatedStorage/Voidline/Config/CodesConfig")
	for _, code in { "VOIDLINE", "KILLSHOT", "LAUNCH" } do
		local reward = CodesConfig.Codes[code]
		expect(reward ~= nil).toBe(true)
		expect(reward.OneTime).toBe(true)
	end
end

return tests
