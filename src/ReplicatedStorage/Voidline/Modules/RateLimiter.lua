local RateLimiter = {}
RateLimiter.__index = RateLimiter

function RateLimiter.new(minInterval: number)
	return setmetatable({
		_minInterval = minInterval,
		_last = {} :: { [number]: number },
	}, RateLimiter)
end

function RateLimiter:Allow(userId: number): boolean
	local now = os.clock()
	local last = self._last[userId]
	if last and (now - last) < self._minInterval then
		return false
	end
	self._last[userId] = now
	return true
end

function RateLimiter:Clear(userId: number)
	self._last[userId] = nil
end

return RateLimiter
