--!strict
-- Forge, rebirth, daily streak and code rules (spec §5, §8, §11, §12).
local Config = script.Parent.Parent.Config
local ForgeConfig = require(Config.ForgeConfig)
local RebirthConfig = require(Config.RebirthConfig)
local DailyConfig = require(Config.DailyConfig)
local CodesConfig = require(Config.CodesConfig)

local ProgressionRules = {}

local SECONDS_PER_DAY = 86400

function ProgressionRules.DayKey(unixTime: number): string
	local d = os.date("!*t", math.floor(unixTime)) :: any
	return string.format("%04d-%02d-%02d", d.year, d.month, d.day)
end

-- Weeks start Monday 00:00 UTC (1970-01-05 was a Monday).
function ProgressionRules.WeekKey(unixTime: number): string
	local week = math.floor((unixTime - 4 * SECONDS_PER_DAY) / (7 * SECONDS_PER_DAY))
	return "W" .. tostring(week)
end

-- Forge ---------------------------------------------------------------------

function ProgressionRules.RefreshForgeDay(profile: any, unixTime: number)
	local key = ProgressionRules.DayKey(unixTime)
	if profile.ForgeDayKey ~= key then
		profile.ForgeDayKey = key
		profile.ForgeTokensEarnedToday = 0
	end
end

function ProgressionRules.ForgeCooling(profile: any): boolean
	return profile.ForgeTokensEarnedToday >= ForgeConfig.DailyTokenSoftCap
end

function ProgressionRules.ForgeDuration(profile: any): number
	local duration = ForgeConfig.ForgeDurationSeconds
	if ProgressionRules.ForgeCooling(profile) then
		duration /= ForgeConfig.CoolingMultiplier
	end
	return duration
end

-- Returns ok, reason ("busy" | "shards"), duration.
function ProgressionRules.StartForge(profile: any, unixTime: number): (boolean, string?, number)
	ProgressionRules.RefreshForgeDay(profile, unixTime)
	if profile.ForgeJobEndsAt > 0 then
		return false, "busy", 0
	end
	if profile.VoidShards < ForgeConfig.ShardsPerArtifact then
		return false, "shards", 0
	end
	local duration = ProgressionRules.ForgeDuration(profile)
	profile.VoidShards -= ForgeConfig.ShardsPerArtifact
	profile.ForgeJobEndsAt = unixTime + duration
	return true, nil, duration
end

-- Completes a finished job (also on rejoin: the job end time is saved).
function ProgressionRules.CollectForge(profile: any, unixTime: number): boolean
	if profile.ForgeJobEndsAt > 0 and unixTime >= profile.ForgeJobEndsAt then
		profile.ForgeJobEndsAt = 0
		profile.Artifacts += 1
		return true
	end
	return false
end

function ProgressionRules.TurnInArtifact(profile: any, unixTime: number): (boolean, number)
	ProgressionRules.RefreshForgeDay(profile, unixTime)
	if profile.Artifacts < 1 then
		return false, 0
	end
	local tokens = ForgeConfig.TokensPerArtifact
	profile.Artifacts -= 1
	profile.VoidlineTokens += tokens
	profile.LifetimeTokens += tokens
	profile.ForgeTokensEarnedToday += tokens
	return true, tokens
end

-- Rebirth -------------------------------------------------------------------

function ProgressionRules.CanRebirth(profile: any): boolean
	return profile.StationTier >= RebirthConfig.RequiredStationTier
end

-- Resets credits, station tier, drill/cargo and cargo hold. Keeps passes,
-- tokens, shards, artifacts, relics, codex, squads, cosmetics, drone slots/tier
-- and discovered sectors.
function ProgressionRules.Rebirth(profile: any): (number, number)
	local n = profile.Rebirths + 1
	local shards = RebirthConfig.ShardPayout(n)
	profile.Rebirths = n
	profile.CreditMult = RebirthConfig.CreditMultiplier(n)
	profile.Credits = 0
	profile.Ore = 0
	profile.CargoValue = 0
	profile.StationTier = 1
	profile.DrillLevel = 1
	profile.CargoLevel = 1
	profile.VoidShards += shards
	profile.LifetimeShards += shards
	return n, shards
end

-- Daily streak ----------------------------------------------------------------

-- Updates the streak position (1..7) on the first login of a UTC day.
function ProgressionRules.OnLogin(profile: any, unixTime: number): boolean
	local today = ProgressionRules.DayKey(unixTime)
	if profile.LastLoginDay == today then
		return false
	end
	local yesterday = ProgressionRules.DayKey(unixTime - SECONDS_PER_DAY)
	if profile.LastLoginDay == yesterday and profile.DailyStreak >= 1 then
		profile.DailyStreak = (profile.DailyStreak % DailyConfig.CycleLength) + 1
	else
		profile.DailyStreak = 1
	end
	profile.LastLoginDay = today
	return true
end

function ProgressionRules.CanClaimDaily(profile: any, unixTime: number): boolean
	return profile.LastDailyClaimDay ~= ProgressionRules.DayKey(unixTime)
end

function ProgressionRules.ClaimDaily(profile: any, unixTime: number): (boolean, DailyConfig.DayReward?, number)
	ProgressionRules.OnLogin(profile, unixTime)
	if not ProgressionRules.CanClaimDaily(profile, unixTime) then
		return false, nil, profile.DailyStreak
	end
	local day = math.clamp(profile.DailyStreak, 1, DailyConfig.CycleLength)
	local reward = DailyConfig.Rewards[day]
	profile.LastDailyClaimDay = ProgressionRules.DayKey(unixTime)
	profile.Credits += reward.Credits
	profile.LifetimeCredits += reward.Credits
	profile.VoidShards += reward.VoidShards
	profile.LifetimeShards += reward.VoidShards
	if reward.TrialPerk then
		local expires = unixTime + (reward.TrialHours or 24) * 3600
		profile.TrialVouchers[reward.TrialPerk] = math.max(profile.TrialVouchers[reward.TrialPerk] or 0, expires)
	end
	return true, reward, day
end

-- Codes -----------------------------------------------------------------------

function ProgressionRules.NormalizeCode(raw: any): string?
	if type(raw) ~= "string" or #raw > 64 then
		return nil
	end
	local code = string.upper((string.gsub(raw, "%s+", "")))
	if #code == 0 or #code > CodesConfig.MaxLength or string.find(code, "[^A-Z0-9]") then
		return nil
	end
	return code
end

-- Returns ok, reason ("invalid" | "unknown" | "used"), normalized code.
function ProgressionRules.RedeemCode(profile: any, raw: any): (boolean, string?, string?)
	local code = ProgressionRules.NormalizeCode(raw)
	if not code then
		return false, "invalid", nil
	end
	local reward = CodesConfig.Codes[code]
	if not reward then
		return false, "unknown", code
	end
	if profile.RedeemedCodes[code] then
		return false, "used", code
	end
	profile.RedeemedCodes[code] = true
	profile.Credits += reward.Credits
	profile.LifetimeCredits += reward.Credits
	profile.VoidShards += reward.VoidShards
	profile.LifetimeShards += reward.VoidShards
	if reward.Title then
		profile.Titles[reward.Title] = true
	end
	return true, nil, code
end

return ProgressionRules
