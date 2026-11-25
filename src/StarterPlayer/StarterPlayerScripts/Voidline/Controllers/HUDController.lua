local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Voidline = ReplicatedStorage:WaitForChild("Voidline")
local FormatNumber = require(Voidline.Modules.FormatNumber)
local OreMath = require(Voidline.Modules.OreMath)
local GameConfig = require(Voidline.Config.GameConfig)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local HUDController = {
	_gui = nil :: ScreenGui?,
	_data = nil,
	_clip = false,
}

local function ensureGui()
	if HUDController._gui then
		return HUDController._gui
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "VoidlineHUD"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = playerGui

	local pill = Instance.new("Frame")
	pill.Name = "TopPill"
	pill.AnchorPoint = Vector2.new(0.5, 0)
	pill.Position = UDim2.new(0.5, 0, 0, 16)
	pill.Size = UDim2.fromOffset(520, 44)
	pill.BackgroundColor3 = GameConfig.Colors.Obsidian
	pill.BackgroundTransparency = 0.15
	pill.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Color = GameConfig.Colors.Gold
	stroke.Thickness = 1
	stroke.Parent = pill
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = pill

	local label = Instance.new("TextLabel")
	label.Name = "Stats"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 16
	label.TextColor3 = GameConfig.Colors.GoldBright
	label.Text = "CREDITS 0  |  CARGO 0/10  |  DRONES 1  |  SHARDS 0"
	label.Parent = pill

	local cargoBar = Instance.new("Frame")
	cargoBar.Name = "CargoBarBg"
	cargoBar.AnchorPoint = Vector2.new(0.5, 0)
	cargoBar.Position = UDim2.new(0.5, 0, 0, 64)
	cargoBar.Size = UDim2.fromOffset(280, 6)
	cargoBar.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
	cargoBar.Parent = gui
	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(1, 0)
	barCorner.Parent = cargoBar
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = GameConfig.Colors.Gold
	fill.BorderSizePixel = 0
	fill.Parent = cargoBar
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = fill

	local ticker = Instance.new("TextLabel")
	ticker.Name = "TutorialTicker"
	ticker.AnchorPoint = Vector2.new(0.5, 0)
	ticker.Position = UDim2.new(0.5, 0, 0, 78)
	ticker.Size = UDim2.fromOffset(420, 22)
	ticker.BackgroundTransparency = 1
	ticker.Font = Enum.Font.GothamMedium
	ticker.TextSize = 14
	ticker.TextColor3 = GameConfig.Colors.Gold
	ticker.Text = "[1/4] HARVESTING ORE"
	ticker.Parent = gui

	local banner = Instance.new("TextLabel")
	banner.Name = "EventBanner"
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.new(0.5, 0, 0, -60)
	banner.Size = UDim2.fromOffset(560, 36)
	banner.BackgroundColor3 = GameConfig.Colors.Obsidian
	banner.BackgroundTransparency = 0.1
	banner.Font = Enum.Font.GothamBold
	banner.TextSize = 18
	banner.TextColor3 = GameConfig.Colors.GoldBright
	banner.Text = ""
	banner.Visible = false
	banner.Parent = gui
	local bStroke = Instance.new("UIStroke")
	bStroke.Color = GameConfig.Colors.Gold
	bStroke.Parent = banner

	HUDController._gui = gui
	return gui
end

local TICKER = {
	[1] = "[1/4] HARVESTING ORE",
	[2] = "[2/4] REFINE AT PAD",
	[3] = "[3/4] DEPLOY 2ND DRONE",
	[4] = "[4/4] ENERGY BRIDGE ONLINE",
}

function HUDController.SetData(data)
	HUDController._data = data
	local gui = ensureGui()
	if HUDController._clip then
		gui.Enabled = false
		return
	end
	gui.Enabled = true
	local cap = OreMath.CargoCap(data.CargoLevel)
	gui.TopPill.Stats.Text = string.format(
		"CREDITS %s  |  CARGO %d/%d  |  DRONES %d  |  SHARDS %s",
		FormatNumber.Compact(data.Credits),
		data.Ore,
		cap,
		data.DroneSlots,
		FormatNumber.Compact(data.VoidShards)
	)
	gui.CargoBarBg.Fill.Size = UDim2.fromScale(math.clamp(data.Ore / math.max(1, cap), 0, 1), 1)
	if data.TutorialComplete then
		gui.TutorialTicker.Visible = false
	else
		gui.TutorialTicker.Visible = true
		gui.TutorialTicker.Text = TICKER[data.TutorialStep] or TICKER[1]
	end
end

function HUDController.SetClipMode(on: boolean)
	HUDController._clip = on
	local gui = ensureGui()
	gui.Enabled = not on
end

function HUDController.ShowBanner(text: string, seconds: number?)
	local gui = ensureGui()
	local banner = gui.EventBanner
	banner.Text = text
	banner.Visible = true
	banner.Position = UDim2.new(0.5, 0, 0, 12)
	task.delay(seconds or 3, function()
		banner.Visible = false
		banner.Position = UDim2.new(0.5, 0, 0, -60)
	end)
end

function HUDController.Init()
	ensureGui()
end

return HUDController
