local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Voidline = ReplicatedStorage:WaitForChild("Voidline")
local Remotes = require(Voidline.Remotes)
local GameConfig = require(Voidline.Config.GameConfig)
local DroneConfig = require(Voidline.Config.DroneConfig)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local SettingsController = { _gui = nil, _perf = false, _hideJet = false }

function SettingsController.Toggle()
	if SettingsController._gui then
		SettingsController._gui.Enabled = not SettingsController._gui.Enabled
	end
end

function SettingsController.Init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "VoidlineSettings"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.Parent = playerGui

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(360, 280)
	panel.BackgroundColor3 = GameConfig.Colors.Obsidian
	panel.Parent = gui
	Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 12)
	local stroke = Instance.new("UIStroke")
	stroke.Color = GameConfig.Colors.Gold
	stroke.Parent = panel

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -16, 0, 32)
	title.Position = UDim2.fromOffset(12, 8)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 20
	title.TextColor3 = GameConfig.Colors.Gold
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "SETTINGS"
	title.Parent = panel

	local function toggleBtn(y, label, callback)
		local b = Instance.new("TextButton")
		b.Size = UDim2.new(1, -24, 0, 40)
		b.Position = UDim2.fromOffset(12, y)
		b.BackgroundColor3 = Color3.fromRGB(24, 24, 32)
		b.TextColor3 = GameConfig.Colors.GoldBright
		b.Font = Enum.Font.GothamMedium
		b.TextSize = 14
		b.Text = label
		b.Parent = panel
		Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
		b.MouseButton1Click:Connect(function()
			callback(b)
		end)
		return b
	end

	toggleBtn(56, "Performance Mode: OFF", function(b)
		SettingsController._perf = not SettingsController._perf
		b.Text = "Performance Mode: " .. (SettingsController._perf and "ON" or "OFF")
		Lighting.Bloom.Enabled = not SettingsController._perf
		Remotes.Get("SettingsUpdate"):FireServer({ PerfMode = SettingsController._perf })
	end)

	toggleBtn(108, "Hide Jetpack: OFF", function(b)
		SettingsController._hideJet = not SettingsController._hideJet
		b.Text = "Hide Jetpack: " .. (SettingsController._hideJet and "ON" or "OFF")
		Remotes.Get("SettingsUpdate"):FireServer({ HideJetpack = SettingsController._hideJet })
		player:SetAttribute("HideJetpack", SettingsController._hideJet)
	end)

	local close = Instance.new("TextButton")
	close.Size = UDim2.new(1, -24, 0, 40)
	close.Position = UDim2.fromOffset(12, 220)
	close.BackgroundColor3 = GameConfig.Colors.Gold
	close.TextColor3 = GameConfig.Colors.Obsidian
	close.Font = Enum.Font.GothamBold
	close.Text = "CLOSE"
	close.Parent = panel
	Instance.new("UICorner", close).CornerRadius = UDim.new(0, 8)
	close.MouseButton1Click:Connect(function()
		gui.Enabled = false
	end)

	-- Ensure bloom exists for perf toggle
	if not Lighting:FindFirstChildOfClass("BloomEffect") then
		local bloom = Instance.new("BloomEffect")
		bloom.Intensity = 0.6
		bloom.Size = 24
		bloom.Threshold = 1.2
		bloom.Parent = Lighting
	end

	SettingsController._gui = gui
end

return SettingsController
