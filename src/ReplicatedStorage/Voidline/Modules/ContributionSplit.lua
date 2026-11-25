local SoftContestConfig = require(script.Parent.Parent.Config.SoftContestConfig)

local ContributionSplit = {}

-- damageMap: { [playerUserId]: number }
-- returns { [userId]: shareFraction } that sum to ~1 among qualifiers
function ContributionSplit.Compute(damageMap: { [number]: number }): { [number]: number }
	local total = 0
	for _, dmg in damageMap do
		total += dmg
	end
	if total <= 0 then
		return {}
	end

	local qualifiers: { [number]: number } = {}
	local topId: number? = nil
	local topDmg = -1
	for userId, dmg in damageMap do
		local pct = dmg / total
		if pct >= SoftContestConfig.MinDamagePercent then
			qualifiers[userId] = dmg
			if dmg > topDmg then
				topDmg = dmg
				topId = userId
			end
		end
	end

	local shares: { [number]: number } = {}
	local qualTotal = 0
	for _, dmg in qualifiers do
		qualTotal += dmg
	end
	if qualTotal <= 0 or not topId then
		return {}
	end

	-- Top gets exclusive 40% pool + share of remaining 60%
	for userId, dmg in qualifiers do
		local prop = (dmg / qualTotal) * SoftContestConfig.ProportionalPool
		shares[userId] = prop
	end
	shares[topId] = (shares[topId] or 0) + SoftContestConfig.TopContributorPool
	return shares
end

return ContributionSplit
