local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Voidline = ReplicatedStorage:WaitForChild("Voidline")
local GameConfig = require(Voidline.Config.GameConfig)
local RebirthConfig = require(Voidline.Config.RebirthConfig)
local PerformanceConfig = require(Voidline.Config.PerformanceConfig)
local DroneConfig = require(Voidline.Config.DroneConfig)
local Remotes = require(Voidline.Remotes)

local STORE_NAME = "VoidlinePlayer_v1"
local store = DataStoreService:GetDataStore(STORE_NAME)

local PlayerDataService = {
	_profiles = {} :: { [number]: any },
	_saving = {} :: { [number]: boolean },
}

local function dayKey(): string
	return os.date("!%Y-%m-%d")
end

local function defaultProfile()
	return {
		Credits = 0,
		Ore = 0,
		VoidShards = 0,
		Artifacts = 0,
		VoidlineTokens = 0,
		Rebirths = 0,
		CreditMult = 1,
		StationTier = 1,
		DrillLevel = 1,
		CargoLevel = 1,
		DroneSlots = DroneConfig.StarterSlots,
		DroneTier = 1,
		GalaxyFlags = {
			Starter = true,
			Nebula = false,
			VoidRim = false,
			Celestial = false,
		},
		OwnedPerks = {},
		RedeemedCodes = {},
		TutorialStep = 1,
		TutorialComplete = false,
		Settings = {
			PerfMode = PerformanceConfig.DefaultPerfMode,
			HideJetpack = false,
			ClipMode = false,
			LaserColor = DroneConfig.DefaultLaserColor,
		},
		Cosmetics = { Title = nil },
		ForgeTokensEarnedToday = 0,
		ForgeDayKey = dayKey(),
		DailyStreak = 0,
		LastLoginDay = "",
		TrialVouchers = {},
		Codex = {},
		Relics = {},
		Formation = 1,
		Version = 1,
	}
end

function PlayerDataService.Get(player: Player)
	return PlayerDataService._profiles[player.UserId]
end

function PlayerDataService.Replicate(player: Player)
	local data = PlayerDataService.Get(player)
	if not data then
		return
	end
	Remotes.Get("DataSnapshot"):FireClient(player, data)
end

function PlayerDataService.Load(player: Player)
	local key = "p_" .. player.UserId
	local ok, saved = pcall(function()
		return store:GetAsync(key)
	end)
	local data = defaultProfile()
	if ok and typeof(saved) == "table" then
		for k, v in saved do
			data[k] = v
		end
	end
	-- Daily streak on load
	local today = dayKey()
	if data.LastLoginDay ~= today then
		local yesterday = os.date("!%Y-%m-%d", os.time() - 86400)
		if data.LastLoginDay == yesterday then
			data.DailyStreak = math.min(7, (data.DailyStreak or 0) + 1)
		else
			data.DailyStreak = 1
		end
		data.LastLoginDay = today
	end
	if data.ForgeDayKey ~= today then
		data.ForgeDayKey = today
		data.ForgeTokensEarnedToday = 0
	end
	data.CreditMult = RebirthConfig.CreditMultiplier(data.Rebirths or 0)
	PlayerDataService._profiles[player.UserId] = data
	PlayerDataService.Replicate(player)
	return data
end

function PlayerDataService.Save(player: Player)
	local data = PlayerDataService.Get(player)
	if not data or PlayerDataService._saving[player.UserId] then
		return
	end
	PlayerDataService._saving[player.UserId] = true
	local key = "p_" .. player.UserId
	local payload = table.clone(data)
	payload.Ore = data.Ore -- session ore persists too for fairness
	local ok, err = pcall(function()
		store:UpdateAsync(key, function()
			return payload
		end)
	end)
	PlayerDataService._saving[player.UserId] = false
	if not ok then
		warn("[Voidline] Save failed", player.Name, err)
	end
end

function PlayerDataService.Mutate(player: Player, mutator: (any) -> ())
	local data = PlayerDataService.Get(player)
	if not data then
		return
	end
	mutator(data)
	PlayerDataService.Replicate(player)
end

function PlayerDataService.HasPerk(player: Player, perkId: string): boolean
	local data = PlayerDataService.Get(player)
	if not data then
		return false
	end
	if data.OwnedPerks[perkId] then
		return true
	end
	local voucherExp = data.TrialVouchers[perkId]
	if voucherExp and voucherExp > os.time() then
		return true
	end
	return false
end

function PlayerDataService.Init()
	Remotes.Get("SettingsUpdate").OnServerEvent:Connect(function(player, patch)
		if typeof(patch) ~= "table" then
			return
		end
		PlayerDataService.Mutate(player, function(d)
			if typeof(patch.PerfMode) == "boolean" then
				d.Settings.PerfMode = patch.PerfMode
			end
			if typeof(patch.HideJetpack) == "boolean" then
				d.Settings.HideJetpack = patch.HideJetpack
			end
			if typeof(patch.ClipMode) == "boolean" then
				d.Settings.ClipMode = patch.ClipMode
			end
			if typeof(patch.LaserColor) == "string" then
				d.Settings.LaserColor = patch.LaserColor
			end
		end)
	end)

	Players.PlayerAdded:Connect(function(player)
		PlayerDataService.Load(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		PlayerDataService.Save(player)
		PlayerDataService._profiles[player.UserId] = nil
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(PlayerDataService.Load, player)
	end
	task.spawn(function()
		while true do
			task.wait(GameConfig.AutosaveSeconds)
			for _, player in Players:GetPlayers() do
				task.spawn(PlayerDataService.Save, player)
			end
		end
	end)
	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
			PlayerDataService.Save(player)
		end
	end)
end

return PlayerDataService
