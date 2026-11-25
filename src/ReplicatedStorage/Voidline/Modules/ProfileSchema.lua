--!strict
-- Saved profile shape, defaults and migration. Shared so the client can start
-- from the same defaults before its first snapshot arrives.
-- Rules: never drop unknown fields, never rename keys, registry IDs are stable
-- strings. Bump VERSION and add a step to Migrate for every shape change.
local ProfileSchema = {}

ProfileSchema.VERSION = 2
ProfileSchema.MAX_RECEIPTS = 64

local function defaults()
	return {
		Version = ProfileSchema.VERSION,
		Credits = 0,
		LifetimeCredits = 0,
		Ore = 0,
		CargoValue = 0,
		LifetimeOre = 0,
		VoidShards = 0,
		LifetimeShards = 0,
		Artifacts = 0,
		VoidlineTokens = 0,
		LifetimeTokens = 0,
		Rebirths = 0,
		CreditMult = 1,
		StationTier = 1,
		DrillLevel = 1,
		CargoLevel = 1,
		DroneSlots = 1,
		DroneTier = 1,
		DroneBranch = "",
		Formation = 1,
		GalaxyFlags = { Starter = true, Nebula = false, VoidRim = false, Celestial = false },
		OwnedPerks = {},
		PassGrants = {},
		TrialVouchers = {},
		RedeemedCodes = {},
		TutorialStep = 1,
		TutorialComplete = false,
		TutorialSkipped = false,
		TutorialFlags = { Drill = false, Cargo = false, Drone = false },
		Settings = {
			PerfMode = false,
			HideJetpack = false,
			ClipMode = false,
			ReducedMotion = false,
			LaserColor = "Gold",
			MusicVolume = 0.5,
			SfxVolume = 0.8,
		},
		Cosmetics = { Title = "", LaserShader = "", Thruster = "", HitEffect = "", DroneMutation = "" },
		Titles = {},
		Unlocks = {},
		ForgeTokensEarnedToday = 0,
		ForgeDayKey = "",
		ForgeJobEndsAt = 0,
		DailyStreak = 0,
		LastLoginDay = "",
		LastDailyClaimDay = "",
		Codex = {},
		Relics = {},
		RelicDisplay = {},
		Stats = {},
		Achievements = {},
		Quests = { DayKey = "", Daily = {}, WeekKey = "", Weekly = {} },
		ProcessedReceipts = {},
		FirstJoin = 0,
		LastSeen = 0,
		PlaytimeSeconds = 0,
	}
end

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value do
		copy[k] = deepCopy(v)
	end
	return copy
end
ProfileSchema.DeepCopy = deepCopy

function ProfileSchema.Default(): any
	return defaults()
end

local function isFinite(n: number): boolean
	return n == n and n ~= math.huge and n ~= -math.huge
end

-- Fills missing keys and repairs wrong types/non-finite numbers in place.
-- Unknown keys are preserved untouched.
local function reconcile(target: any, template: any)
	for key, defaultValue in template do
		local current = target[key]
		if current == nil then
			target[key] = deepCopy(defaultValue)
		elseif type(defaultValue) == "table" then
			if type(current) ~= "table" then
				target[key] = deepCopy(defaultValue)
			else
				reconcile(current, defaultValue)
			end
		elseif type(current) ~= type(defaultValue) or (type(current) == "number" and not isFinite(current)) then
			target[key] = defaultValue
		end
	end
end

-- Integer counters that must never go negative.
local NON_NEGATIVE = {
	"Credits",
	"LifetimeCredits",
	"Ore",
	"CargoValue",
	"LifetimeOre",
	"VoidShards",
	"LifetimeShards",
	"Artifacts",
	"VoidlineTokens",
	"LifetimeTokens",
	"Rebirths",
	"ForgeTokensEarnedToday",
	"ForgeJobEndsAt",
	"DailyStreak",
	"PlaytimeSeconds",
}

local AT_LEAST_ONE = { "StationTier", "DrillLevel", "CargoLevel", "DroneSlots", "DroneTier", "Formation" }

-- Accepts anything read from a DataStore (nil, v1 flat profile, v2 profile)
-- and returns a valid current-version profile.
function ProfileSchema.Migrate(saved: any): any
	if type(saved) ~= "table" then
		return defaults()
	end
	local profile = saved
	local version = if type(profile.Version) == "number" then profile.Version else 1

	if version < 2 then
		-- v1 had no cargo value; value existing ore at the starter rate.
		if type(profile.Ore) == "number" and profile.CargoValue == nil then
			profile.CargoValue = math.max(0, math.floor(profile.Ore)) * 3
		end
		-- v1 stored Cosmetics.Title = nil; v2 uses "" for none.
		-- v1 had no lifetime counters; seed them from current balances.
		if profile.LifetimeCredits == nil and type(profile.Credits) == "number" then
			profile.LifetimeCredits = profile.Credits
		end
		if profile.LifetimeShards == nil and type(profile.VoidShards) == "number" then
			profile.LifetimeShards = profile.VoidShards
		end
		if profile.LifetimeTokens == nil and type(profile.VoidlineTokens) == "number" then
			profile.LifetimeTokens = profile.VoidlineTokens
		end
		-- v1 kept the session plot index in the profile; plots are per server.
		profile.PlotIndex = nil
	end

	reconcile(profile, defaults())

	for _, key in NON_NEGATIVE do
		profile[key] = math.max(0, math.floor(profile[key]))
	end
	for _, key in AT_LEAST_ONE do
		profile[key] = math.max(1, math.floor(profile[key]))
	end
	profile.Formation = math.clamp(profile.Formation, 1, 3)
	profile.TutorialStep = math.clamp(math.floor(profile.TutorialStep), 1, 4)
	profile.Version = ProfileSchema.VERSION
	return profile
end

-- Records a processed purchase id and trims the oldest beyond MAX_RECEIPTS.
function ProfileSchema.RecordReceipt(profile: any, purchaseId: string, unixTime: number)
	local receipts = profile.ProcessedReceipts
	receipts[purchaseId] = unixTime
	local count = 0
	for _ in receipts do
		count += 1
	end
	while count > ProfileSchema.MAX_RECEIPTS do
		local oldestId, oldestTime = nil, math.huge
		for id, t in receipts do
			if t < oldestTime then
				oldestId, oldestTime = id, t
			end
		end
		if oldestId == nil then
			break
		end
		receipts[oldestId] = nil
		count -= 1
	end
end

function ProfileSchema.Bump(profile: any, statId: string, amount: number?)
	local stats = profile.Stats
	stats[statId] = (stats[statId] or 0) + (amount or 1)
end

return ProfileSchema
