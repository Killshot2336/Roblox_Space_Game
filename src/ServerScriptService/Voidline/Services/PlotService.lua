--!strict
-- Plot ownership. Every pilot gets the lowest free plot as soon as their
-- profile loads, spawns there, and keeps it until they leave. The Energy
-- Bridge to the hub is lit once onboarding is done (returning pilots join
-- with it already lit).
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Voidline = ReplicatedStorage:WaitForChild("Voidline")
local GameConfig = require(Voidline.Config.GameConfig)
local PlotLayout = require(Voidline.Modules.PlotLayout)

local PlayerDataService = require(script.Parent.PlayerDataService)

local PlotService = {
	Owners = {} :: { [number]: Player },
	ByUserId = {} :: { [number]: number },
}

local claimedCallbacks: { (Player, number) -> () } = {}
local releasedCallbacks: { (Player, number) -> () } = {}

-- Horizontal radius that counts as "on your plot" (drones mine the belt).
local ON_PLOT_RADIUS = 46

local function plotFolder(index: number): Instance?
	local map = Workspace:FindFirstChild("VoidlineMap")
	local plots = map and map:FindFirstChild("Plots")
	return plots and plots:FindFirstChild("Plot_" .. index)
end
PlotService.Folder = plotFolder

function PlotService.IndexOf(player: Player): number?
	return PlotService.ByUserId[player.UserId]
end

function PlotService.PlotOf(player: Player): Instance?
	local index = PlotService.ByUserId[player.UserId]
	return if index then plotFolder(index) else nil
end

function PlotService.OnClaimed(callback: (Player, number) -> ())
	table.insert(claimedCallbacks, callback)
end

function PlotService.OnReleased(callback: (Player, number) -> ())
	table.insert(releasedCallbacks, callback)
end

function PlotService.World(player: Player, localOffset: Vector3): Vector3?
	local index = PlotService.ByUserId[player.UserId]
	return if index then PlotLayout.World(index, localOffset) else nil
end

function PlotService.GrinderPosition(player: Player): Vector3?
	return PlotService.World(player, PlotLayout.Grinder)
end

function PlotService.SpawnCFrame(index: number): CFrame
	local plotCFrame = PlotLayout.PlotCFrame(index)
	local position = plotCFrame:PointToWorldSpace(PlotLayout.Spawn + Vector3.new(0, 3, 0))
	-- Face the hub so the bridge and Monolith are in view on spawn.
	return CFrame.lookAt(position, Vector3.new(0, position.Y, 0))
end

function PlotService.RootPart(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

function PlotService.IsOnPlot(player: Player): boolean
	local index = PlotService.ByUserId[player.UserId]
	local root = PlotService.RootPart(player)
	if not index or not root then
		return false
	end
	local center = PlotLayout.PlotCFrame(index).Position
	local offset = root.Position - center
	return Vector3.new(offset.X, 0, offset.Z).Magnitude <= ON_PLOT_RADIUS and math.abs(offset.Y) < 40
end

local function moveToPlot(player: Player)
	local index = PlotService.ByUserId[player.UserId]
	local character = player.Character
	if not index or not character then
		return
	end
	character:PivotTo(PlotService.SpawnCFrame(index))
end

local function setBridge(index: number, lit: boolean)
	local plot = plotFolder(index)
	if not plot then
		return
	end
	plot:SetAttribute("BridgeIgnited", lit)
	plot:SetAttribute("BridgeIgnitedAt", if lit then Workspace:GetServerTimeNow() else 0)
	local bridge = plot:FindFirstChild("EnergyBridge")
	if not bridge then
		return
	end
	for _, child in bridge:GetChildren() do
		if child:IsA("BasePart") and string.sub(child.Name, 1, 7) == "Segment" then
			child.Transparency = if lit then 0.15 else 0.85
		end
	end
end

function PlotService.IgniteBridge(player: Player)
	local index = PlotService.ByUserId[player.UserId]
	if index then
		local plot = plotFolder(index)
		if plot and plot:GetAttribute("BridgeIgnited") ~= true then
			setBridge(index, true)
		end
	end
end

local function claim(player: Player, profile: any)
	if PlotService.ByUserId[player.UserId] or player.Parent ~= Players then
		return
	end
	local index: number? = nil
	for i = 1, GameConfig.PlotCount do
		if not PlotService.Owners[i] then
			index = i
			break
		end
	end
	if not index then
		warn("[Voidline] no free plot for " .. player.Name)
		return
	end
	PlotService.Owners[index] = player
	PlotService.ByUserId[player.UserId] = index
	player:SetAttribute("PlotIndex", index)
	local plot = plotFolder(index)
	if plot then
		plot:SetAttribute("OwnerUserId", player.UserId)
		plot:SetAttribute("OwnerName", player.DisplayName)
	end
	setBridge(index, profile.TutorialComplete == true)
	moveToPlot(player)
	for _, callback in claimedCallbacks do
		task.spawn(callback, player, index)
	end
end

local function release(player: Player)
	local index = PlotService.ByUserId[player.UserId]
	if not index then
		return
	end
	for _, callback in releasedCallbacks do
		local ok, err = pcall(callback :: (Player, number) -> ...any, player, index)
		if not ok then
			warn("[Voidline] plot release callback failed: " .. tostring(err))
		end
	end
	PlotService.Owners[index] = nil
	PlotService.ByUserId[player.UserId] = nil
	local plot = plotFolder(index)
	if plot then
		plot:SetAttribute("OwnerUserId", 0)
		plot:SetAttribute("OwnerName", "")
	end
	setBridge(index, false)
end

function PlotService.Init()
	PlayerDataService.OnLoaded(claim)
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			-- Wait a frame so the character is fully parented before moving it.
			task.defer(moveToPlot, player)
		end)
	end)
	for _, player in Players:GetPlayers() do
		player.CharacterAdded:Connect(function()
			task.defer(moveToPlot, player)
		end)
	end
	Players.PlayerRemoving:Connect(release)
end

return PlotService
