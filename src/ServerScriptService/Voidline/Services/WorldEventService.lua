local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Voidline = ReplicatedStorage:WaitForChild("Voidline")
local GameConfig = require(Voidline.Config.GameConfig)
local SoftContestConfig = require(Voidline.Config.SoftContestConfig)
local Remotes = require(Voidline.Remotes)

local WorldEventService = {
	_active = false,
	_queue = {} :: { { Player: Player, Kind: string } },
	_luckSurgeUntil = 0,
}

local function getDeep(): Folder?
	local map = Workspace:FindFirstChild("VoidlineMap")
	return map and map:FindFirstChild("DeepSpace")
end

local function spawnEventMeteor(kind: string)
	local deep = getDeep()
	if not deep then
		return
	end
	local folder = deep:FindFirstChild("EventMeteors")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "EventMeteors"
		folder.Parent = deep
	end
	folder:ClearAllChildren()
	local meteor = Instance.new("Part")
	meteor.Name = kind == "LuckSurge" and "LuckSurgeCore" or "StarfallCore"
	meteor.Shape = Enum.PartType.Ball
	meteor.Size = Vector3.new(28, 28, 28)
	meteor.Anchored = true
	meteor.Material = Enum.Material.Neon
	meteor.Color = kind == "LuckSurge" and Color3.fromRGB(120, 80, 255) or Color3.fromRGB(255, 200, 80)
	meteor.CFrame = CFrame.new(0, 36, 0)
	meteor:SetAttribute("Shared", true)
	meteor:SetAttribute("Sector", "VoidRim")
	meteor:SetAttribute("MaxHealth", SoftContestConfig.EventCoreHealth)
	meteor:SetAttribute("Health", SoftContestConfig.EventCoreHealth)
	meteor:SetAttribute("EventKind", kind)
	meteor.Parent = folder

	local monolith = Workspace:FindFirstChild("VoidlineMap")
		and Workspace.VoidlineMap.Hub:FindFirstChild("VoidlineMonolith")
	if monolith then
		local core = monolith:FindFirstChild("MonolithCore")
		if core and core:IsA("BasePart") then
			core.Size = Vector3.new(22, 78, 8) -- "split" silhouette
		end
	end
	return meteor
end

local function endEvent()
	WorldEventService._active = false
	local deep = getDeep()
	local folder = deep and deep:FindFirstChild("EventMeteors")
	if folder then
		folder:ClearAllChildren()
	end
	local map = Workspace:FindFirstChild("VoidlineMap")
	local monolith = map and map.Hub:FindFirstChild("VoidlineMonolith")
	local core = monolith and monolith:FindFirstChild("MonolithCore")
	if core and core:IsA("BasePart") then
		core.Size = Vector3.new(18, 72, 18)
	end
	Remotes.Get("WorldEventState"):FireAllClients({ Active = false })
	-- Drain queue
	local nextJob = table.remove(WorldEventService._queue, 1)
	if nextJob then
		task.defer(function()
			WorldEventService.Start(nextJob.Kind, nextJob.Player)
		end)
	end
end

function WorldEventService.Start(kind: string, summoner: Player?)
	if WorldEventService._active then
		if summoner then
			table.insert(WorldEventService._queue, { Player = summoner, Kind = kind })
		end
		return
	end
	WorldEventService._active = true
	spawnEventMeteor(kind)
	if kind == "LuckSurge" then
		WorldEventService._luckSurgeUntil = os.time() + GameConfig.WorldEventDurationSeconds
	end
	local name = summoner and summoner.DisplayName or "VOIDLINE"
	Remotes.Get("WorldEventState"):FireAllClients({
		Active = true,
		Kind = kind,
		Summoner = name,
		Duration = GameConfig.WorldEventDurationSeconds,
	})
	Remotes.Get("JuiceEvent"):FireAllClients({
		Kind = "EventBanner",
		Text = string.upper(kind) .. " — " .. name,
	})
	task.delay(GameConfig.WorldEventDurationSeconds, endEvent)
end

function WorldEventService.IsLuckSurge(): boolean
	return os.time() < WorldEventService._luckSurgeUntil
end

function WorldEventService.QueueSummon(player: Player, kind: string)
	WorldEventService.Start(kind, player)
end

function WorldEventService.Init()
	task.spawn(function()
		while true do
			task.wait(GameConfig.WorldEventIntervalSeconds)
			if not WorldEventService._active then
				local kind = if math.random() > 0.5 then "VoidStarfall" else "LuckSurge"
				WorldEventService.Start(kind, nil)
			end
		end
	end)
end

return WorldEventService
