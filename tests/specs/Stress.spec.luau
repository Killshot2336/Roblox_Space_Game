--!nocheck
-- Randomized stress tests (seeded, reproducible).
local Harness = require("../harness/Harness")
local Expect = require("../harness/Expect")
local expect = Expect.expect

local tests = {}

local function lcg(seed)
	local state = seed
	return function()
		state = (state * 1103515245 + 12345) % 2147483648
		return state / 2147483648
	end
end

tests["10,000 random contest splits keep every invariant"] = function()
	local world = Harness.new()
	local Split = world:require("ReplicatedStorage/Voidline/Modules/ContributionSplit")
	local Config = world:require("ReplicatedStorage/Voidline/Config/SoftContestConfig")
	local rand = lcg(20261125)
	local checked = 0
	for _ = 1, 10000 do
		local count = 1 + math.floor(rand() * 12)
		local damage = {}
		local cleanTotal = 0
		for i = 1, count do
			local roll = rand()
			local value
			if roll < 0.05 then
				value = 0
			elseif roll < 0.08 then
				value = rand() * 1e-12
			elseif roll < 0.10 then
				value = -rand() * 100
			elseif roll < 0.11 then
				value = 0 / 0
			elseif roll < 0.12 then
				value = math.huge
			elseif roll < 0.20 then
				value = rand() * 1e9
			else
				value = rand() * 5000
			end
			local userId = 1000 + i * 7
			damage[userId] = value
			if value == value and value > 0 and value < math.huge then
				cleanTotal += value
			end
		end
		local shares = Split.Compute(damage)
		local total = 0
		local topShare = 0
		local any = false
		for userId, share in shares do
			any = true
			expect(share).toBeFinite()
			expect(share).toBeGreaterThanOrEqual(0)
			local dmg = damage[userId]
			expect(dmg == dmg and dmg > 0 and dmg < math.huge).toBe(true)
			expect(dmg / cleanTotal).toBeGreaterThanOrEqual(Config.MinDamagePercent - 1e-12)
			total += share
			if share > topShare then
				topShare = share
			end
		end
		expect(total).toBeLessThanOrEqual(1 + 1e-9)
		if any then
			expect(total).toBeCloseTo(1, 1e-9)
			expect(topShare).toBeGreaterThanOrEqual(Config.TopContributorPool)
		else
			expect(cleanTotal == 0).toBe(true)
		end
		checked += 1
	end
	expect(checked).toBe(10000)
end

tests["integer payout rounding never exceeds the pool"] = function()
	local world = Harness.new()
	local Split = world:require("ReplicatedStorage/Voidline/Modules/ContributionSplit")
	local rand = lcg(42)
	for _ = 1, 2000 do
		local damage = {}
		for i = 1, 1 + math.floor(rand() * 12) do
			damage[i] = rand() * 1000
		end
		local pool = math.floor(rand() * 500)
		local payouts = Split.Allocate(Split.Compute(damage), pool)
		local paid = 0
		for _, amount in payouts do
			expect(amount).toBe(math.floor(amount))
			expect(amount).toBeGreaterThanOrEqual(0)
			paid += amount
		end
		expect(paid).toBeLessThanOrEqual(pool)
	end
end

return tests
