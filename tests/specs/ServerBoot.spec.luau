--!nocheck
-- Headless end-to-end: boots the real server (Boot.server.lua + every
-- service) in the harness, joins pilots and plays the onboarding flow by
-- firing the same remotes / standing on the same pads a client would.
local Harness = require("../harness/Harness")
local Expect = require("../harness/Expect")
local expect = Expect.expect

local tests = {}

local SERVICES = "ServerScriptService/Voidline/Services/"
local STORE = "VoidlinePlayer_v1/global"

local CLIENT_TO_SERVER = {
	"RequestUpgrade",
	"QuickUpgrade",
	"SetFormation",
	"SellOre",
	"RequestRebirth",
	"RequestForge",
	"TurnInArtifact",
	"PurchaseWithTokens",
	"PromptRobuxPurchase",
	"SquadInvite",
	"SquadRespond",
	"SquadLeave",
	"SquadKick",
	"SettingsUpdate",
	"RedeemCode",
	"RedeemDaily",
	"EquipCosmetic",
	"TutorialSkip",
	"PlayerInput",
	"WarpRequest",
	"SetRelicDisplay",
	"InspectPilot",
}

local function boot(options)
	local world = Harness.new(options)
	world:runScript("ServerScriptService/Voidline/Boot")
	world:advance(0.5, 0.1)
	world:assertNoErrors()
	return world
end

local function service(world, name)
	return world:require(SERVICES .. name)
end

local function joinAndLoad(world, userId, name)
	local player = world:addPlayer(userId, name)
	world:advance(1, 0.1)
	world:assertNoErrors()
	expect(service(world, "PlayerDataService").IsLoaded(player)).toBe(true)
	return player
end

local function lastEvent(world, player, remoteName)
	local events = world:clientEvents(player, remoteName)
	return events[#events] and events[#events][1]
end

local function juiceKinds(world, player)
	local kinds = {}
	for _, args in world:clientEvents(player, "JuiceEvent") do
		kinds[args[1].Kind] = (kinds[args[1].Kind] or 0) + 1
	end
	return kinds
end

tests["boots every service without errors or failed Inits"] = function()
	local world = boot()
	local booted = false
	for _, line in world.prints do
		if string.find(line, "Boot complete", 1, true) then
			booted = true
		end
	end
	for _, line in world.warnings do
		expect(string.find(line, "Init failed", 1, true)).toBeNil()
	end
	expect(booted).toBe(true)
	world:advance(30, 0.1)
	world:assertNoErrors()
end

tests["every client-to-server remote is bound exactly once"] = function()
	local world = boot()
	local Remotes = world:require("ReplicatedStorage/Voidline/Remotes")
	for _, name in CLIENT_TO_SERVER do
		expect(Remotes.Names[name]).toBe("Event")
		local remote = world:findRemote(name)
		expect(remote ~= nil).toBe(true)
		expect(remote.OnServerEvent:ConnectionCount()).toBe(1)
	end
end

tests["first join claims a plot, spawns the belt and starts the tutorial"] = function()
	local world = boot()
	local player = joinAndLoad(world, 1001, "Nova")
	expect(player:GetAttribute("PlotIndex")).toBe(1)
	local plot = world:find("Workspace/VoidlineMap/Plots/Plot_1")
	expect(plot:GetAttribute("OwnerUserId")).toBe(1001)
	expect(plot:GetAttribute("BridgeIgnited")).toBe(false)
	expect(service(world, "PlotService").IsOnPlot(player)).toBe(true)
	local rocks = service(world, "BeltService").Rocks(player)
	expect(#rocks).toBe(world:require("ReplicatedStorage/Voidline/Config/GameConfig").BeltAsteroidsPerPlot)
	local OreRegistry = world:require("ReplicatedStorage/Voidline/Content/OreRegistry")
	for _, rock in rocks do
		expect(rock.OreId).toBe(OreRegistry.TutorialOreId)
	end
	local progress = lastEvent(world, player, "TutorialProgress")
	expect(progress.Step).toBe(1)
	expect(progress.Complete).toBe(false)
	expect(player:GetAttribute("DroneCount")).toBe(1)
end

-- Plays onboarding like a player following the golden beams: wait on the
-- plot while the drone mines, walk onto the Refinery pad when the hold is
-- full, buy the highlighted upgrade when affordable.
local function playTutorial(world, player)
	local PDS = service(world, "PlayerDataService")
	local PlotLayout = world:require("ReplicatedStorage/Voidline/Modules/PlotLayout")
	local EconomyRules = world:require("ReplicatedStorage/Voidline/Rules/EconomyRules")
	local TutorialRules = world:require("ReplicatedStorage/Voidline/Rules/TutorialRules")
	local CFrame = Harness.roblox.CFrame
	local index = player:GetAttribute("PlotIndex")
	local plotCFrame = PlotLayout.PlotCFrame(index)
	local refinery = plotCFrame:PointToWorldSpace(PlotLayout.Refinery + Harness.roblox.Vector3.new(0, 3, 0))
	local spawn = plotCFrame:PointToWorldSpace(PlotLayout.Spawn + Harness.roblox.Vector3.new(0, 3, 0))
	local elapsed, trips = 0, 0
	local atPad = false
	while elapsed < 120 do
		local profile = PDS.Get(player)
		if profile.TutorialComplete then
			break
		end
		local capacity = EconomyRules.CargoCap(profile)
		if profile.Ore >= capacity and not atPad then
			player.Character:PivotTo(CFrame.new(refinery))
			atPad = true
			trips += 1
		elseif profile.Ore == 0 then
			local nextId = TutorialRules.NextUpgrade(profile)
			if nextId then
				local cost = EconomyRules.UpgradeCost(profile, nextId, PDS.Ctx(player))
				if cost and cost <= profile.Credits then
					world:fireServer("RequestUpgrade", player, nextId)
				end
			end
			if atPad then
				player.Character:PivotTo(CFrame.new(spawn))
				atPad = false
			end
		end
		world:advance(0.1, 0.1)
		world:assertNoErrors()
		elapsed += 0.1
	end
	return elapsed, trips
end

tests["onboarding: 10 ore -> 30 Cr, 20/35/50 upgrades, bridge ignites with +100 (109 Cr)"] = function()
	local world = boot()
	local player = joinAndLoad(world, 1001, "Nova")
	world:clearRemoteLog()
	local elapsed, trips = playTutorial(world, player)
	local profile = service(world, "PlayerDataService").Get(player)
	expect(profile.TutorialComplete).toBe(true)
	expect(profile.TutorialSkipped).toBe(false)
	expect(profile.DrillLevel).toBe(2)
	expect(profile.CargoLevel).toBe(2)
	expect(profile.DroneSlots).toBe(2)
	-- 30 - 20 + 30 - 35 + 54 - 50 + 100
	expect(profile.Credits).toBe(109)
	expect(trips).toBe(3)
	-- Instant walking here; the design target with walking is ~45 s.
	expect(elapsed > 15 and elapsed < 45).toBe(true)
	local plot = world:find("Workspace/VoidlineMap/Plots/Plot_1")
	expect(plot:GetAttribute("BridgeIgnited")).toBe(true)
	for _, segment in plot.EnergyBridge:GetChildren() do
		expect(segment.CanCollide).toBe(true)
	end
	local kinds = juiceKinds(world, player)
	expect(kinds.BridgeIgnite).toBe(1)
	expect(kinds.Sell).toBe(3)
	expect(kinds.Upgrade).toBe(3)
	local progress = lastEvent(world, player, "TutorialProgress")
	expect(progress.Complete).toBe(true)
	expect(player:GetAttribute("DroneCount")).toBe(2)
	-- Tutorial rocks are all starter ore; nothing random leaked in.
	expect(profile.VoidShards).toBe(0)
	-- Achievements earned during onboarding arrive a beat after the bridge.
	expect(kinds.Achievement).toBeNil()
	world:advance(5, 0.1)
	world:assertNoErrors()
	expect(juiceKinds(world, player).Achievement > 0).toBe(true)
	expect(service(world, "PlayerDataService").Get(player).Credits > 109).toBe(true)
	print(("    onboarding finished in %.1f s simulated (instant walking), %d refinery trips"):format(elapsed, trips))
end

tests["onboarding skip gives the same end state and bonus once"] = function()
	local world = boot()
	local player = joinAndLoad(world, 1002, "Skipper")
	world:fireServer("TutorialSkip", player)
	world:advance(1, 0.1)
	world:fireServer("TutorialSkip", player)
	world:advance(1, 0.1)
	world:assertNoErrors()
	local profile = service(world, "PlayerDataService").Get(player)
	expect(profile.TutorialComplete).toBe(true)
	expect(profile.TutorialSkipped).toBe(true)
	expect(profile.Credits).toBe(100)
	local plot = world:find("Workspace/VoidlineMap/Plots/Plot_1")
	expect(plot:GetAttribute("BridgeIgnited")).toBe(true)
	expect(juiceKinds(world, player).BridgeIgnite).toBe(1)
end

tests["leaving saves the profile and releases the session lock"] = function()
	local world = boot()
	local player = joinAndLoad(world, 1003, "Leaver")
	world:fireServer("TutorialSkip", player)
	world:advance(2, 0.1)
	world:removePlayer(player)
	world:advance(2, 0.1)
	world:assertNoErrors()
	local record = world.dataStoreData[STORE]["p_1003"]
	expect(record ~= nil).toBe(true)
	expect(record.Lock).toBeNil()
	expect(record.Data.TutorialComplete).toBe(true)
	expect(record.Data.Credits).toBe(100)
	local plot = world:find("Workspace/VoidlineMap/Plots/Plot_1")
	expect(plot:GetAttribute("OwnerUserId")).toBe(0)
	expect(#service(world, "BeltService").Rocks(player)).toBe(0)
end

tests["returning pilot keeps progress and lands with the bridge lit"] = function()
	local first = boot()
	local player = joinAndLoad(first, 1004, "Veteran")
	first:fireServer("TutorialSkip", player)
	first:advance(2, 0.1)
	first:removePlayer(player)
	first:advance(2, 0.1)

	local second = Harness.new({ jobId = "test-job-2" })
	second.dataStoreData = first.dataStoreData
	second:runScript("ServerScriptService/Voidline/Boot")
	second:advance(0.5, 0.1)
	local again = joinAndLoad(second, 1004, "Veteran")
	local profile = service(second, "PlayerDataService").Get(again)
	expect(profile.TutorialComplete).toBe(true)
	-- 100 saved; achievements earned in the first session may pay out now.
	expect(profile.Credits >= 100).toBe(true)
	expect(profile.LifetimeCredits >= 100).toBe(true)
	local plot = second:find("Workspace/VoidlineMap/Plots/Plot_1")
	expect(plot:GetAttribute("BridgeIgnited")).toBe(true)
	-- Not tutorial ore any more: the belt rolls from the sector table.
	expect(#service(second, "BeltService").Rocks(again) > 0).toBe(true)
end

tests["twelve pilots get twelve distinct plots; the thirteenth waits safely"] = function()
	local world = boot()
	local seen = {}
	for i = 1, 12 do
		local player = world:addPlayer(2000 + i, "P" .. i)
		world:advance(0.3, 0.1)
		local index = player:GetAttribute("PlotIndex")
		expect(index ~= nil).toBe(true)
		expect(seen[index]).toBeNil()
		seen[index] = true
	end
	world:addPlayer(2013, "P13")
	world:advance(1, 0.1)
	world:assertNoErrors()
	world:advance(20, 0.1)
	world:assertNoErrors()
end

-- Harness-only product id (not a published Roblox asset). Exercises receipt idempotency.
local HARNESS_PRODUCT_ID = 910000001

tests["ProcessReceipt is idempotent and PurchaseGranted only after save"] = function()
	local world = boot()
	local player = joinAndLoad(world, 5101, "Buyer")
	local MonetizationConfig = world:require("ReplicatedStorage/Voidline/Config/MonetizationConfig")
	for _, product in MonetizationConfig.DevProducts do
		if product.Id == "SummonVoidStarfall" then
			product.ProductId = HARNESS_PRODUCT_ID
			break
		end
	end
	local MS = service(world, "MonetizationService")
	local PDS = service(world, "PlayerDataService")
	local receipt = {
		PlayerId = player.UserId,
		PurchaseId = "harness-rcpt-1",
		ProductId = HARNESS_PRODUCT_ID,
	}
	local first = MS.ProcessReceipt(receipt)
	expect(first.Name).toBe("PurchaseGranted")
	local profile = PDS.Get(player)
	expect(type(profile.ProcessedReceipts["harness-rcpt-1"])).toBe("number")
	local summons = profile.Summons
	local second = MS.ProcessReceipt(receipt)
	expect(second.Name).toBe("PurchaseGranted")
	expect(PDS.Get(player).Summons).toBe(summons)
	world:assertNoErrors()
end

tests["SetFormation updates profile and player attribute"] = function()
	local world = boot()
	local player = joinAndLoad(world, 4101, "FormationPilot")
	world:fireServer("TutorialSkip", player)
	world:advance(0.2, 0.1)
	world:fireServer("SetFormation", player, 2)
	world:advance(0.2, 0.1)
	world:assertNoErrors()
	local profile = service(world, "PlayerDataService").Get(player)
	expect(profile.Formation).toBe(2)
	expect(player:GetAttribute("Formation")).toBe(2)
end

tests["forge: 25 shards -> artifact -> tokens payout"] = function()
	local world = boot()
	local player = joinAndLoad(world, 4102, "Smith")
	world:fireServer("TutorialSkip", player)
	local PDS = service(world, "PlayerDataService")
	local ForgeConfig = world:require("ReplicatedStorage/Voidline/Config/ForgeConfig")
	PDS.Mutate(player, function(p)
		p.VoidShards = ForgeConfig.ShardsPerArtifact
	end)
	world:clearRemoteLog()
	world:fireServer("RequestForge", player)
	world:advance(0.3, 0.1)
	world:assertNoErrors()
	expect(PDS.Get(player).ForgeJobEndsAt > 0).toBe(true)
	world:advance(20, 0.25)
	world:assertNoErrors()
	expect(juiceKinds(world, player).Forge >= 1).toBe(true)
	expect(PDS.Get(player).Artifacts > 0).toBe(true)
	local tokensBefore = PDS.Get(player).VoidlineTokens
	world:fireServer("TurnInArtifact", player)
	world:advance(0.5, 0.1)
	world:assertNoErrors()
	expect(PDS.Get(player).VoidlineTokens > tokensBefore).toBe(true)
	expect(juiceKinds(world, player).Tokens >= 1).toBe(true)
end

tests["rebirth at station tier 10 resets tiers and bumps multiplier"] = function()
	local world = boot()
	local player = joinAndLoad(world, 4103, "VoidI")
	world:fireServer("TutorialSkip", player)
	local PDS = service(world, "PlayerDataService")
	local RebirthConfig = world:require("ReplicatedStorage/Voidline/Config/RebirthConfig")
	PDS.Mutate(player, function(p)
		p.StationTier = RebirthConfig.RequiredStationTier
		p.Credits = 99999
	end)
	world:clearRemoteLog()
	world:fireServer("RequestRebirth", player)
	world:advance(0.5, 0.1)
	world:assertNoErrors()
	local profile = PDS.Get(player)
	expect(profile.Rebirths).toBe(1)
	expect(profile.StationTier).toBe(1)
	expect(juiceKinds(world, player).Rebirth).toBe(1)
end

tests["a full server simulates a minute of mining without errors"] = function()
	local world = boot()
	local players = {}
	for i = 1, 8 do
		table.insert(players, world:addPlayer(3000 + i, "M" .. i))
	end
	world:advance(2, 0.1)
	for _, player in players do
		world:fireServer("TutorialSkip", player)
	end
	world:advance(60, 0.1)
	world:assertNoErrors()
	local PDS = service(world, "PlayerDataService")
	for _, player in players do
		expect(PDS.Get(player).LifetimeOre > 0).toBe(true)
	end
end

return tests
