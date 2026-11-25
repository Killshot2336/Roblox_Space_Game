--!strict
-- Deterministic PRNG for content generation (mulberry32 + FNV-1a seeding).
-- Pure 32-bit integer math through bit32, so generated registries are
-- identical in Studio, live servers and the headless test harness. Do not
-- use Random.new here: its sequence is not guaranteed across engine versions.
local Prng = {}
Prng.__index = Prng

local TWO_32 = 4294967296

-- (a * b) mod 2^32 without losing precision in doubles.
local function imul(a: number, b: number): number
	local ah = bit32.rshift(a, 16)
	local al = bit32.band(a, 0xFFFF)
	return ((ah * b) % 65536 * 65536 + al * b) % TWO_32
end

-- FNV-1a 32-bit. FNV prime 16777619 = 2^24 + 403.
function Prng.Hash(text: string): number
	local h = 2166136261
	for i = 1, #text do
		h = bit32.bxor(h, string.byte(text, i))
		h = (bit32.lshift(h, 24) + h * 403) % TWO_32
	end
	return h
end

export type Prng = typeof(setmetatable({} :: { _state: number }, Prng))

function Prng.new(seed: number | string): Prng
	local state = if type(seed) == "string" then Prng.Hash(seed) else math.floor(seed) % TWO_32
	return setmetatable({ _state = state }, Prng)
end

-- Next unsigned 32-bit integer.
function Prng.NextUInt(self: Prng): number
	self._state = (self._state + 0x6D2B79F5) % TWO_32
	local t = self._state
	t = imul(bit32.bxor(t, bit32.rshift(t, 15)), bit32.bor(t, 1))
	t = bit32.bxor(t, (t + imul(bit32.bxor(t, bit32.rshift(t, 7)), bit32.bor(t, 61))) % TWO_32)
	return bit32.bxor(t, bit32.rshift(t, 14))
end

-- Uniform in [0, 1), or [min, max) when bounds are given.
function Prng.NextNumber(self: Prng, min: number?, max: number?): number
	local unit = self:NextUInt() / TWO_32
	if min and max then
		return min + (max - min) * unit
	end
	return unit
end

-- Uniform integer in [min, max] inclusive.
function Prng.NextInteger(self: Prng, min: number, max: number): number
	return min + (self:NextUInt() % (max - min + 1))
end

function Prng.Chance(self: Prng, probability: number): boolean
	return self:NextNumber() < probability
end

function Prng.Pick<T>(self: Prng, list: { T }): T
	return list[self:NextInteger(1, #list)]
end

function Prng.Shuffle<T>(self: Prng, list: { T }): { T }
	for i = #list, 2, -1 do
		local j = self:NextInteger(1, i)
		list[i], list[j] = list[j], list[i]
	end
	return list
end

-- Picks `count` distinct items (order preserved from a shuffled copy).
function Prng.Sample<T>(self: Prng, list: { T }, count: number): { T }
	local copy = table.clone(list)
	self:Shuffle(copy)
	local out = {}
	for i = 1, math.min(count, #copy) do
		out[i] = copy[i]
	end
	return out
end

return Prng
