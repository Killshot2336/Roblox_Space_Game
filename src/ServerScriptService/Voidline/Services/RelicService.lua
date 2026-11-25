--!strict
-- Relic finds, duplicates and the pedestal row on each pilot's station.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Voidline = ReplicatedStorage:WaitForChild("Voidline")
local PlotLayout = require(Voidline.Modules.PlotLayout)
local RelicRegistry = require(Voidline.Content.RelicRegistry)
local GameConfig = require(Voidline.Config.GameConfig)

local ValidateRemote = require(script.Parent.Parent.Security.ValidateRemote)
local PlayerDataService = require(script.Parent.PlayerDataService)
local PlotService = require(script.Parent.PlotService)
local JuiceService = require(script.Parent.JuiceService)
local StatService = require(script.Parent.StatService)
local CodexService = require(script.Parent.CodexService)

local RelicService = {}

local DUPLICATE_SHARDS = 2
local SHAPES: { [string]: Enum.PartType } = {
	Orb = Enum.PartType.Ball,
	Crown = Enum.PartType.Ball,
	Ring = Enum.PartType.Cylinder,
	Device = Enum.PartType.Cylinder,
	Shard = Enum.PartType.Wedge,
	Idol = Enum.PartType.Block,
	Tablet = Enum.PartType.Block,
}

local rng = Random.new()

local function ownedCount(value: any): number
	if type(value) == "number" then
		return value
	end
	return if value then 1 else 0
end

local function pedestalPart(folder: Instance, slot: number, plotCFrame: CFrame, name: string): Part
	local existing = folder:FindFirstChild(name .. slot)
	if existing and existing:IsA("Part") then
		return existing
	end
	local part = Instance.new("Part")
	part.Name = name .. slot
	part.Anchored = true
	part.CanTouch = false
	part.CastShadow = false
	if name == "Pedestal" then
		part.Size = Vector3.new(2.4, 3, 2.4)
		part.Material = Enum.Material.Marble
		part.Color = GameConfig.Colors.Obsidian
		part.CFrame = plotCFrame * CFrame.new(PlotLayout.Pedestal(slot) - Vector3.new(0, 0.5, 0))
	else
		part.Size = Vector3.new(1.4, 1.4, 1.4)
		part.Material = Enum.Material.Neon
		part.CanCollide = false
		part.CFrame = plotCFrame * CFrame.new(PlotLayout.Pedestal(slot) + Vector3.new(0, 2, 0))
	end
	part.Parent = folder
	return part
end

-- Rebuilds the pedestal row for the pilot's current display list.
function RelicService.RefreshPedestals(player: Player)
	local index = PlotService.IndexOf(player)
	local profile = PlayerDataService.Get(player)
	local plot = index and PlotService.Folder(index)
	local folder = plot and plot:FindFirstChild("Pedestals")
	if not index or not profile or not folder then
		return
	end
	local plotCFrame = PlotLayout.PlotCFrame(index)
	for slot = 1, PlotLayout.PedestalCount do
		local relicId = profile.RelicDisplay[slot]
		local relic = if type(relicId) == "string" then RelicRegistry.ById[relicId] else nil
		local gemName = "Gem" .. slot
		if relic then
			pedestalPart(folder, slot, plotCFrame, "Pedestal")
			local gem = pedestalPart(folder, slot, plotCFrame, "Gem")
			gem.Shape = SHAPES[relic.Shape] or Enum.PartType.Ball
			gem.Color = relic.Color
			gem:SetAttribute("RelicId", relic.Id)
		else
			local pedestal = folder:FindFirstChild("Pedestal" .. slot)
			local gem = folder:FindFirstChild(gemName)
			if pedestal then
				pedestal:Destroy()
			end
			if gem then
				gem:Destroy()
			end
		end
	end
end

local function clearPedestals(_player: Player, index: number)
	local plot = PlotService.Folder(index)
	local folder = plot and plot:FindFirstChild("Pedestals")
	if folder then
		folder:ClearAllChildren()
	end
end

-- Grants a relic (rolled unless `relicId` is given). Returns the relic.
function RelicService.Grant(player: Player, source: string, relicId: string?): RelicRegistry.Relic?
	local relic: RelicRegistry.Relic = if relicId and RelicRegistry.ById[relicId]
		then RelicRegistry.ById[relicId]
		else RelicRegistry.Roll(rng)
	local isNew = false
	local applied = PlayerDataService.Mutate(player, function(p)
		local count = ownedCount(p.Relics[relic.Id])
		isNew = count == 0
		p.Relics[relic.Id] = count + 1
		if isNew and #p.RelicDisplay < PlotLayout.PedestalCount then
			table.insert(p.RelicDisplay, relic.Id)
		end
		if not isNew then
			p.VoidShards += DUPLICATE_SHARDS
			p.LifetimeShards += DUPLICATE_SHARDS
		end
	end)
	if not applied then
		return nil
	end
	JuiceService.Send(player, "Relic", {
		Id = relic.Id,
		New = isNew,
		Source = source,
		DuplicateShards = if isNew then 0 else DUPLICATE_SHARDS,
	})
	if isNew then
		CodexService.Discover(player, relic.Id, true)
		StatService.Check(player, "RelicCount", "RelicSet:" .. relic.Set)
		RelicService.RefreshPedestals(player)
	else
		StatService.Check(player, "LifetimeShards")
	end
	return relic
end

-- Rolls a find with the given probability. Returns the relic or nil.
function RelicService.TryFind(player: Player, chance: number, source: string): RelicRegistry.Relic?
	if chance > 0 and rng:NextNumber() < chance then
		return RelicService.Grant(player, source)
	end
	return nil
end

function RelicService.Init()
	PlotService.OnClaimed(function(player)
		RelicService.RefreshPedestals(player)
	end)
	PlotService.OnReleased(clearPedestals)

	ValidateRemote.Bind("SetRelicDisplay", { Rate = 0.5, Burst = 3, Args = { "table" } }, function(player, list)
		local profile = PlayerDataService.Get(player)
		if not profile or #list > PlotLayout.PedestalCount then
			return
		end
		local clean: { string } = {}
		local seen: { [string]: boolean } = {}
		for i = 1, #list do
			local id = list[i]
			if type(id) ~= "string" or seen[id] or ownedCount(profile.Relics[id]) == 0 then
				return
			end
			seen[id] = true
			table.insert(clean, id)
		end
		PlayerDataService.Mutate(player, function(p)
			p.RelicDisplay = clean
		end)
		RelicService.RefreshPedestals(player)
	end)
end

return RelicService
