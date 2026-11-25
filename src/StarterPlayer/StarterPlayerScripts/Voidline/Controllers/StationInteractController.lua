local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Voidline = ReplicatedStorage:WaitForChild("Voidline")
local Remotes = require(Voidline.Remotes)
local DroneConfig = require(Voidline.Config.DroneConfig)

local player = Players.LocalPlayer

local StationInteractController = {}

local function addPrompt(part: BasePart, action: string, objectText: string)
	if part:FindFirstChildOfClass("ProximityPrompt") then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = action
	prompt.ObjectText = objectText
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = part
end

function StationInteractController.Init()
	task.spawn(function()
		local map = Workspace:WaitForChild("VoidlineMap", 30)
		if not map then
			return
		end
		for _, plot in map.Plots:GetChildren() do
			local station = plot:FindFirstChild("Station")
			if station then
				local refinery = station:FindFirstChild("Refinery")
				if refinery then
					addPrompt(refinery, "Sell Ore", "Station Refinery")
				end
				local pads = station:FindFirstChild("UpgradePads")
				if pads then
					for _, pad in pads:GetChildren() do
						if pad:IsA("BasePart") then
							addPrompt(pad, "Upgrade", pad.Name)
						end
					end
				end
				local tuner = station:FindFirstChild("LaserTuner")
				if tuner and tuner:IsA("BasePart") then
					addPrompt(tuner, "Cycle Laser Color", "Laser Tuner")
				end
			end
		end
		local monolith = map.Hub:FindFirstChild("VoidlineMonolith")
		if monolith then
			if monolith:FindFirstChild("RebirthPad") then
				addPrompt(monolith.RebirthPad, "Void Rebirth", "Monolith")
			end
			if monolith:FindFirstChild("ForgeAnchor") then
				addPrompt(monolith.ForgeAnchor, "Forge Artifact", "Artifact Forge")
				local turnIn = Instance.new("ProximityPrompt")
				turnIn.Name = "TurnIn"
				turnIn.ActionText = "Turn In Artifact"
				turnIn.ObjectText = "Token Redemption"
				turnIn.HoldDuration = 0
				turnIn.MaxActivationDistance = 14
				turnIn.RequiresLineOfSight = false
				turnIn.Parent = monolith.ForgeAnchor
			end
			if monolith:FindFirstChild("CodeTerminal") then
				addPrompt(monolith.CodeTerminal, "Enter Code", "Voidline Codes")
			end
			if monolith:FindFirstChild("SummonPads") then
				addPrompt(monolith.SummonPads, "Summon Starfall", "Server Summons")
			end
		end
	end)

	ProximityPromptService.PromptTriggered:Connect(function(prompt, triggerPlayer)
		if triggerPlayer ~= player then
			return
		end
		local part = prompt.Parent
		if not part or not part:IsA("BasePart") then
			return
		end
		local name = part.Name
		if name == "Refinery" then
			Remotes.Get("SellOre"):FireServer()
		elseif part:GetAttribute("UpgradeId") then
			Remotes.Get("RequestUpgrade"):FireServer(part:GetAttribute("UpgradeId"))
		elseif name == "RebirthPad" then
			Remotes.Get("RequestRebirth"):FireServer()
		elseif name == "ForgeAnchor" and prompt.Name == "TurnIn" then
			Remotes.Get("TurnInArtifact"):FireServer()
		elseif name == "ForgeAnchor" then
			Remotes.Get("RequestForge"):FireServer()
		elseif name == "CodeTerminal" then
			-- Simple Studio-friendly cycle of launch codes via attribute index
			local codes = { "VOIDLINE", "KILLSHOT", "LAUNCH" }
			local idx = (part:GetAttribute("CodeIdx") or 0) + 1
			if idx > #codes then
				idx = 1
			end
			part:SetAttribute("CodeIdx", idx)
			Remotes.Get("RedeemCode"):FireServer(codes[idx])
		elseif name == "SummonPads" then
			Remotes.Get("PromptRobuxPurchase"):FireServer("Product", "SummonVoidStarfall")
		elseif name == "LaserTuner" then
			local colors = {}
			for k in DroneConfig.LaserColors do
				table.insert(colors, k)
			end
			table.sort(colors)
			local idx = (part:GetAttribute("ColorIdx") or 0) + 1
			if idx > #colors then
				idx = 1
			end
			part:SetAttribute("ColorIdx", idx)
			Remotes.Get("SetLaserColor"):FireServer(colors[idx])
		elseif name == "VIPLoungePad" then
			Remotes.Get("RedeemDaily"):FireServer()
		end
	end)
end

return StationInteractController
