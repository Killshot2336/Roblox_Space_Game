--!strict
-- Warps: Home and Hub are always free. The Star Overlook and the Void Rift
-- open from their hub gates; the Deep-Space Warp Pass opens them (and the
-- Monolith plaza) from anywhere. Pilots who fall into the void are caught
-- and warped home instead of dying.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Voidline = ReplicatedStorage:WaitForChild("Voidline")
local HubLayout = require(Voidline.Modules.HubLayout)

local ValidateRemote = require(script.Parent.Parent.Security.ValidateRemote)
local PlayerDataService = require(script.Parent.PlayerDataService)
local PlotService = require(script.Parent.PlotService)
local RiftService = require(script.Parent.RiftService)
local JuiceService = require(script.Parent.JuiceService)

local WarpService = {}

local COOLDOWN = 2
local GATE_RANGE = 14
local VOID_CATCH_Y = -90
local CHECK_INTERVAL = 0.5
local WARP_PASS = "DeepSpaceWarpPass"

local lastWarp: { [number]: number } = {}

local function hubSpawn(): CFrame
	return CFrame.lookAt(HubLayout.Spawn + Vector3.new(0, 3, 0), Vector3.new(0, HubLayout.Spawn.Y + 3, 0))
end

local DESTINATIONS: { [string]: (Player) -> CFrame? } = {
	Home = function(player)
		local index = PlotService.IndexOf(player)
		return if index then PlotService.SpawnCFrame(index) else nil
	end,
	Hub = function()
		return hubSpawn()
	end,
	Monolith = function()
		local plaza = Vector3.new(0, 4.5, 16)
		return CFrame.lookAt(plaza, Vector3.new(0, 4.5, 0))
	end,
	Overlook = function()
		local arrival = HubLayout.Overlook + Vector3.new(0, 4, 6)
		return CFrame.lookAt(arrival, HubLayout.Overlook + Vector3.new(60, 4, -60))
	end,
	Rift = function()
		if not RiftService.IsOpen() then
			return nil
		end
		return CFrame.new(HubLayout.RiftPlatform(1) + Vector3.new(0, 4, 0))
	end,
}

local GATED: { [string]: Vector3 } = {
	Overlook = HubLayout.OverlookGate,
	Rift = HubLayout.RiftGate,
	Monolith = HubLayout.Spawn,
}

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

function WarpService.CanWarp(player: Player, destination: string): (boolean, string?)
	if not DESTINATIONS[destination] then
		return false, "unknown"
	end
	local gate = GATED[destination]
	if gate and not PlayerDataService.HasPerk(player, WARP_PASS) then
		local root = rootOf(player)
		if not root or (root.Position - gate).Magnitude > GATE_RANGE then
			return false, "pass"
		end
	end
	if destination == "Rift" and not RiftService.IsOpen() then
		return false, "closed"
	end
	return true, nil
end

function WarpService.Warp(player: Player, destination: string): boolean
	local now = os.clock()
	if now - (lastWarp[player.UserId] or -math.huge) < COOLDOWN then
		return false
	end
	local ok, reason = WarpService.CanWarp(player, destination)
	if not ok then
		JuiceService.Send(player, "WarpLocked", { Destination = destination, Reason = reason })
		return false
	end
	local target = DESTINATIONS[destination](player)
	local character = player.Character
	if not target or not character then
		return false
	end
	lastWarp[player.UserId] = now
	character:PivotTo(target)
	JuiceService.Send(player, "Warp", { Destination = destination })
	return true
end

local function makeGatePrompt(pad: Instance?, destination: string, text: string)
	if not pad or not pad:IsA("BasePart") then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "WarpPrompt"
	prompt.ActionText = text
	prompt.ObjectText = "Warp Gate"
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = pad
	prompt.Triggered:Connect(function(player)
		WarpService.Warp(player, destination)
	end)
end

local function catchFallers()
	for _, player in Players:GetPlayers() do
		local root = rootOf(player)
		if root and root.Position.Y < VOID_CATCH_Y then
			local target = DESTINATIONS.Home(player) or hubSpawn()
			local character = player.Character
			if character then
				character:PivotTo(target)
				root.AssemblyLinearVelocity = Vector3.zero
				JuiceService.Send(player, "VoidCatch", {})
			end
		end
	end
end

function WarpService.Init()
	local map = Workspace:FindFirstChild("VoidlineMap")
	local hub = map and map:FindFirstChild("Hub")
	if hub then
		makeGatePrompt(hub:FindFirstChild("OverlookGate"), "Overlook", "Warp to the Overlook")
		makeGatePrompt(hub:FindFirstChild("RiftGate"), "Rift", "Enter the Void Rift")
	end
	local overlook = map and map:FindFirstChild("StarOverlook")
	if overlook then
		makeGatePrompt(overlook:FindFirstChild("ArrivalPad"), "Hub", "Return to the hub")
	end

	ValidateRemote.Bind(
		"WarpRequest",
		{ Rate = 1, Burst = 2, Args = { "string" }, MaxString = 16, RequireCharacter = true },
		function(player, destination)
			WarpService.Warp(player, destination)
		end
	)

	Players.PlayerRemoving:Connect(function(player)
		lastWarp[player.UserId] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(CHECK_INTERVAL)
			catchFallers()
		end
	end)
end

return WarpService
