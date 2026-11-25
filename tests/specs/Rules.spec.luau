--!nocheck
-- Shared rules modules: economy, tutorial, forge, rebirth, daily streak,
-- codes, store and mining. These are the numbers the server enforces.
local Harness = require("../harness/Harness")
local Expect = require("../harness/Expect")
local expect = Expect.expect

local tests = {}

local function load()
	local world = Harness.new()
	local function r(path)
		return world:require("ReplicatedStorage/Voidline/" .. path)
	end
	return {
		world = world,
		Schema = r("Modules/ProfileSchema"),
		Economy = r("Rules/EconomyRules"),
		Tutorial = r("Rules/TutorialRules"),
		Progression = r("Rules/ProgressionRules"),
		Store = r("Rules/StoreRules"),
		Mining = r("Rules/MiningRules"),
		EconomyConfig = r("Config/EconomyConfig"),
		MonetizationConfig = r("Config/MonetizationConfig"),
	}
end

local DAY = 86400
local EPOCH = 1795564800 -- 2026-11-25T00:00:00Z

tests["deterministic tutorial: 10 ore -> 30 credits -> 20/35/50 -> +100"] = function()
	local m = load()
	local p = m.Schema.Default()
	local events = {}
	local function note(change)
		if change then
			table.insert(events, change.Step)
		end
	end

	-- First tow lands: 10 ore at 3 credits each.
	expect(m.Economy.AddOre(p, 10, m.Economy.UnitValue("Starter"))).toBe(10)
	note(m.Tutorial.OnOreStored(p))
	expect(p.TutorialStep).toBe(2)
	local paid = m.Economy.Sell(p, { Perks = {} })
	expect(paid).toBe(30)
	note(m.Tutorial.OnSold(p))
	expect(p.TutorialStep).toBe(3)
	expect(m.Tutorial.NextUpgrade(p)).toBe("Drill")

	local ok, cost = m.Economy.ApplyUpgrade(p, "Drill", nil)
	expect(ok).toBe(true)
	expect(cost).toBe(20)
	note(m.Tutorial.OnUpgrade(p, "Drill"))
	expect(m.Tutorial.NextUpgrade(p)).toBe("Cargo")

	m.Economy.AddOre(p, 10, 3)
	m.Economy.Sell(p, nil)
	ok, cost = m.Economy.ApplyUpgrade(p, "Cargo", nil)
	expect(ok).toBe(true)
	expect(cost).toBe(35)
	note(m.Tutorial.OnUpgrade(p, "Cargo"))
	expect(m.Economy.CargoCap(p)).toBe(18)

	expect(m.Economy.AddOre(p, 20, 3)).toBe(18)
	m.Economy.Sell(p, nil)
	ok, cost = m.Economy.ApplyUpgrade(p, "DroneSlot", nil)
	expect(ok).toBe(true)
	expect(cost).toBe(50)
	local done = m.Tutorial.OnUpgrade(p, "DroneSlot")
	expect(done.Completed).toBe(true)
	expect(done.Bonus).toBe(100)
	expect(p.TutorialComplete).toBe(true)
	expect(p.TutorialStep).toBe(4)
	-- 30 - 20 + 30 - 35 + 54 - 50 + 100
	expect(p.Credits).toBe(109)
	expect(p.DroneSlots).toBe(2)
	expect(table.concat(events, ",")).toBe("2,3")

	-- The bonus can never be granted twice.
	expect(m.Tutorial.OnUpgrade(p, "DroneSlot")).toBeNil()
	expect(m.Tutorial.Skip(p)).toBeNil()
	expect(p.Credits).toBe(109)
end

tests["tutorial skip grants the same end state exactly once"] = function()
	local m = load()
	local p = m.Schema.Default()
	local change = m.Tutorial.Skip(p)
	expect(change.Completed).toBe(true)
	expect(p.Credits).toBe(100)
	expect(p.TutorialSkipped).toBe(true)
	expect(m.Tutorial.Skip(p)).toBeNil()
	expect(m.Tutorial.OnSold(p)).toBeNil()
	expect(p.Credits).toBe(100)
end

tests["tutorial completes on first sell if upgrades were bought early"] = function()
	local m = load()
	local p = m.Schema.Default()
	p.Credits = 105 -- e.g. a code redeemed before the first sell
	for _, id in { "Drill", "Cargo", "DroneSlot" } do
		m.Economy.ApplyUpgrade(p, id, nil)
		expect(m.Tutorial.OnUpgrade(p, id)).toBeNil()
	end
	m.Economy.AddOre(p, 10, 3)
	m.Tutorial.OnOreStored(p)
	m.Economy.Sell(p, nil)
	local change = m.Tutorial.OnSold(p)
	expect(change.Completed).toBe(true)
	expect(p.Credits).toBe(130)
end

tests["cargo cap clamps stored ore and rejects bad input"] = function()
	local m = load()
	local p = m.Schema.Default()
	expect(m.Economy.AddOre(p, 25, 3)).toBe(10)
	expect(m.Economy.AddOre(p, 5, 3)).toBe(0)
	expect(p.Ore).toBe(10)
	expect(p.CargoValue).toBe(30)
	local q = m.Schema.Default()
	expect(m.Economy.AddOre(q, 0 / 0, 3)).toBe(0)
	expect(m.Economy.AddOre(q, -5, 3)).toBe(0)
	expect(m.Economy.AddOre(q, 5, 0 / 0)).toBe(0)
	expect(q.Ore).toBe(0)
end

tests["credit multipliers: rebirth, 2x pass, VIP, boosts"] = function()
	local m = load()
	local p = m.Schema.Default()
	m.Economy.AddOre(p, 10, 3)
	expect(m.Economy.SellPayout(p, { Perks = { Credits2x = true } })).toBe(60)
	p.Rebirths = 1
	expect(m.Economy.SellPayout(p, nil)).toBe(37)
	p.Rebirths = 0
	expect(m.Economy.SellPayout(p, { Perks = { VoidSovereignVIP = true } })).toBe(33)
	expect(m.Economy.SellPayout(p, { CreditBoost = 2, CodexMult = 1.5 })).toBe(90)
	local empty = m.Schema.Default()
	expect(m.Economy.SellPayout(empty, { Perks = { Credits2x = true } })).toBe(0)
	local paid, sold = m.Economy.Sell(empty, nil)
	expect(paid).toBe(0)
	expect(sold).toBe(0)
end

tests["upgrade reasons: funds, max, locked drone tier, unknown"] = function()
	local m = load()
	local p = m.Schema.Default()
	local ok, reason = m.Economy.CanUpgrade(p, "Drill", nil)
	expect(ok).toBe(false)
	expect(reason).toBe("funds")
	ok, reason = m.Economy.CanUpgrade(p, "Nope", nil)
	expect(reason).toBe("unknown")
	p.Credits = 1e12
	p.DroneSlots = 6
	ok, reason = m.Economy.CanUpgrade(p, "DroneSlot", nil)
	expect(reason).toBe("max")
	-- Evolving past stage N needs Station Tier 2N.
	ok, reason = m.Economy.CanUpgrade(p, "DroneTier", nil)
	expect(reason).toBe("locked")
	p.StationTier = 2
	ok, reason = m.Economy.CanUpgrade(p, "DroneTier", nil)
	expect(ok).toBe(true)
	p.DroneTier = 2
	p.StationTier = 3
	ok, reason = m.Economy.CanUpgrade(p, "DroneTier", nil)
	expect(reason).toBe("locked")
	p.StationTier = 4
	ok = m.Economy.CanUpgrade(p, "DroneTier", nil)
	expect(ok).toBe(true)
	-- Eternal Architect: Station Tier upgrades 10% cheaper.
	local base = m.Economy.UpgradeCost(p, "StationTier", nil)
	local cheap = m.Economy.UpgradeCost(p, "StationTier", { Perks = { EternalArchitect = true } })
	expect(cheap).toBe(math.floor(base * 0.9))
end

tests["drone evolution branches at stage 6 and defaults to Miner"] = function()
	local m = load()
	local p = m.Schema.Default()
	p.Credits = 1e15
	p.StationTier = 30
	for _ = 1, 4 do
		m.Economy.ApplyUpgrade(p, "DroneTier", nil)
	end
	expect(p.DroneTier).toBe(5)
	expect(p.DroneBranch).toBe("")
	m.Economy.ApplyUpgrade(p, "DroneTier", nil, "Hauler")
	expect(p.DroneTier).toBe(6)
	expect(p.DroneBranch).toBe("Hauler")
	m.Economy.ApplyUpgrade(p, "DroneTier", nil, "Swarm")
	expect(p.DroneBranch).toBe("Hauler")
	local q = m.Schema.Default()
	q.Credits, q.StationTier, q.DroneTier = 1e15, 30, 5
	m.Economy.ApplyUpgrade(q, "DroneTier", nil, "NotABranch")
	expect(q.DroneBranch).toBe("Miner")
end

tests["galaxy sectors stay discovered across rebirth (no reset)"] = function()
	local m = load()
	local p = m.Schema.Default()
	p.StationTier = 10
	p.DroneTier = 2
	local newly = m.Economy.RefreshGalaxyFlags(p)
	expect(#newly).toBe(3)
	expect(m.Economy.ActiveSector(p)).toBe("Celestial")
	local n, shards = m.Progression.Rebirth(p)
	expect(n).toBe(1)
	expect(shards).toBe(15)
	expect(p.GalaxyFlags.Celestial).toBe(true)
	expect(p.GalaxyFlags.Nebula).toBe(true)
	expect(m.Economy.ActiveSector(p)).toBe("Starter")
	expect(p.StationTier).toBe(1)
	expect(p.DroneTier).toBe(2)
	expect(p.CreditMult).toBe(1.25)
end

tests["quick upgrade follows tutorial order then cheapest"] = function()
	local m = load()
	local p = m.Schema.Default()
	p.Credits = 1000
	expect(m.Economy.QuickUpgradeChoice(p, nil)).toBe("Drill")
	p.TutorialFlags.Drill = true
	expect(m.Economy.QuickUpgradeChoice(p, nil)).toBe("Cargo")
	p.TutorialComplete = true
	p.DrillLevel = 5
	-- Cargo 35 is cheaper than Drill L5 (20*1.55^4 = 115) and Drone 50.
	expect(m.Economy.QuickUpgradeChoice(p, nil)).toBe("Cargo")
	p.Credits = 0
	expect(m.Economy.QuickUpgradeChoice(p, nil)).toBeNil()
end

tests["forge: 25 shards -> 1 artifact in 10 s -> 40 tokens; soft cool at 500"] = function()
	local m = load()
	local p = m.Schema.Default()
	p.VoidShards = 25 * 20
	local now = EPOCH
	local ok, reason = m.Progression.StartForge(p, now)
	expect(ok).toBe(true)
	ok, reason = m.Progression.StartForge(p, now)
	expect(reason).toBe("busy")
	expect(m.Progression.CollectForge(p, now + 9)).toBe(false)
	expect(m.Progression.CollectForge(p, now + 10)).toBe(true)
	expect(p.Artifacts).toBe(1)
	local turned, tokens = m.Progression.TurnInArtifact(p, now + 10)
	expect(turned).toBe(true)
	expect(tokens).toBe(40)
	expect(p.VoidlineTokens).toBe(40)

	-- Earn up to the soft cap, then forging slows but never locks.
	for _ = 1, 12 do
		now += 60
		m.Progression.StartForge(p, now)
		m.Progression.CollectForge(p, now + 100)
		m.Progression.TurnInArtifact(p, now + 100)
	end
	expect(p.ForgeTokensEarnedToday).toBe(520)
	expect(m.Progression.ForgeCooling(p)).toBe(true)
	local _, _, duration = m.Progression.StartForge(p, now + 200)
	expect(duration).toBeCloseTo(10 / 0.35, 1e-9)
	-- Next UTC day resets the soft cap.
	m.Progression.CollectForge(p, now + DAY)
	m.Progression.TurnInArtifact(p, now + DAY)
	expect(p.ForgeTokensEarnedToday).toBe(40)
	expect(m.Progression.ForgeCooling(p)).toBe(false)
	local turnedNone = m.Progression.TurnInArtifact(m.Schema.Default(), now)
	expect(turnedNone).toBe(false)
end

tests["forge refuses without 25 shards"] = function()
	local m = load()
	local p = m.Schema.Default()
	p.VoidShards = 24
	local ok, reason = m.Progression.StartForge(p, EPOCH)
	expect(ok).toBe(false)
	expect(reason).toBe("shards")
	expect(p.VoidShards).toBe(24)
end

tests["rebirth requires station tier 10 and keeps the keep-list"] = function()
	local m = load()
	local p = m.Schema.Default()
	expect(m.Progression.CanRebirth(p)).toBe(false)
	p.StationTier = 10
	p.Credits = 999
	p.VoidlineTokens = 80
	p.Artifacts = 2
	p.VoidShards = 7
	p.OwnedPerks.Credits2x = true
	p.Relics["relic.x"] = true
	p.DroneSlots = 4
	expect(m.Progression.CanRebirth(p)).toBe(true)
	m.Progression.Rebirth(p)
	expect(p.Credits).toBe(0)
	expect(p.VoidlineTokens).toBe(80)
	expect(p.Artifacts).toBe(2)
	expect(p.VoidShards).toBe(7 + 15)
	expect(p.OwnedPerks.Credits2x).toBe(true)
	expect(p.Relics["relic.x"]).toBe(true)
	expect(p.DroneSlots).toBe(4)
end

tests["daily streak cycles 1..7 and one claim per UTC day"] = function()
	local m = load()
	local p = m.Schema.Default()
	local seen = {}
	for day = 0, 8 do
		local now = EPOCH + day * DAY + 3600
		local ok, reward, streakDay = m.Progression.ClaimDaily(p, now)
		expect(ok).toBe(true)
		table.insert(seen, streakDay)
		expect(reward.Credits).toBeGreaterThan(0)
		local again = m.Progression.ClaimDaily(p, now + 60)
		expect(again).toBe(false)
	end
	expect(table.concat(seen, ",")).toBe("1,2,3,4,5,6,7,1,2")
	-- Day 7 voucher: Credits2x for 24 h.
	expect(p.TrialVouchers.Credits2x).toBe(EPOCH + 6 * DAY + 3600 + 24 * 3600)
	-- Missing a day resets the streak.
	local ok, _, streakDay = m.Progression.ClaimDaily(p, EPOCH + 11 * DAY)
	expect(ok).toBe(true)
	expect(streakDay).toBe(1)
end

tests["codes normalize case/space, redeem once, reject junk"] = function()
	local m = load()
	local p = m.Schema.Default()
	local ok, reason, code = m.Progression.RedeemCode(p, "  void line ")
	expect(ok).toBe(true)
	expect(code).toBe("VOIDLINE")
	expect(p.Credits).toBe(250)
	expect(p.Titles["title.code.voidline"]).toBe(true)
	ok, reason = m.Progression.RedeemCode(p, "voidline")
	expect(reason).toBe("used")
	ok, reason = m.Progression.RedeemCode(p, "NOPE")
	expect(reason).toBe("unknown")
	for _, junk in { 5, nil, {}, "", "DROP;TABLE", string.rep("A", 65), "ÄÖÜ" } do
		ok, reason = m.Progression.RedeemCode(p, junk)
		expect(ok).toBe(false)
		expect(reason).toBe("invalid")
	end
	expect(p.Credits).toBe(250)
end

tests["token store: prices, ownership, insufficient tokens"] = function()
	local m = load()
	local p = m.Schema.Default()
	p.VoidlineTokens = 400
	local ok, reason = m.Store.BuyWithTokens(p, "Credits2x")
	expect(ok).toBe(true)
	expect(p.VoidlineTokens).toBe(30)
	ok, reason = m.Store.BuyWithTokens(p, "Credits2x")
	expect(reason).toBe("owned")
	ok, reason = m.Store.BuyWithTokens(p, "MegaSwarm5")
	expect(reason).toBe("tokens")
	ok, reason = m.Store.BuyWithTokens(p, "ShardPack")
	expect(reason).toBe("unknown")
	expect(p.VoidlineTokens).toBe(30)
end

tests["pass grants apply once; vouchers expire"] = function()
	local m = load()
	local p = m.Schema.Default()
	expect(m.Store.ApplyPassGrants(p, "StarterBundle")).toBe(true)
	expect(m.Store.ApplyPassGrants(p, "StarterBundle")).toBe(false)
	expect(p.Credits).toBe(m.MonetizationConfig.StarterBundleCredits)
	p.TrialVouchers.Credits2x = EPOCH + 10
	expect(m.Store.EffectivePerks(p, EPOCH, nil).Credits2x).toBe(true)
	expect(m.Store.EffectivePerks(p, EPOCH + 10, nil).Credits2x).toBeNil()
	expect(m.Store.EffectivePerks(p, EPOCH, { AutoSellWarpLink = true }).AutoSellWarpLink).toBe(true)
end

tests["mining: drones, damage, formations, tows, luck"] = function()
	local m = load()
	local p = m.Schema.Default()
	expect(m.Mining.DroneCount(p, nil)).toBe(1)
	expect(m.Mining.DroneCount(p, { DroneSlots3 = true, MegaSwarm5 = true })).toBe(9)
	p.DroneSlots = 6
	expect(m.Mining.DroneCount(p, { DroneSlots3 = true, MegaSwarm5 = true })).toBe(14)
	expect(m.Mining.DamagePerDrone(m.Schema.Default(), nil)).toBe(8)
	local d = m.Schema.Default()
	d.DrillLevel = 2
	expect(m.Mining.DamagePerDrone(d, nil)).toBe(12)
	expect(m.Mining.DamagePerDrone(d, { LaserOverclock = true })).toBeCloseTo(16.2, 1e-9)
	expect(m.Mining.SwarmDps(d, nil, 2, 0)).toBeCloseTo(12 * 1.35, 1e-9)
	expect(m.Mining.SwarmDps(d, nil, 2, 2)).toBeCloseTo(12 * 1.55, 1e-9)
	expect(m.Mining.SwarmDps(d, nil, 3, 0)).toBeCloseTo(6, 1e-9)
	expect(m.Mining.TowSeconds(d, nil, 1000)).toBe(4.5)
	expect(m.Mining.TowSeconds(d, nil, 1)).toBe(0.9)
	expect(m.Mining.LuckMultiplier({ ShardRelicLuck2x = true }, true, true)).toBeCloseTo(4.4, 1e-9)
	local s = m.Schema.Default()
	s.DroneTier, s.DroneBranch = 12, "Swarm"
	expect(m.Mining.DroneCount(s, nil)).toBe(1 + 2)
end

tests["profile migration from v1 keeps data and repairs junk"] = function()
	local m = load()
	local v1 = {
		Version = 1,
		Credits = 1234,
		Ore = 7,
		VoidShards = 3,
		Rebirths = 2,
		StationTier = 5,
		Settings = { PerfMode = true, LaserColor = "Cyan" },
		Cosmetics = {},
		OwnedPerks = { Credits2x = true },
		PlotIndex = 4,
		SomeFutureField = "keep me",
		DrillLevel = 0 / 0,
		CargoLevel = "three",
	}
	local p = m.Schema.Migrate(v1)
	expect(p.Version).toBe(2)
	expect(p.Credits).toBe(1234)
	expect(p.LifetimeCredits).toBe(1234)
	expect(p.CargoValue).toBe(21)
	expect(p.Settings.PerfMode).toBe(true)
	expect(p.Settings.LaserColor).toBe("Cyan")
	expect(p.Settings.SfxVolume).toBe(0.8)
	expect(p.Cosmetics.Title).toBe("")
	expect(p.OwnedPerks.Credits2x).toBe(true)
	expect(p.PlotIndex).toBeNil()
	expect(p.SomeFutureField).toBe("keep me")
	expect(p.DrillLevel).toBe(1)
	expect(p.CargoLevel).toBe(1)
	expect(m.Schema.Migrate(nil).Version).toBe(2)
	expect(m.Schema.Migrate("garbage").Credits).toBe(0)
	local negative = m.Schema.Migrate({ Version = 2, Credits = -50, Formation = 9 })
	expect(negative.Credits).toBe(0)
	expect(negative.Formation).toBe(3)
end

tests["receipt log is bounded and keeps the newest"] = function()
	local m = load()
	local p = m.Schema.Default()
	for i = 1, 100 do
		m.Schema.RecordReceipt(p, "purchase-" .. i, EPOCH + i)
	end
	local count = 0
	for _ in p.ProcessedReceipts do
		count += 1
	end
	expect(count).toBe(m.Schema.MAX_RECEIPTS)
	expect(p.ProcessedReceipts["purchase-100"]).toBe(EPOCH + 100)
	expect(p.ProcessedReceipts["purchase-1"]).toBeNil()
end

return tests
