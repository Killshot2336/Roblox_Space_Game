--!strict
-- Client-only ProximityPrompts for hub kiosks that just open UI (the Code
-- Terminal, the Summon pad, the streak board in the lounge) and a "Pilot
-- Card" prompt on other pilots. Prompts work with touch, mouse, keys and pads.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Client = script.Parent.Parent.Client
local Ui = require(Client.Ui)
local ClientState = require(Client.ClientState)

local InteractController = {}

export type Actions = {
	OpenStore: (tab: string?) -> (),
	OpenMenu: (tab: string?) -> (),
}

local player = Players.LocalPlayer
local cardPrompts: { [Player]: ProximityPrompt } = {}

local function prompt(parent: Instance, action: string, object: string, onTrigger: () -> ()): ProximityPrompt
	local existing = parent:FindFirstChild("VoidlineLocalPrompt")
	if existing then
		existing:Destroy()
	end
	local p = Ui.Make("ProximityPrompt", {
		Name = "VoidlineLocalPrompt",
		ActionText = action,
		ObjectText = object,
		HoldDuration = 0,
		MaxActivationDistance = 12,
		RequiresLineOfSight = false,
		KeyboardKeyCode = Enum.KeyCode.E,
		Parent = parent,
	}) :: ProximityPrompt
	p.Triggered:Connect(onTrigger)
	return p
end

local function addCardPrompt(other: Player, character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not root then
		return
	end
	local existing = cardPrompts[other]
	if existing then
		existing:Destroy()
	end
	local p = Ui.Make("ProximityPrompt", {
		Name = "VoidlinePilotCard",
		ActionText = "Pilot Card",
		ObjectText = other.DisplayName,
		HoldDuration = 0.2,
		MaxActivationDistance = 10,
		RequiresLineOfSight = false,
		KeyboardKeyCode = Enum.KeyCode.F,
		Parent = root,
	}) :: ProximityPrompt
	p.Triggered:Connect(function()
		ClientState.Fire("InspectPilot", other.UserId)
	end)
	cardPrompts[other] = p
end

local function watchPlayer(other: Player)
	if other == player then
		return
	end
	other.CharacterAdded:Connect(function(character)
		addCardPrompt(other, character)
	end)
	if other.Character then
		task.spawn(addCardPrompt, other, other.Character)
	end
end

function InteractController.Init(actions: Actions)
	local map = Workspace:WaitForChild("VoidlineMap", 30)
	local hub = map and map:WaitForChild("Hub", 30)
	if hub then
		local terminal = hub:WaitForChild("CodeTerminal", 10)
		if terminal then
			prompt(terminal, "Enter Code", "Code Terminal", function()
				actions.OpenMenu("Codes")
			end)
		end
		local summon = hub:WaitForChild("SummonPad", 10)
		if summon then
			prompt(summon, "Server Summons", "Summon Pad", function()
				actions.OpenStore("Summons")
			end)
		end
		local lounge = hub:WaitForChild("VipLounge", 10)
		if lounge then
			prompt(lounge, "Daily Streak", "Sovereign Lounge", function()
				actions.OpenMenu("Daily")
			end)
		end
	end
	for _, other in Players:GetPlayers() do
		watchPlayer(other)
	end
	Players.PlayerAdded:Connect(watchPlayer)
	Players.PlayerRemoving:Connect(function(other)
		local p = cardPrompts[other]
		if p then
			p:Destroy()
			cardPrompts[other] = nil
		end
	end)
end

return InteractController
