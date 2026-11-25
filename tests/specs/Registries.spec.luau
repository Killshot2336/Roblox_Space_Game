--!nocheck
-- Procedural content registries: counts, stable IDs, determinism, schema,
-- cross-references and the frozen-ID snapshot.
local fs = require("@lune/fs")

local Harness = require("../harness/Harness")
local Expect = require("../harness/Expect")
local expect = Expect.expect

local tests = {}

local SNAPSHOT = "tests/snapshots/content_ids.txt"

local function content(world)
	world = world or Harness.new()
	local function r(name)
		return world:require("ReplicatedStorage/Voidline/Content/" .. name)
	end
	return {
		world = world,
		Index = r("ContentIndex"),
		Prng = r("Prng"),
		Ore = r("OreRegistry"),
		Biome = r("BiomeRegistry"),
		Relic = r("RelicRegistry"),
		Drone = r("DroneRegistry"),
		Title = r("TitleRegistry"),
		Achievement = r("AchievementRegistry"),
		Citadel = r("CitadelRegistry"),
		Quest = r("QuestRegistry"),
		Event = r("WorldEventRegistry"),
	}
end

local MINIMUMS = {
	ore = 250,
	biome = 50,
	relic = 150,
	drone = 100,
	achievement = 200,
	title = 100,
	citadel = 25,
	hazard = 12,
	quest = 45,
	event = 8,
}

tests["registry counts meet the owner brief targets"] = function()
	local c = content()
	local rows, total = c.Index.Totals()
	local counts = {}
	for _, row in rows do
		counts[row.Kind] = row.Count
	end
	for kind, minimum in MINIMUMS do
		expect(counts[kind]).toBeGreaterThanOrEqual(minimum)
	end
	expect(total).toBeGreaterThanOrEqual(1000)
	expect(c.Index.CodexTotal).toBeGreaterThanOrEqual(650)
end

tests["every id is a unique lowercase dotted slug"] = function()
	local c = content()
	local seen = {}
	for _, info in c.Index.Registries do
		for _, entry in info.Registry.List do
			local id = entry.Id
			expect(string.match(id, "^[a-z][a-z0-9_]*%.[a-z0-9_%.]+$") ~= nil).toBe(true)
			expect(string.find(id, "%.%.") == nil and string.sub(id, -1) ~= ".").toBe(true)
			expect(seen[id]).toBeNil()
			seen[id] = true
			expect(c.Index.Get(id)).toBe(entry)
			expect(info.Registry.ById[id]).toBe(entry)
		end
	end
end

local function dump(value, out)
	local kind = typeof(value)
	if kind == "table" then
		local keys = {}
		for k in value do
			table.insert(keys, tostring(k))
		end
		table.sort(keys)
		table.insert(out, "{")
		for _, k in keys do
			local v = value[k]
			if v == nil then
				v = value[tonumber(k)]
			end
			table.insert(out, k .. "=")
			dump(v, out)
			table.insert(out, ",")
		end
		table.insert(out, "}")
	elseif kind == "number" then
		table.insert(out, string.format("%.17g", value))
	elseif kind == "Color3" then
		table.insert(out, string.format("C(%.6f,%.6f,%.6f)", value.R, value.G, value.B))
	elseif kind == "function" then
		table.insert(out, "fn")
	else
		table.insert(out, tostring(value))
	end
end

tests["registries are deterministic across fresh worlds"] = function()
	local a = content(Harness.new())
	local b = content(Harness.new({ epoch = 1900000000 }))
	for i, info in a.Index.Registries do
		local left, right = {}, {}
		dump(info.Registry.List, left)
		dump(b.Index.Registries[i].Registry.List, right)
		expect(table.concat(left)).toBe(table.concat(right))
	end
end

local SCHEMAS = {
	ore = {
		Id = "string",
		Name = "string",
		Tier = "string",
		TierIndex = "number",
		Root = "string",
		Modifier = "string",
		ValueMult = "number",
		ShardChance = "number",
		RelicChance = "number",
		Weight = "number",
		Color = "Color3",
		Glow = "Color3",
		Material = "EnumItem",
		MinSector = "number",
		Flavor = "string",
	},
	biome = {
		Id = "string",
		Name = "string",
		Archetype = "string",
		ArchetypeName = "string",
		Intensity = "number",
		IntensityName = "string",
		GravityMult = "number",
		HazardIds = "table",
		HazardInterval = "number",
		TierBias = "table",
		RelicMult = "number",
		CreditMult = "number",
		Sky = "table",
		Flavor = "string",
	},
	hazard = {
		Id = "string",
		Name = "string",
		Effect = "string",
		TelegraphSeconds = "number",
		Duration = "number",
		Radius = "number",
		Color = "Color3",
		Flavor = "string",
	},
	relic = {
		Id = "string",
		Name = "string",
		Set = "string",
		SetName = "string",
		Rarity = "string",
		RarityIndex = "number",
		Shape = "string",
		Color = "Color3",
		Glow = "Color3",
		DropWeight = "number",
		Flavor = "string",
	},
	title = { Id = "string", Name = "string", Source = "string", Rarity = "string", Color = "Color3" },
	achievement = {
		Id = "string",
		Name = "string",
		Description = "string",
		Category = "string",
		Stat = "string",
		Threshold = "number",
		RewardCredits = "number",
		RewardShards = "number",
		RewardTitle = "string",
		RewardUnlock = "string",
	},
	citadel = {
		Id = "string",
		Name = "string",
		Tier = "number",
		Era = "string",
		Adds = "table",
		RelicSlots = "number",
		Accent = "Color3",
		Height = "number",
		Flavor = "string",
	},
	quest = {
		Id = "string",
		Name = "string",
		Cadence = "string",
		Stat = "string",
		Target = "number",
		ScalesWithTier = "boolean",
		RewardCredits = "number",
		RewardShards = "number",
		RewardCosmetic = "boolean",
	},
	event = {
		Id = "string",
		Name = "string",
		Kind = "string",
		Duration = "number",
		Weight = "number",
		Banner = "string",
		Color = "Color3",
		CoreHealth = "number",
		Meteors = "number",
		MeteorHealth = "number",
		CreditMult = "number",
		LuckMult = "number",
		GravityMult = "number",
		CelestialBias = "number",
		RelicGuaranteed = "boolean",
		Flavor = "string",
	},
}

local DRONE_EVOLUTION = {
	Id = "string",
	Name = "string",
	Stage = "number",
	Branch = "string",
	BodyScale = "number",
	RingCount = "number",
	FinCount = "number",
	Color = "Color3",
	Glow = "Color3",
	Flavor = "string",
}
local DRONE_COSMETIC = {
	Id = "string",
	Name = "string",
	Category = "string",
	Style = "string",
	Color = "Color3",
	Accent = "Color3",
	Rarity = "string",
	Source = "string",
}

local function checkSchema(entry, schema)
	for field, kind in schema do
		local value = entry[field]
		if typeof(value) ~= kind then
			error(("%s.%s is %s, expected %s"):format(entry.Id, field, typeof(value), kind))
		end
		if kind == "number" then
			expect(value).toBeFinite()
		elseif kind == "string" and (field == "Id" or field == "Name") then
			expect(#value).toBeGreaterThan(0)
		end
	end
end

tests["every entry has every field with the right type (no nils)"] = function()
	local c = content()
	for _, info in c.Index.Registries do
		for _, entry in info.Registry.List do
			if info.Kind == "drone" then
				checkSchema(entry, if string.find(entry.Id, "^drone%.evo%.") then DRONE_EVOLUTION else DRONE_COSMETIC)
			else
				checkSchema(entry, SCHEMAS[info.Kind])
			end
		end
	end
end

tests["cross references resolve"] = function()
	local c = content()
	for _, achievement in c.Achievement.List do
		if achievement.RewardTitle ~= "" then
			expect(c.Title.ById[achievement.RewardTitle] ~= nil).toBe(true)
		end
		if achievement.RewardUnlock ~= "" then
			expect(c.Drone.ById[achievement.RewardUnlock] ~= nil).toBe(true)
		end
		expect(achievement.Threshold).toBeGreaterThan(0)
	end
	for _, biome in c.Biome.List do
		expect(#biome.HazardIds).toBeGreaterThan(0)
		for _, hazardId in biome.HazardIds do
			expect(c.Biome.Hazards.ById[hazardId] ~= nil).toBe(true)
		end
	end
	local codes = c.world:require("ReplicatedStorage/Voidline/Config/CodesConfig")
	for _, reward in codes.Codes do
		expect(c.Title.ById[reward.Title] ~= nil).toBe(true)
	end
	for _, id in
		{
			"title.pass.pioneer",
			"title.pass.void_sovereign",
			"title.pass.eternal_architect",
			"title.void.1",
			"title.void.50",
			"title.star_breaker",
			"title.monolith_architect",
			"title.event_horizon",
		}
	do
		expect(c.Title.ById[id] ~= nil).toBe(true)
	end
	expect(c.Drone.ById["thruster.gold_comet"] ~= nil).toBe(true)
	expect(c.Drone.ById["laser.overclock"] ~= nil).toBe(true)
	for stage = 1, 12 do
		for _, branch in { "", "Miner", "Hauler", "Swarm" } do
			local evo = c.Drone.EvolutionFor(stage, branch)
			expect(evo ~= nil).toBe(true)
			expect(evo.Stage).toBe(stage)
		end
	end
end

tests["tutorial ore is exact and early sectors never roll late tiers"] = function()
	local c = content()
	local tutorialOre = c.Ore.ById[c.Ore.TutorialOreId]
	expect(tutorialOre.ValueMult).toBe(1)
	expect(tutorialOre.TierIndex).toBe(1)
	local rng = c.Prng.new("roll-test")
	local seenTiers = {}
	for _ = 1, 5000 do
		local ore = c.Ore.Roll(rng, 1, 1)
		expect(ore.MinSector).toBeLessThanOrEqual(1)
		seenTiers[ore.TierIndex] = true
	end
	expect(seenTiers[1]).toBe(true)
	expect(seenTiers[2]).toBe(true)
	local celestialSeen = false
	for _ = 1, 20000 do
		local ore = c.Ore.Roll(rng, 4, 4, { [6] = 3 })
		if ore.TierIndex >= 5 then
			celestialSeen = true
		end
	end
	expect(celestialSeen).toBe(true)
end

tests["prng is deterministic, bounded and roughly uniform"] = function()
	local c = content()
	local a, b = c.Prng.new("seed"), c.Prng.new("seed")
	for _ = 1, 1000 do
		expect(a:NextUInt()).toBe(b:NextUInt())
	end
	local rng = c.Prng.new(12345)
	local buckets = table.create(10, 0)
	local draws = 100000
	for _ = 1, draws do
		local x = rng:NextNumber()
		expect(x >= 0 and x < 1).toBe(true)
		local bucket = math.floor(x * 10) + 1
		buckets[bucket] += 1
	end
	for _, count in buckets do
		expect(math.abs(count - draws / 10)).toBeLessThan(draws / 10 * 0.05)
	end
	local seen = {}
	for _ = 1, 2000 do
		local n = rng:NextInteger(3, 7)
		expect(n >= 3 and n <= 7).toBe(true)
		seen[n] = true
	end
	for n = 3, 7 do
		expect(seen[n]).toBe(true)
	end
	expect(c.Prng.Hash("")).toBe(2166136261)
	expect(c.Prng.Hash("a")).toBe(0xE40C292C)
	expect(c.Prng.Hash("foobar")).toBe(0xBF9CF968)
end

tests["quest assignment: 3 distinct stats, stable per day and pilot"] = function()
	local c = content()
	local first = c.Quest.Assign("Daily", "2026-11-25", 42)
	local again = c.Quest.Assign("Daily", "2026-11-25", 42)
	expect(#first).toBe(3)
	local stats = {}
	for i, quest in first do
		expect(again[i].Id).toBe(quest.Id)
		expect(stats[quest.Stat]).toBeNil()
		stats[quest.Stat] = true
	end
	local weekly = c.Quest.Assign("Weekly", "W2917", 42)
	expect(#weekly).toBe(3)
	local scaling = c.Quest.ById["quest.daily.creditsearned.200"]
	expect(c.Quest.TargetFor(scaling, 1)).toBe(200)
	expect(c.Quest.TargetFor(scaling, 3)).toBe(512)
end

tests["relic sets, odds and world event rotation"] = function()
	local c = content()
	local owned = {}
	for _, id in c.Relic.SetMembers.titan_wreck do
		owned[id] = true
	end
	expect(c.Relic.SetComplete(owned, "titan_wreck")).toBe(true)
	owned["relic.titan_wreck.10"] = nil
	expect(c.Relic.SetComplete(owned, "titan_wreck")).toBe(false)
	local totalOdds = 0
	for _, relic in c.Relic.List do
		totalOdds += c.Relic.Odds(relic.Id)
	end
	expect(totalOdds).toBeCloseTo(1, 1e-9)
	for slot = 1, 50 do
		expect(c.Event.ForSlot(slot)).toBe(c.Event.ForSlot(slot))
		expect(c.Biome.ForSlot(slot) ~= nil).toBe(true)
	end
	expect(#c.Citadel.StructuresUpTo(30)).toBeGreaterThan(30)
	expect(c.Citadel.ForTier(99).Tier).toBe(30)
end

tests["snapshot: shipped ids and names never change"] = function()
	local c = content()
	if not fs.isFile(SNAPSHOT) then
		error("missing " .. SNAPSHOT .. " (run: lune run scripts/content_report.luau --write-snapshot)")
	end
	local current = {}
	for _, info in c.Index.Registries do
		for _, entry in info.Registry.List do
			current[info.Kind .. "\t" .. entry.Id] = entry.Name
		end
	end
	local checked = 0
	for line in string.gmatch(fs.readFile(SNAPSHOT), "[^\n]+") do
		local kind, id, name = string.match(line, "^([^\t]+)\t([^\t]+)\t(.*)$")
		local key = kind .. "\t" .. id
		if current[key] == nil then
			error("shipped content id removed or renamed: " .. id)
		end
		if current[key] ~= name then
			error(("shipped content %s renamed: %q -> %q"):format(id, name, current[key]))
		end
		checked += 1
	end
	expect(checked).toBeGreaterThanOrEqual(1000)
end

return tests
