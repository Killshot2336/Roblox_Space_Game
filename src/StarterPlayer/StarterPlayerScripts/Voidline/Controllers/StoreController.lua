--!strict
-- Dual-currency store. Passes: Robux (Roblox prompt) or Voidline Tokens at a
-- 15-20% discount (two-tap confirm). Server summons: Robux only, with drop
-- odds always shown before the buy button; paid random summons are hidden
-- behind a notice for players whose policy restricts paid random items.
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Voidline = ReplicatedStorage:WaitForChild("Voidline")
local MonetizationConfig = require(Voidline.Config.MonetizationConfig)

local Client = script.Parent.Parent.Client
local Ui = require(Client.Ui)
local ClientState = require(Client.ClientState)

local StoreController = {}

local CONFIRM_SECONDS = 3

local gui: ScreenGui
local panel: Frame
local list: ScrollingFrame
local tokensLabel: TextLabel
local tabButtons: { [string]: TextButton } = {}
local currentTab = "Passes"
local armed: { Id: string, Until: number }? = nil
local onOpened: (() -> ())? = nil

local function owns(passId: string): boolean
	return ClientState.Store.GamePasses[passId] == true or ClientState.Profile.OwnedPerks[passId] == true
end

local function trialLeft(passId: string): number
	local expires = ClientState.Profile.TrialVouchers[passId]
	return if type(expires) == "number" then expires - os.time() else 0
end

local function row(height: number, order: number): Frame
	local frame = Ui.Make("Frame", {
		Name = "Row" .. order,
		Size = UDim2.new(1, -8, 0, height),
		BackgroundColor3 = Ui.Colors.GlassLight,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		LayoutOrder = order,
		Parent = list,
	}) :: Frame
	Ui.Corner(frame, 10)
	return frame
end

local function rowText(frame: Frame, title: string, body: string, rightInset: number)
	Ui.Label({
		Name = "Title",
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.new(1, -(rightInset + 24), 0, 20),
		Text = title,
		Font = Ui.Font.Title,
		TextSize = 16,
		TextColor3 = Ui.Colors.GoldBright,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = frame,
	})
	Ui.Label({
		Name = "Body",
		Position = UDim2.fromOffset(12, 30),
		Size = UDim2.new(1, -(rightInset + 24), 0, 34),
		Text = body,
		TextSize = 13,
		TextColor3 = Ui.Colors.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = frame,
	})
end

local function buyTokens(passId: string, button: TextButton, price: number)
	local now = os.clock()
	local current = armed
	if current and current.Id == passId and now < current.Until then
		armed = nil
		ClientState.Fire("PurchaseWithTokens", passId)
		button.Text = "…"
		return
	end
	armed = { Id = passId, Until = now + CONFIRM_SECONDS }
	button.Text = ("CONFIRM ⬡%d"):format(price)
	task.delay(CONFIRM_SECONDS, function()
		if armed == nil or armed.Id ~= passId or os.clock() >= armed.Until then
			if button.Parent then
				button.Text = ("⬡ %d"):format(price)
			end
		end
	end)
end

local function renderPasses()
	local tokens = ClientState.Profile.VoidlineTokens
	for i, pass in MonetizationConfig.Passes do
		local frame = row(76, i)
		rowText(frame, pass.Name, pass.Blurb, 232)
		local buttons = Ui.Make("Frame", {
			Name = "Buttons",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(222, Ui.TOUCH),
			BackgroundTransparency = 1,
			Parent = frame,
		})
		Ui.List(buttons, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Right)
		if owns(pass.Id) then
			Ui.Label({
				Name = "Owned",
				Size = UDim2.fromOffset(110, Ui.TOUCH),
				Text = "OWNED",
				Font = Ui.Font.Title,
				TextSize = 16,
				TextColor3 = Ui.Colors.Good,
				Parent = buttons,
			})
			continue
		end
		local trial = trialLeft(pass.Id)
		if trial > 0 then
			Ui.Label({
				Name = "Trial",
				Size = UDim2.fromOffset(70, Ui.TOUCH),
				Text = ("TRIAL %dh"):format(math.ceil(trial / 3600)),
				Font = Ui.Font.Bold,
				TextSize = 12,
				TextColor3 = Ui.Colors.Cyan,
				LayoutOrder = 0,
				Parent = buttons,
			})
		end
		if pass.GamePassId ~= 0 then
			Ui.Button({
				Name = "Robux",
				Size = UDim2.fromOffset(100, Ui.TOUCH),
				Text = ("R$ %d"):format(pass.Robux),
				LayoutOrder = 1,
				Parent = buttons,
			}, function()
				ClientState.Fire("PromptRobuxPurchase", "Pass", pass.Id)
			end)
		end
		local tokenButton = Ui.Button({
			Name = "Tokens",
			Size = UDim2.fromOffset(110, Ui.TOUCH),
			Text = ("⬡ %d"):format(pass.Tokens),
			TextColor3 = if tokens >= pass.Tokens then Ui.Colors.Cyan else Ui.Colors.Muted,
			LayoutOrder = 2,
			Parent = buttons,
		})
		tokenButton.Activated:Connect(function()
			buyTokens(pass.Id, tokenButton, pass.Tokens)
		end)
	end
end

local function queueText(productId: string): string
	local attr = if productId == "SummonVoidStarfall" then "StarfallQueue" else "SurgeQueue"
	local queued = Workspace:GetAttribute(attr)
	if type(queued) == "number" and queued > 0 then
		return ("%d queued · each runs after the last"):format(queued)
	end
	return "Starts right away if nothing is queued"
end

local function renderSummons()
	local restricted = ClientState.Store.PaidRandomRestricted
	for i, product in MonetizationConfig.DevProducts do
		local odds: { { Label: string, Chance: number } } = {}
		if product.RandomOutcome then
			odds = MonetizationConfig.StarfallOdds()
		end
		local height = 84 + #odds * 18
		local frame = row(height, i)
		rowText(frame, product.Name, product.Blurb, 132)
		if #odds > 0 then
			local oddsBox = Ui.Make("Frame", {
				Name = "Odds",
				Position = UDim2.fromOffset(12, 62),
				Size = UDim2.new(1, -156, 0, #odds * 18),
				BackgroundTransparency = 1,
				Parent = frame,
			})
			Ui.List(oddsBox, Enum.FillDirection.Vertical, 0, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top)
			for j, entry in ipairs(odds) do
				Ui.Label({
					Name = "Odd" .. j,
					Size = UDim2.new(1, 0, 0, 18),
					Text = ("%s%% · %s"):format(
						if entry.Chance >= 1 then "100" else ("%.1f"):format(entry.Chance * 100),
						entry.Label
					),
					TextSize = 12,
					TextColor3 = Ui.Colors.Text,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
					LayoutOrder = j,
					Parent = oddsBox,
				})
			end
		end
		Ui.Label({
			Name = "Queue",
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -12, 1, -6),
			Size = UDim2.fromOffset(240, 16),
			Text = queueText(product.Id),
			TextSize = 11,
			TextColor3 = Ui.Colors.Muted,
			TextXAlignment = Enum.TextXAlignment.Right,
			Parent = frame,
		})
		local blocked = product.RandomOutcome and restricted
		if blocked then
			Ui.Label({
				Name = "Restricted",
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -10, 0, 10),
				Size = UDim2.fromOffset(120, Ui.TOUCH),
				Text = "Not available in your region",
				TextSize = 12,
				TextColor3 = Ui.Colors.Muted,
				Parent = frame,
			})
		elseif product.ProductId == 0 then
			Ui.Label({
				Name = "Soon",
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -10, 0, 10),
				Size = UDim2.fromOffset(120, Ui.TOUCH),
				Text = "Coming soon",
				TextSize = 13,
				TextColor3 = Ui.Colors.Muted,
				Parent = frame,
			})
		else
			Ui.Button({
				Name = "Robux",
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -10, 0, 10),
				Size = UDim2.fromOffset(110, Ui.TOUCH),
				Text = ("R$ %d"):format(product.Robux),
				Parent = frame,
			}, function()
				ClientState.Fire("PromptRobuxPurchase", "Product", product.Id)
			end)
		end
	end
end

local function render()
	if not gui.Enabled then
		return
	end
	Ui.ClearChildren(list)
	tokensLabel.Text = ("⬡ %s Tokens · earned at the Artifact Forge, never sold or traded"):format(
		Ui.Compact(ClientState.Profile.VoidlineTokens)
	)
	for name, button in tabButtons do
		button.BackgroundColor3 = if name == currentTab then Ui.Colors.Gold else Ui.Colors.GlassLight
		button.TextColor3 = if name == currentTab then Ui.Colors.Shadow else Ui.Colors.Text
	end
	if currentTab == "Passes" then
		renderPasses()
	else
		renderSummons()
	end
end

function StoreController.Open(tab: string?)
	if tab then
		currentTab = tab
	end
	gui.Enabled = true
	Ui.Pop(panel, 0.9)
	render()
	if onOpened then
		onOpened()
	end
end

function StoreController.Close()
	gui.Enabled = false
	armed = nil
end

function StoreController.Toggle()
	if gui.Enabled then
		StoreController.Close()
	else
		StoreController.Open(nil)
	end
end

function StoreController.IsOpen(): boolean
	return gui.Enabled
end

function StoreController.OnOpened(callback: () -> ())
	onOpened = callback
end

function StoreController.Init()
	gui = Ui.Screen("VoidlineStore", 20)
	gui.Enabled = false
	panel = Ui.Glass({
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.92, 0.82),
		Parent = gui,
	})
	Ui.Make("UISizeConstraint", { MaxSize = Vector2.new(680, 520), Parent = panel })
	Ui.Label({
		Name = "Title",
		Position = UDim2.fromOffset(18, 10),
		Size = UDim2.new(1, -90, 0, 30),
		Text = "VOIDLINE STORE",
		Font = Ui.Font.Title,
		TextSize = 22,
		TextColor3 = Ui.Colors.GoldBright,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = panel,
	})
	Ui.Button({
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 8),
		Size = UDim2.fromOffset(Ui.TOUCH, Ui.TOUCH),
		Text = "✕",
		TextSize = 20,
		Parent = panel,
	}, StoreController.Close)
	tokensLabel = Ui.Label({
		Name = "Tokens",
		Position = UDim2.fromOffset(18, 42),
		Size = UDim2.new(1, -36, 0, 18),
		TextSize = 12,
		TextColor3 = Ui.Colors.Cyan,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = panel,
	})
	local tabs = Ui.Make("Frame", {
		Name = "Tabs",
		Position = UDim2.fromOffset(14, 64),
		Size = UDim2.new(1, -28, 0, Ui.TOUCH),
		BackgroundTransparency = 1,
		Parent = panel,
	})
	Ui.List(tabs, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Left)
	for i, name in { "Passes", "Summons" } do
		tabButtons[name] = Ui.Button({
			Name = name,
			Size = UDim2.fromOffset(140, Ui.TOUCH),
			Text = string.upper(name),
			LayoutOrder = i,
			Parent = tabs,
		}, function()
			currentTab = name
			render()
		end)
	end
	list = Ui.Make("ScrollingFrame", {
		Name = "List",
		Position = UDim2.fromOffset(14, 120),
		Size = UDim2.new(1, -28, 1, -132),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = panel,
	})
	Ui.List(list, Enum.FillDirection.Vertical, 8, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Top)

	ClientState.OnChanged(function(changed)
		if changed.Store or changed.VoidlineTokens or changed.OwnedPerks or changed.TrialVouchers then
			render()
		end
	end)
	Workspace:GetAttributeChangedSignal("StarfallQueue"):Connect(render)
	Workspace:GetAttributeChangedSignal("SurgeQueue"):Connect(render)
end

return StoreController
