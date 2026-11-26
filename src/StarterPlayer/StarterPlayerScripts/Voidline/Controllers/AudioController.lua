--!strict
-- Optional one-shot SFX on JuiceEvent kinds. Uses AudioConfig placeholders only;
-- gameplay does not depend on audio loading or playing.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Voidline = ReplicatedStorage:WaitForChild("Voidline")
local AudioConfig = require(Voidline.Config.AudioConfig)
local Remotes = require(Voidline.Remotes)

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
}

local folder: Folder
local cache: { [string]: Sound } = {}

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
	newSound.Volume = (spec.Volume or 0.5) * (AudioConfig.MasterVolume or 1)
	newSound.RollOffMaxDistance = 0
	newSound.Parent = folder
	cache[key] = newSound
	return newSound
end

local PITCH_BAND: { [string]: { number } } = {
	Mine = { 0.95, 1.05 },
	Sell = { 0.98, 1.08 },
	Upgrade = { 0.92, 1.02 },
	TowArrive = { 0.94, 1.04 },
	Starfall = { 0.9, 1.0 },
	Rebirth = { 0.88, 0.98 },
	StoreSuccess = { 1.0, 1.1 },
	BridgeIgnite = { 0.96, 1.06 },
}

local function playKey(key: string)
	local sound = getOrCreate(key)
	if not sound then
		return
	end
	local band = PITCH_BAND[key]
	if band then
		sound.PlaybackSpeed = band[1] + math.random() * (band[2] - band[1])
	end
	sound.TimePosition = 0
	sound:Play()
end

local function onJuice(message: any)
	if type(message) ~= "table" or type(message.Kind) ~= "string" then
		return
	end
	if message.Kind == "Store" and message.Ok ~= true then
		return
	end
	if message.Kind == "Rebirth" and message.Ok ~= true then
		return
	end
	if message.Kind == "WorldEvent" and message.Phase ~= "start" then
		return
	end
	local key = KIND_TO_KEY[message.Kind]
	if key then
		playKey(key)
	end
end

function AudioController.Init()
	folder = Instance.new("Folder")
	folder.Name = "VoidlineAudio"
	folder.Parent = player:WaitForChild("PlayerGui")
	Remotes.Get("JuiceEvent").OnClientEvent:Connect(onJuice)
end

return AudioController
