local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Voidline = ReplicatedStorage:WaitForChild("Voidline")
local MonetizationConfig = require(Voidline.Config.MonetizationConfig)
local Remotes = require(Voidline.Remotes)
local RateLimiter = require(Voidline.Modules.RateLimiter)
local PlayerDataService = require(script.Parent.PlayerDataService)
local WorldEventService = require(script.Parent.WorldEventService)

local MonetizationService = {
	_limiter = RateLimiter.new(0.5),
}

local function grantPass(player: Player, passId: string)
	PlayerDataService.Mutate(player, function(d)
		d.OwnedPerks[passId] = true
	end)
	PlayerDataService.Save(player)
	Remotes.Get("JuiceEvent"):FireClient(player, { Kind = "PassOwned", Id = passId })
end

function MonetizationService.Init()
	Remotes.Get("PurchaseWithTokens").OnServerEvent:Connect(function(player, passId)
		if not MonetizationService._limiter:Allow(player.UserId) then
			return
		end
		if typeof(passId) ~= "string" then
			return
		end
		local pass = MonetizationConfig.GetPass(passId)
		local data = PlayerDataService.Get(player)
		if not pass or not data then
			return
		end
		if data.OwnedPerks[passId] then
			return
		end
		if data.VoidlineTokens < pass.Tokens then
			return
		end
		PlayerDataService.Mutate(player, function(d)
			d.VoidlineTokens -= pass.Tokens
			d.OwnedPerks[passId] = true
		end)
		PlayerDataService.Save(player)
		Remotes.Get("JuiceEvent"):FireClient(player, { Kind = "PassOwned", Id = passId })
	end)

	Remotes.Get("PromptRobuxPurchase").OnServerEvent:Connect(function(player, kind, id)
		if not MonetizationService._limiter:Allow(player.UserId) then
			return
		end
		if kind == "Pass" then
			local pass = MonetizationConfig.GetPass(id)
			if not pass or pass.GamePassId == 0 then
				-- Studio/dev fallback: grant for testing when ID unset
				grantPass(player, id)
				Remotes.Get("JuiceEvent"):FireClient(player, {
					Kind = "DevGrant",
					Message = "Placeholder GamePassId — granted for Studio test",
				})
				return
			end
			MarketplaceService:PromptGamePassPurchase(player, pass.GamePassId)
		elseif kind == "Product" then
			local product = nil
			for _, p in MonetizationConfig.DevProducts do
				if p.Id == id then
					product = p
					break
				end
			end
			if not product or product.ProductId == 0 then
				if id == "SummonVoidStarfall" then
					WorldEventService.QueueSummon(player, "VoidStarfall")
				elseif id == "ServerLuckSurge" then
					WorldEventService.QueueSummon(player, "LuckSurge")
				end
				return
			end
			MarketplaceService:PromptProductPurchase(player, product.ProductId)
		end
	end)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, wasPurchased)
		if not wasPurchased then
			return
		end
		for _, pass in MonetizationConfig.Passes do
			if pass.GamePassId == passId then
				grantPass(player, pass.Id)
				break
			end
		end
	end)

	MarketplaceService.ProcessReceipt = function(receipt)
		local player = Players:GetPlayerByUserId(receipt.PlayerId)
		if not player then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		for _, product in MonetizationConfig.DevProducts do
			if product.ProductId == receipt.ProductId then
				if product.Id == "SummonVoidStarfall" then
					WorldEventService.QueueSummon(player, "VoidStarfall")
				elseif product.Id == "ServerLuckSurge" then
					WorldEventService.QueueSummon(player, "LuckSurge")
				end
				return Enum.ProductPurchaseDecision.PurchaseGranted
			end
		end
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
end

return MonetizationService
