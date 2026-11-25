local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Voidline = ReplicatedStorage:WaitForChild("Voidline")
local EconomyConfig = require(Voidline.Config.EconomyConfig)
local OreMath = require(Voidline.Modules.OreMath)
local Remotes = require(Voidline.Remotes)
local RateLimiter = require(Voidline.Modules.RateLimiter)
local PlayerDataService = require(script.Parent.PlayerDataService)
local PlotService = require(script.Parent.PlotService)

local EconomyService = {
	_limiter = RateLimiter.new(0.25),
}

local function has2x(player: Player): boolean
	return PlayerDataService.HasPerk(player, "Credits2x")
end

function EconomyService.AddOre(player: Player, amount: number)
	PlayerDataService.Mutate(player, function(data)
		local cap = OreMath.CargoCap(data.CargoLevel)
		data.Ore = math.min(cap, data.Ore + amount)
	end)
end

function EconomyService.Sell(player: Player): boolean
	local data = PlayerDataService.Get(player)
	if not data or data.Ore <= 0 then
		return false
	end
	local sector = "Starter"
	if data.GalaxyFlags.Celestial then
		sector = "Celestial"
	elseif data.GalaxyFlags.VoidRim then
		sector = "VoidRim"
	elseif data.GalaxyFlags.Nebula then
		sector = "Nebula"
	end
	local payout = OreMath.SellValue(data.Ore, sector, data.CreditMult, has2x(player))
	-- First tutorial sell locked to 30 for starter cargo of 10
	if not data.TutorialComplete and data.TutorialStep <= 2 and data.Ore >= 10 then
		payout = EconomyConfig.FirstSellCredits * data.CreditMult
		if has2x(player) then
			payout *= 2
		end
		payout = math.floor(payout)
	end
	PlayerDataService.Mutate(player, function(d)
		d.Credits += payout
		d.Ore = 0
		if d.TutorialStep == 2 then
			d.TutorialStep = 3
		end
	end)
	Remotes.Get("JuiceEvent"):FireClient(player, { Kind = "Sold", Amount = payout })
	Remotes.Get("TutorialProgress"):FireClient(player, PlayerDataService.Get(player).TutorialStep)
	return true
end

function EconomyService.TryUpgrade(player: Player, upgradeId: string): boolean
	local data = PlayerDataService.Get(player)
	if not data then
		return false
	end

	local cost = 0
	local apply: (any) -> () = function() end

	if upgradeId == "Drill" then
		cost = EconomyConfig.DrillCost(data.DrillLevel)
		-- First drill upgrade exact 20
		if data.DrillLevel == 1 then
			cost = 20
		end
		apply = function(d)
			d.DrillLevel += 1
			d.Credits -= cost
			if d.TutorialStep == 3 and d.DrillLevel >= 2 then
				-- stay on step 3 until drone bought; mark drill done via juice only
			end
		end
	elseif upgradeId == "Cargo" then
		cost = EconomyConfig.CargoCost(data.CargoLevel)
		if data.CargoLevel == 1 then
			cost = 35
		end
		apply = function(d)
			d.CargoLevel += 1
			d.Credits -= cost
		end
	elseif upgradeId == "DroneSlot" or upgradeId == "Drone2" then
		cost = EconomyConfig.DroneSlotCost(data.DroneSlots)
		if data.DroneSlots == 1 then
			cost = 50
		end
		apply = function(d)
			d.DroneSlots += 1
			d.Credits -= cost
			if not d.TutorialComplete and d.DroneSlots >= 2 then
				d.TutorialStep = 4
				d.TutorialComplete = true
				d.Credits += 100
			end
		end
	elseif upgradeId == "StationTier" then
		cost = EconomyConfig.StationTierCost(data.StationTier)
		apply = function(d)
			d.StationTier += 1
			d.Credits -= cost
			if d.StationTier >= 3 then
				d.GalaxyFlags.Nebula = true
			end
			if d.StationTier >= 6 and d.DroneTier >= 2 then
				d.GalaxyFlags.VoidRim = true
			end
			if d.StationTier >= 10 then
				d.GalaxyFlags.Celestial = true
			end
			if d.DrillLevel >= 5 then
				d.DroneTier = math.max(d.DroneTier, 2)
			end
		end
	else
		return false
	end

	if data.Credits < cost then
		return false
	end
	PlayerDataService.Mutate(player, apply)
	local after = PlayerDataService.Get(player)
	if after and after.TutorialComplete and after.TutorialStep == 4 then
		PlotService.IgniteBridge(player)
		Remotes.Get("JuiceEvent"):FireClient(player, { Kind = "TutorialComplete", Bonus = 100 })
	end
	Remotes.Get("JuiceEvent"):FireClient(player, { Kind = "Upgrade", Id = upgradeId })
	-- Notify drone service via bindable attribute
	player:SetAttribute("VoidlineDroneSlots", after and after.DroneSlots or 1)
	player:SetAttribute("VoidlineDrillLevel", after and after.DrillLevel or 1)
	return true
end

function EconomyService.Init()
	Remotes.Get("SellOre").OnServerEvent:Connect(function(player)
		if not EconomyService._limiter:Allow(player.UserId) then
			return
		end
		EconomyService.Sell(player)
	end)

	Remotes.Get("RequestUpgrade").OnServerEvent:Connect(function(player, upgradeId)
		if not EconomyService._limiter:Allow(player.UserId) then
			return
		end
		if typeof(upgradeId) ~= "string" then
			return
		end
		EconomyService.TryUpgrade(player, upgradeId)
	end)

	Remotes.Get("QuickUpgrade").OnServerEvent:Connect(function(player)
		if not EconomyService._limiter:Allow(player.UserId) then
			return
		end
		-- Prefer cheapest affordable starter-path upgrade
		local data = PlayerDataService.Get(player)
		if not data then
			return
		end
		local order = { "Drill", "Cargo", "DroneSlot", "StationTier" }
		for _, id in order do
			if EconomyService.TryUpgrade(player, id) then
				return
			end
		end
	end)
end

return EconomyService
