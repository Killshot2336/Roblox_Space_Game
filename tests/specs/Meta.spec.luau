--!nocheck
-- Achievements and quests (rules layer).
local Harness = require("../harness/Harness")
local Expect = require("../harness/Expect")
local expect = Expect.expect

local tests = {}

local EPOCH = 1795564800
local DAY = 86400

local function load()
	local world = Harness.new()
	local function r(path)
		return world:require("ReplicatedStorage/Voidline/" .. path)
	end
	return {
		Schema = r("Modules/ProfileSchema"),
		Ach = r("Rules/AchievementRules"),
		Quest = r("Rules/QuestRules"),
		AchievementRegistry = r("Content/AchievementRegistry"),
		RelicRegistry = r("Content/RelicRegistry"),
		Prng = r("Content/Prng"),
	}
end

tests["achievement ladder grants every reached step once and cascades"] = function()
	local m = load()
	local p = m.Schema.Default()
	p.Stats.RocksMined = 100
	local granted = m.Ach.Check(p, "RocksMined", EPOCH)
	local ids = {}
	for _, g in granted do
		ids[g.Id] = true
	end
	for _, id in { "ach.rocks.1", "ach.rocks.10", "ach.rocks.50", "ach.rocks.100" } do
		expect(ids[id]).toBe(true)
	end
	expect(ids["ach.rocks.500"]).toBeNil()
	expect(p.Titles["title.ladder.rocks.1"]).toBe(true)
	-- Rewards pushed lifetime credits past 100 and shards past 10.
	expect(ids["ach.credits.100"]).toBe(true)
	expect(ids["ach.shards.1"]).toBe(true)
	expect(p.Achievements["ach.rocks.100"]).toBe(EPOCH)
	local again = m.Ach.Check(p, "RocksMined", EPOCH + 5)
	expect(#again).toBe(0)
end

tests["derived achievement stats resolve"] = function()
	local m = load()
	local p = m.Schema.Default()
	expect(m.Ach.StatValue(p, "Flag:GalaxyFlags.Starter")).toBe(1)
	expect(m.Ach.StatValue(p, "Flag:GalaxyFlags.Nebula")).toBe(0)
	expect(m.Ach.StatValue(p, "StationTier")).toBe(1)
	p.Codex["ore.common.ferrite"] = EPOCH
	p.Codex["biome.solar_forge.1"] = EPOCH
	expect(m.Ach.StatValue(p, "CodexCount")).toBe(2)
	for _, id in m.RelicRegistry.SetMembers.solar_forge do
		p.Relics[id] = 1
	end
	expect(m.Ach.StatValue(p, "RelicSet:solar_forge")).toBe(1)
	expect(m.Ach.StatValue(p, "RelicSet:titan_wreck")).toBe(0)
	expect(m.Ach.StatValue(p, "RelicCount")).toBe(10)
	p.DroneBranch = "Swarm"
	expect(m.Ach.StatValue(p, "Branch:Swarm")).toBe(1)
	local granted = m.Ach.Check(p, "RelicSet:solar_forge", EPOCH)
	expect(#granted).toBeGreaterThanOrEqual(1)
	expect(p.Titles["title.curator.solar_forge"]).toBe(true)
	-- Every registry stat key resolves to a finite number on a fresh profile.
	local fresh = m.Schema.Default()
	for _, stat in m.Ach.AllStats() do
		expect(m.Ach.StatValue(fresh, stat)).toBeFinite()
	end
end

tests["full recheck on a maxed profile never errors and is idempotent"] = function()
	local m = load()
	local p = m.Schema.Default()
	p.StationTier, p.DroneTier, p.DroneSlots, p.Rebirths = 30, 12, 6, 100
	p.Stats.RocksMined = 1e6
	local total = 0
	for _, stat in m.Ach.AllStats() do
		total += #m.Ach.Check(p, stat, EPOCH)
	end
	expect(total).toBeGreaterThan(50)
	for _, stat in m.Ach.AllStats() do
		expect(#m.Ach.Check(p, stat, EPOCH)).toBe(0)
	end
	expect(p.Titles["title.event_horizon"]).toBe(true)
	expect(p.Titles["title.monolith_architect"]).toBe(true)
end

tests["quests: 3 daily + 3 weekly, refresh on new day, pay once"] = function()
	local m = load()
	local p = m.Schema.Default()
	expect(m.Quest.Refresh(p, EPOCH, 7)).toBe(true)
	expect(#p.Quests.Daily).toBe(3)
	expect(#p.Quests.Weekly).toBe(3)
	expect(m.Quest.Refresh(p, EPOCH + 3600, 7)).toBe(false)
	local first = p.Quests.Daily[1]
	local rng = m.Prng.new("quest-test")
	local creditsBefore = p.Credits
	local done = m.Quest.Progress(p, first.Stat, first.Target - 1, rng)
	expect(#done).toBe(0)
	done = m.Quest.Progress(p, first.Stat, 5, rng)
	local found = false
	for _, c in done do
		if c.Id == first.Id then
			found = true
		end
	end
	expect(found).toBe(true)
	expect(first.Done).toBe(true)
	expect(first.Progress).toBe(first.Target)
	expect(p.Credits).toBeGreaterThan(creditsBefore)
	local after = p.Credits
	m.Quest.Progress(p, first.Stat, 1000, rng)
	-- Already done: no second payout from the same quest.
	local stillDone = 0
	for _, entry in p.Quests.Daily do
		if entry.Id == first.Id and entry.Done then
			stillDone += 1
		end
	end
	expect(stillDone).toBe(1)
	expect(p.Credits >= after).toBe(true)
	expect(m.Quest.Refresh(p, EPOCH + DAY, 7)).toBe(true)
	expect(p.Quests.Daily[1].Done).toBe(false)
	expect(#m.Quest.Progress(p, "RocksMined", 0 / 0, rng)).toBe(0)
end

tests["weekly top-step quests unlock a cosmetic"] = function()
	local m = load()
	local p = m.Schema.Default()
	p.Quests.WeekKey = "manual"
	p.Quests.DayKey = "manual"
	p.Quests.Daily = {}
	p.Quests.Weekly = {
		{
			Id = "quest.weekly.rocksmined.2500",
			Name = "x",
			Stat = "RocksMined",
			Target = 2500,
			Progress = 0,
			Done = false,
		},
	}
	local done = m.Quest.Progress(p, "RocksMined", 2500, m.Prng.new(1))
	expect(#done).toBe(1)
	expect(done[1].Unlock ~= "").toBe(true)
	expect(p.Unlocks[done[1].Unlock]).toBe(true)
end

return tests
