local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Voidline = ReplicatedStorage:WaitForChild("Voidline")
local Remotes = require(Voidline.Remotes)
local GameConfig = require(Voidline.Config.GameConfig)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local HotbarController = {
	_onOpenStore = nil :: (() -> ())?,
	_onOpenSettings = nil :: (() -> ())?,
	_onOpenSquad = nil :: (() -> ())?,
}

local function mkButton(parent, name, text, order)
	local b = Instance.new("TextButton")
	b.Name = name
	b.Size = UDim2.fromOffset(72, 56)
	b.BackgroundColor3 = GameConfig.Colors.Obsidian
	b.BackgroundTransparency = 0.1
	b.Text = text
	b.TextColor3 = GameConfig.Colors.GoldBright
	b.Font = Enum.Font.GothamBold
	b.TextSize = 12
	b.LayoutOrder = order
	b.Parent = parent
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 8)
	c.Parent = b
	local s = Instance.new("UIStroke")
	s.Color = GameConfig.Colors.Gold
	s.Thickness = 1
	s.Parent = b
	return b
end

function HotbarController.Init(hooks)
	HotbarController._onOpenStore = hooks.OpenStore
	HotbarController._onOpenSettings = hooks.OpenSettings
	HotbarController._onOpenSquad = hooks.OpenSquad

	local gui = Instance.new("ScreenGui")
	gui.Name = "VoidlineHotbar"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = playerGui

	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.Position = UDim2.new(0.5, 0, 1, -24)
	bar.Size = UDim2.fromOffset(520, 64)
	bar.BackgroundTransparency = 1
	bar.Parent = gui

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 8)
	layout.Parent = bar

	local f1 = mkButton(bar, "F1", "1\nSCATTER", 1)
	local f2 = mkButton(bar, "F2", "2\nBEAM", 2)
	local f3 = mkButton(bar, "F3", "3\nHALO", 3)
	local squad = mkButton(bar, "Squad", "SQUAD", 4)
	local shop = mkButton(bar, "Shop", "SHOP", 5)
	local settings = mkButton(bar, "Settings", "SET", 6)
	local upgrade = mkButton(bar, "Upgrade", "U\nUPGRADE", 7)
	local sprint = mkButton(bar, "Sprint", "SPRINT", 8)
	local clip = mkButton(bar, "Clip", "CLIP", 9)

	local function setFormation(n)
		Remotes.Get("SetFormation"):FireServer(n)
	end
	f1.MouseButton1Click:Connect(function()
		setFormation(1)
	end)
	f2.MouseButton1Click:Connect(function()
		setFormation(2)
	end)
	f3.MouseButton1Click:Connect(function()
		setFormation(3)
	end)
	squad.MouseButton1Click:Connect(function()
		if HotbarController._onOpenSquad then
			HotbarController._onOpenSquad()
		end
	end)
	shop.MouseButton1Click:Connect(function()
		if HotbarController._onOpenStore then
			HotbarController._onOpenStore()
		end
	end)
	settings.MouseButton1Click:Connect(function()
		if HotbarController._onOpenSettings then
			HotbarController._onOpenSettings()
		end
	end)
	upgrade.MouseButton1Click:Connect(function()
		Remotes.Get("QuickUpgrade"):FireServer()
	end)

	local sprinting = false
	local function toggleSprint()
		sprinting = not sprinting
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.WalkSpeed = if sprinting then 28 else 16
		end
		Remotes.Get("PlayerInput"):FireServer()
	end
	sprint.MouseButton1Click:Connect(toggleSprint)

	local clipOn = false
	clip.MouseButton1Click:Connect(function()
		clipOn = not clipOn
		hooks.SetClipMode(clipOn)
		gui.Enabled = not clipOn
	end)

	UserInputService.InputBegan:Connect(function(input, gp)
		if gp then
			return
		end
		Remotes.Get("PlayerInput"):FireServer()
		if input.KeyCode == Enum.KeyCode.One then
			setFormation(1)
		elseif input.KeyCode == Enum.KeyCode.Two then
			setFormation(2)
		elseif input.KeyCode == Enum.KeyCode.Three then
			setFormation(3)
		elseif input.KeyCode == Enum.KeyCode.U then
			Remotes.Get("QuickUpgrade"):FireServer()
		elseif input.KeyCode == Enum.KeyCode.LeftShift then
			toggleSprint()
		end
	end)

	UserInputService.InputChanged:Connect(function()
		Remotes.Get("PlayerInput"):FireServer()
	end)

	-- Touch-friendly: show sprint/upgrade always on mobile
	if UserInputService.TouchEnabled then
		sprint.Visible = true
		upgrade.Visible = true
	end

	HotbarController._gui = gui
end

function HotbarController.SetVisible(on: boolean)
	if HotbarController._gui then
		HotbarController._gui.Enabled = on
	end
end

return HotbarController
