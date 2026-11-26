--!strict
-- Soft-contest reward split (GAME_DESIGN.md §6).
-- Qualify at >= MinDamagePercent of total damage. The #1 contributor takes the
-- TopContributorPool bonus plus their proportional share of ProportionalPool;
-- every other qualifier gets their proportional share. Shares sum to exactly 1
-- across qualifiers (or the result is empty when nobody dealt damage).
local SoftContestConfig = require(script.Parent.Parent.Config.SoftContestConfig)

local ContributionSplit = {}

local function sanitize(damage: any): number
	if type(damage) ~= "number" or damage ~= damage or damage <= 0 or damage == math.huge then
		return 0
	end
	return damage
end

-- Highest damage wins; exact ties resolve to the lowest UserId so the
-- "#1 TOP MINER" callout never depends on table iteration order.
function ContributionSplit.TopContributor(damageMap: { [number]: number }): number?
	local topId: number? = nil
	local topDamage = 0
	for userId, raw in damageMap do
		local damage = sanitize(raw)
		if damage > 0 then
			if damage > topDamage or (damage == topDamage and topId ~= nil and userId < topId) then
				topId = userId
				topDamage = damage
			end
		end
	end
	return topId
end

function ContributionSplit.Compute(damageMap: { [number]: number }): { [number]: number }
	-- Normalise by the largest hit first so huge values cannot overflow to inf.
	local maxDamage = 0
	for _, raw in damageMap do
		local damage = sanitize(raw)
		if damage > maxDamage then
			maxDamage = damage
		end
	end
	if maxDamage <= 0 then
		return {}
	end

	local normalised: { [number]: number } = {}
	local total = 0
	for userId, raw in damageMap do
		local damage = sanitize(raw)
		if damage > 0 then
			local n = damage / maxDamage
			normalised[userId] = n
			total += n
		end
	end

	local qualifiers: { [number]: number } = {}
	local qualifierTotal = 0
	for userId, n in normalised do
		if n / total >= SoftContestConfig.MinDamagePercent then
			qualifiers[userId] = n
			qualifierTotal += n
		end
	end

	local topId = ContributionSplit.TopContributor(qualifiers)
	if topId == nil or qualifierTotal <= 0 then
		return {}
	end

	local shares: { [number]: number } = {}
	for userId, n in qualifiers do
		shares[userId] = (n / qualifierTotal) * SoftContestConfig.ProportionalPool
	end
	shares[topId] += SoftContestConfig.TopContributorPool
	return shares
end

-- Convert fractional shares into whole-number payouts (largest remainder).
-- The sum of payouts never exceeds `pool`.
function ContributionSplit.Allocate(shares: { [number]: number }, pool: number): { [number]: number }
	local payouts: { [number]: number } = {}
	local whole = math.max(0, math.floor(sanitize(pool)))
	local remainders: { { userId: number, remainder: number } } = {}
	local assigned = 0
	for userId, share in shares do
		local exact = math.max(0, sanitize(share)) * whole
		local base = math.floor(exact)
		payouts[userId] = base
		assigned += base
		table.insert(remainders, { userId = userId, remainder = exact - base })
	end
	table.sort(remainders, function(a, b)
		if a.remainder ~= b.remainder then
			return a.remainder > b.remainder
		end
		return a.userId < b.userId
	end)
	local leftover = whole - assigned
	local i = 1
	while leftover > 0 and i <= #remainders do
		local userId = remainders[i].userId
		payouts[userId] += 1
		leftover -= 1
		i += 1
	end
	return payouts
end

return ContributionSplit
