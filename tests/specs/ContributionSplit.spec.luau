--!nocheck
-- Soft-contest split (§6): >=5% qualifies, #1 gets the 40% pool plus their
-- proportional share of the 60% pool, payouts never exceed the pool.
local Harness = require("../harness/Harness")
local Expect = require("../harness/Expect")
local expect = Expect.expect

local tests = {}

local function load()
	local world = Harness.new()
	return world:require("ReplicatedStorage/Voidline/Modules/ContributionSplit")
end

local function sum(shares)
	local total = 0
	for _, v in shares do
		total += v
	end
	return total
end

tests["single contributor takes the whole pool"] = function()
	local Split = load()
	local shares = Split.Compute({ [1] = 500 })
	expect(shares[1]).toBeCloseTo(1, 1e-12)
end

tests["top gets 40% plus proportional share of 60%"] = function()
	local Split = load()
	local shares = Split.Compute({ [1] = 600, [2] = 300, [3] = 100 })
	expect(shares[1]).toBeCloseTo(0.40 + 0.60 * 0.6, 1e-12)
	expect(shares[2]).toBeCloseTo(0.60 * 0.3, 1e-12)
	expect(shares[3]).toBeCloseTo(0.60 * 0.1, 1e-12)
	expect(sum(shares)).toBeCloseTo(1, 1e-12)
end

tests["exactly 5% qualifies and just under does not"] = function()
	local Split = load()
	local shares = Split.Compute({ [1] = 95, [2] = 5 })
	expect(shares[2] ~= nil).toBe(true)
	local shares2 = Split.Compute({ [1] = 95.01, [2] = 4.99 })
	expect(shares2[2]).toBeNil()
	-- Non-qualifier damage is excluded from the proportional pool.
	expect(shares2[1]).toBeCloseTo(1, 1e-12)
end

tests["zero, empty, negative and non-finite damage never produce NaN"] = function()
	local Split = load()
	expect(next(Split.Compute({}))).toBeNil()
	expect(next(Split.Compute({ [1] = 0, [2] = 0 }))).toBeNil()
	local negative = Split.Compute({ [1] = -50, [2] = 10 })
	expect(negative[1]).toBeNil()
	expect(negative[2]).toBeCloseTo(1, 1e-12)
	local weird = Split.Compute({ [1] = 0 / 0, [2] = math.huge, [3] = 40, [4] = 10 })
	for userId, share in weird do
		expect(share).toBeFinite()
		expect(share).toBeGreaterThanOrEqual(0)
		expect(userId == 3 or userId == 4).toBe(true)
	end
	expect(sum(weird)).toBeCloseTo(1, 1e-12)
end

tests["tiny damage values still split cleanly"] = function()
	local Split = load()
	local shares = Split.Compute({ [1] = 1e-300, [2] = 1e-300 })
	for _, share in shares do
		expect(share).toBeFinite()
	end
	expect(sum(shares)).toBeCloseTo(1, 1e-12)
end

tests["ties for top contributor resolve deterministically to the lowest UserId"] = function()
	local Split = load()
	for _ = 1, 20 do
		local shares = Split.Compute({ [900] = 50, [12] = 50, [345] = 50 })
		expect(shares[12]).toBeCloseTo(0.4 + 0.6 / 3, 1e-12)
		expect(shares[345]).toBeCloseTo(0.6 / 3, 1e-12)
		expect(shares[900]).toBeCloseTo(0.6 / 3, 1e-12)
	end
end

tests["TopContributor reports the deterministic #1"] = function()
	local Split = load()
	local topId = Split.TopContributor({ [7] = 10, [3] = 30, [9] = 30 })
	expect(topId).toBe(3)
end

return tests
