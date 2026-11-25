--!strict
-- Achievement evaluation and grants (pure). Stat keys come from
-- AchievementRegistry; derived keys are resolved here.
local Content = script.Parent.Parent.Content
local AchievementRegistry = require(Content.AchievementRegistry)
local RelicRegistry = require(Content.RelicRegistry)

local AchievementRules = {}

local function count(map: { [string]: any }): number
	local n = 0
	for _ in map do
		n += 1
	end
	return n
end
AchievementRules.Count = count

function AchievementRules.StatValue(profile: any, stat: string): number
	local direct = profile[stat]
	if type(direct) == "number" then
		return direct
	end
	if stat == "CodexCount" then
		return count(profile.Codex)
	elseif stat == "RelicCount" then
		return count(profile.Relics)
	end
	local prefix, arg = string.match(stat, "^(%a+):(.+)$")
	if prefix == "Flag" then
		local node = profile
		for part in string.gmatch(arg :: string, "[^%.]+") do
			node = if type(node) == "table" then node[part] else nil
		end
		return if node == true then 1 else 0
	elseif prefix == "RelicSet" then
		return if RelicRegistry.SetComplete(profile.Relics, arg :: string) then 1 else 0
	elseif prefix == "Branch" then
		return if profile.DroneBranch == arg then 1 else 0
	elseif prefix ~= nil then
		-- Formation:<n>, OreTier:<n>, Archetype:<id> are plain counters.
		return profile.Stats[stat] or 0
	end
	return profile.Stats[stat] or 0
end

export type Grant = {
	Id: string,
	Name: string,
	Credits: number,
	Shards: number,
	Title: string,
	Unlock: string,
}

function AchievementRules.Grant(profile: any, achievement: any, unixTime: number): Grant?
	if profile.Achievements[achievement.Id] then
		return nil
	end
	profile.Achievements[achievement.Id] = unixTime
	profile.Credits += achievement.RewardCredits
	profile.LifetimeCredits += achievement.RewardCredits
	profile.VoidShards += achievement.RewardShards
	profile.LifetimeShards += achievement.RewardShards
	if achievement.RewardTitle ~= "" then
		profile.Titles[achievement.RewardTitle] = true
	end
	if achievement.RewardUnlock ~= "" then
		profile.Unlocks[achievement.RewardUnlock] = true
	end
	return {
		Id = achievement.Id,
		Name = achievement.Name,
		Credits = achievement.RewardCredits,
		Shards = achievement.RewardShards,
		Title = achievement.RewardTitle,
		Unlock = achievement.RewardUnlock,
	}
end

-- Grants every newly reached achievement for `stat`. Rewards that move other
-- stats (credits, shards) are re-checked until nothing new unlocks.
function AchievementRules.Check(profile: any, stat: string, unixTime: number): { Grant }
	local granted = {}
	local queue = { stat }
	local queued = { [stat] = true }
	local guard = 0
	while #queue > 0 and guard < 64 do
		guard += 1
		local current = table.remove(queue, 1) :: string
		queued[current] = nil
		local group = AchievementRegistry.ByStat[current]
		if group then
			local value = AchievementRules.StatValue(profile, current)
			for _, achievement in group do
				if achievement.Threshold > value then
					break
				end
				local grant = AchievementRules.Grant(profile, achievement, unixTime)
				if grant then
					table.insert(granted, grant)
					for _, follow in { "LifetimeCredits", "LifetimeShards" } do
						if not queued[follow] then
							queued[follow] = true
							table.insert(queue, follow)
						end
					end
				end
			end
		end
	end
	return granted
end

-- Every stat key the registry uses (for a full re-check on load).
function AchievementRules.AllStats(): { string }
	local stats = {}
	for stat in AchievementRegistry.ByStat do
		table.insert(stats, stat)
	end
	table.sort(stats)
	return stats
end

return AchievementRules
