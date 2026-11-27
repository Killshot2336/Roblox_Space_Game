--!strict
-- Pure HUD copy for sim clarity: next upgrade goal and soft "come back" cues.
local Config = script.Parent.Parent.Config
local EconomyConfig = require(Config.EconomyConfig)
local EconomyRules = require(script.Parent.EconomyRules)
local ProgressionRules = require(script.Parent.ProgressionRules)

local HudCueRules = {}

local function nextUpgrade(profile: any, ctx: any): (string?, number?)
	if not profile.TutorialComplete then
		for _, entry in { { "Drill", "Drill" }, { "Cargo", "Cargo" }, { "Drone", "DroneSlot" } } do
			if not profile.TutorialFlags[entry[1]] then
				return entry[2], EconomyRules.UpgradeCost(profile, entry[2], ctx)
			end
		end
	end
	local best: string?, bestCost = nil, math.huge
	for _, id in EconomyConfig.UpgradeOrder do
		local ok, reason = EconomyRules.CanUpgrade(profile, id, ctx)
		if ok or reason == "funds" then
			local cost = EconomyRules.UpgradeCost(profile, id, ctx) :: number
			if cost < bestCost then
				best, bestCost = id, cost
			end
		end
	end
	if best then
		return best, bestCost
	end
	return nil, nil
end

function HudCueRules.NextGoalLine(profile: any, ctx: any): string
	local id, cost = nextUpgrade(profile, ctx)
	if id and cost then
		local def = EconomyConfig.Upgrades[id]
		local label = if def then def.Label else id
		local afford = profile.Credits >= cost
		if afford then
			return ("NEXT GOAL · %s · tap UPGRADE (U)"):format(label)
		end
		return ("NEXT GOAL · %s · need %d credits"):format(label, math.ceil(cost))
	end
	if not profile.TutorialComplete then
		return "NEXT GOAL · finish tutorial boosts"
	end
	return "NEXT GOAL · all station upgrades maxed"
end

function HudCueRules.ComebackCue(profile: any, unixTime: number): string?
	if ProgressionRules.CanClaimDaily(profile, unixTime) then
		return "◈ DAILY READY — open menu (C)"
	end
	for _, list in { profile.Quests.Daily, profile.Quests.Weekly } do
		for _, entry in list do
			if not entry.Done and type(entry.Target) == "number" and entry.Target > 0 then
				local progress = if type(entry.Progress) == "number" then entry.Progress else 0
				local ratio = progress / entry.Target
				if ratio >= 0.85 and ratio < 1 then
					local pct = math.floor(ratio * 100 + 0.5)
					return ("◈ QUEST · %s · %d%%"):format(tostring(entry.Name), pct)
				end
			end
		end
	end
	ProgressionRules.RefreshForgeDay(profile, unixTime)
	if profile.ForgeJobEndsAt <= unixTime and not ProgressionRules.ForgeCooling(profile) then
		return "◈ FORGE OPEN — visit your Sovereign station"
	end
	return nil
end

return HudCueRules
