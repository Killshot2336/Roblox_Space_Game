--!nocheck
local Harness = require("../harness/Harness")
local Expect = require("../harness/Expect")
local expect = Expect.expect

local tests = {}

tests["allows once per interval per key"] = function()
	local world = Harness.new()
	local RateLimiter = world:require("ReplicatedStorage/Voidline/Modules/RateLimiter")
	local limiter = RateLimiter.new(0.5)
	expect(limiter:Allow(1)).toBe(true)
	expect(limiter:Allow(1)).toBe(false)
	world:advance(0.49)
	expect(limiter:Allow(1)).toBe(false)
	world:advance(0.02)
	expect(limiter:Allow(1)).toBe(true)
end

tests["keys are independent and Clear resets a key"] = function()
	local world = Harness.new()
	local RateLimiter = world:require("ReplicatedStorage/Voidline/Modules/RateLimiter")
	local limiter = RateLimiter.new(1)
	expect(limiter:Allow(1)).toBe(true)
	expect(limiter:Allow(2)).toBe(true)
	expect(limiter:Allow(1)).toBe(false)
	limiter:Clear(1)
	expect(limiter:Allow(1)).toBe(true)
end

tests["burst capacity allows short bursts then throttles to the refill rate"] = function()
	local world = Harness.new()
	local RateLimiter = world:require("ReplicatedStorage/Voidline/Modules/RateLimiter")
	local limiter = RateLimiter.new(0.25, 4)
	local allowed = 0
	for _ = 1, 10 do
		if limiter:Allow(1) then
			allowed += 1
		end
	end
	expect(allowed).toBe(4)
	world:advance(0.26)
	expect(limiter:Allow(1)).toBe(true)
	expect(limiter:Allow(1)).toBe(false)
	-- Over 10 simulated seconds a spammer gets at most burst + 10/0.25 calls.
	local total = 0
	for _ = 1, 1000 do
		world:advance(0.01)
		if limiter:Allow(1) then
			total += 1
		end
	end
	expect(total).toBeLessThanOrEqual(41)
end

return tests
