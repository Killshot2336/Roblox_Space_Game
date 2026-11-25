--!nocheck
-- Minimal RBXScriptSignal double used by the headless harness.

local Connection = {}
Connection.__index = Connection

function Connection:Disconnect()
	self.Connected = false
end

local Signal = {}
Signal.__index = Signal

function Signal.new(scheduler)
	return setmetatable({ _connections = {}, _scheduler = scheduler, _waiting = {} }, Signal)
end

function Signal:Connect(fn)
	assert(type(fn) == "function", "Signal:Connect expects a function")
	local connection = setmetatable({ Connected = true, _fn = fn }, Connection)
	table.insert(self._connections, connection)
	return connection
end

function Signal:Once(fn)
	local connection
	connection = self:Connect(function(...)
		connection:Disconnect()
		fn(...)
	end)
	return connection
end

function Signal:Fire(...)
	for _, connection in table.clone(self._connections) do
		if connection.Connected then
			if self._scheduler then
				self._scheduler:spawn(connection._fn, ...)
			else
				connection._fn(...)
			end
		end
	end
	local waiting = self._waiting
	self._waiting = {}
	for _, thread in waiting do
		if self._scheduler then
			self._scheduler:resume(thread, ...)
		end
	end
end

function Signal:Wait()
	assert(self._scheduler, "Signal:Wait requires a scheduler")
	table.insert(self._waiting, coroutine.running())
	return coroutine.yield()
end

function Signal:ConnectionCount()
	local n = 0
	for _, connection in self._connections do
		if connection.Connected then
			n += 1
		end
	end
	return n
end

return Signal
