--!strict
-- Void Rift parkour: while the Rift event is open the shard spiral around
-- the Monolith turns solid and a cache waits on top. Each pilot can claim it
-- once per opening; falling off just drops you back onto the hub.
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Voidline = ReplicatedStorage:WaitForChild("Voidline")
local HubLayout = require(Voidline.Modules.HubLayout)

local ValidateRemote = require(script.Parent.Parent.Security.ValidateRemote)
local PlayerDataService = require(script.Parent.PlayerDataService)
local EconomyService = require(script.Parent.EconomyService)
local StatService = require(script.Parent.StatService)
local JuiceService = require(script.Parent.JuiceService)

local RiftService = {}

local CLAIM_RANGE = 12
local REWARD_SHARDS = 6
local REWARD_CREDITS_PER_TIER = 120

local claimed: { [number]: boolean } = {}
local open = false

local function riftFolder(): Instance?
	local map = Workspace:FindFirstChild("VoidlineMap")
	local hub = map and map:FindFirstChild("Hub")
	return hub and hub:FindFirstChild("VoidRift")
end

local function setSolid(solid: boolean)
	local folder = riftFolder()
	if not folder then
		return
	end
	for _, part in folder:GetChildren() do
		if part:IsA("BasePart") then
			part.CanCollide = solid
			part.Transparency = if solid then 0.2 else 0.85
		end
	end
end

function RiftService.IsOpen(): boolean
	return open
end

function RiftService.Open()
	open = true
	table.clear(claimed)
	setSolid(true)
	Workspace:SetAttribute("RiftOpen", true)
end

function RiftService.Close()
	open = false
	setSolid(false)
	Workspace:SetAttribute("RiftOpen", false)
end

function RiftService.Claim(player: Player): boolean
	if not open or claimed[player.UserId] then
		return false
	end
	if not ValidateRemote.NearPosition(player, HubLayout.RiftCache, CLAIM_RANGE) then
		return false
	end
	local profile = PlayerDataService.Get(player)
	if not profile then
		return false
	end
	claimed[player.UserId] = true
	EconomyService.AddCredits(player, REWARD_CREDITS_PER_TIER * profile.StationTier, "rift")
	EconomyService.AddShards(player, REWARD_SHARDS, "rift")
	StatService.Bump(player, "RiftClears", 1)
	JuiceService.Send(player, "RiftCleared", {})
	return true
end

function RiftService.Init()
	local folder = riftFolder()
	local cache = folder and folder:FindFirstChild("RiftCache")
	if cache then
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Claim"
		prompt.ObjectText = "Rift Cache"
		prompt.HoldDuration = 0.4
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = cache
		prompt.Triggered:Connect(function(player)
			RiftService.Claim(player)
		end)
	end
	RiftService.Close()
end

return RiftService
