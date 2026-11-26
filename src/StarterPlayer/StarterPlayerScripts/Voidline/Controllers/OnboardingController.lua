--!strict
-- Diegetic onboarding: a golden floor beam from the pilot to the next thing
-- to touch, a pulsing ring on it, the [n/4] ticker and a tiny two-tap Skip.
-- The server owns progress; this only draws what the profile says.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Voidline = ReplicatedStorage:WaitForChild("Voidline")
local JuiceConfig = require(Voidline.Config.JuiceConfig)
local GameConfig = require(Voidline.Config.GameConfig)
local TutorialRules = require(Voidline.Rules.TutorialRules)
local PlotLayout = require(Voidline.Modules.PlotLayout)

local Client = script.Parent.Parent.Client
local Ui = require(Client.Ui)
local ClientState = require(Client.ClientState)

local OnboardingController = {}

local FINALE_SECONDS = 6
local SKIP_CONFIRM_SECONDS = 3
local FLOOR_OFFSET = Vector3.new(0, -2.8, 0)

local player = Players.LocalPlayer
local gui: ScreenGui
local card: Frame
local tickerText: TextLabel
local hintText: TextLabel
local pips: { Frame } = {}
local skipButton: TextButton
local skipArmedUntil = 0

local folder: Folder? = nil
local anchor: Part? = nil
local ring: Part? = nil
local beam: Beam? = nil
local rootAttachment: Attachment? = nil
local finaleUntil = 0
local finished = false

local function ensureWorld(): (Part, Part, Beam)
	if folder and anchor and ring and beam then
		return anchor, ring, beam
	end
	local f = Ui.Make("Folder", { Name = "VoidlineOnboarding", Parent = Workspace }) :: Folder
	local a = Ui.Make("Part", {
		Name = "BeamAnchor",
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Transparency = 1,
		Size = Vector3.new(0.2, 0.2, 0.2),
		Parent = f,
	}) :: Part
	local target = Ui.Make("Attachment", { Name = "Target", Parent = a }) :: Attachment
	local r = Ui.Make("Part", {
		Name = "Ring",
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Shape = Enum.PartType.Cylinder,
		Material = Enum.Material.Neon,
		Color = JuiceConfig.TutorialBeamColor,
		Size = Vector3.new(0.15, 9, 9),
		Transparency = 0.35,
		Parent = f,
	}) :: Part
	Ui.Loop(r, 0.8, { Transparency = 0.75 })
	local b = Ui.Make("Beam", {
		Name = "FloorBeam",
		Attachment1 = target,
		Color = ColorSequence.new(JuiceConfig.TutorialBeamColor, GameConfig.Colors.GoldBright),
		Transparency = NumberSequence.new(0.15, 0.4),
		Width0 = 1.4,
		Width1 = 0.8,
		LightEmission = 1,
		LightInfluence = 0,
		FaceCamera = true,
		Segments = 16,
		Enabled = false,
		Parent = a,
	}) :: Beam
	folder, anchor, ring, beam = f, a, r, b
	return a, r, b
end

local function attachToCharacter(character: Model?)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if rootAttachment then
		rootAttachment:Destroy()
		rootAttachment = nil
	end
	if not root then
		return
	end
	rootAttachment = Ui.Make("Attachment", { Name = "VoidlineGuide", Position = FLOOR_OFFSET, Parent = root })
	if beam then
		beam.Attachment0 = rootAttachment
	end
end

local function plotIndex(): number?
	local index = player:GetAttribute("PlotIndex")
	return if type(index) == "number" then index else nil
end

-- Where to point for the current step: (beam target, ring target).
local function targets(profile: any): (Vector3?, Vector3?)
	local index = plotIndex()
	if not index then
		return nil, nil
	end
	if finaleUntil > os.clock() then
		local hub = PlotLayout.BridgeEnd(index)
		return hub, PlotLayout.World(index, PlotLayout.BridgeStart)
	end
	if profile.TutorialComplete then
		return nil, nil
	end
	local step = profile.TutorialStep
	if step == 1 then
		return nil, PlotLayout.World(index, PlotLayout.Grinder - Vector3.new(0, 4.8, 0))
	elseif step == 2 then
		local pad = PlotLayout.World(index, PlotLayout.Refinery)
		return pad, pad
	elseif step == 3 then
		local id = TutorialRules.NextUpgrade(profile)
		local offset = if id then PlotLayout.Pads[id] else nil
		if offset then
			local pad = PlotLayout.World(index, offset)
			return pad, pad
		end
	end
	return nil, nil
end

local function stepHint(profile: any): string
	local step = profile.TutorialStep
	if step == 3 then
		local flags = profile.TutorialFlags
		local function part(done: boolean, label: string): string
			return if done then "✓ " .. string.split(label, " ")[1] else label
		end
		return ("%s  ·  %s  ·  %s"):format(
			part(flags.Drill, "Drill 20"),
			part(flags.Cargo, "Cargo 35"),
			part(flags.Drone, "Drone 50")
		)
	end
	local info = TutorialRules.Steps[step]
	return if info then info.Hint else ""
end

local function render()
	local profile = ClientState.Profile
	if not ClientState.Loaded then
		gui.Enabled = false
		return
	end
	local inFinale = finaleUntil > os.clock()
	if profile.TutorialComplete and not inFinale then
		gui.Enabled = false
		if folder then
			folder:Destroy()
			folder, anchor, ring, beam = nil, nil, nil, nil
		end
		finished = true
		return
	end
	local clip = profile.Settings.ClipMode == true
	gui.Enabled = not clip
	if clip then
		local _, _, b = ensureWorld()
		b.Enabled = false
		if ring then
			ring.CFrame = CFrame.new(0, -500, 0)
		end
		return
	end
	local step = if inFinale then TutorialRules.DoneStep else profile.TutorialStep
	local info = TutorialRules.Steps[step]
	tickerText.Text = if info then info.Ticker else ""
	if inFinale then
		hintText.Text = if profile.TutorialSkipped
			then ("Skipped · +%d Credits"):format(GameConfig.TutorialCompleteBonusCredits)
			else ("Bridge to the Monolith is open · +%d Credits"):format(GameConfig.TutorialCompleteBonusCredits)
	else
		hintText.Text = stepHint(profile)
	end
	for i, pip in pips do
		pip.BackgroundColor3 = if i <= step then Ui.Colors.Gold else Ui.Colors.Shadow
	end
	skipButton.Visible = not inFinale

	local beamTarget, ringTarget = targets(profile)
	local a, r, b = ensureWorld()
	if beamTarget then
		a.CFrame = CFrame.new(beamTarget + Vector3.new(0, 0.3, 0))
		b.Enabled = true
		if not rootAttachment then
			attachToCharacter(player.Character)
		end
		b.Attachment0 = rootAttachment
	else
		b.Enabled = false
	end
	if ringTarget then
		r.CFrame = CFrame.new(ringTarget + Vector3.new(0, 0.4, 0)) * CFrame.Angles(0, 0, math.rad(90))
	else
		r.CFrame = CFrame.new(0, -500, 0)
	end
end

local function onSkip()
	if os.clock() < skipArmedUntil then
		skipArmedUntil = 0
		ClientState.Fire("TutorialSkip")
		return
	end
	skipArmedUntil = os.clock() + SKIP_CONFIRM_SECONDS
	local label = skipButton:FindFirstChild("Label") :: TextLabel?
	if label then
		label.Text = "Tap again to skip"
		task.delay(SKIP_CONFIRM_SECONDS, function()
			label.Text = "Skip tutorial"
		end)
	end
end

-- Called by the juice dispatcher when the bridge ignites.
function OnboardingController.Finale()
	if finished then
		return
	end
	finaleUntil = os.clock() + FINALE_SECONDS
	render()
	Ui.Pop(card, 0.8)
	task.delay(FINALE_SECONDS + 0.1, render)
end

local function build()
	gui = Ui.Screen("VoidlineOnboarding", 7)
	card = Ui.Glass({
		Name = "Ticker",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 16, 0.34, 0),
		Size = UDim2.fromOffset(300, 86),
		Parent = gui,
	})
	tickerText = Ui.Label({
		Name = "Step",
		Position = UDim2.fromOffset(14, 8),
		Size = UDim2.new(1, -28, 0, 24),
		Font = Ui.Font.Title,
		TextSize = 18,
		TextColor3 = Ui.Colors.GoldBright,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = card,
	})
	hintText = Ui.Label({
		Name = "Hint",
		Position = UDim2.fromOffset(14, 34),
		Size = UDim2.new(1, -28, 0, 30),
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = card,
	})
	local pipRow = Ui.Make("Frame", {
		Name = "Pips",
		Position = UDim2.new(0, 14, 1, -14),
		Size = UDim2.new(1, -28, 0, 6),
		BackgroundTransparency = 1,
		Parent = card,
	})
	Ui.List(pipRow, Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Left)
	for i = 1, TutorialRules.DoneStep do
		local pip = Ui.Make("Frame", {
			Name = "Pip" .. i,
			Size = UDim2.new(0.25, -5, 1, 0),
			BackgroundColor3 = Ui.Colors.Shadow,
			BorderSizePixel = 0,
			LayoutOrder = i,
			Parent = pipRow,
		}) :: Frame
		Ui.Corner(pip, 3)
		pips[i] = pip
	end
	skipButton = Ui.Make("TextButton", {
		Name = "Skip",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.new(0, 16, 0.34, 46),
		Size = UDim2.fromOffset(140, Ui.TOUCH),
		BackgroundTransparency = 1,
		Text = "",
		Parent = gui,
	}) :: TextButton
	Ui.Label({
		Name = "Label",
		Size = UDim2.fromScale(1, 1),
		Text = "Skip tutorial",
		TextSize = 12,
		TextColor3 = Ui.Colors.Muted,
		TextTransparency = 0.25,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = skipButton,
	})
	skipButton.Activated:Connect(onSkip)
end

function OnboardingController.Init()
	build()
	gui.Enabled = false
	player.CharacterAdded:Connect(function(character)
		attachToCharacter(character)
		render()
	end)
	player:GetAttributeChangedSignal("PlotIndex"):Connect(render)
	ClientState.OnChanged(function(changed)
		if
			changed.Loaded
			or changed.TutorialStep
			or changed.TutorialFlags
			or changed.TutorialComplete
			or changed.Tutorial
			or changed.Settings
		then
			render()
		end
	end)
	render()
end

return OnboardingController
