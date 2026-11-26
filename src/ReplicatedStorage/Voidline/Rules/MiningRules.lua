--!strict
-- Drone swarm math (spec §6). Server-authoritative: the server simulates
-- damage with these numbers; clients only render.
local Config = script.Parent.Parent.Config
local DroneConfig = require(Config.DroneConfig)
local SquadConfig = require(Config.SquadConfig)

local MiningRules = {}

local function hasPerk(perks: { [string]: boolean }?, perkId: string): boolean
	return perks ~= nil and perks[perkId] == true
end

function MiningRules.BranchStats(profile: any)
	return DroneConfig.Branches[profile.DroneBranch]
end

function MiningRules.DroneCount(profile: any, perks: { [string]: boolean }?): number
	local count = profile.DroneSlots
	if hasPerk(perks, "DroneSlots3") then
		count += 3
	end
	if hasPerk(perks, "MegaSwarm5") then
		count += 5
	end
	local branch = MiningRules.BranchStats(profile)
	if branch and branch.ExtraDronesPerStages then
		local stagesInBranch = profile.DroneTier - DroneConfig.BranchStage + 1
		count += math.floor(math.max(0, stagesInBranch) / branch.ExtraDronesPerStages)
	end
	return math.clamp(count, 1, DroneConfig.MaxDrones)
end

function MiningRules.DamagePerDrone(profile: any, perks: { [string]: boolean }?): number
	local dps = DroneConfig.BaseDamagePerSecond + DroneConfig.DamagePerDrillLevel * (profile.DrillLevel - 1)
	dps *= 1 + DroneConfig.DamagePerDroneTier * (profile.DroneTier - 1)
	if hasPerk(perks, "LaserOverclock") then
		dps *= DroneConfig.LaserOverclockMult
	end
	local branch = MiningRules.BranchStats(profile)
	if branch then
		dps *= branch.DamageMult
	end
	return dps
end

-- Total swarm damage per second for a formation. `linkedSquadmates` counts
-- squad members also in Beam-Link formation.
function MiningRules.SwarmDps(
	profile: any,
	perks: { [string]: boolean }?,
	formation: number,
	linkedSquadmates: number?
): number
	local stats = DroneConfig.FormationStats[formation] or DroneConfig.FormationStats[1]
	local mult = stats.DamageMult
	if stats.SquadLinkBonus and linkedSquadmates then
		mult += stats.SquadLinkBonus * math.clamp(linkedSquadmates, 0, 3)
	end
	return MiningRules.DamagePerDrone(profile, perks) * MiningRules.DroneCount(profile, perks) * mult
end

function MiningRules.OrePerRock(profile: any, baseOre: number): number
	local branch = MiningRules.BranchStats(profile)
	local mult = if branch then branch.OreMult else 1
	return math.floor(baseOre * mult + 1e-9)
end

-- Seconds for a drone to tow a rock `distance` studs home.
function MiningRules.TowSeconds(profile: any, perks: { [string]: boolean }?, distance: number): number
	local speed = DroneConfig.TowSpeed
	local branch = MiningRules.BranchStats(profile)
	if branch then
		speed *= branch.TowMult
	end
	if hasPerk(perks, "DeepSpaceWarpPass") then
		speed *= 1.25
	end
	return math.clamp(distance / speed, DroneConfig.TowMinSeconds, DroneConfig.TowMaxSeconds)
end

-- Probability multiplier for shard/relic finds.
function MiningRules.LuckMultiplier(perks: { [string]: boolean }?, squadLinked: boolean, serverSurge: boolean): number
	local luck = 1
	if hasPerk(perks, "ShardRelicLuck2x") then
		luck *= 2
	end
	if serverSurge then
		luck *= 2
	end
	if squadLinked then
		luck *= 1 + SquadConfig.LinkedShardLuckBonus
	end
	return luck
end

return MiningRules
