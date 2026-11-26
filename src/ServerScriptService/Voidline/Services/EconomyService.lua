--!strict
-- Cargo, refining and station upgrades. All amounts are computed here from
-- the profile and shared rules; clients only ask ("sell", "upgrade Drill").
-- Diegetic controls: ProximityPrompts on each plot's pads, plus standing on
-- the gold Refinery pad auto-refines.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Voidline = ReplicatedStorage:WaitForChild("Voidline")
local GameConfig = require(Voidline.Config.GameConfig)
local EconomyConfig = require(Voidline.Config.EconomyConfig)
local DroneConfig = require(Voidline.Config.DroneConfig)
local GalaxyConfig = require(Voidline.Config.GalaxyConfig)
local PlotLayout = require(Voidline.Modules.PlotLayout)
local FormatNumber = require(Voidline.Modules.FormatNumber)
local EconomyRules = require(Voidline.Rules.EconomyRules)
local OreRegistry = require(Voidline.Content.OreRegistry)

local ValidateRemote = require(script.Parent.Parent.Security.ValidateRemote)
local PlayerDataService = require(script.Parent.PlayerDataService)
local PlotService = require(script.Parent.PlotService)
local JuiceService = require(script.Parent.JuiceService)
local StatService = require(script.Parent.StatService)
local CodexService = require(script.Parent.CodexService)
local TutorialService = require(script.Parent.TutorialService)

local EconomyService = {}

local upgradedCallbacks: { (Player, string) -> () } = {}
local lastPadSell: { [number]: number } = {}
local prompts: { [number]: { [string]: ProximityPrompt } } = {}

local PAD_SELL_COOLDOWN = 0.75
local PAD_ZONE_HALF = 5.5

function EconomyService.OnUpgraded(callback: (Player, string) -> ())
	table.insert(upgradedCallbacks, callback)
end

local function promptText(profile: any, upgradeId: string, ctx: EconomyRules.Ctx): string
	local def = EconomyConfig.Upgrades[upgradeId]
	local level = profile[def.Stat]
	if level >= def.Max then
		return ("%s · MAX"):format(def.Label)
	end
	local cost = EconomyRules.UpgradeCost(profile, upgradeId, ctx) or 0
	local _, reason = EconomyRules.CanUpgrade(profile, upgradeId, ctx)
	if reason == "locked" then
		return ("%s · needs Station Tier %d"):format(def.Label, 2 * profile.DroneTier)
	end
	return ("%s Lv%d · %s Cr"):format(def.Label, level + 1, FormatNumber.Compact(cost))
end

-- Refreshes the owner's pad prompts (costs change after every purchase).
function EconomyService.RefreshPrompts(player: Player)
	local index = PlotService.IndexOf(player)
	local profile = PlayerDataService.Get(player)
	if not index or not profile then
		return
	end
	local set = prompts[index]
	if not set then
		return
	end
	local ctx = PlayerDataService.Ctx(player)
	for upgradeId, prompt in set do
		if EconomyConfig.Upgrades[upgradeId] then
			prompt.ObjectText = promptText(profile, upgradeId, ctx)
		end
	end
end

local function cargoFull(profile: any): boolean
	return EconomyRules.CargoSpace(profile) <= 0
end

function EconomyService.UnitValue(profile: any, oreId: string): number
	local ore = OreRegistry.ById[oreId]
	return EconomyRules.UnitValue(EconomyRules.ActiveSector(profile), if ore then ore.ValueMult else 1)
end

-- Sells the whole hold. `source`: "pad" | "prompt" | "remote" | "warp".
function EconomyService.Sell(player: Player, source: string): (number, number)
	local profile = PlayerDataService.Get(player)
	if not profile or profile.Ore <= 0 then
		return 0, 0
	end
	local ctx = PlayerDataService.Ctx(player)
	local credits, ore = 0, 0
	PlayerDataService.Mutate(player, function(p)
		credits, ore = EconomyRules.Sell(p, ctx)
	end)
	if ore <= 0 then
		return 0, 0
	end
	JuiceService.Send(player, "Sell", { Credits = credits, Ore = ore, Source = source })
	StatService.Bump(player, "Sells", 1)
	StatService.Bump(player, "CreditsEarned", credits)
	StatService.Check(player, "LifetimeCredits", "Credits")
	TutorialService.OnSold(player)
	EconomyService.RefreshPrompts(player)
	return credits, ore
end

export type GrantOptions = {
	Overflow: string?, -- "refine": contest payouts never go to waste
	Position: Vector3?,
	Source: string?,
}

-- Adds mined ore to the cargo hold. Returns (stored, creditsFromOverflow).
function EconomyService.GrantOre(
	player: Player,
	oreId: string,
	amount: number,
	options: GrantOptions?
): (number, number)
	local profile = PlayerDataService.Get(player)
	if not profile or amount <= 0 then
		return 0, 0
	end
	local opts: GrantOptions = options or {}
	local unit = EconomyService.UnitValue(profile, oreId)
	local ctx = PlayerDataService.Ctx(player)
	local stored, refined = 0, 0
	PlayerDataService.Mutate(player, function(p)
		stored = EconomyRules.AddOre(p, amount, unit)
		local overflow = math.floor(amount) - stored
		if opts.Overflow == "refine" and overflow > 0 then
			refined = math.floor(overflow * unit * EconomyRules.CreditMultiplier(p, ctx) + 1e-9)
			EconomyRules.AddCredits(p, refined)
		end
	end)
	JuiceService.Send(player, "Ore", {
		Amount = stored,
		OreId = oreId,
		Refined = refined,
		Full = cargoFull(profile),
		Position = opts.Position,
		Source = opts.Source,
	})
	CodexService.Discover(player, oreId)
	if stored > 0 then
		StatService.Bump(player, "OreStored", stored)
		StatService.Check(player, "LifetimeOre")
		TutorialService.OnOreStored(player)
	end
	if refined > 0 then
		StatService.Check(player, "LifetimeCredits", "Credits")
	end
	-- Auto-Sell Warp Link: a full hold warps itself to the refinery.
	if cargoFull(profile) and profile.TutorialComplete and PlayerDataService.HasPerk(player, "AutoSellWarpLink") then
		EconomyService.Sell(player, "warp")
	end
	return stored, refined
end

function EconomyService.AddCredits(player: Player, amount: number, source: string)
	if amount <= 0 then
		return
	end
	PlayerDataService.Mutate(player, function(p)
		EconomyRules.AddCredits(p, math.floor(amount))
	end)
	JuiceService.Send(player, "Credits", { Amount = math.floor(amount), Source = source })
	StatService.Check(player, "LifetimeCredits", "Credits")
	EconomyService.RefreshPrompts(player)
end

function EconomyService.AddShards(player: Player, amount: number, source: string)
	if amount <= 0 then
		return
	end
	PlayerDataService.Mutate(player, function(p)
		p.VoidShards += math.floor(amount)
		p.LifetimeShards += math.floor(amount)
	end)
	JuiceService.Send(player, "Shards", { Amount = math.floor(amount), Source = source })
	StatService.Bump(player, "ShardsFound", math.floor(amount))
	StatService.Check(player, "LifetimeShards")
end

function EconomyService.Upgrade(player: Player, upgradeId: string, branch: string?): (boolean, string?)
	local id = EconomyRules.NormalizeUpgradeId(upgradeId)
	if not EconomyConfig.Upgrades[id] then
		return false, "unknown"
	end
	local ctx = PlayerDataService.Ctx(player)
	local ok, cost, reason = false, 0, nil :: string?
	local newSectors: { string } = {}
	PlayerDataService.Mutate(player, function(p)
		local before = table.clone(p.GalaxyFlags)
		ok, cost, reason = EconomyRules.ApplyUpgrade(p, id, ctx, branch)
		if ok then
			for sectorId, flag in p.GalaxyFlags do
				if flag and not before[sectorId] then
					table.insert(newSectors, sectorId)
				end
			end
		end
	end)
	if not ok then
		JuiceService.Send(player, "UpgradeFail", { Id = id, Reason = reason })
		return false, reason
	end
	local profile = PlayerDataService.Get(player) :: any
	local def = EconomyConfig.Upgrades[id]
	JuiceService.Send(player, "Upgrade", { Id = id, Level = profile[def.Stat], Cost = cost })
	StatService.Bump(player, "UpgradesBought", 1)
	StatService.Check(player, def.Stat)
	for _, sectorId in newSectors do
		JuiceService.Banner(player, "SECTOR DISCOVERED · " .. GalaxyConfig.Label(sectorId), "gold")
		StatService.Check(player, "Flag:GalaxyFlags." .. sectorId)
	end
	TutorialService.OnUpgrade(player, id)
	for _, callback in upgradedCallbacks do
		task.spawn(callback, player, id)
	end
	EconomyService.RefreshPrompts(player)
	return true, nil
end

function EconomyService.QuickUpgrade(player: Player): boolean
	local profile = PlayerDataService.Get(player)
	if not profile then
		return false
	end
	local choice = EconomyRules.QuickUpgradeChoice(profile, PlayerDataService.Ctx(player))
	if not choice then
		JuiceService.Send(player, "UpgradeFail", { Id = "", Reason = "funds" })
		return false
	end
	return (EconomyService.Upgrade(player, choice))
end

local function ownerOf(index: number): Player?
	return PlotService.Owners[index]
end

local function makePrompt(parent: Instance, action: string, object: string, key: Enum.KeyCode): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = action
	prompt.ObjectText = object
	prompt.KeyboardKeyCode = key
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = true
	prompt.Enabled = false -- enabled only while a pilot owns this plot
	prompt.Parent = parent
	return prompt
end

local function setPlotPromptsEnabled(index: number, enabled: boolean)
	local set = prompts[index]
	if not set then
		return
	end
	for _, prompt in set do
		prompt.Enabled = enabled
	end
end

local function buildPrompts(index: number)
	local plot = PlotService.Folder(index)
	local station = plot and plot:FindFirstChild("Station")
	if not station then
		return
	end
	local set: { [string]: ProximityPrompt } = {}
	prompts[index] = set
	local pads = station:FindFirstChild("UpgradePads")
	if pads then
		for _, pad in pads:GetChildren() do
			local upgradeId = pad:GetAttribute("UpgradeId")
			if type(upgradeId) == "string" and EconomyConfig.Upgrades[upgradeId] then
				local prompt = makePrompt(pad, "Upgrade", EconomyConfig.Upgrades[upgradeId].Label, Enum.KeyCode.E)
				set[upgradeId] = prompt
				prompt.Triggered:Connect(function(player)
					if ownerOf(index) ~= player then
						JuiceService.Banner(player, "This is another pilot's station", "warn")
						return
					end
					local branch = if upgradeId == "DroneTier" then player:GetAttribute("PreferredBranch") else nil
					EconomyService.Upgrade(player, upgradeId, if type(branch) == "string" then branch else nil)
				end)
			end
		end
	end
	local refinery = station:FindFirstChild("Refinery")
	if refinery then
		local prompt = makePrompt(refinery, "Refine", "Refinery", Enum.KeyCode.E)
		set.Refinery = prompt
		prompt.Triggered:Connect(function(player)
			if ownerOf(index) == player then
				EconomyService.Sell(player, "prompt")
			end
		end)
	end
	local tuner = station:FindFirstChild("LaserTuner")
	if tuner then
		local prompt = makePrompt(tuner, "Tune Laser", "Laser Tuner", Enum.KeyCode.E)
		set.LaserTuner = prompt
		prompt.Triggered:Connect(function(player)
			if ownerOf(index) ~= player then
				return
			end
			PlayerDataService.Mutate(player, function(p)
				local order = DroneConfig.LaserColorOrder
				local current = table.find(order, p.Settings.LaserColor) or 0
				p.Settings.LaserColor = order[current % #order + 1]
				player:SetAttribute("LaserColor", p.Settings.LaserColor)
			end)
			JuiceService.Send(player, "LaserTuned", {})
		end)
	end
end

local function nearOwnRefinery(player: Player, extra: number): boolean
	local position = PlotService.World(player, PlotLayout.Refinery)
	return position ~= nil and ValidateRemote.NearPosition(player, position, extra)
end

local function padSellTick()
	local now = os.clock()
	for index, player in PlotService.Owners do
		local profile = PlayerDataService.Get(player)
		local root = PlotService.RootPart(player)
		if not profile or not root or profile.Ore <= 0 then
			continue
		end
		if now - (lastPadSell[player.UserId] or 0) < PAD_SELL_COOLDOWN then
			continue
		end
		local localPos = PlotLayout.PlotCFrame(index):PointToObjectSpace(root.Position) - PlotLayout.Refinery
		if
			math.abs(localPos.X) <= PAD_ZONE_HALF
			and math.abs(localPos.Z) <= PAD_ZONE_HALF
			and math.abs(localPos.Y) < 7
		then
			lastPadSell[player.UserId] = now
			EconomyService.Sell(player, "pad")
		end
	end
end

function EconomyService.Init()
	for index = 1, GameConfig.PlotCount do
		buildPrompts(index)
	end
	PlotService.OnClaimed(function(player, index)
		setPlotPromptsEnabled(index, true)
		EconomyService.RefreshPrompts(player)
	end)

	ValidateRemote.Bind("SellOre", { Rate = 0.4, Burst = 3 }, function(player)
		local profile = PlayerDataService.Get(player)
		if not profile then
			return
		end
		local remote = PlayerDataService.HasPerk(player, "AutoSellWarpLink")
		if remote or nearOwnRefinery(player, EconomyConfig.SellRange) then
			EconomyService.Sell(player, if remote then "warp" else "remote")
		else
			JuiceService.Banner(player, "Fly back to your Refinery to sell", "warn")
		end
	end)

	ValidateRemote.Bind(
		"RequestUpgrade",
		{ Rate = 0.15, Burst = 6, Args = { "string", "string?" }, MaxString = 24 },
		function(player, upgradeId, branch)
			if branch ~= nil and not DroneConfig.Branches[branch] then
				return
			end
			if branch then
				player:SetAttribute("PreferredBranch", branch)
			end
			EconomyService.Upgrade(player, upgradeId, branch)
		end
	)

	ValidateRemote.Bind("QuickUpgrade", { Rate = 0.15, Burst = 6 }, function(player)
		EconomyService.QuickUpgrade(player)
	end)

	task.spawn(function()
		while true do
			task.wait(0.25)
			padSellTick()
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastPadSell[player.UserId] = nil
	end)
end

return EconomyService
