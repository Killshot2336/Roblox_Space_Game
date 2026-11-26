--!strict
-- Per-key token bucket. `minInterval` is the steady-state spacing between
-- allowed calls; `burst` (default 1) is how many calls may arrive at once.
-- RateLimiter.new(0.5) keeps the original "once per 0.5s" behaviour.
local RateLimiter = {}
RateLimiter.__index = RateLimiter

type Bucket = { tokens: number, stamp: number }

export type RateLimiter = typeof(setmetatable(
	{} :: {
		_interval: number,
		_burst: number,
		_buckets: { [any]: Bucket },
	},
	RateLimiter
))

function RateLimiter.new(minInterval: number, burst: number?): RateLimiter
	assert(type(minInterval) == "number" and minInterval > 0, "RateLimiter.new: minInterval must be > 0")
	return setmetatable({
		_interval = minInterval,
		_burst = math.max(1, burst or 1),
		_buckets = {},
	}, RateLimiter)
end

function RateLimiter.Allow(self: RateLimiter, key: any): boolean
	local now = os.clock()
	local bucket = self._buckets[key]
	if bucket == nil then
		bucket = { tokens = self._burst, stamp = now }
		self._buckets[key] = bucket
	else
		local refill = (now - bucket.stamp) / self._interval
		bucket.tokens = math.min(self._burst, bucket.tokens + math.max(0, refill))
		bucket.stamp = now
	end
	if bucket.tokens >= 1 then
		bucket.tokens -= 1
		return true
	end
	return false
end

function RateLimiter.Clear(self: RateLimiter, key: any)
	self._buckets[key] = nil
end

return RateLimiter
