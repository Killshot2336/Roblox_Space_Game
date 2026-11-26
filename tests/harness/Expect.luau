--!nocheck
-- Tiny assertion helpers. Every check increments a global counter so the
-- runner can report how many assertions ran.

local Expect = { assertions = 0 }

local function fmt(v)
	if type(v) == "string" then
		return string.format("%q", v)
	end
	return tostring(v)
end

local function fail(message, level)
	error(message, (level or 1) + 2)
end

local Matcher = {}
Matcher.__index = Matcher

function Matcher:toBe(expected)
	Expect.assertions += 1
	if self.value ~= expected then
		fail(("expected %s to be %s"):format(fmt(self.value), fmt(expected)))
	end
end

function Matcher:never()
	return setmetatable({ value = self.value, negate = true }, Matcher)
end

function Matcher:toNotBe(expected)
	Expect.assertions += 1
	if self.value == expected then
		fail(("expected %s to not be %s"):format(fmt(self.value), fmt(expected)))
	end
end

function Matcher:toBeCloseTo(expected, epsilon)
	Expect.assertions += 1
	epsilon = epsilon or 1e-9
	if type(self.value) ~= "number" or math.abs(self.value - expected) > epsilon then
		fail(("expected %s to be within %s of %s"):format(fmt(self.value), fmt(epsilon), fmt(expected)))
	end
end

function Matcher:toBeTruthy()
	Expect.assertions += 1
	if not self.value then
		fail(("expected %s to be truthy"):format(fmt(self.value)))
	end
end

function Matcher:toBeFalsy()
	Expect.assertions += 1
	if self.value then
		fail(("expected %s to be falsy"):format(fmt(self.value)))
	end
end

function Matcher:toBeNil()
	Expect.assertions += 1
	if self.value ~= nil then
		fail(("expected nil, got %s"):format(fmt(self.value)))
	end
end

function Matcher:toBeA(kind)
	Expect.assertions += 1
	if typeof(self.value) ~= kind then
		fail(("expected a %s, got %s (%s)"):format(kind, typeof(self.value), fmt(self.value)))
	end
end

function Matcher:toBeGreaterThan(n)
	Expect.assertions += 1
	if not (type(self.value) == "number" and self.value > n) then
		fail(("expected %s > %s"):format(fmt(self.value), fmt(n)))
	end
end

function Matcher:toBeGreaterThanOrEqual(n)
	Expect.assertions += 1
	if not (type(self.value) == "number" and self.value >= n) then
		fail(("expected %s >= %s"):format(fmt(self.value), fmt(n)))
	end
end

function Matcher:toBeLessThan(n)
	Expect.assertions += 1
	if not (type(self.value) == "number" and self.value < n) then
		fail(("expected %s < %s"):format(fmt(self.value), fmt(n)))
	end
end

function Matcher:toBeLessThanOrEqual(n)
	Expect.assertions += 1
	if not (type(self.value) == "number" and self.value <= n) then
		fail(("expected %s <= %s"):format(fmt(self.value), fmt(n)))
	end
end

function Matcher:toBeFinite()
	Expect.assertions += 1
	local v = self.value
	if type(v) ~= "number" or v ~= v or v == math.huge or v == -math.huge then
		fail(("expected a finite number, got %s"):format(fmt(v)))
	end
end

function Matcher:toContain(item)
	Expect.assertions += 1
	if type(self.value) == "string" then
		if not string.find(self.value, item, 1, true) then
			fail(("expected %s to contain %s"):format(fmt(self.value), fmt(item)))
		end
		return
	end
	for _, v in self.value do
		if v == item then
			return
		end
	end
	fail(("expected table to contain %s"):format(fmt(item)))
end

function Matcher:toThrow(pattern)
	Expect.assertions += 1
	local ok, err = pcall(self.value)
	if ok then
		fail("expected function to throw")
	end
	if pattern and not string.find(tostring(err), pattern) then
		fail(("expected error matching %s, got %s"):format(fmt(pattern), fmt(err)))
	end
end

function Matcher:toNotThrow()
	Expect.assertions += 1
	local ok, err = pcall(self.value)
	if not ok then
		fail(("expected function not to throw, got %s"):format(tostring(err)))
	end
end

-- Jest-style dot calls: expect(x).toBe(y). Each matcher is bound to `value`.
function Expect.expect(value)
	local state = setmetatable({ value = value }, Matcher)
	local bound = {}
	for name, fn in Matcher do
		if type(fn) == "function" then
			bound[name] = function(...)
				return fn(state, ...)
			end
		end
	end
	return bound
end

function Expect.fail(message)
	Expect.assertions += 1
	error(message, 2)
end

return Expect
