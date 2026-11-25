local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local ThrusterCosmeticController = {}

local function attachPack(character: Model)
	if character:FindFirstChild("VoidlineThrusterPack") then
		return
	end
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	if not torso then
		return
	end
	local pack = Instance.new("Part")
	pack.Name = "VoidlineThrusterPack"
	pack.Size = Vector3.new(1.4, 1.8, 0.6)
	pack.Color = Color3.fromRGB(12, 12, 18)
	pack.Material = Enum.Material.Metal
	pack.CanCollide = false
	pack.Massless = true
	pack.Parent = character
	local weld = Instance.new("Weld")
	weld.Part0 = torso
	weld.Part1 = pack
	weld.C0 = CFrame.new(0, 0.2, 0.75)
	weld.Parent = pack
	local glow = Instance.new("Part")
	glow.Name = "GoldTrim"
	glow.Size = Vector3.new(1.5, 0.2, 0.65)
	glow.Color = Color3.fromRGB(232, 186, 74)
	glow.Material = Enum.Material.Neon
	glow.CanCollide = false
	glow.Massless = true
	glow.Parent = character
	local weld2 = Instance.new("Weld")
	weld2.Part0 = pack
	weld2.Part1 = glow
	weld2.Parent = glow
end

function ThrusterCosmeticController.Init()
	local function onChar(char)
		task.wait(0.2)
		attachPack(char)
	end
	if player.Character then
		onChar(player.Character)
	end
	player.CharacterAdded:Connect(onChar)

	RunService.RenderStepped:Connect(function()
		local char = player.Character
		if not char then
			return
		end
		local pack = char:FindFirstChild("VoidlineThrusterPack")
		local trim = char:FindFirstChild("GoldTrim")
		local hide = player:GetAttribute("HideJetpack") == true
		if pack and pack:IsA("BasePart") then
			pack.Transparency = if hide then 1 else 0
		end
		if trim and trim:IsA("BasePart") then
			trim.Transparency = if hide then 1 else 0
		end
	end)
end

return ThrusterCosmeticController
