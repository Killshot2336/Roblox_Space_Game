--!strict
-- Pure economy rules shared by server services, the client HUD and tests.
-- Functions that mutate take the profile table explicitly; nothing here
-- touches Instances, remotes or DataStores.
local Config = script.Parent.Parent.Config
local EconomyConfig = require(Config.EconomyConfig)
local GalaxyConfig = require(Config.GalaxyConfig)
local RebirthConfig = require(Config.RebirthConfig)
local DroneConfig = require(Config.DroneConfig)

export type Ctx = {
	Perks: { [string]: boolean }?,
	CreditBoost: number?,
	CodexMult: number?,
}

local EconomyRules = {}

function EconomyRules.HasPerk(ctx: Ctx?, perkId: string): boolean
	return ctx ~= nil and ctx.Perks ~= nil and ctx.Perks[perkId] == true
end

function EconomyRules.CargoCap(profile: any): number
	return EconomyConfig.CargoCapacityForLevel(profile.CargoLevel)
end

function EconomyRules.CargoSpace(profile: any): number
	return math.max(0, EconomyRules.CargoCap(profile) - profile.Ore)
end

function EconomyRules.ActiveSector(profile: any): string
	return GalaxyConfig.ActiveSector(profile)
end

function EconomyRules.UnitValue(sectorId: string, variantMult: number?): number
	local base = EconomyConfig.OreValueBySector[sectorId] or EconomyConfig.CreditsPerOreBase
	return base * (variantMult or 1)
end

-- Adds ore up to the cargo cap. Returns how many units were stored.
function EconomyRules.AddOre(profile: any, amount: number, unitValue: number): number
	if amount ~= amount or amount <= 0 or unitValue ~= unitValue or unitValue < 0 then
		return 0
	end
	local added = math.min(math.floor(amount), EconomyRules.CargoSpace(profile))
	if added <= 0 then
		return 0
	end
	profile.Ore += added
	profile.CargoValue += added * unitValue
	profile.LifetimeOre += added
	return added
end

function EconomyRules.CreditMultiplier(profile: any, ctx: Ctx?): number
	local mult = RebirthConfig.CreditMultiplier(profile.Rebirths)
	if EconomyRules.HasPerk(ctx, "Credits2x") then
		mult *= 2
	end
	if EconomyRules.HasPerk(ctx, "VoidSovereignVIP") then
		mult *= 1.1
	end
	if ctx then
		mult *= (ctx.CreditBoost or 1) * (ctx.CodexMult or 1)
	end
	return mult
end

function EconomyRules.SellPayout(profile: any, ctx: Ctx?): number
	if profile.Ore <= 0 or profile.CargoValue <= 0 then
		return 0
	end
	return math.floor(profile.CargoValue * EconomyRules.CreditMultiplier(profile, ctx) + 1e-9)
end

-- Sells the whole cargo hold. Returns credits paid and ore sold.
function EconomyRules.Sell(profile: any, ctx: Ctx?): (number, number)
	local ore = profile.Ore
	local payout = EconomyRules.SellPayout(profile, ctx)
	if ore <= 0 then
		return 0, 0
	end
	profile.Ore = 0
	profile.CargoValue = 0
	EconomyRules.AddCredits(profile, payout)
	return payout, ore
end

function EconomyRules.AddCredits(profile: any, amount: number)
	if amount ~= amount or amount <= 0 or amount == math.huge then
		return
	end
	profile.Credits += amount
	profile.LifetimeCredits += amount
end

function EconomyRules.NormalizeUpgradeId(upgradeId: string): string
	if upgradeId == "Drone2" then
		return "DroneSlot"
	end
	return upgradeId
end

function EconomyRules.UpgradeCost(profile: any, upgradeId: string, ctx: Ctx?): number?
	local def = EconomyConfig.Upgrades[EconomyRules.NormalizeUpgradeId(upgradeId)]
	if not def then
		return nil
	end
	local cost = def.Cost(profile[def.Stat])
	if def.Id == "StationTier" and EconomyRules.HasPerk(ctx, "EternalArchitect") then
		cost = math.floor(cost * 0.9)
	end
	return cost
end

-- Returns ok plus a short reason code: "unknown" | "max" | "locked" | "funds".
function EconomyRules.CanUpgrade(profile: any, upgradeId: string, ctx: Ctx?): (boolean, string?)
	local id = EconomyRules.NormalizeUpgradeId(upgradeId)
	local def = EconomyConfig.Upgrades[id]
	if not def then
		return false, "unknown"
	end
	if profile[def.Stat] >= def.Max then
		return false, "max"
	end
	if id == "DroneTier" and profile.StationTier < 2 * profile.DroneTier then
		return false, "locked"
	end
	local cost = EconomyRules.UpgradeCost(profile, id, ctx) :: number
	if profile.Credits < cost then
		return false, "funds"
	end
	return true, nil
end

-- Applies an upgrade. `branch` picks the drone evolution line at the branch stage.
function EconomyRules.ApplyUpgrade(
	profile: any,
	upgradeId: string,
	ctx: Ctx?,
	branch: string?
): (boolean, number, string?)
	local id = EconomyRules.NormalizeUpgradeId(upgradeId)
	local ok, reason = EconomyRules.CanUpgrade(profile, id, ctx)
	if not ok then
		return false, 0, reason
	end
	local def = EconomyConfig.Upgrades[id]
	local cost = EconomyRules.UpgradeCost(profile, id, ctx) :: number
	profile.Credits -= cost
	profile[def.Stat] += 1
	if id == "DroneTier" and profile.DroneTier >= DroneConfig.BranchStage and profile.DroneBranch == "" then
		profile.DroneBranch = if branch and DroneConfig.Branches[branch] then branch else "Miner"
	end
	EconomyRules.RefreshGalaxyFlags(profile)
	return true, cost, nil
end

-- Sectors stay discovered forever (no reset), spec §5.
function EconomyRules.RefreshGalaxyFlags(profile: any): { string }
	local newly = {}
	for _, sector in GalaxyConfig.Sectors do
		if not profile.GalaxyFlags[sector.Id] and GalaxyConfig.IsUnlocked(sector.Id, profile) then
			profile.GalaxyFlags[sector.Id] = true
			table.insert(newly, sector.Id)
		end
	end
	return newly
end

-- Quick-Upgrade (U): during onboarding follow the tutorial order, afterwards
-- buy the cheapest affordable upgrade.
function EconomyRules.QuickUpgradeChoice(profile: any, ctx: Ctx?): string?
	if not profile.TutorialComplete then
		local flags = profile.TutorialFlags
		for _, entry in { { "Drill", "Drill" }, { "Cargo", "Cargo" }, { "Drone", "DroneSlot" } } do
			if not flags[entry[1]] then
				local ok = EconomyRules.CanUpgrade(profile, entry[2], ctx)
				return if ok then entry[2] else nil
			end
		end
	end
	local best, bestCost = nil, math.huge
	for _, id in EconomyConfig.UpgradeOrder do
		if EconomyRules.CanUpgrade(profile, id, ctx) then
			local cost = EconomyRules.UpgradeCost(profile, id, ctx) :: number
			if cost < bestCost then
				best, bestCost = id, cost
			end
		end
	end
	return best
end

return EconomyRules
