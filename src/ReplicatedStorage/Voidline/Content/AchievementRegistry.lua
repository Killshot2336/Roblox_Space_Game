--!strict
-- Achievements: stat ladders plus one-off discoveries. Stat names resolve
-- through AchievementRules.StatValue (profile fields, profile.Stats counters
-- and a few derived checks such as "RelicSet:<id>").
-- FROZEN lists: LADDERS order and thresholds are append-only.
local ContentUtil = require(script.Parent.ContentUtil)
local RelicRegistry = require(script.Parent.RelicRegistry)
local BiomeRegistry = require(script.Parent.BiomeRegistry)
local DroneRegistry = require(script.Parent.DroneRegistry)
local OreRegistry = require(script.Parent.OreRegistry)

export type Achievement = {
	Id: string,
	Name: string,
	Description: string,
	Category: string,
	Stat: string,
	Threshold: number,
	RewardCredits: number,
	RewardShards: number,
	RewardTitle: string,
	RewardUnlock: string,
}

type Ladder = {
	Key: string,
	One: string?, -- description when the threshold is 1
	Stat: string,
	Name: string,
	Verb: string,
	Category: string,
	Thresholds: { number },
	Titles: { [number]: string }?,
}

local function range(a: number, b: number): { number }
	local out = {}
	for i = a, b do
		table.insert(out, i)
	end
	return out
end

local LADDERS: { Ladder } = {
	{
		Key = "credits",
		Stat = "LifetimeCredits",
		Name = "Credit Runner",
		Verb = "Earn %s lifetime Credits",
		Category = "Economy",
		Thresholds = { 100, 1e3, 1e4, 1e5, 1e6, 1e7, 1e8, 1e9, 1e10, 1e11 },
		Titles = { [5] = "title.ladder.credits.1", [8] = "title.ladder.credits.2", [10] = "title.ladder.credits.3" },
	},
	{
		Key = "ore",
		Stat = "LifetimeOre",
		Name = "Ore Hauler",
		Verb = "Store %s ore",
		Category = "Economy",
		Thresholds = { 10, 100, 1e3, 1e4, 1e5, 1e6, 1e7 },
	},
	{
		Key = "rocks",
		One = "Break your first rock",
		Stat = "RocksMined",
		Name = "Rock Breaker",
		Verb = "Break %s rocks",
		Category = "Mining",
		Thresholds = { 1, 10, 50, 100, 500, 1e3, 5e3, 1e4, 5e4, 1e5 },
		Titles = { [4] = "title.ladder.rocks.1", [7] = "title.ladder.rocks.2", [10] = "title.ladder.rocks.3" },
	},
	{
		Key = "sells",
		One = "Refine your first cargo",
		Stat = "Sells",
		Name = "Refiner",
		Verb = "Refine cargo %s times",
		Category = "Economy",
		Thresholds = { 1, 10, 50, 100, 500, 1e3, 5e3 },
	},
	{
		Key = "shards",
		One = "Find your first Void Shard",
		Stat = "LifetimeShards",
		Name = "Shard Seeker",
		Verb = "Find %s Void Shards",
		Category = "Mining",
		Thresholds = { 1, 10, 50, 100, 500, 1e3, 5e3 },
		Titles = { [4] = "title.ladder.shards.1", [7] = "title.ladder.shards.2" },
	},
	{
		Key = "relics",
		One = "Find your first relic",
		Stat = "RelicCount",
		Name = "Relic Hunter",
		Verb = "Collect %s relics",
		Category = "Codex",
		Thresholds = { 1, 5, 10, 25, 50, 75, 100, 150 },
		Titles = { [4] = "title.ladder.relics.1", [8] = "title.ladder.relics.2" },
	},
	{
		Key = "codex",
		Stat = "CodexCount",
		Name = "Codex Keeper",
		Verb = "Log %s Codex entries",
		Category = "Codex",
		Thresholds = { 10, 25, 50, 100, 175, 250, 350, 450, 550, 650 },
		Titles = { [4] = "title.codex.scholar", [10] = "title.codex.archivist" },
	},
	{
		Key = "rebirths",
		One = "Rebirth for the first time",
		Stat = "Rebirths",
		Name = "Reborn",
		Verb = "Rebirth %s times",
		Category = "Progression",
		Thresholds = { 1, 2, 3, 5, 10, 15, 20, 25, 50, 75, 100 },
	},
	{
		Key = "station_tier",
		Stat = "StationTier",
		Name = "Citadel",
		Verb = "Reach Station Tier %s",
		Category = "Progression",
		Thresholds = range(2, 30),
		Titles = { [24] = "title.monolith_architect" },
	},
	{
		Key = "drone_tier",
		Stat = "DroneTier",
		Name = "Evolution",
		Verb = "Evolve drones to stage %s",
		Category = "Drones",
		Thresholds = range(2, 12),
		Titles = { [11] = "title.event_horizon" },
	},
	{
		Key = "drone_slots",
		Stat = "DroneSlots",
		Name = "Swarm Size",
		Verb = "Own %s drone slots",
		Category = "Drones",
		Thresholds = range(2, 6),
	},
	{
		Key = "drill",
		Stat = "DrillLevel",
		Name = "Drill Master",
		Verb = "Reach Drill level %s",
		Category = "Drones",
		Thresholds = { 5, 10, 25, 50, 75, 100, 120 },
	},
	{
		Key = "cargo",
		Stat = "CargoLevel",
		Name = "Cargo Master",
		Verb = "Reach Cargo level %s",
		Category = "Drones",
		Thresholds = { 5, 10, 25, 50, 75, 100, 120 },
	},
	{
		Key = "meteors",
		One = "Qualify on your first boss meteor",
		Stat = "MeteorsContested",
		Name = "Meteor Brawler",
		Verb = "Qualify on %s boss meteors",
		Category = "Events",
		Thresholds = { 1, 10, 50, 100, 500 },
		Titles = { [3] = "title.ladder.meteors.1" },
	},
	{
		Key = "meteor_tops",
		One = "Top-contribute on a boss meteor",
		Stat = "MeteorTops",
		Name = "Star Breaker",
		Verb = "Top-contribute on %s boss meteors",
		Category = "Events",
		Thresholds = { 1, 10, 50, 100 },
		Titles = { [2] = "title.star_breaker" },
	},
	{
		Key = "events",
		One = "Join your first world event",
		Stat = "EventsJoined",
		Name = "Event Chaser",
		Verb = "Join %s world events",
		Category = "Events",
		Thresholds = { 1, 5, 25, 100, 250 },
	},
	{
		Key = "forge",
		One = "Forge your first artifact",
		Stat = "ArtifactsForged",
		Name = "Voidsmith",
		Verb = "Forge %s artifacts",
		Category = "Economy",
		Thresholds = { 1, 10, 50, 100, 500 },
		Titles = { [2] = "title.forge.smith" },
	},
	{
		Key = "tokens",
		Stat = "LifetimeTokens",
		Name = "Token Earner",
		Verb = "Earn %s Voidline Tokens",
		Category = "Economy",
		Thresholds = { 40, 400, 2000, 10000 },
	},
	{
		Key = "daily",
		One = "Claim your first daily reward",
		Stat = "DailyClaims",
		Name = "Daily Pilot",
		Verb = "Claim %s daily rewards",
		Category = "Social",
		Thresholds = { 1, 7, 30, 100, 365 },
		Titles = { [2] = "title.streak.seven" },
	},
	{
		Key = "rift",
		One = "Clear the Void Rift",
		Stat = "RiftClears",
		Name = "Rift Runner",
		Verb = "Clear the Void Rift %s times",
		Category = "Events",
		Thresholds = { 1, 5, 25, 100 },
		Titles = { [2] = "title.event.rift" },
	},
	{
		Key = "squad",
		Stat = "SquadMinutes",
		Name = "Wingmate",
		Verb = "Fly %s minutes in a squad",
		Category = "Social",
		Thresholds = { 10, 60, 300, 1000 },
		Titles = { [3] = "title.squad.captain" },
	},
	{
		Key = "warps",
		One = "Warp for the first time",
		Stat = "Warps",
		Name = "Warp Jumper",
		Verb = "Warp %s times",
		Category = "Social",
		Thresholds = { 1, 25, 100 },
	},
	{
		Key = "codes",
		One = "Redeem your first code",
		Stat = "CodesRedeemed",
		Name = "Codebreaker",
		Verb = "Redeem %s codes",
		Category = "Social",
		Thresholds = { 1, 3 },
	},
	{
		Key = "anomalies",
		One = "Witness your first anomaly",
		Stat = "AnomaliesSeen",
		Name = "Anomaly Witness",
		Verb = "Witness %s anomalies",
		Category = "Events",
		Thresholds = { 1, 5, 10, 25, 50 },
	},
	{
		Key = "hazards",
		One = "Fly through your first hazard",
		Stat = "HazardsSurvived",
		Name = "Hazard Runner",
		Verb = "Fly through %s hazards",
		Category = "Events",
		Thresholds = { 1, 10, 100 },
	},
	{
		Key = "starfalls",
		One = "Join your first Void Starfall",
		Stat = "StarfallsJoined",
		Name = "Starfall Chaser",
		Verb = "Join %s Void Starfalls",
		Category = "Events",
		Thresholds = { 1, 10 },
		Titles = { [1] = "title.event.starfall" },
	},
}

local list: { Achievement } = {}

-- Cosmetic unlock rewards are dealt out in registry order to ladder steps
-- 3, 5 and 7 so every cosmetic has an earnable source.
local lasers = DroneRegistry.ByCategory("Laser")
local hits = DroneRegistry.ByCategory("HitEffect")
local thrusters = DroneRegistry.ByCategory("Thruster")
local nextLaser, nextHit, nextThruster = 1, 1, 1

local function takeUnlock(step: number): string
	if step == 3 then
		while lasers[nextLaser] and lasers[nextLaser].Source ~= "Achievements and quests" do
			nextLaser += 1
		end
		local item = lasers[nextLaser]
		nextLaser += 1
		return if item then item.Id else ""
	elseif step == 5 then
		local item = hits[nextHit]
		nextHit += 1
		return if item then item.Id else ""
	elseif step == 7 then
		while thrusters[nextThruster] and thrusters[nextThruster].Source ~= "Achievements and quests" do
			nextThruster += 1
		end
		local item = thrusters[nextThruster]
		nextThruster += 1
		return if item then item.Id else ""
	end
	return ""
end

for _, ladder in LADDERS do
	for step, threshold in ladder.Thresholds do
		local titles = ladder.Titles
		table.insert(list, {
			Id = ("ach.%s.%s"):format(ladder.Key, tostring(threshold)),
			Name = ladder.Name .. " " .. ContentUtil.Roman(step),
			Description = if threshold == 1 and ladder.One
				then ladder.One
				else ladder.Verb:format(ContentUtil.FormatCount(threshold)),
			Category = ladder.Category,
			Stat = ladder.Stat,
			Threshold = threshold,
			RewardCredits = math.floor(25 * 1.9 ^ (step - 1)),
			RewardShards = math.min(10, step),
			RewardTitle = if titles and titles[step] then titles[step] else "",
			RewardUnlock = takeUnlock(step),
		})
	end
end

local function special(id: string, name: string, description: string, category: string, stat: string, title: string?)
	table.insert(list, {
		Id = id,
		Name = name,
		Description = description,
		Category = category,
		Stat = stat,
		Threshold = 1,
		RewardCredits = 250,
		RewardShards = 3,
		RewardTitle = title or "",
		RewardUnlock = "",
	})
end

for _, sector in { { "Nebula", "Nebula Ring" }, { "VoidRim", "Void Rim" }, { "Celestial", "Celestial Orbit" } } do
	special(
		"ach.sector." .. string.lower(sector[1]),
		"Charted: " .. sector[2],
		"Discover the " .. sector[2],
		"Progression",
		"Flag:GalaxyFlags." .. sector[1],
		"title.sector." .. string.lower(sector[1])
	)
end

for index, formation in { { "scatter", "Scatter" }, { "beam_link", "Orbital Beam-Link" }, { "halo", "Sovereign Halo" } } do
	special(
		"ach.formation." .. formation[1],
		"Formation: " .. formation[2],
		"Fly the " .. formation[2] .. " formation",
		"Drones",
		"Formation:" .. index,
		"title.formation." .. formation[1]
	)
end

for _, tier in OreRegistry.Tiers do
	special(
		"ach.ore_tier." .. tier.Id,
		"First " .. tier.Label .. " Ore",
		"Mine any " .. tier.Label .. " ore",
		"Codex",
		"OreTier:" .. tier.Index,
		nil
	)
end

for _, archetype in BiomeRegistry.Archetypes do
	special(
		"ach.anomaly." .. archetype.Id,
		"Witness: " .. archetype.Name,
		"Be in the deep-space zone during a " .. archetype.Name,
		"Events",
		"Archetype:" .. archetype.Id,
		"title.witness." .. archetype.Id
	)
end

for _, set in RelicRegistry.Sets do
	special(
		"ach.relic_set." .. set.Id,
		"Curator: " .. set.Name,
		"Collect every " .. set.Name .. " relic",
		"Codex",
		"RelicSet:" .. set.Id,
		"title.curator." .. set.Id
	)
end

for _, branch in { "Miner", "Hauler", "Swarm" } do
	special(
		"ach.branch." .. string.lower(branch),
		branch .. " Line",
		"Choose the " .. branch .. " drone evolution line",
		"Drones",
		"Branch:" .. branch,
		"title.branch." .. string.lower(branch)
	)
end

local registry = ContentUtil.Registry("achievement", list) :: any
registry.Ladders = LADDERS

-- Achievements grouped by stat, thresholds ascending, for cheap checks.
local byStat: { [string]: { Achievement } } = {}
for _, achievement in list do
	byStat[achievement.Stat] = byStat[achievement.Stat] or {}
	table.insert(byStat[achievement.Stat], achievement)
end
for _, group in byStat do
	table.sort(group, function(a, b)
		return a.Threshold < b.Threshold
	end)
end
registry.ByStat = byStat

return registry
