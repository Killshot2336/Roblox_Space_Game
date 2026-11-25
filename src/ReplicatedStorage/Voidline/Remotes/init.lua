--!strict
-- Remote registry. Only the server creates remotes (ReplicatedStorage.Voidline.Net);
-- clients wait for the server's instances. A client must never create its own
-- copy: a client-created RemoteEvent does not replicate and silently drops traffic.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "Net"
local CLIENT_WAIT_SECONDS = 60

-- "Event" = RemoteEvent (reliable). "Unreliable" = UnreliableRemoteEvent for
-- high-frequency cosmetic state where a dropped packet is harmless.
local REMOTES: { [string]: "Event" | "Unreliable" } = {
	-- client -> server
	ClaimPlot = "Event",
	RequestUpgrade = "Event",
	QuickUpgrade = "Event",
	SetFormation = "Event",
	SellOre = "Event",
	RequestRebirth = "Event",
	RequestForge = "Event",
	TurnInArtifact = "Event",
	PurchaseWithTokens = "Event",
	PromptRobuxPurchase = "Event",
	SquadInvite = "Event",
	SquadRespond = "Event",
	SquadLeave = "Event",
	SquadKick = "Event",
	SettingsUpdate = "Event",
	RedeemCode = "Event",
	RedeemDaily = "Event",
	SetLaserColor = "Event",
	EquipCosmetic = "Event",
	TutorialSkip = "Event",
	PlayerInput = "Event",
	WarpRequest = "Event",
	SetRelicDisplay = "Event",
	InspectPilot = "Event",
	-- server -> client
	DataSnapshot = "Event",
	CollectionDelta = "Event",
	TutorialProgress = "Event",
	JuiceEvent = "Event",
	WorldEventState = "Event",
	StoreState = "Event",
	SquadUpdate = "Event",
	InspectResult = "Event",
	SoftContestUpdate = "Unreliable",
}

local Remotes = {}
Remotes.Names = REMOTES

local function serverFolder(): Folder
	local voidline = ReplicatedStorage:WaitForChild("Voidline")
	local existing = voidline:FindFirstChild(FOLDER_NAME)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder.Parent = voidline
	return folder
end

-- Server only. Idempotent.
function Remotes.Ensure(): Folder
	assert(RunService:IsServer(), "Remotes.Ensure is server-only; clients use Remotes.Get")
	local folder = serverFolder()
	for name, kind in REMOTES do
		if not folder:FindFirstChild(name) then
			local className = if kind == "Unreliable" then "UnreliableRemoteEvent" else "RemoteEvent"
			local remote = Instance.new(className)
			remote.Name = name
			remote.Parent = folder
		end
	end
	return folder
end

local cache: { [string]: Instance } = {}

local function resolve(name: string): Instance
	local hit = cache[name]
	if hit and hit.Parent then
		return hit
	end
	assert(REMOTES[name] ~= nil, "Unknown remote " .. name)
	local folder: Instance
	if RunService:IsServer() then
		folder = Remotes.Ensure()
	else
		local voidline = ReplicatedStorage:WaitForChild("Voidline")
		local found = voidline:WaitForChild(FOLDER_NAME, CLIENT_WAIT_SECONDS)
		assert(found, "Voidline remotes folder never replicated (is the server running Boot?)")
		folder = found
	end
	local remote = folder:WaitForChild(name, CLIENT_WAIT_SECONDS)
	assert(remote, "Missing remote " .. name)
	cache[name] = remote
	return remote
end

function Remotes.Get(name: string): RemoteEvent
	local remote = resolve(name)
	assert(remote:IsA("RemoteEvent"), name .. " is not a reliable RemoteEvent")
	return remote
end

function Remotes.GetUnreliable(name: string): UnreliableRemoteEvent
	local remote = resolve(name)
	assert(remote:IsA("UnreliableRemoteEvent"), name .. " is not an UnreliableRemoteEvent")
	return remote
end

return Remotes
