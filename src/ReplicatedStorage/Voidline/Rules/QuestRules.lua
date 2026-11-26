--!strict
-- Daily/weekly quest state (pure). Quests auto-complete and pay out the
-- moment their target is reached: no extra claim step to forget.
local Rules = script.Parent
local Content = Rules.Parent.Content
local QuestRegistry = require(Content.QuestRegistry)
local DroneRegistry = require(Content.DroneRegistry)
local ProgressionRules = require(Rules.ProgressionRules)

local QuestRules = {}

export type Completion = {
	Id: string,
	Name: string,
	Credits: number,
	Shards: number,
	Unlock: string,
}

local function assign(cadence: string, periodKey: string, userId: number, stationTier: number): { any }
	local out = {}
	for _, quest in QuestRegistry.Assign(cadence, periodKey, userId) do
		local target = QuestRegistry.TargetFor(quest, stationTier)
		table.insert(out, {
			Id = quest.Id,
			Name = QuestRegistry.NameFor(quest, target),
			Stat = quest.Stat,
			Target = target,
			Progress = 0,
			Done = false,
		})
	end
	return out
end

-- Rolls new quests when the UTC day/week changed. Returns true if refreshed.
function QuestRules.Refresh(profile: any, unixTime: number, userId: number): boolean
	local quests = profile.Quests
	local changed = false
	local day = ProgressionRules.DayKey(unixTime)
	if quests.DayKey ~= day then
		quests.DayKey = day
		quests.Daily = assign("Daily", day, userId, profile.StationTier)
		changed = true
	end
	local week = ProgressionRules.WeekKey(unixTime)
	if quests.WeekKey ~= week then
		quests.WeekKey = week
		quests.Weekly = assign("Weekly", week, userId, profile.StationTier)
		changed = true
	end
	return changed
end

local function lockedCosmetics(profile: any): { string }
	local out = {}
	for _, cosmetic in DroneRegistry.Cosmetics do
		if cosmetic.Source == "Achievements and quests" and not profile.Unlocks[cosmetic.Id] then
			table.insert(out, cosmetic.Id)
		end
	end
	return out
end

-- Adds progress for `stat`. `rng` (NextInteger) picks cosmetic rewards.
function QuestRules.Progress(profile: any, stat: string, amount: number, rng: any): { Completion }
	local completions = {}
	if amount <= 0 or amount ~= amount then
		return completions
	end
	for _, list in { profile.Quests.Daily, profile.Quests.Weekly } do
		for _, entry in list do
			if not entry.Done and entry.Stat == stat then
				entry.Progress = math.min(entry.Target, entry.Progress + amount)
				if entry.Progress >= entry.Target then
					entry.Done = true
					local quest = QuestRegistry.ById[entry.Id]
					local unlock = ""
					if quest then
						profile.Credits += quest.RewardCredits
						profile.LifetimeCredits += quest.RewardCredits
						profile.VoidShards += quest.RewardShards
						profile.LifetimeShards += quest.RewardShards
						if quest.RewardCosmetic then
							local pool = lockedCosmetics(profile)
							if #pool > 0 then
								unlock = pool[rng:NextInteger(1, #pool)]
								profile.Unlocks[unlock] = true
							end
						end
					end
					table.insert(completions, {
						Id = entry.Id,
						Name = entry.Name,
						Credits = if quest then quest.RewardCredits else 0,
						Shards = if quest then quest.RewardShards else 0,
						Unlock = unlock,
					})
				end
			end
		end
	end
	return completions
end

return QuestRules
