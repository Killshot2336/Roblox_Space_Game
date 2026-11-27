--!strict
-- One-shot SFX + soft ambient bed. Uses AudioConfig (engine rbxasset:// by
-- default). Gameplay never depends on audio loading or playing.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Voidline = ReplicatedStorage:WaitForChild("Voidline")
local AudioConfig = require(Voidline.Config.AudioConfig)
local Remotes = require(Voidline.Remotes)

local Controllers = script.Parent
local TowController = require(Controllers.TowController)

local AudioController = {}

local player = Players.LocalPlayer

local KIND_TO_KEY: { [string]: string } = {
	Ore = "Mine",
	Sell = "Sell",
	Upgrade = "Upgrade",
	BridgeIgnite = "BridgeIgnite",
	ContestShare = "TowArrive",
	WorldEvent = "Starfall",
	Rebirth = "Rebirth",
	PassGranted = "StoreSuccess",
	Store = "StoreSuccess",
	Warp = "Warp",
	VoidCatch = "Warp",
	Forge = "Forge",
	Achievement = "Achievement",
	Quest = "Achievement",
	Relic = "Relic",
	Codex = "Codex",
	CodexMilestone = "Achievement",
	Evolution = "Achievement",
	Mutation = "Relic",
	Tokens = "StoreSuccess",
	Daily = "StoreSuccess",
	RiftCleared = "Starfall",
	SquadChallenge = "Achievement",
	UpgradeFail = "Warn",
	StoreFail = "Warn",
	WarpLocked = "Warn",
	Code = "Click",
}

local folder: Folder
local cache: { [string]: Sound } = {}
local ambient: Sound? = nil
local muted = false

local PITCH_BAND: { [string]: { number } } = {
	Mine = { 0.92, 1.08 },
	Sell = { 0.98, 1.08 },
	Upgrade = { 0.94, 1.06 },
	TowArrive = { 0.94, 1.04 },
	Starfall = { 0.88, 1.0 },
	Rebirth = { 0.9, 1.02 },
	StoreSuccess = { 1.0, 1.1 },
	BridgeIgnite = { 0.96, 1.06 },
	Click = { 0.97, 1.05 },
	Formation = { 0.95, 1.08 },
	Warp = { 0.9, 1.05 },
	Forge = { 0.85, 1.0 },
	Achievement = { 0.95, 1.05 },
	Warn = { 0.85, 0.95 },
	Relic = { 0.92, 1.06 },
	Codex = { 1.05, 1.15 },
	MonolithSplit = { 0.9, 1.02 },
	MonolithCore = { 0.82, 0.96 },
	HaloForm = { 0.96, 1.08 },
	TowLatch = { 0.94, 1.05 },
	StarfallStreak = { 0.88, 1.02 },
}

local function getOrCreate(key: string): Sound?
	local spec = AudioConfig.Sounds[key]
	if not spec or type(spec.AssetId) ~= "string" or spec.AssetId == "" then
		return nil
	end
	local sound = cache[key]
	if sound and sound.Parent then
		return sound
	end
	local newSound = Instance.new("Sound")
	newSound.Name = "Voidline_" .. key
	newSound.SoundId = spec.AssetId
	local volume = (spec.Volume or 0.5) * (AudioConfig.MasterVolume or 1)
	if key == "Ambient" then
		volume = (AudioConfig.AmbientVolume or volume) * (AudioConfig.MasterVolume or 1)
	end
	newSound.Volume = volume
	newSound.Looped = spec.Loop == true
	newSound.RollOffMaxDistance = 0
	newSound.Parent = folder
	cache[key] = newSound
	return newSound
end

function AudioController.Play(key: string)
	if muted then
		return
	end
	local sound = getOrCreate(key)
	if not sound then
		return
	end
	local band = PITCH_BAND[key]
	if band and not sound.Looped then
		sound.PlaybackSpeed = band[1] + math.random() * (band[2] - band[1])
	else
		sound.PlaybackSpeed = 1
	end
	if not sound.Looped then
		sound.TimePosition = 0
	end
	sound:Play()
end

function AudioController.PlayClick()
	AudioController.Play("Click")
end

function AudioController.SetMuted(value: boolean)
	muted = value == true
	if ambient then
		if muted then
			ambient:Stop()
		elseif not ambient.IsPlaying then
			ambient:Play()
		end
	end
end

function AudioController.SetAmbientEnabled(enabled: boolean)
	if not ambient then
		return
	end
	if enabled and not muted then
		if not ambient.IsPlaying then
			ambient:Play()
		end
	else
		ambient:Stop()
	end
end

local function onJuice(message: any)
	if type(message) ~= "table" or type(message.Kind) ~= "string" then
		return
	end
	local kind = message.Kind
	if kind == "Store" and message.Ok ~= true then
		AudioController.Play("Warn")
		return
	end
	if kind == "Rebirth" and message.Ok ~= true then
		AudioController.Play("Warn")
		return
	end
	if kind == "Code" and message.Ok ~= true then
		AudioController.Play("Warn")
		return
	end
	if kind == "Daily" and message.Ok ~= true then
		return
	end
	if kind == "Forge" then
		if message.Phase == "done" or message.Phase == "start" then
			AudioController.Play("Forge")
		elseif message.Phase == "fail" then
			AudioController.Play("Warn")
		end
		return
	end
	if kind == "WorldEvent" and message.Phase == "start" then
		AudioController.Play("StarfallStreak")
	end
	if kind == "WorldEvent" and message.Phase ~= "start" then
		return
	end
	local key = KIND_TO_KEY[kind]
	if key then
		AudioController.Play(key)
	end
end

function AudioController.Init()
	folder = Instance.new("Folder")
	folder.Name = "VoidlineAudio"
	folder.Parent = player:WaitForChild("PlayerGui")

	-- Soft group under SoundService for future mixing.
	pcall(function()
		local group = SoundService:FindFirstChild("VoidlineSFX")
		if not group then
			group = Instance.new("SoundGroup")
			group.Name = "VoidlineSFX"
			group.Volume = 1
			group.Parent = SoundService
		end
	end)

	Remotes.Get("JuiceEvent").OnClientEvent:Connect(onJuice)

	TowController.OnArrive(function(tow)
		if tow.Owner == player.UserId then
			AudioController.Play("TowArrive")
		end
	end)

	-- UI click hook (avoids circular require at module load).
	local ok, UiMod = pcall(function()
		return require(script.Parent.Parent.Client.Ui)
	end)
	if ok and UiMod then
		UiMod.ClickSound = AudioController.PlayClick
	end

	ambient = getOrCreate("Ambient")
	if ambient and not muted then
		ambient:Play()
	end
end

return AudioController
