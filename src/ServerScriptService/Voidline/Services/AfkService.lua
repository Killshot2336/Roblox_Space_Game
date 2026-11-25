local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Voidline = ReplicatedStorage:WaitForChild("Voidline")
local GameConfig = require(Voidline.Config.GameConfig)
local Remotes = require(Voidline.Remotes)
local DroneService = require(script.Parent.DroneService)

local AfkService = {
	_lastInput = {} :: { [number]: number },
}

function AfkService.Init()
	Remotes.Get("PlayerInput").OnServerEvent:Connect(function(player)
		AfkService._lastInput[player.UserId] = os.clock()
		DroneService.SetAfk(player, false)
	end)

	Players.PlayerAdded:Connect(function(player)
		AfkService._lastInput[player.UserId] = os.clock()
	end)
	Players.PlayerRemoving:Connect(function(player)
		AfkService._lastInput[player.UserId] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(5)
			local now = os.clock()
			for _, player in Players:GetPlayers() do
				local last = AfkService._lastInput[player.UserId] or now
				if now - last >= GameConfig.AfkIdleSeconds then
					DroneService.SetAfk(player, true)
					Remotes.Get("JuiceEvent"):FireClient(player, { Kind = "AfkIdle" })
				end
			end
		end
	end)
end

return AfkService
