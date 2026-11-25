--!nocheck
-- Headless Roblox harness for Lune.
--
-- Builds a fake DataModel from Rojo's sourcemap.json so game code can use
-- `script.Parent.X`, `ReplicatedStorage:WaitForChild("Voidline")` and
-- `require(instance)` exactly as it does in Roblox. Each World is isolated
-- (own module cache, own clock, own fake services).

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local serde = require("@lune/serde")
local roblox = require("@lune/roblox")

local FakeInstance = require("./FakeInstance")
local FakeServices = require("./FakeServices")
local Scheduler = require("./Scheduler")
local Signal = require("./Signal")

local props = FakeInstance.props
local IS_FAKE = FakeInstance.IS_FAKE

local Harness = {}

local World = {}
World.__index = World

local DATATYPES = {
	"Axes",
	"BrickColor",
	"CFrame",
	"Color3",
	"ColorSequence",
	"ColorSequenceKeypoint",
	"Enum",
	"Faces",
	"Font",
	"NumberRange",
	"NumberSequence",
	"NumberSequenceKeypoint",
	"PhysicalProperties",
	"Ray",
	"Rect",
	"Region3",
	"UDim",
	"UDim2",
	"Vector2",
	"Vector2int16",
	"Vector3",
	"Vector3int16",
}

local SOURCEMAP_CACHE = {}

local function readSourcemap(path)
	if SOURCEMAP_CACHE[path] then
		return SOURCEMAP_CACHE[path]
	end
	if not fs.isFile(path) then
		error(("sourcemap not found at %s; run `rojo sourcemap default.project.json -o sourcemap.json`"):format(path))
	end
	local decoded = serde.decode("json", fs.readFile(path))
	SOURCEMAP_CACHE[path] = decoded
	return decoded
end

local SOURCE_CACHE = {}
local function readSource(path)
	local cached = SOURCE_CACHE[path]
	if cached then
		return cached
	end
	local source = fs.readFile(path)
	SOURCE_CACHE[path] = source
	return source
end

local function pickScriptPath(filePaths)
	if not filePaths then
		return nil
	end
	for _, p in filePaths do
		if string.match(p, "%.luau?$") then
			return p
		end
	end
	return nil
end

-- Simple deterministic stand-in for Roblox's Random (sequence differs from
-- Roblox's PCG; game content must use the shared Voidline PRNG instead).
local function makeRandomLib()
	local RandomMT = {}
	RandomMT.__index = RandomMT
	local function nextState(self)
		-- xorshift32
		local x = self._s
		x = bit32.bxor(x, bit32.lshift(x, 13))
		x = bit32.bxor(x, bit32.rshift(x, 17))
		x = bit32.bxor(x, bit32.lshift(x, 5))
		self._s = x
		return x
	end
	function RandomMT:NextNumber(min, max)
		local u = nextState(self) / 4294967296
		if min == nil then
			return u
		end
		return min + (max - min) * u
	end
	function RandomMT:NextInteger(min, max)
		local u = nextState(self) / 4294967296
		return min + math.floor(u * (max - min + 1))
	end
	function RandomMT:Clone()
		return setmetatable({ _s = self._s }, RandomMT)
	end
	function RandomMT:Shuffle(t)
		for i = #t, 2, -1 do
			local j = self:NextInteger(1, i)
			t[i], t[j] = t[j], t[i]
		end
	end
	function RandomMT:NextUnitVector()
		local v = roblox.Vector3.new(self:NextNumber(-1, 1), self:NextNumber(-1, 1), self:NextNumber(-1, 1))
		if v.Magnitude < 1e-6 then
			return roblox.Vector3.new(0, 1, 0)
		end
		return v.Unit
	end
	return {
		new = function(seed)
			local s = math.floor(seed or 1) % 4294967296
			if s == 0 then
				s = 2463534242
			end
			return setmetatable({ _s = s }, RandomMT)
		end,
	}
end

function Harness.new(options)
	options = options or {}
	local self = setmetatable({}, World)
	self.context = options.context or "server"
	self.isStudio = options.isStudio ~= false
	self.scheduler = Scheduler.new(options.epoch)
	self.sourcemapPath = options.sourcemap or "sourcemap.json"
	self.echo = options.echo == true
	self.modules = {}
	self.loading = {}
	self.prints = {}
	self.warnings = {}
	self.remoteLog = {}
	self.prompts = {}
	self.badges = {}
	self.analytics = {}
	self.tagged = {}
	self.renderSteps = {}
	self.bindToClose = {}
	self.dataStoreData = {}
	self.dataStoreFailures = {}
	self.dataStoreCalls = 0
	self.dataStoreBudget = options.dataStoreBudget or 100
	self.dataStoresDisabled = options.dataStoresDisabled == true
	self.ownedGamePasses = {}
	self.paidRandomRestricted = {}
	self.guidCounter = 0
	self.tweenCount = 0
	self.instancesCreated = 0
	self.touchEnabled = options.touchEnabled == true
	self.jobId = options.jobId or "test-job-1"
	self.kicks = {}

	self.onInstanceCreated = function()
		self.instancesCreated += 1
	end
	self.onKick = function(player, message)
		table.insert(self.kicks, { player = player, message = message })
	end
	self.onFireClient = function(remote, player, args)
		table.insert(self.remoteLog, { remote = props(remote).Name, player = player, args = args })
	end
	self.onFireAllClients = function(remote, args)
		local players = self:service("Players"):GetPlayers()
		for _, player in players do
			table.insert(
				self.remoteLog,
				{ remote = props(remote).Name, player = player, args = args, broadcast = true }
			)
		end
		if #players == 0 then
			table.insert(self.remoteLog, { remote = props(remote).Name, player = nil, args = args, broadcast = true })
		end
	end

	self:_buildDataModel()
	self:_buildEnvironmentPrototype()

	local runService = self:service("RunService")
	self.scheduler.onStep = function(dt)
		local w = self
		props(runService).Stepped:Fire(w.scheduler.now, dt)
		props(runService).PreSimulation:Fire(dt)
		props(runService).Heartbeat:Fire(dt)
		props(runService).PostSimulation:Fire(dt)
		if w.context == "client" then
			props(runService).RenderStepped:Fire(dt)
			props(runService).PreRender:Fire(dt)
			for _, fn in w.renderSteps do
				fn(dt)
			end
		end
	end
	return self
end

function World:_buildDataModel()
	local game = FakeInstance.new(self, "DataModel", "Game")
	self.game = game
	props(game).JobId = self.jobId
	props(game).PlaceId = 0
	props(game).PlaceVersion = 0
	props(game).GameId = 0
	props(game).CreatorId = 0
	props(game).PrivateServerId = ""
	local world = self
	props(game).GetService = function(dm, name)
		return world:service(name, dm)
	end
	props(game).FindService = function(_, name)
		for _, child in FakeInstance.children(game) do
			if props(child).ClassName == name then
				return child
			end
		end
		return nil
	end
	props(game).BindToClose = function(_, fn)
		table.insert(world.bindToClose, fn)
	end
	props(game).IsLoaded = function()
		return true
	end
	props(game).Loaded = Signal.new(self.scheduler)

	local map = readSourcemap(self.sourcemapPath)
	local function build(node, parent)
		local inst
		if node.className == "DataModel" then
			inst = game
		else
			inst = FakeInstance.new(self, node.className, node.name)
			local scriptPath = pickScriptPath(node.filePaths)
			if scriptPath then
				rawset(inst, "_filePath", scriptPath)
			end
			if parent == game then
				local factory = FakeServices[node.className]
				if factory then
					factory(self, inst)
				end
			end
			FakeInstance.MT.__newindex(inst, "Parent", parent)
		end
		for _, child in node.children or {} do
			build(child, inst)
		end
		return inst
	end
	build(map, nil)
end

function World:service(name, _dm)
	local game = self.game
	for _, child in FakeInstance.children(game) do
		if props(child).ClassName == name then
			return child
		end
	end
	local node = FakeInstance.new(self, name, name)
	local factory = FakeServices[name]
	if factory then
		factory(self, node)
	end
	FakeInstance.MT.__newindex(node, "Parent", game)
	return node
end

function World:_typeof(value)
	if type(value) == "table" then
		if IS_FAKE[value] then
			return "Instance"
		end
		local mt = getmetatable(value)
		if mt == Signal then
			return "RBXScriptSignal"
		end
		if rawget(value, "__tweeninfo") then
			return "TweenInfo"
		end
	end
	return typeof(value)
end

function World:_buildEnvironmentPrototype()
	local world = self
	local proto = {}
	for _, name in DATATYPES do
		proto[name] = roblox[name]
	end
	proto.Random = makeRandomLib()
	proto.TweenInfo = {
		new = function(time, style, direction, repeatCount, reverses, delayTime)
			return {
				__tweeninfo = true,
				Time = time or 1,
				EasingStyle = style,
				EasingDirection = direction,
				RepeatCount = repeatCount or 0,
				Reverses = reverses or false,
				DelayTime = delayTime or 0,
			}
		end,
	}
	proto.DateTime = {
		now = function()
			local ms = math.floor((world.scheduler.epoch + world.scheduler.now) * 1000)
			return { UnixTimestamp = math.floor(ms / 1000), UnixTimestampMillis = ms }
		end,
	}
	proto.Instance = {
		new = function(className, parent)
			local inst = FakeInstance.new(world, className, className)
			if className == "RemoteEvent" or className == "UnreliableRemoteEvent" then
				-- created lazily via SIGNAL_NAMES
			end
			if parent then
				inst.Parent = parent
			end
			return inst
		end,
	}
	proto.typeof = function(value)
		return world:_typeof(value)
	end
	proto.task = self.scheduler:taskLibrary()
	proto.os = self.scheduler:osLibrary()
	proto.tick = function()
		return world.scheduler.epoch + world.scheduler.now
	end
	proto.time = function()
		return world.scheduler.now
	end
	proto.elapsedTime = proto.time
	proto.wait = function(t)
		return world.scheduler:wait(t)
	end
	proto.delay = function(t, fn)
		return world.scheduler:delay(t, fn)
	end
	proto.spawn = function(fn)
		return world.scheduler:defer(fn)
	end
	proto.print = function(...)
		local parts = table.pack(...)
		for i = 1, parts.n do
			parts[i] = tostring(parts[i])
		end
		local line = table.concat(parts, " ", 1, parts.n)
		table.insert(world.prints, line)
		if world.echo then
			print("[game] " .. line)
		end
	end
	proto.warn = function(...)
		local parts = table.pack(...)
		for i = 1, parts.n do
			parts[i] = tostring(parts[i])
		end
		local line = table.concat(parts, " ", 1, parts.n)
		table.insert(world.warnings, line)
		if world.echo then
			print("[game:warn] " .. line)
		end
	end
	proto.shared = {}
	self.envPrototype = proto
end

function World:_makeEnvironment(scriptInstance)
	local env = table.clone(self.envPrototype)
	env.script = scriptInstance
	env.game = self.game
	env.workspace = self:service("Workspace")
	env.Workspace = env.workspace
	env.require = function(target)
		return self:requireInstance(target, scriptInstance)
	end
	env._G = env
	return env
end

function World:requireInstance(target, requiredBy)
	if not IS_FAKE[target] then
		error(("require() expects a ModuleScript instance, got %s"):format(typeof(target)), 3)
	end
	if props(target).ClassName ~= "ModuleScript" then
		error(
			("require() target %s is a %s, not a ModuleScript"):format(target:GetFullName(), props(target).ClassName),
			3
		)
	end
	local cached = self.modules[target]
	if cached then
		return cached.value
	end
	if self.loading[target] then
		error(
			("Requested module was required recursively: %s (from %s)"):format(
				target:GetFullName(),
				requiredBy and requiredBy:GetFullName() or "?"
			),
			3
		)
	end
	local path = rawget(target, "_filePath")
	if not path then
		error(("ModuleScript %s has no source file"):format(target:GetFullName()), 3)
	end
	self.loading[target] = true
	local source = readSource(path)
	local ok, chunk = pcall(luau.load, source, { debugName = path, environment = self:_makeEnvironment(target) })
	if not ok then
		self.loading[target] = nil
		error(("failed to compile %s: %s"):format(path, tostring(chunk)), 3)
	end
	local results = table.pack(chunk())
	self.loading[target] = nil
	if results.n ~= 1 then
		error(("Module code did not return exactly one value: %s (returned %d)"):format(path, results.n), 3)
	end
	self.modules[target] = { value = results[1] }
	return results[1]
end

-- Resolve "ReplicatedStorage/Voidline/Modules/RateLimiter" to an instance.
function World:find(path)
	local current = self.game
	for segment in string.gmatch(path, "[^/]+") do
		local nextNode = current:FindFirstChild(segment)
		if not nextNode then
			if current == self.game then
				nextNode = self:service(segment)
			else
				error(("path segment %q not found in %s"):format(segment, path), 2)
			end
		end
		current = nextNode
	end
	return current
end

function World:require(path)
	return self:requireInstance(self:find(path), nil)
end

-- Run a Script/LocalScript source file (e.g. Boot.server.lua) in the world.
function World:runScript(path)
	local inst = self:find(path)
	local file = rawget(inst, "_filePath")
	assert(file, "no file for script " .. path)
	local chunk = luau.load(readSource(file), { debugName = file, environment = self:_makeEnvironment(inst) })
	self.scheduler:spawn(chunk)
	self:assertNoErrors()
end

-- Run a function inside a scheduler coroutine so it may yield.
function World:run(fn, ...)
	local thread = self.scheduler:spawn(fn, ...)
	return thread
end

function World:advance(seconds, step)
	self.scheduler:advance(seconds, step)
end

function World:assertNoErrors()
	if #self.scheduler.errors > 0 then
		local first = self.scheduler.errors[1]
		self.scheduler.errors = {}
		error("error inside scheduled game thread:\n" .. first, 2)
	end
end

function World:close()
	for _, fn in self.bindToClose do
		self.scheduler:spawn(fn)
	end
end

function World:newInstance(className, name)
	return FakeInstance.new(self, className, name or className)
end

-- Players ----------------------------------------------------------------------
function World:spawnCharacter(player, position)
	local character = FakeInstance.new(self, "Model", props(player).Name)
	local root = FakeInstance.new(self, "Part", "HumanoidRootPart")
	root.CFrame = roblox.CFrame.new(position or roblox.Vector3.new(0, 5, 0))
	root.Parent = character
	local humanoid = FakeInstance.new(self, "Humanoid", "Humanoid")
	humanoid.Parent = character
	character.PrimaryPart = root
	character.Parent = self:service("Workspace")
	player.Character = character
	player.CharacterAdded:Fire(character)
	return character
end

function World:addPlayer(userId, name, options)
	options = options or {}
	local player = FakeInstance.new(self, "Player", name or ("Pilot" .. tostring(userId)))
	props(player).UserId = userId
	props(player).DisplayName = options.displayName or props(player).Name
	props(player).AccountAge = options.accountAge or 30
	props(player).MembershipType = roblox.Enum.MembershipType.None
	props(player).LocaleId = "en-us"
	local world = self
	self.onLoadCharacter = function(p)
		world:spawnCharacter(p)
	end
	player.Parent = self:service("Players")
	props(self:service("Players")).PlayerAdded:Fire(player)
	if options.character ~= false then
		self:spawnCharacter(player, options.position)
	end
	return player
end

function World:removePlayer(player)
	props(self:service("Players")).PlayerRemoving:Fire(player)
	player.Parent = nil
end

-- Simulate a client firing a RemoteEvent at the server.
function World:fireServer(remote, player, ...)
	if type(remote) == "string" then
		remote = self:findRemote(remote)
	end
	assert(remote, "remote not found")
	remote.OnServerEvent:Fire(player, ...)
end

function World:findRemote(name)
	for _, d in self.game:GetDescendants() do
		local className = props(d).ClassName
		if (className == "RemoteEvent" or className == "UnreliableRemoteEvent") and props(d).Name == name then
			return d
		end
	end
	return nil
end

function World:clientEvents(player, remoteName)
	local out = {}
	for _, entry in self.remoteLog do
		if (player == nil or entry.player == player) and (remoteName == nil or entry.remote == remoteName) then
			table.insert(out, entry.args)
		end
	end
	return out
end

function World:clearRemoteLog()
	self.remoteLog = {}
end

Harness.World = World
Harness.FakeInstance = FakeInstance
Harness.roblox = roblox

return Harness
