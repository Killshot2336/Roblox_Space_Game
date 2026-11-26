--!strict
-- Dual-currency store. Every Marketplace/Policy call is pcall-wrapped.
--   * Game passes: ownership checked on join and after a purchase prompt.
--     An ID of 0 is a placeholder: never prompted, never granted.
--   * Tokens: the same passes 15-20% cheaper, earn-only currency.
--   * Developer products (Robux-only summons): ProcessReceipt is idempotent.
--     The PurchaseId is recorded in the profile with the grant and
--     PurchaseGranted is returned only after that profile was saved.
--   * Paid random outcomes (Void Starfall) are disabled for players whose
--     policy restricts them (and when the policy lookup fails).
local MarketplaceService = game:GetService("MarketplaceService")
local PolicyService = game:GetService("PolicyService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Voidline = ReplicatedStorage:WaitForChild("Voidline")
local MonetizationConfig = require(Voidline.Config.MonetizationConfig)
local ProfileSchema = require(Voidline.Modules.ProfileSchema)
local StoreRules = require(Voidline.Rules.StoreRules)
local Remotes = require(Voidline.Remotes)

local ValidateRemote = require(script.Parent.Parent.Security.ValidateRemote)
local PlayerDataService = require(script.Parent.PlayerDataService)
local JuiceService = require(script.Parent.JuiceService)
local DroneService = require(script.Parent.DroneService)
local SummonService = require(script.Parent.SummonService)
local EconomyService = require(script.Parent.EconomyService)

local MonetizationService = {}

local restricted: { [number]: boolean } = {}

local function sendStoreState(player: Player)
	local session = PlayerDataService.Session(player)
	if not session then
		return
	end
	Remotes.Get("StoreState"):FireClient(player, {
		GamePasses = session.GamePasses,
		PaidRandomRestricted = restricted[player.UserId] ~= false,
	})
end

function MonetizationService.IsRandomRestricted(player: Player): boolean
	return restricted[player.UserId] ~= false
end

local function refreshPolicy(player: Player)
	local ok, info = pcall(function()
		return PolicyService:GetPolicyInfoForPlayerAsync(player)
	end)
	-- Fail closed: if we cannot read the policy, treat random items as restricted.
	local value = true
	if ok and type(info) == "table" then
		value = info.ArePaidRandomItemsRestricted == true
	end
	restricted[player.UserId] = value
	player:SetAttribute("PaidRandomRestricted", value)
end

local function applyPassGrants(player: Player, passId: string)
	local granted = false
	PlayerDataService.Mutate(player, function(p)
		granted = StoreRules.ApplyPassGrants(p, passId)
	end)
	if granted then
		local pass = MonetizationConfig.GetPass(passId)
		JuiceService.Send(player, "PassGranted", { Id = passId, Name = if pass then pass.Name else passId })
		if passId == "StarterBundle" then
			EconomyService.RefreshPrompts(player)
		end
	end
end

local function refreshGamePasses(player: Player)
	for _, pass in MonetizationConfig.Passes do
		if pass.GamePassId == 0 then
			continue
		end
		local ok, owned = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.GamePassId)
		end)
		if ok then
			PlayerDataService.SetGamePass(player, pass.Id, owned == true)
			if owned then
				applyPassGrants(player, pass.Id)
			end
		end
	end
	DroneService.RefreshLook(player)
	sendStoreState(player)
end

function MonetizationService.BuyWithTokens(player: Player, passId: string): (boolean, string?)
	local ok, reason = false, nil :: string?
	PlayerDataService.Mutate(player, function(p)
		ok, reason = StoreRules.BuyWithTokens(p, passId)
	end)
	if not ok then
		JuiceService.Send(player, "Store", { Ok = false, Reason = reason, Id = passId })
		return false, reason
	end
	applyPassGrants(player, passId)
	JuiceService.Send(player, "Store", { Ok = true, Id = passId, Currency = "Tokens" })
	DroneService.RefreshLook(player)
	sendStoreState(player)
	task.spawn(PlayerDataService.Save, player)
	return true, nil
end

function MonetizationService.PromptRobux(player: Player, kind: string, id: string): boolean
	if kind == "Pass" then
		local pass = MonetizationConfig.GetPass(id)
		if not pass or pass.GamePassId == 0 then
			JuiceService.Send(player, "Store", { Ok = false, Reason = "unavailable", Id = id })
			return false
		end
		local ok = pcall(function()
			MarketplaceService:PromptGamePassPurchase(player, pass.GamePassId)
		end)
		return ok
	elseif kind == "Product" then
		local product = MonetizationConfig.GetProduct(id)
		if not product or product.ProductId == 0 then
			JuiceService.Send(player, "Store", { Ok = false, Reason = "unavailable", Id = id })
			return false
		end
		if product.RandomOutcome and MonetizationService.IsRandomRestricted(player) then
			JuiceService.Send(player, "Store", { Ok = false, Reason = "restricted", Id = id })
			return false
		end
		local ok = pcall(function()
			MarketplaceService:PromptProductPurchase(player, product.ProductId)
		end)
		return ok
	end
	return false
end

function MonetizationService.ProcessReceipt(receiptInfo: any): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	local session = if player then PlayerDataService.Session(player) else nil
	if not player or not session then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local purchaseId = tostring(receiptInfo.PurchaseId)
	if session.Profile.ProcessedReceipts[purchaseId] then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local product = MonetizationConfig.ProductByProductId(receiptInfo.ProductId)
	if not product then
		warn(("[Voidline] receipt for unknown product %s"):format(tostring(receiptInfo.ProductId)))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	PlayerDataService.Mutate(player, function(p)
		ProfileSchema.RecordReceipt(p, purchaseId, os.time())
		ProfileSchema.Bump(p, "Summons", 1)
	end)
	SummonService.Enqueue(product.Id, player)
	JuiceService.Send(player, "Store", { Ok = true, Id = product.Id, Currency = "Robux" })
	if not PlayerDataService.SaveNow(player) then
		-- Recorded in memory, so a retry on this server will not double-grant.
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function MonetizationService.Init()
	MarketplaceService.ProcessReceipt = MonetizationService.ProcessReceipt

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamePassId, purchased)
		if not purchased then
			return
		end
		local pass = MonetizationConfig.PassByGamePassId(gamePassId)
		if pass then
			PlayerDataService.SetGamePass(player, pass.Id, true)
			applyPassGrants(player, pass.Id)
			DroneService.RefreshLook(player)
			sendStoreState(player)
		end
	end)

	ValidateRemote.Bind(
		"PurchaseWithTokens",
		{ Rate = 0.5, Burst = 2, Args = { "string" }, MaxString = 32 },
		function(player, passId)
			MonetizationService.BuyWithTokens(player, passId)
		end
	)
	ValidateRemote.Bind(
		"PromptRobuxPurchase",
		{ Rate = 0.5, Burst = 2, Args = { "string", "string" }, MaxString = 32 },
		function(player, kind, id)
			MonetizationService.PromptRobux(player, kind, id)
		end
	)

	PlayerDataService.OnLoaded(function(player)
		refreshPolicy(player)
		refreshGamePasses(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		restricted[player.UserId] = nil
	end)
end

return MonetizationService
