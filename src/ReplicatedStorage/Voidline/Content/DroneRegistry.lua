--!strict
-- Drone content: the evolution tree (Mk.I -> three branches -> Omega
-- Antimatter), cosmetic mutations, laser shaders, hit effects and thrusters.
-- FROZEN lists: everything below is append-only (see ContentUtil).
local ContentUtil = require(script.Parent.ContentUtil)

export type Evolution = {
	Id: string,
	Name: string,
	Stage: number,
	Branch: string,
	BodyScale: number,
	RingCount: number,
	FinCount: number,
	Color: Color3,
	Glow: Color3,
	Flavor: string,
}

export type Cosmetic = {
	Id: string,
	Name: string,
	Category: string, -- "Mutation" | "Laser" | "HitEffect" | "Thruster"
	Style: string,
	Color: Color3,
	Accent: Color3,
	Rarity: string,
	Source: string,
}

local SHARED_STAGES = {
	{ "Mk.I Prospector", "A tough little cutter. Every fleet starts here." },
	{ "Mk.II Cutter", "Twin emitters and a better tow winch." },
	{ "Mk.III Borer", "Bores through rock that used to bounce lasers." },
	{ "Mk.IV Lancer", "Long-lance emitter, longer reach." },
	{ "Mk.V Vanguard", "The last common frame before the branches." },
}

local BRANCHES = {
	{
		Id = "Miner",
		Color = Color3.fromRGB(255, 190, 80),
		Names = { "Core Breaker", "Magma Lancer", "Quasar Drill", "Pulsar Ram", "Nova Bore", "Singularity Bore" },
		Flavor = "Miner line: every upgrade goes into the laser.",
	},
	{
		Id = "Hauler",
		Color = Color3.fromRGB(90, 220, 255),
		Names = {
			"Tug Hauler",
			"Gravity Mule",
			"Tether Titan",
			"Orbit Freighter",
			"Warp Barge",
			"Event Horizon Hauler",
		},
		Flavor = "Hauler line: faster tows, heavier rocks, more ore per rock.",
	},
	{
		Id = "Swarm",
		Color = Color3.fromRGB(180, 120, 255),
		Names = { "Hive Spark", "Swarm Wisp", "Locust Array", "Murmuration", "Star Choir", "Legion Prime" },
		Flavor = "Swarm line: extra drones join as the line grows.",
	},
}

local MUTATIONS: { { any } } = {
	{ "Shiny", Color3.fromRGB(255, 255, 255), Color3.fromRGB(200, 240, 255), "Rare" },
	{ "Golden", Color3.fromRGB(255, 205, 70), Color3.fromRGB(255, 240, 170), "Epic" },
	{ "Void-Corrupted", Color3.fromRGB(80, 30, 120), Color3.fromRGB(190, 110, 255), "Epic" },
	{ "Starforged", Color3.fromRGB(255, 150, 80), Color3.fromRGB(255, 230, 160), "Legendary" },
	{ "Prismatic", Color3.fromRGB(255, 150, 230), Color3.fromRGB(150, 230, 255), "Legendary" },
	{ "Spectral", Color3.fromRGB(200, 230, 255), Color3.fromRGB(255, 255, 255), "Epic" },
	{ "Crystalline", Color3.fromRGB(170, 230, 255), Color3.fromRGB(240, 250, 255), "Rare" },
	{ "Solar-Kissed", Color3.fromRGB(255, 180, 90), Color3.fromRGB(255, 230, 120), "Rare" },
	{ "Frostbitten", Color3.fromRGB(150, 200, 255), Color3.fromRGB(220, 245, 255), "Rare" },
	{ "Nebula-Born", Color3.fromRGB(150, 80, 200), Color3.fromRGB(255, 150, 220), "Epic" },
	{ "Quantum", Color3.fromRGB(120, 255, 220), Color3.fromRGB(255, 255, 255), "Legendary" },
	{ "Obsidian", Color3.fromRGB(25, 25, 35), Color3.fromRGB(232, 186, 74), "Mythic" },
}

local PALETTES: { { any } } = {
	{ "Gold", Color3.fromRGB(255, 210, 90), Color3.fromRGB(255, 245, 200) },
	{ "Cyan", Color3.fromRGB(90, 220, 255), Color3.fromRGB(220, 250, 255) },
	{ "Void", Color3.fromRGB(170, 110, 255), Color3.fromRGB(240, 220, 255) },
	{ "Crimson", Color3.fromRGB(255, 90, 110), Color3.fromRGB(255, 210, 210) },
	{ "Emerald", Color3.fromRGB(90, 255, 160), Color3.fromRGB(220, 255, 235) },
	{ "Solar", Color3.fromRGB(255, 150, 60), Color3.fromRGB(255, 230, 170) },
	{ "Aurora", Color3.fromRGB(120, 255, 200), Color3.fromRGB(190, 160, 255) },
	{ "Plasma", Color3.fromRGB(255, 80, 220), Color3.fromRGB(120, 200, 255) },
}

local LASER_STYLES = { "Pulse", "Helix", "Ribbon", "Lattice", "Flare", "Needle" }
local HIT_STYLES = { "Sparks", "Shatter", "Ripple", "Bloom" }
local THRUSTER_STYLES = { "Comet", "Ion", "Plasma", "Ember" }
local PALETTES_PER_SMALL_STYLE = 6

local RARITY_BY_PALETTE = { "Common", "Common", "Rare", "Rare", "Rare", "Epic", "Epic", "Legendary" }

local evolutions: { Evolution } = {}
local cosmetics: { Cosmetic } = {}

for stage, entry in SHARED_STAGES do
	local id = "drone.evo.mk" .. stage
	local rng = ContentUtil.Rng("drone", id)
	table.insert(evolutions, {
		Id = id,
		Name = entry[1],
		Stage = stage,
		Branch = "",
		BodyScale = ContentUtil.Round(1 + 0.06 * (stage - 1), 3),
		RingCount = 0,
		FinCount = 2 + math.floor(stage / 2),
		Color = ContentUtil.ShiftColor(Color3.fromRGB(232, 186, 74), rng, 0.03),
		Glow = Color3.fromRGB(255, 230, 150),
		Flavor = entry[2],
	})
end

for _, branch in BRANCHES do
	for offset, name in branch.Names do
		local stage = 5 + offset
		local id = ("drone.evo.%s.%d"):format(string.lower(branch.Id), stage)
		local rng = ContentUtil.Rng("drone", id)
		table.insert(evolutions, {
			Id = id,
			Name = name,
			Stage = stage,
			Branch = branch.Id,
			BodyScale = ContentUtil.Round(1.3 + 0.08 * offset, 3),
			RingCount = 1 + math.floor(offset / 2),
			FinCount = 4 + offset,
			Color = ContentUtil.ShiftColor(branch.Color, rng, 0.04),
			Glow = branch.Color:Lerp(Color3.new(1, 1, 1), 0.4),
			Flavor = branch.Flavor,
		})
	end
end

table.insert(evolutions, {
	Id = "drone.evo.omega",
	Name = "Omega Antimatter",
	Stage = 12,
	Branch = "Omega",
	BodyScale = 2.0,
	RingCount = 4,
	FinCount = 12,
	Color = Color3.fromRGB(20, 10, 30),
	Glow = Color3.fromRGB(255, 80, 200),
	Flavor = "Every branch ends here. The laser cuts reality a little.",
})

for _, mutation in MUTATIONS do
	table.insert(cosmetics, {
		Id = "drone.mut." .. ContentUtil.Slug(mutation[1]),
		Name = mutation[1],
		Category = "Mutation",
		Style = "Mutation",
		Color = mutation[2],
		Accent = mutation[3],
		Rarity = mutation[4],
		Source = "Evolution roll, boss meteors and Starfalls",
	})
end

for _, style in LASER_STYLES do
	for paletteIndex, palette in PALETTES do
		table.insert(cosmetics, {
			Id = ("laser.%s.%s"):format(string.lower(style), string.lower(palette[1])),
			Name = style .. " · " .. palette[1],
			Category = "Laser",
			Style = style,
			Color = palette[2],
			Accent = palette[3],
			Rarity = RARITY_BY_PALETTE[paletteIndex],
			Source = "Achievements and quests",
		})
	end
end

table.insert(cosmetics, {
	Id = "laser.overclock",
	Name = "Overclock",
	Category = "Laser",
	Style = "Overclock",
	Color = Color3.fromRGB(255, 255, 255),
	Accent = Color3.fromRGB(255, 120, 60),
	Rarity = "Legendary",
	Source = "Laser Overclock pass",
})

for _, style in HIT_STYLES do
	for paletteIndex = 1, PALETTES_PER_SMALL_STYLE do
		local palette = PALETTES[paletteIndex]
		table.insert(cosmetics, {
			Id = ("hit.%s.%s"):format(string.lower(style), string.lower(palette[1])),
			Name = style .. " · " .. palette[1],
			Category = "HitEffect",
			Style = style,
			Color = palette[2],
			Accent = palette[3],
			Rarity = RARITY_BY_PALETTE[paletteIndex],
			Source = "Achievements and quests",
		})
	end
end

for _, style in THRUSTER_STYLES do
	for paletteIndex = 1, PALETTES_PER_SMALL_STYLE do
		local palette = PALETTES[paletteIndex]
		table.insert(cosmetics, {
			Id = ("thruster.%s.%s"):format(string.lower(style), string.lower(palette[1])),
			Name = style .. " · " .. palette[1],
			Category = "Thruster",
			Style = style,
			Color = palette[2],
			Accent = palette[3],
			Rarity = RARITY_BY_PALETTE[paletteIndex],
			Source = "Achievements and quests",
		})
	end
end

table.insert(cosmetics, {
	Id = "thruster.gold_comet",
	Name = "Gold Comet",
	Category = "Thruster",
	Style = "Comet",
	Color = Color3.fromRGB(255, 205, 90),
	Accent = Color3.fromRGB(255, 245, 200),
	Rarity = "Epic",
	Source = "Starter Bundle",
})

local all: { any } = {}
for _, evo in evolutions do
	table.insert(all, evo)
end
for _, cosmetic in cosmetics do
	table.insert(all, cosmetic)
end

local registry = ContentUtil.Registry("drone", all) :: any
registry.Evolutions = evolutions
registry.Cosmetics = cosmetics

-- Evolution for a stage/branch pair (stage 1..12).
function registry.EvolutionFor(stage: number, branch: string): Evolution
	if stage <= 5 then
		return evolutions[math.max(1, stage)]
	elseif stage >= 12 then
		return registry.ById["drone.evo.omega"]
	end
	local branchId = if branch ~= "" then string.lower(branch) else "miner"
	return registry.ById[("drone.evo.%s.%d"):format(branchId, stage)]
end

function registry.ByCategory(category: string): { Cosmetic }
	local out = {}
	for _, cosmetic in cosmetics do
		if cosmetic.Category == category then
			table.insert(out, cosmetic)
		end
	end
	return out
end

return registry
