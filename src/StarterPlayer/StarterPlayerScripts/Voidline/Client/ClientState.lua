--!strict
-- Client replica of the local pilot's profile plus the latest store, squad
-- and onboarding state. Only server remotes write here; controllers read it
-- and subscribe to the keys they draw.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Voidline = ReplicatedStorage:WaitForChild("Voidline")
local ProfileSchema = require(Voidline.Modules.ProfileSchema)
local StoreRules = require(Voidline.Rules.StoreRules)
local ContentIndex = require(Voidline.Content.ContentIndex)
local Remotes = require(Voidline.Remotes)

export type Changed = { [string]: boolean }
type Listener = (Changed) -> ()

local ClientState = {}

ClientState.Profile = ProfileSchema.Default() :: any
ClientState.Loaded = false
ClientState.Store = { GamePasses = {}, PaidRandomRestricted = true } :: {
	GamePasses: { [string]: boolean },
	PaidRandomRestricted: boolean,
}
ClientState.Squad = { SquadId = nil, Members = {} } :: { [string]: any }
ClientState.Tutorial = nil :: { [string]: any }?
ClientState.CodexCount = 0

local listeners: { Listener } = {}

function ClientState.OnChanged(fn: Listener): () -> ()
	table.insert(listeners, fn)
	return function()
		local index = table.find(listeners, fn)
		if index then
			table.remove(listeners, index)
		end
	end
end

local function emit(changed: Changed)
	for _, fn in table.clone(listeners) do
		task.spawn(fn, changed)
	end
end

local function countCodex(profile: any): number
	local n = 0
	for id in profile.Codex do
		if ContentIndex.IsCodexId(id) then
			n += 1
		end
	end
	return n
end

function ClientState.Apply(payload: any)
	if type(payload) ~= "table" then
		return
	end
	local changed: Changed = {}
	if payload.Full == true and type(payload.Data) == "table" then
		ClientState.Profile = ProfileSchema.Migrate(payload.Data)
		ClientState.Loaded = true
		changed.Loaded = true
		for key in ClientState.Profile do
			changed[key] = true
		end
	else
		local profile = ClientState.Profile
		if type(payload.Set) == "table" then
			for key, value in payload.Set do
				profile[key] = value
				changed[key] = true
			end
		end
		if type(payload.Sub) == "table" then
			for key, patch in payload.Sub do
				if type(patch) ~= "table" then
					continue
				end
				local target = profile[key]
				if type(target) ~= "table" then
					target = {}
					profile[key] = target
				end
				for subKey, value in patch do
					target[subKey] = if value == ProfileSchema.REMOVED then nil else value
				end
				changed[key] = true
			end
		end
	end
	if changed.Codex then
		ClientState.CodexCount = countCodex(ClientState.Profile)
	end
	if next(changed) then
		emit(changed)
	end
end

function ClientState.Perks(): { [string]: boolean }
	return StoreRules.EffectivePerks(ClientState.Profile, os.time(), ClientState.Store.GamePasses)
end

function ClientState.HasPerk(perkId: string): boolean
	return ClientState.Perks()[perkId] == true
end

-- Display-only economy context (the server recomputes everything it charges).
function ClientState.Ctx(): { [string]: any }
	local boost = Workspace:GetAttribute("EventCreditMult")
	return {
		Perks = ClientState.Perks(),
		CreditBoost = if type(boost) == "number" then boost else 1,
		CodexMult = ContentIndex.CodexMultiplier(ClientState.CodexCount),
	}
end

function ClientState.Fire(remoteName: string, ...: any)
	Remotes.Get(remoteName):FireServer(...)
end

function ClientState.Init()
	Remotes.Get("DataSnapshot").OnClientEvent:Connect(ClientState.Apply)
	Remotes.Get("StoreState").OnClientEvent:Connect(function(state: any)
		if type(state) ~= "table" then
			return
		end
		ClientState.Store = {
			GamePasses = if type(state.GamePasses) == "table" then state.GamePasses else {},
			PaidRandomRestricted = state.PaidRandomRestricted ~= false,
		}
		emit({ Store = true })
	end)
	Remotes.Get("SquadUpdate").OnClientEvent:Connect(function(state: any)
		if type(state) ~= "table" then
			return
		end
		ClientState.Squad = state
		emit({ Squad = true })
	end)
	Remotes.Get("TutorialProgress").OnClientEvent:Connect(function(state: any)
		if type(state) ~= "table" then
			return
		end
		ClientState.Tutorial = state
		emit({ Tutorial = true })
	end)
end

function ClientState.LocalPlayer(): Player
	return Players.LocalPlayer
end

return ClientState
