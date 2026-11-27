--!strict
-- Pooled one-shot visuals: floating reward popups (world or screen), the
-- Energy Bridge ignition sweep, pad/grinder flashes and screen flashes.
-- Nothing is created per frame; popups come from a fixed-size pool.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Voidline = ReplicatedStorage:WaitForChild("Voidline")
local PlotLayout = require(Voidline.Modules.PlotLayout)
local VisualBibleConfig = require(Voidline.Config.VisualBibleConfig)
local HubLayout = require(Voidline.Modules.HubLayout)

local Client = script.Parent.Parent.Client
local Ui = require(Client.Ui)
local CameraController = require(script.Parent.CameraController)

local VFXController = {}

local WORLD_POOL = 12
local SCREEN_POOL = 6
local POPUP_SECONDS = 1.1
local SWEEP_STEP = 0.07

type WorldPopup = { Anchor: Part, Gui: BillboardGui, Label: TextLabel }
type ScreenPopup = { Label: TextLabel }

local player = Players.LocalPlayer
local folder: Folder
local screenGui: ScreenGui
local flashFrame: Frame
local worldPool: { WorldPopup } = {}
local screenPool: { ScreenPopup } = {}
local worldNext = 1
local screenNext = 1
local clipHidden = false
local perfMode = false
local flashGui: ScreenGui

local function plotFolder(): Instance?
	local index = player:GetAttribute("PlotIndex")
	if type(index) ~= "number" then
		return nil
	end
	local map = Workspace:FindFirstChild("VoidlineMap")
	local plots = map and map:FindFirstChild("Plots")
	return plots and plots:FindFirstChild("Plot_" .. index)
end

function VFXController.OwnPlotWorld(localOffset: Vector3): Vector3?
	local index = player:GetAttribute("PlotIndex")
	if type(index) ~= "number" then
		return nil
	end
	return PlotLayout.World(index, localOffset)
end

local function makeWorldPopup(): WorldPopup
	local anchor = Ui.Make("Part", {
		Name = "PopupAnchor",
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Transparency = 1,
		Size = Vector3.new(0.2, 0.2, 0.2),
		CFrame = CFrame.new(0, -500, 0),
		Parent = folder,
	}) :: Part
	local gui = Ui.Make("BillboardGui", {
		Name = "Popup",
		Size = UDim2.fromOffset(220, 44),
		AlwaysOnTop = true,
		LightInfluence = 0,
		MaxDistance = 160,
		Enabled = false,
		Parent = anchor,
	}) :: BillboardGui
	local label = Ui.Label({
		Name = "Text",
		Size = UDim2.fromScale(1, 1),
		Font = Ui.Font.Title,
		TextSize = 24,
		TextStrokeTransparency = 0.4,
		Parent = gui,
	})
	return { Anchor = anchor, Gui = gui, Label = label }
end

local function makeScreenPopup(): ScreenPopup
	local label = Ui.Label({
		Name = "Popup",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 54),
		Size = UDim2.fromOffset(260, 30),
		Font = Ui.Font.Title,
		TextSize = 22,
		TextStrokeTransparency = 0.4,
		Visible = false,
		Parent = screenGui,
	})
	return { Label = label }
end

-- Floating text. With a position it rises in the world, otherwise under the
-- top pill.
function VFXController.SetClipHidden(on: boolean)
	clipHidden = on
	if screenGui then
		screenGui.Enabled = not on
	end
	if flashGui then
		flashGui.Enabled = not on
	end
end

function VFXController.SetPerfMode(on: boolean)
	perfMode = on
end

function VFXController.Popup(text: string, color: Color3?, position: Vector3?)
	if clipHidden then
		return
	end
	if position then
		local popup = worldPool[worldNext]
		worldNext = worldNext % WORLD_POOL + 1
		popup.Anchor.CFrame = CFrame.new(position)
		popup.Gui.StudsOffset = Vector3.new(0, 2, 0)
		popup.Gui.Enabled = true
		popup.Label.Text = text
		popup.Label.TextColor3 = color or Ui.Colors.GoldBright
		popup.Label.TextTransparency = 0
		Ui.Tween(popup.Gui, POPUP_SECONDS, { StudsOffset = Vector3.new(0, 6, 0) })
		Ui.Tween(popup.Label, POPUP_SECONDS, { TextTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		return
	end
	local popup = screenPool[screenNext]
	screenNext = screenNext % SCREEN_POOL + 1
	popup.Label.Text = text
	popup.Label.TextColor3 = color or Ui.Colors.GoldBright
	popup.Label.TextTransparency = 0
	popup.Label.Position = UDim2.new(0.5, 0, 0, 92)
	popup.Label.Visible = true
	Ui.Tween(popup.Label, POPUP_SECONDS, { Position = UDim2.new(0.5, 0, 0, 52), TextTransparency = 1 })
end

function VFXController.ScreenFlash(color: Color3?, seconds: number?)
	if clipHidden or perfMode or Ui.ReducedMotion then
		return
	end
	flashFrame.BackgroundColor3 = color or Color3.new(1, 1, 1)
	flashFrame.BackgroundTransparency = 0.35
	flashFrame.Visible = true
	Ui.Tween(flashFrame, seconds or 0.45, { BackgroundTransparency = 1 })
end

-- Segment-by-segment ignition from the plot to the hub.
function VFXController.BridgeSweep()
	local plot = plotFolder()
	local bridge = plot and plot:FindFirstChild("EnergyBridge")
	if not bridge then
		return
	end
	local segments: { BasePart } = {}
	for _, child in bridge:GetChildren() do
		if child:IsA("BasePart") then
			table.insert(segments, child)
		end
	end
	table.sort(segments, function(a, b)
		local ai = tonumber(a:GetAttribute("SegmentIndex")) or 0
		local bi = tonumber(b:GetAttribute("SegmentIndex")) or 0
		return ai < bi
	end)
	for i, segment in segments do
		segment.Transparency = 0.85
		task.delay(Ui.Motion(i * SWEEP_STEP), function()
			Ui.Tween(segment, 0.35, { Transparency = 0.08, Color = Color3.fromRGB(28, 26, 36) })
		end)
	end
	CameraController.Punch(7, 1.4)
	CameraController.Shake(0.45, 0.5)
	VFXController.ScreenFlash(Ui.Colors.GoldBright, 0.6)
end

function VFXController.PadFlash(upgradeId: string)
	local plot = plotFolder()
	local station = plot and plot:FindFirstChild("Station")
	local pads = station and station:FindFirstChild("UpgradePads")
	local pad = pads and pads:FindFirstChild(upgradeId)
	if pad and pad:IsA("BasePart") then
		pad.Color = Color3.new(1, 1, 1)
		Ui.Tween(pad, 0.4, { Color = Ui.Colors.Gold })
	end
end

local function shockRing(parent: Instance, center: Vector3, maxSize: number, color: Color3, seconds: number)
	local ring = Ui.Make("Part", {
		Name = "ShockRing",
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Shape = Enum.PartType.Cylinder,
		Material = Enum.Material.Neon,
		Color = color,
		Size = Vector3.new(0.35, 4, 4),
		CFrame = CFrame.new(center.X, center.Y + 0.2, center.Z) * CFrame.Angles(0, 0, math.rad(90)),
		Transparency = 0.35,
		Parent = parent,
	}) :: Part
	Ui.Tween(ring, seconds, {
		Size = Vector3.new(0.15, maxSize, maxSize),
		Transparency = 1,
	}, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	task.delay(seconds + 0.05, function()
		ring:Destroy()
	end)
end

function VFXController.MonolithSplitCrack()
	if clipHidden or perfMode then
		return
	end
	local map = Workspace:FindFirstChild("VoidlineMap")
	local hub = map and map:FindFirstChild("Hub")
	local monolith = hub and hub:FindFirstChild("VoidlineMonolith")
	local seam = monolith and monolith:FindFirstChild("MonolithSplitSeam")
	if not (seam and seam:IsA("BasePart")) then
		return
	end
	local cfg = VisualBibleConfig.MonolithSplit
	Ui.Tween(seam, cfg.Duration * 0.35, {
		Transparency = cfg.SeamPulseTransparency[1],
		Size = Vector3.new(0.65, seam.Size.Y * 1.02, seam.Size.Z * 1.05),
	})
	task.delay(cfg.Duration * 0.4, function()
		Ui.Tween(seam, cfg.Duration * 0.5, { Transparency = cfg.SeamPulseTransparency[2] })
	end)
	local sparkCount = cfg.SplitSparkCount or 8
	for i = 1, sparkCount do
		local spark = Ui.Make("Part", {
			Name = "SplitSpark",
			Anchored = true,
			CanCollide = false,
			CanQuery = false,
			Size = Vector3.new(0.35, 0.35, 2.4),
			CFrame = seam.CFrame * CFrame.new(0, -seam.Size.Y / 2 + i * (seam.Size.Y / (sparkCount + 1)), 0),
			Color = VisualBibleConfig.Palette.GoldBright,
			Material = Enum.Material.Neon,
			Parent = folder,
		}) :: Part
		Ui.Tween(spark, 0.9, { Transparency = 1, Size = Vector3.new(0.1, 0.1, 3.6) })
		task.delay(0.95, spark.Destroy, spark)
	end
	VFXController.ScreenFlash(VisualBibleConfig.Palette.GoldCore, 0.55)
end

function VFXController.StarfallSkyBurst()
	if clipHidden or perfMode then
		return
	end
	local cfg = VisualBibleConfig.Starfall
	local origin = HubLayout.VoidCore + Vector3.new(0, 40, 0)
	for i = 1, cfg.StreakCount do
		local angle = (i / cfg.StreakCount) * math.pi * 2
		local offset = Vector3.new(math.cos(angle) * 80, cfg.StreakSpeed, math.sin(angle) * 80)
		local streak = Ui.Make("Part", {
			Name = "StarfallStreak",
			Anchored = true,
			CanCollide = false,
			CanQuery = false,
			Size = Vector3.new(0.5, 0.5, 14),
			CFrame = CFrame.lookAt(origin + offset, origin),
			Color = VisualBibleConfig.Palette.GoldBright,
			Material = Enum.Material.Neon,
			Parent = folder,
		}) :: Part
		Ui.Tween(streak, 0.65, {
			CFrame = CFrame.new(origin) * CFrame.Angles(math.rad(90), angle, 0),
			Transparency = 1,
		})
		task.delay(0.7, streak.Destroy, streak)
	end
	shockRing(folder, HubLayout.MonolithCenter, cfg.ShockRingMax, VisualBibleConfig.Palette.Gold, cfg.ShockRingSeconds)
end

function VFXController.StarfallImpact(position: Vector3?)
	if clipHidden then
		return
	end
	local center = position or HubLayout.MonolithCenter
	shockRing(
		folder,
		center,
		if perfMode then 22 else VisualBibleConfig.Starfall.ShockRingMax * 0.65,
		VisualBibleConfig.Palette.GoldCore,
		VisualBibleConfig.Starfall.ShockRingSeconds * 0.75
	)
	if not perfMode then
		VFXController.ScreenFlash(VisualBibleConfig.Palette.GoldBright, 0.35)
	end
end

function VFXController.TowArriveShock(position: Vector3)
	if clipHidden then
		return
	end
	local cfg = VisualBibleConfig.Tow
	shockRing(
		folder,
		position,
		if perfMode then cfg.ShockRadius * 0.7 else cfg.ShockRadius,
		VisualBibleConfig.Palette.Gold,
		cfg.ShockSeconds
	)
	if not perfMode then
		CameraController.Punch(3, 0.45)
	end
end

function VFXController.SovereignHaloPulse()
	if clipHidden or perfMode then
		return
	end
	local haloCfg = VisualBibleConfig.SovereignHalo
	VFXController.ScreenFlash(VisualBibleConfig.Palette.GoldBright, haloCfg.PulseFlashSeconds or 0.35)
	if not Ui.ReducedMotion then
		shockRing(folder, HubLayout.MonolithCenter + Vector3.new(0, 18, 0), 18, VisualBibleConfig.Palette.Gold, 0.75)
	end
end

function VFXController.GrinderPulse()
	local plot = plotFolder()
	local station = plot and plot:FindFirstChild("Station")
	local grinder = station and station:FindFirstChild("GrinderCore")
	local glow = grinder and grinder:FindFirstChild("GrinderGlow")
	if glow and glow:IsA("BasePart") then
		glow.Size = Vector3.new(5.5, 5.5, 5.5)
		Ui.Tween(glow, 0.35, { Size = Vector3.new(4, 4, 4) }, Enum.EasingStyle.Back)
	end
end

function VFXController.Init()
	folder = Ui.Make("Folder", { Name = "VoidlineVFX", Parent = Workspace })
	screenGui = Ui.Screen("VoidlineVFX", 8)
	flashGui = Ui.Screen("VoidlineFlash", 30)
	flashGui.IgnoreGuiInset = true
	flashGui.ScreenInsets = Enum.ScreenInsets.None
	flashFrame = Ui.Make("Frame", {
		Name = "Flash",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Visible = false,
		Parent = flashGui,
	})
	for _ = 1, WORLD_POOL do
		table.insert(worldPool, makeWorldPopup())
	end
	for _ = 1, SCREEN_POOL do
		table.insert(screenPool, makeScreenPopup())
	end
end

return VFXController
