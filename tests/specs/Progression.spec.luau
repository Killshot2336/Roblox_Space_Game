--!nocheck
-- Rebirth (§8) and Artifact Forge (§9) invariants.
local Harness = require("../harness/Harness")
local Expect = require("../harness/Expect")
local expect = Expect.expect

local tests = {}

tests["rebirth multiplier is 1 + 0.25 x R"] = function()
	local world = Harness.new()
	local RebirthConfig = world:require("ReplicatedStorage/Voidline/Config/RebirthConfig")
	for r = 0, 200 do
		expect(RebirthConfig.CreditMultiplier(r)).toBeCloseTo(1 + 0.25 * r, 1e-9)
	end
	expect(RebirthConfig.RequiredStationTier).toBe(10)
end

tests["rebirth shard payout is 10 + 5 x R"] = function()
	local world = Harness.new()
	local RebirthConfig = world:require("ReplicatedStorage/Voidline/Config/RebirthConfig")
	for r = 1, 200 do
		expect(RebirthConfig.ShardPayout(r)).toBe(10 + 5 * r)
	end
end

tests["forge converts 25 shards to 1 artifact worth 40 tokens"] = function()
	local world = Harness.new()
	local ForgeConfig = world:require("ReplicatedStorage/Voidline/Config/ForgeConfig")
	expect(ForgeConfig.ShardsPerArtifact).toBe(25)
	expect(ForgeConfig.TokensPerArtifact).toBe(40)
	expect(ForgeConfig.ForgeDurationSeconds).toBe(10)
end

tests["forge soft-cools after 500 tokens per day without hard locking"] = function()
	local world = Harness.new()
	local ForgeConfig = world:require("ReplicatedStorage/Voidline/Config/ForgeConfig")
	expect(ForgeConfig.DailyTokenSoftCap).toBe(500)
	expect(ForgeConfig.CoolingMultiplier).toBeGreaterThan(0)
	expect(ForgeConfig.CoolingMultiplier).toBeLessThan(1)
end

return tests
