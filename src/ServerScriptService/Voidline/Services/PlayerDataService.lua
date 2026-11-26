--!strict
-- Session-locked player profiles.
--   * Load: UpdateAsync takes a lock {JobId, Time}. A live lock held by
--     another server is retried with backoff; the final attempt (or a lock
--     older than LOCK_STALE_SECONDS) takes the session over.
--   * Save: UpdateAsync only writes while this server still owns the lock, so
--     a server whose session was taken over can never overwrite newer data.
--   * Leave/BindToClose: final save releases the lock. A rejoin on the same
--     server waits for the in-flight release before loading.
--   * Replication: only changed keys are sent (DataSnapshot patches), at most
--     every FLUSH_INTERVAL seconds per player.
-- Studio without API access (or any DataStore outage at startup) degrades to
-- in-memory profiles that are never written.
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Voidline = ReplicatedStorage:WaitForChild("Voidline")
local GameConfig = require(Voidline.Config.GameConfig)
local DroneConfig = require(Voidline.Config.DroneConfig)
local ProfileSchema = require(Voidline.Modules.ProfileSchema)
local StoreRules = require(Voidline.Rules.StoreRules)
local EconomyRules = require(Voidline.Rules.EconomyRules)
local ContentIndex = require(Voidline.Content.ContentIndex)
local Remotes = require(Voidline.Remotes)

local ValidateRemote = require(script.Parent.Parent.Security.ValidateRemote)

local STORE_NAME = "VoidlinePlayer_v1"
local KEY_PREFIX = "p_"
local RECORD_SCHEMA = 2
local LOCK_STALE_SECONDS = 30 * 60
local LOAD_ATTEMPTS = 5
local SAVE_ATTEMPTS = 3
local FLUSH_INTERVAL = 0.15
local RELEASE_WAIT_SECONDS = 30
local REMOVED = ProfileSchema.REMOVED

-- Never replicated to the client.
local SERVER_ONLY = { ProcessedReceipts = true, PassGrants = true, RedeemedCodes = true }

local SERVER_ID = if game.JobId ~= "" then game.JobId else "studio-" .. HttpService:GenerateGUID(false)

export type Session = {
	Player: Player,
	UserId: number,
	Profile: any,
	LastSent: any,
	Dirty: boolean,
	Saving: boolean,
	SaveQueued: boolean,
	Persist: boolean,
	Stolen: boolean,
	GamePasses: { [string]: boolean },
	CodexCount: number,
	JoinedAt: number,
}

local PlayerDataService = {
	ServerId = SERVER_ID,
	InMemory = false,
	_sessions = {} :: { [number]: Session },
	_loading = {} :: { [number]: boolean },
	_releasing = {} :: { [number]: boolean },
	_onLoaded = {} :: { (Player, any) -> () },
	_onRelease = {} :: { (Player, any) -> () },
	_onSettings = {} :: { (Player, any) -> () },
	_store = nil :: any,
	-- Set by WorldEventService: server-wide credit boost (events, anomalies).
	CreditBoostProvider = function(): number
		return 1
	end,
}

local function getStore(): any
	if PlayerDataService._store or PlayerDataService.InMemory then
		return PlayerDataService._store
	end
	local ok, store = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok and store then
		PlayerDataService._store = store
		return store
	end
	PlayerDataService.InMemory = true
	warn("[Voidline] DataStore unavailable; profiles are in-memory this session: " .. tostring(store))
	return nil
end

local function toRecord(raw: any): any
	if type(raw) ~= "table" then
		return { Schema = RECORD_SCHEMA }
	end
	if raw.Schema == nil and raw.Data == nil then
		-- v1 stored the flat profile directly under the key.
		return { Schema = RECORD_SCHEMA, Data = raw }
	end
	return raw
end

local function lockHeldElsewhere(record: any, now: number): boolean
	local lock = record.Lock
	return type(lock) == "table"
		and lock.JobId ~= SERVER_ID
		and type(lock.Time) == "number"
		and now - lock.Time < LOCK_STALE_SECONDS
end

-- Returns "ok" | "locked" | "error" plus the stored profile data.
local function acquire(store: any, userId: number, force: boolean): (string, any)
	local status, data = "error", nil
	local ok, err = pcall(function()
		store:UpdateAsync(KEY_PREFIX .. userId, function(raw)
			local record = toRecord(raw)
			local now = os.time()
			if lockHeldElsewhere(record, now) and not force then
				status = "locked"
				return nil
			end
			if force and lockHeldElsewhere(record, now) then
				warn(("[Voidline] taking over session lock for %d from %s"):format(userId, tostring(record.Lock.JobId)))
			end
			record.Lock = { JobId = SERVER_ID, Time = now }
			record.Schema = RECORD_SCHEMA
			status = "ok"
			data = record.Data
			return record
		end)
	end)
	if not ok then
		warn("[Voidline] profile load error for " .. userId .. ": " .. tostring(err))
		return "error", nil
	end
	return status, data
end

local function writeRecord(store: any, userId: number, snapshot: any, release: boolean): (boolean, boolean)
	local stolen = false
	local ok, err = pcall(function()
		store:UpdateAsync(KEY_PREFIX .. userId, function(raw)
			local record = toRecord(raw)
			if type(record.Lock) == "table" and record.Lock.JobId ~= SERVER_ID then
				stolen = true
				return nil
			end
			local now = os.time()
			record.Schema = RECORD_SCHEMA
			record.Data = snapshot
			record.SavedAt = now
			record.Lock = if release then nil else { JobId = SERVER_ID, Time = now }
			return record
		end)
	end)
	if not ok then
		warn("[Voidline] profile save error for " .. userId .. ": " .. tostring(err))
	end
	return ok, stolen
end

-- Replication ---------------------------------------------------------------

local function isFlat(t: { [any]: any }): boolean
	if #t > 0 then
		return false
	end
	for _, v in t do
		if type(v) == "table" then
			return false
		end
	end
	return true
end

local function deepEqual(a: any, b: any): boolean
	if a == b then
		return true
	end
	if type(a) ~= "table" or type(b) ~= "table" then
		return false
	end
	for k, v in a do
		if not deepEqual(v, b[k]) then
			return false
		end
	end
	for k in b do
		if a[k] == nil then
			return false
		end
	end
	return true
end

local function clientCopy(profile: any): any
	local out = {}
	for key, value in profile do
		if not SERVER_ONLY[key] then
			out[key] = ProfileSchema.DeepCopy(value)
		end
	end
	return out
end

-- Builds a patch of changed keys and advances `lastSent` to match.
function PlayerDataService.Diff(profile: any, lastSent: any): (any?, any?)
	local set, sub = nil, nil
	for key, value in profile do
		if SERVER_ONLY[key] then
			continue
		end
		local old = lastSent[key]
		if type(value) == "table" and type(old) == "table" and isFlat(value) and isFlat(old) then
			local changes = nil
			for k, v in value do
				if old[k] ~= v then
					changes = changes or {}
					changes[k] = v
				end
			end
			for k in old do
				if value[k] == nil then
					changes = changes or {}
					changes[k] = REMOVED
				end
			end
			if changes then
				sub = sub or {}
				sub[key] = changes
				for k, v in changes do
					old[k] = if v == REMOVED then nil else v
				end
			end
		elseif not deepEqual(value, old) then
			set = set or {}
			set[key] = ProfileSchema.DeepCopy(value)
			lastSent[key] = ProfileSchema.DeepCopy(value)
		end
	end
	return set, sub
end
PlayerDataService.REMOVED = REMOVED

local function flush(session: Session)
	session.Dirty = false
	local set, sub = PlayerDataService.Diff(session.Profile, session.LastSent)
	if set or sub then
		Remotes.Get("DataSnapshot"):FireClient(session.Player, { Set = set, Sub = sub })
	end
end

-- Public API ------------------------------------------------------------------

function PlayerDataService.Session(player: Player): Session?
	return PlayerDataService._sessions[player.UserId]
end

function PlayerDataService.Get(player: Player): any?
	local session = PlayerDataService._sessions[player.UserId]
	return if session then session.Profile else nil
end

function PlayerDataService.IsLoaded(player: Player): boolean
	return PlayerDataService._sessions[player.UserId] ~= nil
end

function PlayerDataService.MarkDirty(player: Player)
	local session = PlayerDataService._sessions[player.UserId]
	if session then
		session.Dirty = true
	end
end

function PlayerDataService.Mutate(player: Player, mutator: (any) -> ()): boolean
	local session = PlayerDataService._sessions[player.UserId]
	if not session then
		return false
	end
	mutator(session.Profile)
	session.Dirty = true
	return true
end

function PlayerDataService.FlushNow(player: Player)
	local session = PlayerDataService._sessions[player.UserId]
	if session then
		flush(session)
	end
end

function PlayerDataService.OnLoaded(callback: (Player, any) -> ())
	table.insert(PlayerDataService._onLoaded, callback)
end

function PlayerDataService.OnRelease(callback: (Player, any) -> ())
	table.insert(PlayerDataService._onRelease, callback)
end

function PlayerDataService.OnSettingsChanged(callback: (Player, any) -> ())
	table.insert(PlayerDataService._onSettings, callback)
end

function PlayerDataService.SetGamePass(player: Player, passId: string, owned: boolean)
	local session = PlayerDataService._sessions[player.UserId]
	if session then
		session.GamePasses[passId] = owned
	end
end

function PlayerDataService.Perks(player: Player): { [string]: boolean }
	local session = PlayerDataService._sessions[player.UserId]
	if not session then
		return {}
	end
	return StoreRules.EffectivePerks(session.Profile, os.time(), session.GamePasses)
end

function PlayerDataService.HasPerk(player: Player, perkId: string): boolean
	return PlayerDataService.Perks(player)[perkId] == true
end

function PlayerDataService.SetCodexCount(player: Player, count: number)
	local session = PlayerDataService._sessions[player.UserId]
	if session then
		session.CodexCount = count
	end
end

-- Rules context. During onboarding world/codex boosts are ignored so the
-- tutorial rewards stay exactly 10 ore -> 30 Credits.
function PlayerDataService.Ctx(player: Player): EconomyRules.Ctx
	local session = PlayerDataService._sessions[player.UserId]
	if not session then
		return { Perks = {} }
	end
	local perks = StoreRules.EffectivePerks(session.Profile, os.time(), session.GamePasses)
	if not session.Profile.TutorialComplete then
		return { Perks = perks, CreditBoost = 1, CodexMult = 1 }
	end
	return {
		Perks = perks,
		CreditBoost = PlayerDataService.CreditBoostProvider(),
		CodexMult = ContentIndex.CodexMultiplier(session.CodexCount),
	}
end

local function saveSession(session: Session, release: boolean?, waitForInFlight: boolean?): boolean
	if session.Stolen then
		return false
	end
	if not session.Persist then
		return true
	end
	if session.Saving then
		if not release and not waitForInFlight then
			session.SaveQueued = true
			return false
		end
		local waited = 0
		while session.Saving and waited < RELEASE_WAIT_SECONDS do
			task.wait(0.1)
			waited += 0.1
		end
	end
	session.Saving = true
	session.SaveQueued = false
	local snapshot = ProfileSchema.DeepCopy(session.Profile)
	snapshot.LastSeen = os.time()
	local saved = false
	for attempt = 1, SAVE_ATTEMPTS do
		local ok, stolen = writeRecord(PlayerDataService._store, session.UserId, snapshot, release == true)
		if ok then
			if stolen then
				session.Stolen = true
				warn(("[Voidline] session for %d is owned by another server; not saving here"):format(session.UserId))
			end
			saved = not stolen
			break
		end
		if attempt < SAVE_ATTEMPTS then
			task.wait(2 ^ (attempt - 1))
		end
	end
	session.Saving = false
	if session.SaveQueued and not release and not session.Stolen then
		task.spawn(saveSession, session)
	end
	return saved
end

-- Saves the profile. `release` drops the session lock (leave/shutdown).
function PlayerDataService.Save(player: Player, release: boolean?): boolean
	local session = PlayerDataService._sessions[player.UserId]
	if not session then
		return false
	end
	return saveSession(session, release)
end

-- Saves and reports whether *this* state reached the DataStore, waiting
-- for an in-flight autosave first (purchases need a definite answer).
function PlayerDataService.SaveNow(player: Player): boolean
	local session = PlayerDataService._sessions[player.UserId]
	if not session then
		return false
	end
	return saveSession(session, false, true)
end

local function runCallbacks(list: { (Player, any) -> () }, player: Player, profile: any)
	for _, callback in list do
		local ok, err = xpcall(callback :: (Player, any) -> ...any, debug.traceback, player, profile)
		if not ok then
			warn("[Voidline] profile callback error: " .. tostring(err))
		end
	end
end

local loadInto: (Player) -> ()

function PlayerDataService.Load(player: Player)
	local userId = player.UserId
	if PlayerDataService._sessions[userId] or PlayerDataService._loading[userId] then
		return
	end
	PlayerDataService._loading[userId] = true
	local ok, err = xpcall(loadInto :: (Player) -> ...any, debug.traceback, player)
	PlayerDataService._loading[userId] = nil
	if not ok then
		warn("[Voidline] profile load crashed for " .. userId .. ": " .. tostring(err))
	end
end

function loadInto(player: Player)
	local userId = player.UserId
	local waited = 0
	while PlayerDataService._releasing[userId] and waited < RELEASE_WAIT_SECONDS do
		task.wait(0.25)
		waited += 0.25
	end

	local store = getStore()
	local data, persist = nil, false
	if store then
		local status = "error"
		for attempt = 1, LOAD_ATTEMPTS do
			local value
			status, value = acquire(store, userId, attempt == LOAD_ATTEMPTS)
			if status == "ok" then
				data, persist = value, true
				break
			end
			if player.Parent == nil then
				return
			end
			task.wait(math.min(2 ^ (attempt - 1), 8))
		end
		if not persist then
			if RunService:IsStudio() then
				warn("[Voidline] profile load failed in Studio; using an unsaved profile")
			else
				player:Kick("Voidline could not load your save right now. Please rejoin in a minute.")
				return
			end
		end
	end

	if player.Parent == nil then
		-- Left while loading: hand the lock straight back.
		if persist then
			writeRecord(store, userId, data, true)
		end
		return
	end

	local profile = ProfileSchema.Migrate(data)
	local now = os.time()
	if profile.FirstJoin == 0 then
		profile.FirstJoin = now
	end
	local codexCount = 0
	for _ in profile.Codex do
		codexCount += 1
	end
	local session: Session = {
		Player = player,
		UserId = userId,
		Profile = profile,
		LastSent = clientCopy(profile),
		Dirty = false,
		Saving = false,
		SaveQueued = false,
		Persist = persist,
		Stolen = false,
		GamePasses = {},
		CodexCount = codexCount,
		JoinedAt = now,
	}
	PlayerDataService._sessions[userId] = session
	Remotes.Get("DataSnapshot"):FireClient(player, { Full = true, Data = session.LastSent })
	player:SetAttribute("ProfileLoaded", true)
	runCallbacks(PlayerDataService._onLoaded, player, profile)
end

-- Final save + lock release. Safe to call from both PlayerRemoving and
-- BindToClose: the second caller waits for the first to finish.
function PlayerDataService.Release(player: Player)
	local userId = player.UserId
	if PlayerDataService._releasing[userId] then
		local waited = 0
		while PlayerDataService._releasing[userId] and waited < RELEASE_WAIT_SECONDS do
			task.wait(0.1)
			waited += 0.1
		end
		return
	end
	local session = PlayerDataService._sessions[userId]
	if not session then
		return
	end
	PlayerDataService._releasing[userId] = true
	runCallbacks(PlayerDataService._onRelease, player, session.Profile)
	-- Drop the session first so no gameplay or receipt touches it mid-save.
	PlayerDataService._sessions[userId] = nil
	saveSession(session, true)
	PlayerDataService._releasing[userId] = nil
end

local function applySettings(profile: any, patch: { [string]: any })
	local settings = profile.Settings
	for _, key in { "PerfMode", "HideJetpack", "ClipMode", "ReducedMotion" } do
		if type(patch[key]) == "boolean" then
			settings[key] = patch[key]
		end
	end
	for _, key in { "MusicVolume", "SfxVolume" } do
		local value = patch[key]
		if ValidateRemote.IsFiniteNumber(value) then
			settings[key] = math.clamp(value, 0, 1)
		end
	end
	if type(patch.LaserColor) == "string" and DroneConfig.LaserColors[patch.LaserColor] then
		settings.LaserColor = patch.LaserColor
	end
end

function PlayerDataService.Init()
	ValidateRemote.ProfileGate = PlayerDataService.IsLoaded

	ValidateRemote.Bind("SettingsUpdate", { Rate = 0.2, Burst = 6, Args = { "table" } }, function(player, patch)
		local applied = PlayerDataService.Mutate(player, function(profile)
			applySettings(profile, patch)
		end)
		if applied then
			runCallbacks(PlayerDataService._onSettings, player, PlayerDataService.Get(player))
		end
	end)

	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < FLUSH_INTERVAL then
			return
		end
		accumulator = 0
		for _, session in PlayerDataService._sessions do
			if session.Dirty then
				flush(session)
			end
		end
	end)

	task.spawn(function()
		while true do
			task.wait(GameConfig.AutosaveSeconds)
			local sessions = {}
			for _, session in PlayerDataService._sessions do
				table.insert(sessions, session)
			end
			-- Spread saves across the interval instead of bursting the budget.
			local gap = math.min(2, GameConfig.AutosaveSeconds / math.max(1, #sessions) * 0.5)
			for _, session in sessions do
				if session.Player.Parent and PlayerDataService._sessions[session.UserId] == session then
					local okBudget, budget = pcall(function()
						return DataStoreService:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.UpdateAsync)
					end)
					if not okBudget or budget > 2 then
						task.spawn(saveSession, session)
					end
					task.wait(gap)
				end
			end
		end
	end)

	game:BindToClose(function()
		local pending = 0
		for _, player in Players:GetPlayers() do
			if PlayerDataService._sessions[player.UserId] then
				pending += 1
				task.spawn(function()
					PlayerDataService.Release(player)
					pending -= 1
				end)
			end
		end
		local waited = 0
		while (pending > 0 or next(PlayerDataService._releasing) ~= nil) and waited < 28 do
			waited += task.wait(0.1)
		end
	end)
end

-- Starts loading profiles. Boot calls this after every service has
-- registered its OnLoaded callbacks (in-memory loads finish instantly).
function PlayerDataService.Start()
	Players.PlayerAdded:Connect(PlayerDataService.Load)
	Players.PlayerRemoving:Connect(PlayerDataService.Release)
	for _, player in Players:GetPlayers() do
		task.spawn(PlayerDataService.Load, player)
	end
end

return PlayerDataService
