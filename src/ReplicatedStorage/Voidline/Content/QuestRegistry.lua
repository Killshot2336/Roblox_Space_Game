--!strict
-- Daily (3 per UTC day) and weekly (3 per week) quest templates. Assignment
-- is seeded by (day or week, UserId) so it is stable across servers.
-- FROZEN lists: DAILY, WEEKLY (append-only).
local ContentUtil = require(script.Parent.ContentUtil)

export type Quest = {
	Id: string,
	Name: string,
	Cadence: string, -- "Daily" | "Weekly"
	Stat: string,
	Target: number,
	ScalesWithTier: boolean,
	RewardCredits: number,
	RewardShards: number,
	RewardCosmetic: boolean,
}

-- { stat key, name when target is 1, name pattern, targets, scales with station tier }
local DAILY: { { any } } = {
	{ "RocksMined", "Break a rock", "Break %s rocks", { 25, 50, 100 }, false },
	{ "Sells", "Refine cargo once", "Refine cargo %s times", { 5, 10, 20 }, false },
	{ "CreditsEarned", "Earn a Credit", "Earn %s Credits", { 200, 600, 1500 }, true },
	{ "ShardsFound", "Find a Void Shard", "Find %s Void Shards", { 1, 3, 5 }, false },
	{ "UpgradesBought", "Buy an upgrade", "Buy %s upgrades", { 3, 5, 10 }, false },
	{ "MeteorsContested", "Qualify on a boss meteor", "Qualify on %s boss meteors", { 1, 3 }, false },
	{ "EventsJoined", "Join a world event", "Join %s world events", { 1, 2 }, false },
	{ "ArtifactsForged", "Forge an artifact", "Forge %s artifacts", { 1, 2 }, false },
	{ "HazardsSurvived", "Fly through a hazard", "Fly through %s hazards", { 1, 3 }, false },
	{ "AnomaliesSeen", "Witness an anomaly", "Witness %s anomalies", { 1 }, false },
	{ "RiftClears", "Clear the Void Rift", "Clear the Void Rift %s times", { 1 }, false },
	{ "SquadMinutes", "Fly a minute in a squad", "Fly %s minutes in a squad", { 5, 15 }, false },
	{ "PlaytimeMinutes", "Fly for a minute", "Fly for %s minutes", { 10, 20, 30 }, false },
	{ "OreStored", "Store an ore", "Store %s ore", { 100, 250, 500 }, true },
	{ "Warps", "Warp once", "Warp %s times", { 1, 3 }, false },
}

local WEEKLY: { { any } } = {
	{ "RocksMined", "Break a rock", "Break %s rocks", { 500, 1000, 2500 }, false },
	{ "Sells", "Refine cargo once", "Refine cargo %s times", { 100, 250 }, false },
	{ "CreditsEarned", "Earn a Credit", "Earn %s Credits", { 5000, 15000, 40000 }, true },
	{ "ShardsFound", "Find a Void Shard", "Find %s Void Shards", { 20, 50 }, false },
	{ "MeteorsContested", "Qualify on a boss meteor", "Qualify on %s boss meteors", { 10, 25 }, false },
	{ "EventsJoined", "Join a world event", "Join %s world events", { 10 }, false },
	{ "ArtifactsForged", "Forge an artifact", "Forge %s artifacts", { 10 }, false },
	{ "RiftClears", "Clear the Void Rift", "Clear the Void Rift %s times", { 5 }, false },
	{ "SquadMinutes", "Fly a minute in a squad", "Fly %s minutes in a squad", { 120 }, false },
	{ "PlaytimeMinutes", "Fly for a minute", "Fly for %s minutes", { 180 }, false },
	{ "UpgradesBought", "Buy an upgrade", "Buy %s upgrades", { 50 }, false },
	{ "HazardsSurvived", "Fly through a hazard", "Fly through %s hazards", { 25 }, false },
}

local list: { Quest } = {}

local function build(cadence: string, templates: { any })
	for _, template in templates do
		local stat, one, pattern, targets, scales = template[1], template[2], template[3], template[4], template[5]
		for step, target in targets do
			local id = ("quest.%s.%s.%d"):format(string.lower(cadence), ContentUtil.Slug(stat), target)
			local weekly = cadence == "Weekly"
			table.insert(list, {
				Id = id,
				Name = if target == 1 then one else pattern:format(ContentUtil.FormatCount(target)),
				Cadence = cadence,
				Stat = stat,
				Target = target,
				ScalesWithTier = scales,
				RewardCredits = (if weekly then 400 else 60) * step,
				RewardShards = if weekly then 8 + 4 * step else 1 + step,
				RewardCosmetic = weekly and step == #targets,
			})
		end
	end
end

build("Daily", DAILY)
build("Weekly", WEEKLY)

local registry = ContentUtil.Registry("quest", list) :: any

local daily, weekly = {}, {}
for _, quest in list do
	table.insert(if quest.Cadence == "Daily" then daily else weekly, quest)
end
registry.Daily = daily
registry.Weekly = weekly
registry.PerCadence = 3

-- Display name for a pilot whose target was scaled by station tier.
function registry.NameFor(quest: Quest, target: number): string
	if not quest.ScalesWithTier then
		return quest.Name
	end
	local templates: { { any } } = if quest.Cadence == "Daily" then DAILY else WEEKLY
	for _, template in templates do
		if template[1] == quest.Stat then
			return template[3]:format(ContentUtil.FormatCount(target))
		end
	end
	return quest.Name
end

-- Target for a pilot at `stationTier` (credit/ore quests grow with tier).
function registry.TargetFor(quest: Quest, stationTier: number): number
	if not quest.ScalesWithTier then
		return quest.Target
	end
	return math.floor(quest.Target * 1.6 ^ math.max(0, stationTier - 1))
end

-- Three distinct quests for this pilot and period.
function registry.Assign(cadence: string, periodKey: string, userId: number): { Quest }
	local pool = if cadence == "Daily" then daily else weekly
	local rng = ContentUtil.Rng("quest-" .. cadence, periodKey .. ":" .. tostring(userId))
	local picked, usedStats = {}, {}
	for _, quest in rng:Shuffle(table.clone(pool)) do
		if not usedStats[quest.Stat] then
			usedStats[quest.Stat] = true
			table.insert(picked, quest)
			if #picked >= registry.PerCadence then
				break
			end
		end
	end
	return picked
end

return registry
