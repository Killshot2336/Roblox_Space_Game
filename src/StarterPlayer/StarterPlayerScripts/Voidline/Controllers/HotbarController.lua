--!strict
-- Bottom hotbar: Quick Upgrade, the three formations, Store, Menu, Home warp
-- and (with Auto-Sell Warp Link) remote Sell. Every key has an on-screen
-- button of at least 48 px, so touch players get the same actions.
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Voidline = ReplicatedStorage:WaitForChild("Voidline")
local EconomyConfig = require(Voidline.Config.EconomyConfig)
local DroneConfig = require(Voidline.Config.DroneConfig)
local EconomyRules = require(Voidline.Rules.EconomyRules)

local Client = script.Parent.Parent.Client
local Ui = require(Client.Ui)
local ClientState = require(Client.ClientState)

local HotbarController = {}

export type Actions = {
	OpenStore: () -> (),
	OpenMenu: (tab: string?) -> (),
	ToggleClip: () -> (),
}

local SLOT = 56
local FORMATION_GLYPHS = { "✶", "⟐", "♛" }

local gui: ScreenGui
local bar: Frame
local upgradeButton: TextButton
local upgradeDetail: TextLabel
local formationButtons: { TextButton } = {}
local sellButton: TextButton
local actions: Actions

-- Next upgrade worth showing (affordable or not): tutorial order first, then
-- the cheapest available upgrade.
function HotbarController.NextUpgrade(profile: any, ctx: any): (string?, number?)
	if not profile.TutorialComplete then
		for _, entry in { { "Drill", "Drill" }, { "Cargo", "Cargo" }, { "Drone", "DroneSlot" } } do
			if not profile.TutorialFlags[entry[1]] then
				return entry[2], EconomyRules.UpgradeCost(profile, entry[2], ctx)
			end
		end
	end
	local best, bestCost = nil, math.huge
	for _, id in EconomyConfig.UpgradeOrder do
		local ok, reason = EconomyRules.CanUpgrade(profile, id, ctx)
		if ok or reason == "funds" then
			local cost = EconomyRules.UpgradeCost(profile, id, ctx) :: number
			if cost < bestCost then
				best, bestCost = id, cost
			end
		end
	end
	if best then
		return best, bestCost
	end
	return nil, nil
end

local function keyHint(parent: Instance, key: string)
	if Ui.IsTouch() then
		return
	end
	local hint = Ui.Label({
		Name = "Key",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -4, 0, 2),
		Size = UDim2.fromOffset(16, 14),
		Text = key,
		TextSize = 11,
		Font = Ui.Font.Bold,
		TextColor3 = Ui.Colors.Muted,
		ZIndex = 3,
		Parent = parent,
	})
	hint.TextXAlignment = Enum.TextXAlignment.Right
end

local function slotButton(
	name: string,
	glyph: string,
	caption: string,
	key: string,
	order: number,
	onActivate: () -> ()
): TextButton
	local button = Ui.Button({
		Name = name,
		Size = UDim2.fromOffset(SLOT, SLOT),
		Text = "",
		LayoutOrder = order,
		Parent = bar,
	}, onActivate)
	Ui.Label({
		Name = "Glyph",
		Size = UDim2.new(1, 0, 0, 34),
		Position = UDim2.fromOffset(0, 4),
		Text = glyph,
		Font = Ui.Font.Title,
		TextSize = 24,
		TextColor3 = Ui.Colors.GoldBright,
		Parent = button,
	})
	Ui.Label({
		Name = "Caption",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -3),
		Size = UDim2.new(1, 0, 0, 14),
		Text = caption,
		Font = Ui.Font.Bold,
		TextSize = 10,
		TextColor3 = Ui.Colors.Muted,
		Parent = button,
	})
	keyHint(button, key)
	return button
end

local function quickUpgrade()
	ClientState.Fire("QuickUpgrade")
end

local function setFormation(n: number)
	if ClientState.Profile.Formation == n then
		return
	end
	ClientState.Fire("SetFormation", n)
end

local function refresh()
	local profile = ClientState.Profile
	local ctx = ClientState.Ctx()
	local id, cost = HotbarController.NextUpgrade(profile, ctx)
	if id and cost then
		local def = EconomyConfig.Upgrades[id]
		local affordable = profile.Credits >= cost
		upgradeDetail.Text = ("%s · ◆%s"):format(def.Label, Ui.Compact(cost))
		upgradeDetail.TextColor3 = if affordable then Ui.Colors.GoldBright else Ui.Colors.Muted
		local stroke = upgradeButton:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Transparency = if affordable then 0.1 else 0.6
		end
	else
		upgradeDetail.Text = "ALL MAXED"
		upgradeDetail.TextColor3 = Ui.Colors.Muted
	end
	for n, button in formationButtons do
		local selected = profile.Formation == n
		button.BackgroundColor3 = if selected then Ui.Colors.Gold else Ui.Colors.GlassLight
		local glyph = button:FindFirstChild("Glyph") :: TextLabel?
		if glyph then
			glyph.TextColor3 = if selected then Ui.Colors.Shadow else Ui.Colors.GoldBright
		end
	end
	sellButton.Visible = ClientState.HasPerk("AutoSellWarpLink")
end

local function bindKey(name: string, fn: () -> (), ...: Enum.KeyCode)
	ContextActionService:BindAction(name, function(_, state)
		if state == Enum.UserInputState.Begin then
			fn()
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, false, ...)
end

function HotbarController.SetVisible(on: boolean)
	gui.Enabled = on
end

function HotbarController.Init(hotbarActions: Actions)
	actions = hotbarActions
	gui = Ui.Screen("VoidlineHotbar", 6)
	bar = Ui.Glass({
		Name = "Hotbar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.fromOffset(0, SLOT + 16),
		AutomaticSize = Enum.AutomaticSize.X,
		CornerRadius = 18,
		Parent = gui,
	})
	Ui.Padding(bar, 8)
	Ui.List(bar, Enum.FillDirection.Horizontal, 8)

	upgradeButton = Ui.Button({
		Name = "Upgrade",
		Size = UDim2.fromOffset(176, SLOT),
		Text = "",
		LayoutOrder = 1,
		Parent = bar,
	}, quickUpgrade)
	Ui.Label({
		Name = "Title",
		Position = UDim2.fromOffset(0, 6),
		Size = UDim2.new(1, 0, 0, 22),
		Text = "UPGRADE",
		Font = Ui.Font.Title,
		TextSize = 18,
		TextColor3 = Ui.Colors.Text,
		Parent = upgradeButton,
	})
	upgradeDetail = Ui.Label({
		Name = "Detail",
		Position = UDim2.fromOffset(4, 30),
		Size = UDim2.new(1, -8, 0, 18),
		Text = "",
		Font = Ui.Font.Bold,
		TextSize = 13,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = upgradeButton,
	})
	keyHint(upgradeButton, "U")

	for n = 1, 3 do
		local caption = string.split(DroneConfig.FormationLabels[n], " ")
		formationButtons[n] = slotButton(
			"Formation" .. n,
			FORMATION_GLYPHS[n],
			caption[#caption],
			tostring(n),
			1 + n,
			function()
				setFormation(n)
			end
		)
	end
	slotButton("Store", "⬡", "STORE", "B", 10, function()
		actions.OpenStore()
	end)
	slotButton("Menu", "☰", "CODEX", "C", 11, function()
		actions.OpenMenu(nil)
	end)
	slotButton("Home", "⌂", "HOME", "H", 12, function()
		ClientState.Fire("WarpRequest", "Home")
	end)
	sellButton = slotButton("Sell", "⇪", "SELL", "R", 13, function()
		ClientState.Fire("SellOre")
	end)
	if Ui.IsTouch() then
		slotButton("Clip", "▣", "CLIP", "K", 14, function()
			actions.ToggleClip()
		end)
	end

	bindKey("VoidlineUpgrade", quickUpgrade, Enum.KeyCode.U)
	bindKey("VoidlineFormation1", function()
		setFormation(1)
	end, Enum.KeyCode.One)
	bindKey("VoidlineFormation2", function()
		setFormation(2)
	end, Enum.KeyCode.Two)
	bindKey("VoidlineFormation3", function()
		setFormation(3)
	end, Enum.KeyCode.Three)
	bindKey("VoidlineStore", function()
		actions.OpenStore()
	end, Enum.KeyCode.B)
	bindKey("VoidlineMenu", function()
		actions.OpenMenu(nil)
	end, Enum.KeyCode.C)
	bindKey("VoidlineHome", function()
		ClientState.Fire("WarpRequest", "Home")
	end, Enum.KeyCode.H)
	bindKey("VoidlineSell", function()
		if ClientState.HasPerk("AutoSellWarpLink") then
			ClientState.Fire("SellOre")
		end
	end, Enum.KeyCode.R)
	bindKey("VoidlineClipMode", function()
		actions.ToggleClip()
	end, Enum.KeyCode.K)

	refresh()
	ClientState.OnChanged(function(changed)
		if
			changed.Credits
			or changed.Formation
			or changed.TutorialFlags
			or changed.Store
			or changed.OwnedPerks
			or changed.TrialVouchers
			or changed.Loaded
			or changed.DrillLevel
			or changed.CargoLevel
			or changed.DroneSlots
			or changed.StationTier
			or changed.DroneTier
		then
			refresh()
		end
		if changed.Settings or changed.Loaded then
			HotbarController.SetVisible(ClientState.Profile.Settings.ClipMode ~= true)
		end
	end)
end

return HotbarController
