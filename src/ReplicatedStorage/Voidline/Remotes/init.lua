-- Remotes folder bootstrap. Server calls Ensure() once at boot.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local REMOTE_NAMES = {
	"ClaimPlot",
	"RequestUpgrade",
	"SetFormation",
	"SellOre",
	"RequestRebirth",
	"RequestForge",
	"TurnInArtifact",
	"PurchaseWithTokens",
	"PromptRobuxPurchase",
	"SquadInvite",
	"SquadLeave",
	"SquadKick",
	"SquadUpdate",
	"WorldEventState",
	"SoftContestUpdate",
	"SettingsUpdate",
	"TutorialProgress",
	"JuiceEvent",
	"DataSnapshot",
	"RedeemCode",
	"RedeemDaily",
	"QuickUpgrade",
	"SetLaserColor",
	"PlayerInput", -- AFK heartbeat / input ping
}

local Remotes = {}

function Remotes.Ensure(): Folder
	local voidline = ReplicatedStorage:WaitForChild("Voidline")
	local folder = voidline:FindFirstChild("Remotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = voidline
	end

	for _, name in REMOTE_NAMES do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
	end
	return folder :: Folder
end

function Remotes.Get(name: string): RemoteEvent
	local folder = Remotes.Ensure()
	local remote = folder:WaitForChild(name, 10)
	assert(remote and remote:IsA("RemoteEvent"), "Missing remote " .. name)
	return remote
end

return Remotes
