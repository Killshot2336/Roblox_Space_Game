--!nocheck
-- Deterministic fake clock + task library for headless tests.
-- Time only moves when a test calls world:advance(). All yields (task.wait,
-- Signal:Wait) are coroutine based, so code under test behaves like it does
-- inside the Roblox task scheduler, just without real time passing.

local Scheduler = {}
Scheduler.__index = Scheduler

-- 2026-11-25T00:00:00Z: fixed so os.time()/os.date() are reproducible.
Scheduler.DEFAULT_EPOCH = 1795564800

function Scheduler.new(epoch: number?)
	return setmetatable({
		now = 0,
		epoch = epoch or Scheduler.DEFAULT_EPOCH,
		errors = {},
		onStep = nil,
		_timers = {},
		_deferred = {},
		_seq = 0,
		_cancelled = setmetatable({}, { __mode = "k" }),
	}, Scheduler)
end

function Scheduler:_report(thread, err)
	table.insert(self.errors, debug.traceback(thread, tostring(err)))
end

function Scheduler:_run(thread, ...)
	if self._cancelled[thread] then
		return
	end
	if coroutine.status(thread) ~= "suspended" then
		return
	end
	local ok, err = coroutine.resume(thread, ...)
	if not ok then
		self:_report(thread, err)
	end
end

local function toThread(fnOrThread)
	if type(fnOrThread) == "thread" then
		return fnOrThread
	end
	assert(type(fnOrThread) == "function", "expected function or thread")
	return coroutine.create(fnOrThread)
end

function Scheduler:spawn(fnOrThread, ...)
	local thread = toThread(fnOrThread)
	self:_run(thread, ...)
	return thread
end

function Scheduler:resume(thread, ...)
	self:_run(thread, ...)
end

function Scheduler:defer(fnOrThread, ...)
	local thread = toThread(fnOrThread)
	table.insert(self._deferred, { thread = thread, args = table.pack(...) })
	return thread
end

function Scheduler:_addTimer(at, thread, args, waitStart)
	self._seq += 1
	table.insert(self._timers, { at = at, seq = self._seq, thread = thread, args = args, waitStart = waitStart })
end

function Scheduler:delay(seconds, fnOrThread, ...)
	local thread = toThread(fnOrThread)
	self:_addTimer(self.now + math.max(0, seconds or 0), thread, table.pack(...), nil)
	return thread
end

function Scheduler:wait(seconds)
	local thread = coroutine.running()
	if not coroutine.isyieldable() then
		error("task.wait() called outside a scheduler coroutine; wrap the test body in world:run()", 2)
	end
	local duration = math.max(seconds or 0, 1 / 60)
	self:_addTimer(self.now + duration, thread, nil, self.now)
	return coroutine.yield()
end

function Scheduler:cancel(thread)
	self._cancelled[thread] = true
	for i = #self._timers, 1, -1 do
		if self._timers[i].thread == thread then
			table.remove(self._timers, i)
		end
	end
	if coroutine.status(thread) == "suspended" then
		pcall(coroutine.close, thread)
	end
end

function Scheduler:_flushDeferred()
	local guard = 0
	while #self._deferred > 0 do
		guard += 1
		if guard > 10000 then
			error("deferred task storm (>10000 re-deferrals in one step)")
		end
		local batch = self._deferred
		self._deferred = {}
		for _, job in batch do
			self:_run(job.thread, table.unpack(job.args, 1, job.args.n))
		end
	end
end

function Scheduler:_popDue(limit)
	local bestIndex, best = nil, nil
	for i, timer in self._timers do
		if timer.at <= limit + 1e-9 then
			if not best or timer.at < best.at or (timer.at == best.at and timer.seq < best.seq) then
				best = timer
				bestIndex = i
			end
		end
	end
	if bestIndex then
		table.remove(self._timers, bestIndex)
	end
	return best
end

function Scheduler:_runTimersUntil(limit)
	while true do
		local timer = self:_popDue(limit)
		if not timer then
			return
		end
		if timer.at > self.now then
			self.now = timer.at
		end
		if timer.waitStart then
			self:_run(timer.thread, self.now - timer.waitStart)
		elseif timer.args then
			self:_run(timer.thread, table.unpack(timer.args, 1, timer.args.n))
		else
			self:_run(timer.thread)
		end
		self:_flushDeferred()
	end
end

-- Advance simulated time by `seconds`, stepping Heartbeat every `step` seconds.
function Scheduler:advance(seconds, step)
	step = step or (1 / 30)
	local target = self.now + seconds
	self:_flushDeferred()
	while self.now < target - 1e-9 do
		local nextNow = math.min(target, self.now + step)
		self:_runTimersUntil(nextNow)
		local dt = nextNow - self.now
		self.now = nextNow
		if self.onStep and dt > 0 then
			self.onStep(dt)
		end
		self:_flushDeferred()
	end
end

function Scheduler:pendingTimers()
	return #self._timers
end

function Scheduler:taskLibrary()
	local scheduler = self
	return {
		spawn = function(fn, ...)
			return scheduler:spawn(fn, ...)
		end,
		defer = function(fn, ...)
			return scheduler:defer(fn, ...)
		end,
		delay = function(seconds, fn, ...)
			return scheduler:delay(seconds, fn, ...)
		end,
		wait = function(seconds)
			return scheduler:wait(seconds)
		end,
		cancel = function(thread)
			scheduler:cancel(thread)
		end,
		synchronize = function() end,
		desynchronize = function() end,
	}
end

function Scheduler:osLibrary()
	local scheduler = self
	local realOs = os
	return setmetatable({
		clock = function()
			return scheduler.now
		end,
		time = function(t)
			if t ~= nil then
				return realOs.time(t)
			end
			return scheduler.epoch + math.floor(scheduler.now)
		end,
		date = function(fmt, t)
			return realOs.date(fmt, t or (scheduler.epoch + math.floor(scheduler.now)))
		end,
		difftime = realOs.difftime,
	}, { __index = realOs })
end

return Scheduler
