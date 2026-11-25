--!strict
-- Dual-currency store rules (spec §9). Tokens buy the same passes as Robux at
-- a 15-20% discount; tokens are earn-only and never tradeable.
local Config = script.Parent.Parent.Config
local MonetizationConfig = require(Config.MonetizationConfig)

local StoreRules = {}

-- Perks from purchases plus unexpired trial vouchers.
function StoreRules.EffectivePerks(
	profile: any,
	unixTime: number,
	ownedGamePasses: { [string]: boolean }?
): { [string]: boolean }
	local perks = {}
	for perkId, owned in profile.OwnedPerks do
		if owned then
			perks[perkId] = true
		end
	end
	if ownedGamePasses then
		for perkId, owned in ownedGamePasses do
			if owned then
				perks[perkId] = true
			end
		end
	end
	for perkId, expires in profile.TrialVouchers do
		if type(expires) == "number" and expires > unixTime then
			perks[perkId] = true
		end
	end
	return perks
end

-- Returns ok, reason ("unknown" | "owned" | "tokens"), price.
function StoreRules.BuyWithTokens(profile: any, passId: string): (boolean, string?, number)
	local pass = MonetizationConfig.GetPass(passId)
	if not pass then
		return false, "unknown", 0
	end
	if profile.OwnedPerks[passId] then
		return false, "owned", pass.Tokens
	end
	if profile.VoidlineTokens < pass.Tokens then
		return false, "tokens", pass.Tokens
	end
	profile.VoidlineTokens -= pass.Tokens
	profile.OwnedPerks[passId] = true
	return true, nil, pass.Tokens
end

-- One-time grants that come with owning a pass (however it was obtained).
-- Returns true when something new was granted.
function StoreRules.ApplyPassGrants(profile: any, passId: string): boolean
	if profile.PassGrants[passId] then
		return false
	end
	profile.PassGrants[passId] = true
	if passId == "StarterBundle" then
		local credits = MonetizationConfig.StarterBundleCredits
		profile.Credits += credits
		profile.LifetimeCredits += credits
		profile.Titles["title.pass.pioneer"] = true
		profile.Unlocks["thruster.gold_comet"] = true
	elseif passId == "VoidSovereignVIP" then
		profile.Titles["title.pass.void_sovereign"] = true
	elseif passId == "EternalArchitect" then
		profile.Titles["title.pass.eternal_architect"] = true
	elseif passId == "LaserOverclock" then
		profile.Unlocks["laser.overclock"] = true
	end
	return true
end

return StoreRules
