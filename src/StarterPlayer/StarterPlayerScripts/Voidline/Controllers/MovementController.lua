--!strict
-- Low-G sprint: faster walk while holding Shift (desktop) or the sprint chip
-- (touch). Small gold foot thrusters when sprinting; respects Hide Jetpack.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Voidline = ReplicatedStorage:WaitForChild("Voidline")
local VisualBibleConfig = require(Voidline.Config.VisualBibleConfig)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Voidline = ReplicatedStorage:WaitForChild("Voidline")
local GameConfig = require(Voidline.Config.GameConfig)

local Client = script.Parent.Parent.Client
local Ui = require(Client.Ui)
local ClientState = require(Client.ClientState)

local MovementController = {}

local BASE_WALK = 16
local SPRINT_WALK = 26
local SPRINT_JUMP = 52

local player = Players.LocalPlayer
local sprinting = false
local sprintGui: ScreenGui?
local footL: ParticleEmitter?
local footR: ParticleEmitter?

local function humanoid(): Humanoid?
	local character = player.Character
	return if character then character:FindFirstChildOfClass("Humanoid") else nil
end

local function hideJetpack(): boolean
	return player:GetAttribute("HideJetpack") == true or ClientState.Profile.Settings.HideJetpack == true
end

local function setFootFx(on: boolean)
	local show = on and not hideJetpack()
	if footL then
		footL.Enabled = show
	end
	if footR then
		footR.Enabled = show
	end
end

local function applySpeed()
	local hum = humanoid()
	if not hum then
		return
	end
	if sprinting then
		hum.WalkSpeed = SPRINT_WALK
		hum.JumpPower = SPRINT_JUMP
	else
		hum.WalkSpeed = BASE_WALK
		hum.JumpPower = 50
	end
	setFootFx(sprinting)
end

local function setSprint(on: boolean)
	if sprinting == on then
		return
	end
	sprinting = on
	applySpeed()
end

local AVATAR_FILL = VisualBibleConfig.Lighting.HubFill

local function attachAvatarFill(character: Model)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	local existing = root:FindFirstChild("VoidlineAvatarFill")
	if existing then
		return
	end
	local light = Instance.new("PointLight")
	light.Name = "VoidlineAvatarFill"
	light.Brightness = AVATAR_FILL.AvatarFillBrightness
	light.Range = AVATAR_FILL.AvatarFillRange
	light.Color = Color3.fromRGB(215, 205, 245)
	light.Shadows = false
	light.Parent = root
end

local function attachFootFx(character: Model)
	footL, footR = nil, nil
	for _, name in { "LeftFoot", "RightFoot", "Left Leg", "Right Leg" } do
		local foot = character:FindFirstChild(name)
		if foot and foot:IsA("BasePart") then
			local existing = foot:FindFirstChild("VoidlineSprintThruster")
			local emitter: ParticleEmitter
			if existing and existing:IsA("ParticleEmitter") then
				emitter = existing
			else
				emitter = Instance.new("ParticleEmitter") :: ParticleEmitter
				emitter.Name = "VoidlineSprintThruster"
				emitter.Texture = ""
				emitter.Rate = 0
				emitter.Lifetime = NumberRange.new(0.15, 0.3)
				emitter.Speed = NumberRange.new(2, 5)
				emitter.SpreadAngle = Vector2.new(25, 25)
				emitter.Color = ColorSequence.new(GameConfig.Colors.GoldBright, GameConfig.Colors.Gold)
				emitter.LightEmission = 0.8
				emitter.Size = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.35),
					NumberSequenceKeypoint.new(1, 0),
				})
				emitter.Enabled = false
				emitter.Parent = foot
			end
			if name:find("Left") then
				footL = emitter
			else
				footR = emitter
			end
		end
	end
	applySpeed()
end

local function bindDesktopSprint()
	ContextActionService:BindAction("VoidlineSprint", function(_, state)
		if state == Enum.UserInputState.Begin then
			setSprint(true)
		elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
			setSprint(false)
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift)
end

local function buildTouchSprint()
	if not Ui.IsTouch() then
		return
	end
	sprintGui = Ui.Screen("VoidlineSprintChip", 5)
	local button = Ui.Button({
		Name = "Sprint",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -18, 1, -140),
		Size = UDim2.fromOffset(Ui.TOUCH, Ui.TOUCH),
		Text = "SPRINT",
		Font = Ui.Font.Bold,
		TextSize = 11,
		TextColor3 = Ui.Colors.GoldBright,
		Parent = sprintGui,
	}, function() end)
	Ui.Make("UISizeConstraint", { MinSize = Vector2.new(Ui.TOUCH, Ui.TOUCH), Parent = button })
	button.MouseButton1Down:Connect(function()
		setSprint(true)
	end)
	button.MouseButton1Up:Connect(function()
		setSprint(false)
	end)
	button.MouseLeave:Connect(function()
		setSprint(false)
	end)
	ClientState.OnChanged(function(changed)
		if changed.Settings or changed.Loaded then
			button.Visible = ClientState.Profile.Settings.ClipMode ~= true
		end
	end)
end

function MovementController.SetVisible(on: boolean)
	if sprintGui then
		sprintGui.Enabled = on
	end
end

function MovementController.Init()
	bindDesktopSprint()
	buildTouchSprint()
	local function onCharacter(character: Model)
		task.defer(function()
			local humInst = character:WaitForChild("Humanoid", 10)
			if humInst and humInst:IsA("Humanoid") then
				humInst.WalkSpeed = BASE_WALK
			end
			attachAvatarFill(character)
			attachFootFx(character)
		end)
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		onCharacter(player.Character)
	end
	player:GetAttributeChangedSignal("HideJetpack"):Connect(function()
		setFootFx(sprinting)
	end)
	ClientState.OnChanged(function(changed)
		if changed.Settings or changed.Loaded then
			setFootFx(sprinting)
		end
	end)
end

return MovementController
