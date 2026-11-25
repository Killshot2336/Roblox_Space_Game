local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Voidline = ReplicatedStorage:WaitForChild("Voidline")
local Remotes = require(Voidline.Remotes)
local JuiceConfig = require(Voidline.Config.JuiceConfig)
local GameConfig = require(Voidline.Config.GameConfig)

local player = Players.LocalPlayer

local OnboardingController = {
	_step = 1,
	_beam = nil :: Beam?,
	_a0 = nil :: Attachment?,
	_a1 = nil :: Attachment?,
	_skipBtn = nil,
}

local function getPlot(): Folder?
	local map = Workspace:FindFirstChild("VoidlineMap")
	local plots = map and map:FindFirstChild("Plots")
	if not plots then
		return nil
	end
	for _, plot in plots:GetChildren() do
		if plot:GetAttribute("OwnerUserId") == player.UserId then
			return plot
		end
	end
	return nil
end

local function ensureBeam()
	if OnboardingController._beam then
		return
	end
	local char = player.Character or player.CharacterAdded:Wait()
	local hrp = char:WaitForChild("HumanoidRootPart")
	local a0 = Instance.new("Attachment")
	a0.Name = "VoidlineBeamA0"
	a0.Parent = hrp
	local a1 = Instance.new("Attachment")
	a1.Name = "VoidlineBeamA1"
	a1.Parent = hrp
	local beam = Instance.new("Beam")
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.Color = ColorSequence.new(JuiceConfig.TutorialBeamColor)
	beam.Width0 = 1.2
	beam.Width1 = 1.2
	beam.FaceCamera = true
	beam.Parent = hrp
	OnboardingController._beam = beam
	OnboardingController._a0 = a0
	OnboardingController._a1 = a1
end

function OnboardingController.SetStep(step: number)
	OnboardingController._step = step
	if step >= 4 then
		if OnboardingController._beam then
			OnboardingController._beam.Enabled = false
		end
		if OnboardingController._skipBtn then
			OnboardingController._skipBtn.Visible = false
		end
	end
end

function OnboardingController.Init()
	local gui = player:WaitForChild("PlayerGui")
	local skip = Instance.new("TextButton")
	skip.Name = "TutorialSkip"
	skip.Size = UDim2.fromOffset(72, 24)
	skip.Position = UDim2.new(0.5, 210, 0, 80)
	skip.BackgroundTransparency = 0.3
	skip.BackgroundColor3 = GameConfig.Colors.Obsidian
	skip.TextColor3 = GameConfig.Colors.Gold
	skip.Font = Enum.Font.Gotham
	skip.TextSize = 12
	skip.Text = "Skip"
	skip.Parent = gui:FindFirstChild("VoidlineHUD") or gui
	skip.MouseButton1Click:Connect(function()
		Remotes.Get("QuickUpgrade"):FireServer()
		-- Soft skip: still need drone; fire sell if cargo full path incomplete
		OnboardingController.SetStep(4)
	end)
	OnboardingController._skipBtn = skip

	Remotes.Get("TutorialProgress").OnClientEvent:Connect(function(step)
		OnboardingController.SetStep(step)
	end)

	RunService.RenderStepped:Connect(function()
		if OnboardingController._step >= 4 then
			return
		end
		ensureBeam()
		local plot = getPlot()
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if not plot or not hrp or not OnboardingController._a1 then
			return
		end
		local target: BasePart? = nil
		if OnboardingController._step <= 1 then
			local belt = plot:FindFirstChild("PersonalBelt")
			target = belt and belt:FindFirstChildWhichIsA("BasePart")
		elseif OnboardingController._step == 2 then
			local station = plot:FindFirstChild("Station")
			target = station and station:FindFirstChild("Refinery")
		else
			local station = plot:FindFirstChild("Station")
			local pads = station and station:FindFirstChild("UpgradePads")
			target = pads and (pads:FindFirstChild("DroneSlot") or pads:FindFirstChild("Drill"))
		end
		if target and target:IsA("BasePart") then
			OnboardingController._a1.WorldPosition = target.Position + Vector3.new(0, 2, 0)
			if OnboardingController._beam then
				OnboardingController._beam.Enabled = true
			end
		end
	end)
end

return OnboardingController
