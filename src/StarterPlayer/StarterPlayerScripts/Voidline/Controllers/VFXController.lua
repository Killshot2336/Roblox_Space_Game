local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Voidline = ReplicatedStorage:WaitForChild("Voidline")
local Remotes = require(Voidline.Remotes)
local GameConfig = require(Voidline.Config.GameConfig)

local player = Players.LocalPlayer

local VFXController = {}

local function floatingText(pos: Vector3, text: string, color: Color3)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.Transparency = 1
	p.Size = Vector3.new(1, 1, 1)
	p.Position = pos
	p.Parent = workspace
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(120, 40)
	bb.AlwaysOnTop = true
	bb.Parent = p
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = color
	label.Text = text
	label.Parent = bb
	TweenService:Create(p, TweenInfo.new(0.8), { Position = pos + Vector3.new(0, 6, 0) }):Play()
	task.delay(0.85, function()
		p:Destroy()
	end)
end

function VFXController.Init(hud)
	Remotes.Get("JuiceEvent").OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" then
			return
		end
		if payload.Kind == "Shatter" or payload.Kind == "CoreChunk" then
			if payload.Position then
				floatingText(payload.Position, "+" .. tostring(payload.Ore) .. " ORE", GameConfig.Colors.GoldBright)
			end
			if payload.IsTop then
				floatingText(payload.Position or Vector3.zero, "#1 TOP MINER", GameConfig.Colors.Gold)
			end
		elseif payload.Kind == "Sold" then
			floatingText(
				player.Character and player.Character:GetPivot().Position or Vector3.zero,
				"+" .. tostring(payload.Amount) .. " C",
				GameConfig.Colors.Gold
			)
		elseif payload.Kind == "EventBanner" then
			hud.ShowBanner(payload.Text or "WORLD EVENT", 3)
		elseif payload.Kind == "TutorialComplete" then
			hud.ShowBanner("TUTORIAL COMPLETE — +100 CREDITS", 3)
		elseif payload.Kind == "RebirthShockwave" then
			hud.ShowBanner((payload.PlayerName or "?") .. " REBIRTH VOID " .. tostring(payload.Rebirths), 3)
		elseif payload.Kind == "AfkIdle" then
			hud.ShowBanner("DRONES IN IDLE ORBIT — MOVE TO RESUME", 3)
		elseif payload.Kind == "CodeSuccess" then
			hud.ShowBanner(payload.Message or "CODE REDEEMED", 3)
		elseif payload.Kind == "DailySuccess" then
			hud.ShowBanner("DAILY STREAK DAY " .. tostring(payload.Day), 3)
		elseif payload.Kind == "ForgeCooling" then
			hud.ShowBanner("FORGE COOLING (REDUCED SPEED)", 3)
		end
	end)

	Remotes.Get("WorldEventState").OnClientEvent:Connect(function(state)
		if state.Active then
			hud.ShowBanner(string.upper(state.Kind or "EVENT") .. " — " .. (state.Summoner or "VOIDLINE"), 3)
		end
	end)
end

return VFXController
