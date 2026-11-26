--!strict
-- One place to look up any content ID, count content and decide what the
-- Codex tracks. Registries live in ReplicatedStorage code, so clients look
-- entries up locally and remotes only ever carry string IDs.
local Content = script.Parent
local OreRegistry = require(Content.OreRegistry)
local BiomeRegistry = require(Content.BiomeRegistry)
local RelicRegistry = require(Content.RelicRegistry)
local DroneRegistry = require(Content.DroneRegistry)
local TitleRegistry = require(Content.TitleRegistry)
local AchievementRegistry = require(Content.AchievementRegistry)
local CitadelRegistry = require(Content.CitadelRegistry)
local QuestRegistry = require(Content.QuestRegistry)
local WorldEventRegistry = require(Content.WorldEventRegistry)

local ContentIndex = {}

ContentIndex.Registries = {
	{ Kind = "ore", Label = "Ore variants", Registry = OreRegistry, Codex = true },
	{ Kind = "biome", Label = "Anomaly biomes", Registry = BiomeRegistry, Codex = true },
	{ Kind = "hazard", Label = "Hazards", Registry = BiomeRegistry.Hazards, Codex = true },
	{ Kind = "relic", Label = "Relics", Registry = RelicRegistry, Codex = true },
	{ Kind = "drone", Label = "Drone evolutions & cosmetics", Registry = DroneRegistry, Codex = true },
	{ Kind = "event", Label = "World events", Registry = WorldEventRegistry, Codex = true },
	{ Kind = "title", Label = "Titles", Registry = TitleRegistry, Codex = false },
	{ Kind = "achievement", Label = "Achievements", Registry = AchievementRegistry, Codex = false },
	{ Kind = "citadel", Label = "Citadel tiers", Registry = CitadelRegistry, Codex = false },
	{ Kind = "quest", Label = "Quests", Registry = QuestRegistry, Codex = false },
}

local lookup: { [string]: { Entry: any, Kind: string, Codex: boolean } } = {}
local codexTotal = 0
for _, info in ContentIndex.Registries do
	for _, entry in info.Registry.List do
		assert(lookup[entry.Id] == nil, "content id used twice: " .. entry.Id)
		lookup[entry.Id] = { Entry = entry, Kind = info.Kind, Codex = info.Codex }
		if info.Codex then
			codexTotal += 1
		end
	end
end
ContentIndex.CodexTotal = codexTotal

function ContentIndex.Get(id: string): (any, string?)
	local hit = lookup[id]
	if hit then
		return hit.Entry, hit.Kind
	end
	return nil, nil
end

function ContentIndex.IsCodexId(id: string): boolean
	local hit = lookup[id]
	return hit ~= nil and hit.Codex
end

function ContentIndex.Totals(): ({ { Kind: string, Label: string, Count: number } }, number)
	local rows = {}
	local total = 0
	for _, info in ContentIndex.Registries do
		table.insert(rows, { Kind = info.Kind, Label = info.Label, Count = info.Registry.Count })
		total += info.Registry.Count
	end
	return rows, total
end

-- Codex milestones: permanent credit multiplier steps (spec §10).
ContentIndex.CodexMilestones = {
	{ Count = 10, Bonus = 0.02 },
	{ Count = 25, Bonus = 0.03 },
	{ Count = 50, Bonus = 0.05 },
	{ Count = 100, Bonus = 0.05 },
	{ Count = 175, Bonus = 0.05 },
	{ Count = 250, Bonus = 0.05 },
	{ Count = 350, Bonus = 0.05 },
	{ Count = 450, Bonus = 0.05 },
	{ Count = 550, Bonus = 0.05 },
	{ Count = 650, Bonus = 0.10 },
}

function ContentIndex.CodexMultiplier(count: number): number
	local mult = 1
	for _, milestone in ContentIndex.CodexMilestones do
		if count >= milestone.Count then
			mult += milestone.Bonus
		end
	end
	return mult
end

return ContentIndex
