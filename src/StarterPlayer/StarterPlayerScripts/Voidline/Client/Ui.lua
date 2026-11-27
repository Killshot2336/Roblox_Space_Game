--!strict
-- Glass UI kit: themed panels, labels and buttons with short tweens
-- (0.2-0.3 s). Every interactive element is at least Ui.TOUCH px tall so the
-- same layout works for touch.
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FormatNumber = require(ReplicatedStorage:WaitForChild("Voidline").Modules.FormatNumber)

local Ui = {}

Ui.Colors = {
	Glass = Color3.fromRGB(16, 13, 28),
	GlassLight = Color3.fromRGB(34, 28, 56),
	Gold = Color3.fromRGB(232, 186, 74),
	GoldBright = Color3.fromRGB(255, 220, 120),
	Text = Color3.fromRGB(244, 240, 255),
	Muted = Color3.fromRGB(170, 160, 200),
	Void = Color3.fromRGB(170, 120, 255),
	Cyan = Color3.fromRGB(90, 220, 255),
	Good = Color3.fromRGB(110, 255, 170),
	Warn = Color3.fromRGB(255, 120, 110),
	Shadow = Color3.fromRGB(4, 3, 10),
}

Ui.StyleColors = {
	info = Ui.Colors.Text,
	good = Ui.Colors.Good,
	gold = Ui.Colors.GoldBright,
	void = Ui.Colors.Void,
	warn = Ui.Colors.Warn,
} :: { [string]: Color3 }

Ui.Font = {
	Title = Enum.Font.GothamBlack,
	Bold = Enum.Font.GothamBold,
	Body = Enum.Font.GothamMedium,
}

Ui.TOUCH = 48
Ui.ReducedMotion = false
-- Set by AudioController.Init to play UI click SFX without a hard require cycle.
Ui.ClickSound = nil :: (() -> ())?

function Ui.Motion(seconds: number): number
	return if Ui.ReducedMotion then 0 else seconds
end

function Ui.Tween(
	instance: Instance,
	seconds: number,
	goals: { [string]: any },
	style: Enum.EasingStyle?,
	direction: Enum.EasingDirection?
): Tween
	local info =
		TweenInfo.new(Ui.Motion(seconds), style or Enum.EasingStyle.Quint, direction or Enum.EasingDirection.Out)
	local tween = TweenService:Create(instance, info, goals)
	tween:Play()
	return tween
end

-- Endless back-and-forth pulse (skipped with reduced motion).
function Ui.Loop(instance: Instance, seconds: number, goals: { [string]: any }): Tween?
	if Ui.ReducedMotion then
		return nil
	end
	local info = TweenInfo.new(seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	local tween = TweenService:Create(instance, info, goals)
	tween:Play()
	return tween
end

function Ui.Make(className: string, props: { [string]: any }, children: { Instance }?): any
	local instance = Instance.new(className)
	for key, value in props do
		if key ~= "Parent" then
			(instance :: any)[key] = value
		end
	end
	if children then
		for _, child in children do
			child.Parent = instance
		end
	end
	if props.Parent then
		instance.Parent = props.Parent
	end
	return instance
end

function Ui.Corner(parent: Instance, radius: number?): UICorner
	return Ui.Make("UICorner", { CornerRadius = UDim.new(0, radius or 12), Parent = parent })
end

function Ui.Stroke(parent: Instance, color: Color3?, thickness: number?, transparency: number?): UIStroke
	return Ui.Make("UIStroke", {
		Color = color or Ui.Colors.Gold,
		Thickness = thickness or 1.5,
		Transparency = transparency or 0.55,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

function Ui.Padding(parent: Instance, px: number, py: number?): UIPadding
	local y = py or px
	return Ui.Make("UIPadding", {
		PaddingLeft = UDim.new(0, px),
		PaddingRight = UDim.new(0, px),
		PaddingTop = UDim.new(0, y),
		PaddingBottom = UDim.new(0, y),
		Parent = parent,
	})
end

function Ui.List(
	parent: Instance,
	direction: Enum.FillDirection,
	padding: number,
	align: Enum.HorizontalAlignment?,
	valign: Enum.VerticalAlignment?
): UIListLayout
	return Ui.Make("UIListLayout", {
		FillDirection = direction,
		Padding = UDim.new(0, padding),
		HorizontalAlignment = align or Enum.HorizontalAlignment.Center,
		VerticalAlignment = valign or Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = parent,
	})
end

function Ui.Screen(name: string, order: number): ScreenGui
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local existing = playerGui:FindFirstChild(name)
	if existing then
		existing:Destroy()
	end
	return Ui.Make("ScreenGui", {
		Name = name,
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = order,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
		Parent = playerGui,
	})
end

-- Frosted obsidian panel with a thin gold edge.
function Ui.Glass(props: { [string]: any }): Frame
	local frame = Ui.Make("Frame", {
		BackgroundColor3 = Ui.Colors.Glass,
		BackgroundTransparency = 0.18,
		BorderSizePixel = 0,
	}) :: Frame
	for key, value in props do
		if key ~= "Parent" then
			(frame :: any)[key] = value
		end
	end
	Ui.Corner(frame, props.CornerRadius or 14)
	Ui.Stroke(frame)
	Ui.Make("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(1, 0.2),
		}),
		Color = ColorSequence.new(Ui.Colors.GlassLight, Ui.Colors.Glass),
		Parent = frame,
	})
	if props.Parent then
		frame.Parent = props.Parent
	end
	return frame
end

function Ui.Label(props: { [string]: any }): TextLabel
	local label = Ui.Make("TextLabel", {
		BackgroundTransparency = 1,
		Font = Ui.Font.Body,
		TextColor3 = Ui.Colors.Text,
		TextSize = 16,
		TextWrapped = true,
	}) :: TextLabel
	for key, value in props do
		if key ~= "Parent" then
			(label :: any)[key] = value
		end
	end
	if props.Parent then
		label.Parent = props.Parent
	end
	return label
end

local function pressScale(button: GuiObject): UIScale
	local scale = button:FindFirstChild("PressScale") :: UIScale?
	if scale then
		return scale
	end
	return Ui.Make("UIScale", { Name = "PressScale", Parent = button })
end

-- A tappable button. `onActivate` runs on click/tap with a small squash.
function Ui.Button(props: { [string]: any }, onActivate: (() -> ())?): TextButton
	local button = Ui.Make("TextButton", {
		AutoButtonColor = false,
		BackgroundColor3 = Ui.Colors.GlassLight,
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
		Font = Ui.Font.Bold,
		TextColor3 = Ui.Colors.Text,
		TextSize = 16,
		Size = UDim2.fromOffset(120, Ui.TOUCH),
	}) :: TextButton
	for key, value in props do
		if key ~= "Parent" then
			(button :: any)[key] = value
		end
	end
	Ui.Corner(button, 10)
	local stroke = Ui.Stroke(button, Ui.Colors.Gold, 1.5, 0.6)
	local scale = pressScale(button)
	button.MouseEnter:Connect(function()
		Ui.Tween(stroke, 0.15, { Transparency = 0.1 })
	end)
	button.MouseLeave:Connect(function()
		Ui.Tween(stroke, 0.2, { Transparency = 0.6 })
	end)
	button.Activated:Connect(function()
		scale.Scale = if Ui.ReducedMotion then 1 else 0.92
		Ui.Tween(scale, 0.22, { Scale = 1 }, Enum.EasingStyle.Back)
		if Ui.ClickSound then
			Ui.ClickSound()
		end
		if onActivate then
			onActivate()
		end
	end)
	if props.Parent then
		button.Parent = props.Parent
	end
	return button
end

function Ui.SetEnabled(button: TextButton, enabled: boolean)
	button.Active = enabled
	button.AutoButtonColor = false
	button.TextTransparency = if enabled then 0 else 0.45
	button.BackgroundTransparency = if enabled then 0.1 else 0.45
end

-- Quick scale-in for anything that just appeared.
function Ui.Pop(gui: GuiObject, from: number?)
	local scale = gui:FindFirstChild("PopScale") :: UIScale?
	if not scale then
		scale = Ui.Make("UIScale", { Name = "PopScale", Parent = gui })
	end
	local s = scale :: UIScale
	s.Scale = if Ui.ReducedMotion then 1 else (from or 0.85)
	Ui.Tween(s, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
end

function Ui.Compact(n: number): string
	return FormatNumber.Compact(n)
end

function Ui.Clock(seconds: number): string
	local s = math.max(0, math.floor(seconds))
	return ("%d:%02d"):format(s // 60, s % 60)
end

function Ui.IsTouch(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

function Ui.ClearChildren(parent: Instance, keepClass: string?)
	for _, child in parent:GetChildren() do
		if not child:IsA("UIComponent") and (keepClass == nil or not child:IsA(keepClass)) then
			child:Destroy()
		end
	end
end

-- Hotbar/store icon: rbxasset image from ArtConfig with optional glyph fallback label.
function Ui.ArtIcon(parent: Instance, artGroup: string, artKey: string, glyph: string, size: number?): ImageLabel
	local dim = size or 28
	local image = Ui.Make("ImageLabel", {
		Name = "ArtIcon",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(dim, dim),
		Position = UDim2.new(0.5, -dim / 2, 0, 4),
		Image = (function()
			local ok, ArtResolve = pcall(function()
				return require(ReplicatedStorage:WaitForChild("Voidline").Modules.ArtResolve)
			end)
			if ok and ArtResolve then
				return ArtResolve.UiImage(artGroup, artKey)
			end
			return "rbxasset://textures/ui/GuiImagePlaceholder.png"
		end)(),
		ImageTransparency = 0.12,
		ScaleType = Enum.ScaleType.Fit,
		Parent = parent,
	}) :: ImageLabel
	Ui.Label({
		Name = "Glyph",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 4 + dim / 2),
		Size = UDim2.fromOffset(dim, dim),
		Text = glyph,
		Font = Ui.Font.Title,
		TextSize = math.floor(dim * 0.78),
		TextColor3 = Ui.Colors.GoldBright,
		TextTransparency = 0.15,
		BackgroundTransparency = 1,
		Parent = parent,
	})
	return image
end

return Ui
