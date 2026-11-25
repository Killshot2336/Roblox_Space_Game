--!strict
-- Diegetic 4-step onboarding (spec §4, owner brief ~45 s):
--   1 HARVESTING ORE -> 2 REFINE AT PAD -> 3 DEPLOY 2ND DRONE (+Drill, +Cargo,
--   +Drone) -> 4 ENERGY BRIDGE ONLINE (+100 Credits, bridge ignites).
-- Rewards are deterministic; the completion bonus is granted exactly once.
local Config = script.Parent.Parent.Config
local EconomyConfig = require(Config.EconomyConfig)
local GameConfig = require(Config.GameConfig)

local TutorialRules = {}

TutorialRules.Steps = {
	[1] = { Ticker = "[1/4] HARVESTING ORE", Hint = "Your drone is towing a rock home" },
	[2] = { Ticker = "[2/4] REFINE AT PAD", Hint = "Walk onto the gold Refinery pad" },
	[3] = { Ticker = "[3/4] DEPLOY 2ND DRONE", Hint = "Drill 20 · Cargo 35 · Drone 50" },
	[4] = { Ticker = "[4/4] ENERGY BRIDGE ONLINE", Hint = "+100 Credits" },
}
TutorialRules.DoneStep = 4

-- Upgrade id -> tutorial flag.
local FLAG_FOR_UPGRADE = {
	Drill = "Drill",
	Cargo = "Cargo",
	DroneSlot = "Drone",
	Drone2 = "Drone",
}

export type Change = { Step: number, Completed: boolean, Bonus: number }

local function complete(profile: any, skipped: boolean): Change
	profile.TutorialStep = TutorialRules.DoneStep
	profile.TutorialComplete = true
	profile.TutorialSkipped = skipped
	local bonus = GameConfig.TutorialCompleteBonusCredits
	profile.Credits += bonus
	profile.LifetimeCredits += bonus
	return { Step = TutorialRules.DoneStep, Completed = true, Bonus = bonus }
end

local function allFlags(profile: any): boolean
	local flags = profile.TutorialFlags
	return flags.Drill and flags.Cargo and flags.Drone
end

function TutorialRules.OnOreStored(profile: any): Change?
	if profile.TutorialComplete or profile.TutorialStep ~= 1 then
		return nil
	end
	if profile.Ore >= EconomyConfig.StarterCargoCapacity then
		profile.TutorialStep = 2
		return { Step = 2, Completed = false, Bonus = 0 }
	end
	return nil
end

function TutorialRules.OnSold(profile: any): Change?
	if profile.TutorialComplete or profile.TutorialStep > 2 then
		return nil
	end
	if allFlags(profile) then
		return complete(profile, false)
	end
	profile.TutorialStep = 3
	return { Step = 3, Completed = false, Bonus = 0 }
end

function TutorialRules.OnUpgrade(profile: any, upgradeId: string): Change?
	if profile.TutorialComplete then
		return nil
	end
	local flag = FLAG_FOR_UPGRADE[upgradeId]
	if not flag then
		return nil
	end
	profile.TutorialFlags[flag] = true
	if profile.TutorialStep == 3 and allFlags(profile) then
		return complete(profile, false)
	end
	return nil
end

-- The tiny Skip button: same end state and bonus as finishing normally.
function TutorialRules.Skip(profile: any): Change?
	if profile.TutorialComplete then
		return nil
	end
	return complete(profile, true)
end

-- Next upgrade the golden floor beam should point at during step 3.
function TutorialRules.NextUpgrade(profile: any): string?
	if profile.TutorialComplete or profile.TutorialStep ~= 3 then
		return nil
	end
	local flags = profile.TutorialFlags
	if not flags.Drill then
		return "Drill"
	elseif not flags.Cargo then
		return "Cargo"
	elseif not flags.Drone then
		return "DroneSlot"
	end
	return nil
end

return TutorialRules
