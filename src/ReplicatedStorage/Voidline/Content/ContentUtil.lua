--!strict
-- Helpers shared by the content registries.
--
-- Stability contract (read before editing any registry):
--   * IDs are lowercase dotted slugs and are saved in player profiles. Never
--     rename or remove one; add new entries instead.
--   * Every entry's stats come from Prng.new(<kind> .. ":" .. id), so an
--     entry's values never depend on list order.
--   * Word lists feeding generated *names* are frozen once shipped. Append new
--     sets/archetypes rather than editing existing lists. The registry
--     snapshot test (tests/snapshots/content_ids.txt) fails on any rename.
local Prng = require(script.Parent.Prng)

local ContentUtil = {}

function ContentUtil.Slug(text: string): string
	local slug = string.lower(text)
	slug = string.gsub(slug, "[^%w]+", "_")
	slug = string.gsub(slug, "^_+", "")
	slug = string.gsub(slug, "_+$", "")
	return slug
end

local ROMAN: { { any } } = {
	{ 1000, "M" },
	{ 900, "CM" },
	{ 500, "D" },
	{ 400, "CD" },
	{ 100, "C" },
	{ 90, "XC" },
	{ 50, "L" },
	{ 40, "XL" },
	{ 10, "X" },
	{ 9, "IX" },
	{ 5, "V" },
	{ 4, "IV" },
	{ 1, "I" },
}

function ContentUtil.Roman(n: number): string
	local out = {}
	local rest = math.floor(n)
	for _, pair in ROMAN do
		while rest >= pair[1] do
			table.insert(out, pair[2])
			rest -= pair[1]
		end
	end
	return table.concat(out)
end

function ContentUtil.Rng(kind: string, id: string): Prng.Prng
	return Prng.new(kind .. ":" .. id)
end

-- Deterministic yes/no for an (a, b) pair, independent of list positions.
function ContentUtil.Include(salt: string, probability: number): boolean
	return (Prng.Hash(salt) % 10000) / 10000 < probability
end

function ContentUtil.Jitter(rng: Prng.Prng, value: number, spread: number): number
	return value * (1 + rng:NextNumber(-spread, spread))
end

function ContentUtil.Round(value: number, places: number): number
	local scale = 10 ^ places
	return math.floor(value * scale + 0.5) / scale
end

function ContentUtil.ShiftColor(color: Color3, rng: Prng.Prng, amount: number): Color3
	local h, s, v = color:ToHSV()
	h = (h + rng:NextNumber(-amount, amount)) % 1
	s = math.clamp(s + rng:NextNumber(-amount, amount), 0, 1)
	v = math.clamp(v + rng:NextNumber(-amount, amount), 0.15, 1)
	return Color3.fromHSV(h, s, v)
end

function ContentUtil.FormatCount(n: number): string
	if n >= 1e9 then
		return (string.gsub(string.format("%.1fB", n / 1e9), "%.0B", "B"))
	elseif n >= 1e6 then
		return (string.gsub(string.format("%.1fM", n / 1e6), "%.0M", "M"))
	elseif n >= 1e3 then
		return (string.gsub(string.format("%.1fK", n / 1e3), "%.0K", "K"))
	end
	return tostring(n)
end

export type Registry<T> = {
	Kind: string,
	List: { T },
	ById: { [string]: T },
	Count: number,
}

-- Builds the standard registry shape and rejects duplicate IDs.
function ContentUtil.Registry<T>(kind: string, list: { T }): Registry<T>
	local byId = {}
	for _, entry in list do
		local id = (entry :: any).Id
		assert(type(id) == "string", kind .. " entry without Id")
		assert(byId[id] == nil, kind .. " duplicate id " .. id)
		byId[id] = entry
	end
	return { Kind = kind, List = list, ById = byId, Count = #list }
end

return ContentUtil
