local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Voidline = ReplicatedStorage:WaitForChild("Voidline")
local Remotes = require(Voidline.Remotes)
local RateLimiter = require(Voidline.Modules.RateLimiter)
local PlayerDataService = require(script.Parent.PlayerDataService)

local PlotService = {
	Owners = {} :: { [number]: Player },
	ByPlayer = {} :: { [number]: number },
	_limiter = RateLimiter.new(0.5),
}

local function getPlot(index: number): Folder?
	local map = Workspace:FindFirstChild("VoidlineMap")
	if not map then
		return nil
	end
	local plots = map:FindFirstChild("Plots")
	return plots and plots:FindFirstChild("Plot_" .. index)
end

function PlotService.GetPlayerPlot(player: Player): Folder?
	local idx = PlotService.ByPlayer[player.UserId]
	if not idx then
		return nil
	end
	return getPlot(idx)
end

function PlotService.TeleportToPlot(player: Player, plotIndex: number)
	local plot = getPlot(plotIndex)
	if not plot then
		return
	end
	local spawn = plot:FindFirstChild("PlayerSpawn")
	local char = player.Character or player.CharacterAdded:Wait()
	local hrp = char:WaitForChild("HumanoidRootPart")
	if spawn and spawn:IsA("BasePart") then
		hrp.CFrame = spawn.CFrame + Vector3.new(0, 3, 0)
	end
end

function PlotService.Claim(player: Player, plotIndex: number): boolean
	if PlotService.ByPlayer[player.UserId] then
		return false
	end
	if PlotService.Owners[plotIndex] then
		return false
	end
	local plot = getPlot(plotIndex)
	if not plot then
		return false
	end
	PlotService.Owners[plotIndex] = player
	PlotService.ByPlayer[player.UserId] = plotIndex
	plot:SetAttribute("Claimed", true)
	plot:SetAttribute("OwnerUserId", player.UserId)
	PlayerDataService.Mutate(player, function(data)
		data.PlotIndex = plotIndex
	end)
	PlotService.TeleportToPlot(player, plotIndex)
	Remotes.Get("JuiceEvent"):FireClient(player, { Kind = "ClaimPlot", PlotIndex = plotIndex })
	return true
end

function PlotService.IgniteBridge(player: Player)
	local plot = PlotService.GetPlayerPlot(player)
	if not plot then
		return
	end
	local bridge = plot:FindFirstChild("BridgeAttach")
	local beam = bridge and bridge:FindFirstChild("EnergyBridge")
	if beam and beam:IsA("BasePart") then
		beam.Transparency = 0.15
		beam:SetAttribute("Ignited", true)
	end
	Remotes.Get("JuiceEvent"):FireClient(player, { Kind = "BridgeIgnition" })
end

function PlotService.Init()
	Remotes.Get("ClaimPlot").OnServerEvent:Connect(function(player, plotIndex)
		if not PlotService._limiter:Allow(player.UserId) then
			return
		end
		if typeof(plotIndex) ~= "number" then
			return
		end
		plotIndex = math.floor(plotIndex)
		if plotIndex < 1 or plotIndex > 12 then
			return
		end
		PlotService.Claim(player, plotIndex)
	end)

	-- Auto-claim first free plot on join for instant action
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			task.wait(0.5)
			if PlotService.ByPlayer[player.UserId] then
				PlotService.TeleportToPlot(player, PlotService.ByPlayer[player.UserId])
				return
			end
			for i = 1, 12 do
				if not PlotService.Owners[i] then
					PlotService.Claim(player, i)
					break
				end
			end
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		local idx = PlotService.ByPlayer[player.UserId]
		if idx then
			PlotService.Owners[idx] = nil
			local plot = getPlot(idx)
			if plot then
				plot:SetAttribute("Claimed", false)
				plot:SetAttribute("OwnerUserId", nil)
			end
		end
		PlotService.ByPlayer[player.UserId] = nil
		PlotService._limiter:Clear(player.UserId)
	end)
end

return PlotService
