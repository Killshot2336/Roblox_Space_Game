--!strict
-- AFK idle orbit: after AfkIdleSeconds without input or movement a pilot's
-- drones settle into a calm orbit and stop mining. Nobody is ever kicked;
-- any input or movement wakes the fleet again.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Voidline = ReplicatedStorage:WaitForChild("Voidline")
local GameConfig = require(Voidline.Config.GameConfig)

local ValidateRemote = require(script.Parent.Parent.Security.ValidateRemote)
local JuiceService = require(script.Parent.JuiceService)

local AfkService = {}

local CHECK_INTERVAL = 5
local MOVE_EPSILON = 2

AfkService._lastActive = {} :: { [number]: number }
AfkService._lastPos = {} :: { [number]: Vector3 }

local function setAfk(player: Player, afk: boolean)
	if (player:GetAttribute("Afk") == true) == afk then
		return
	end
	player:SetAttribute("Afk", afk)
	JuiceService.Send(player, if afk then "AfkIdle" else "AfkResume", {})
end

function AfkService.MarkActive(player: Player)
	AfkService._lastActive[player.UserId] = os.clock()
	setAfk(player, false)
end

function AfkService.Check(now: number)
	for _, player in Players:GetPlayers() do
		local userId = player.UserId
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			local last = AfkService._lastPos[userId]
			if last and (root.Position - last).Magnitude > MOVE_EPSILON then
				AfkService.MarkActive(player)
			end
			AfkService._lastPos[userId] = root.Position
		end
		local lastActive = AfkService._lastActive[userId] or now
		AfkService._lastActive[userId] = lastActive
		if now - lastActive >= GameConfig.AfkIdleSeconds then
			setAfk(player, true)
		end
	end
end

function AfkService.Init()
	ValidateRemote.Bind("PlayerInput", { Rate = 1, Burst = 3, Args = {} }, function(player)
		AfkService.MarkActive(player)
	end)
	Players.PlayerAdded:Connect(function(player)
		AfkService._lastActive[player.UserId] = os.clock()
		player:SetAttribute("Afk", false)
	end)
	Players.PlayerRemoving:Connect(function(player)
		AfkService._lastActive[player.UserId] = nil
		AfkService._lastPos[player.UserId] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(CHECK_INTERVAL)
			AfkService.Check(os.clock())
		end
	end)
end

return AfkService
