local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Voidline = ReplicatedStorage:WaitForChild("Voidline")
local MonetizationConfig = require(Voidline.Config.MonetizationConfig)
local Remotes = require(Voidline.Remotes)
local GameConfig = require(Voidline.Config.GameConfig)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local StoreController = { _gui = nil }

function StoreController.Toggle()
	local gui = StoreController._gui
	if not gui then
		return
	end
	gui.Enabled = not gui.Enabled
end

function StoreController.Init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "VoidlineStore"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.Parent = playerGui

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(560, 420)
	panel.BackgroundColor3 = GameConfig.Colors.Obsidian
	panel.Parent = gui
	Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 12)
	local stroke = Instance.new("UIStroke")
	stroke.Color = GameConfig.Colors.Gold
	stroke.Parent = panel

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -20, 0, 36)
	title.Position = UDim2.fromOffset(10, 8)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 22
	title.TextColor3 = GameConfig.Colors.Gold
	title.Text = "VOIDLINE STORE"
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = panel

	local close = Instance.new("TextButton")
	close.Size = UDim2.fromOffset(36, 36)
	close.Position = UDim2.new(1, -44, 0, 8)
	close.Text = "X"
	close.Font = Enum.Font.GothamBold
	close.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
	close.TextColor3 = GameConfig.Colors.GoldBright
	close.Parent = panel
	close.MouseButton1Click:Connect(function()
		gui.Enabled = false
	end)

	local scroll = Instance.new("ScrollingFrame")
	scroll.Position = UDim2.fromOffset(12, 52)
	scroll.Size = UDim2.new(1, -24, 1, -64)
	scroll.BackgroundTransparency = 1
	scroll.ScrollBarThickness = 4
	scroll.CanvasSize = UDim2.fromOffset(0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.Parent = panel
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 8)
	list.Parent = scroll

	for _, pass in MonetizationConfig.Passes do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -8, 0, 64)
		row.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
		row.Parent = scroll
		Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)
		local name = Instance.new("TextLabel")
		name.BackgroundTransparency = 1
		name.Position = UDim2.fromOffset(10, 8)
		name.Size = UDim2.new(0.5, 0, 0, 22)
		name.Font = Enum.Font.GothamBold
		name.TextSize = 14
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.TextColor3 = GameConfig.Colors.GoldBright
		name.Text = pass.Name
		name.Parent = row

		local robux = Instance.new("TextButton")
		robux.Size = UDim2.fromOffset(120, 28)
		robux.Position = UDim2.new(1, -260, 0, 18)
		robux.Text = pass.Robux .. " R$"
		robux.Font = Enum.Font.GothamBold
		robux.TextSize = 12
		robux.BackgroundColor3 = GameConfig.Colors.Gold
		robux.TextColor3 = GameConfig.Colors.Obsidian
		robux.Parent = row
		Instance.new("UICorner", robux).CornerRadius = UDim.new(0, 6)
		robux.MouseButton1Click:Connect(function()
			Remotes.Get("PromptRobuxPurchase"):FireServer("Pass", pass.Id)
		end)

		local tokens = Instance.new("TextButton")
		tokens.Size = UDim2.fromOffset(120, 28)
		tokens.Position = UDim2.new(1, -130, 0, 18)
		tokens.Text = pass.Tokens .. " Tokens"
		tokens.Font = Enum.Font.GothamBold
		tokens.TextSize = 12
		tokens.BackgroundColor3 = GameConfig.Colors.VoidAccent
		tokens.TextColor3 = Color3.new(1, 1, 1)
		tokens.Parent = row
		Instance.new("UICorner", tokens).CornerRadius = UDim.new(0, 6)
		tokens.MouseButton1Click:Connect(function()
			Remotes.Get("PurchaseWithTokens"):FireServer(pass.Id)
		end)
	end

	for _, product in MonetizationConfig.DevProducts do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -8, 0, 56)
		row.BackgroundColor3 = Color3.fromRGB(28, 18, 40)
		row.Parent = scroll
		Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)
		local name = Instance.new("TextLabel")
		name.BackgroundTransparency = 1
		name.Position = UDim2.fromOffset(10, 14)
		name.Size = UDim2.new(0.55, 0, 0, 22)
		name.Font = Enum.Font.GothamBold
		name.TextSize = 14
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.TextColor3 = GameConfig.Colors.Gold
		name.Text = product.Name .. " (Robux only)"
		name.Parent = row
		local buy = Instance.new("TextButton")
		buy.Size = UDim2.fromOffset(120, 28)
		buy.Position = UDim2.new(1, -130, 0, 14)
		buy.Text = product.Robux .. " R$"
		buy.Font = Enum.Font.GothamBold
		buy.BackgroundColor3 = GameConfig.Colors.Gold
		buy.TextColor3 = GameConfig.Colors.Obsidian
		buy.Parent = row
		Instance.new("UICorner", buy).CornerRadius = UDim.new(0, 6)
		buy.MouseButton1Click:Connect(function()
			Remotes.Get("PromptRobuxPurchase"):FireServer("Product", product.Id)
		end)
	end

	StoreController._gui = gui
end

return StoreController
