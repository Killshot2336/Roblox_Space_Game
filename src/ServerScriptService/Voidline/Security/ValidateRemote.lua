--!strict
-- Central remote validation: every client -> server remote is bound through
-- ValidateRemote.Bind so type checks, NaN/inf rejection, string limits,
-- numeric ranges, per-player token-bucket rate limits and the "profile is
-- loaded" gate are enforced in one place. Handlers only ever see clean args.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Voidline = ReplicatedStorage:WaitForChild("Voidline")
local Remotes = require(Voidline.Remotes)
local RateLimiter = require(Voidline.Modules.RateLimiter)

export type Spec = {
	Rate: number?, -- steady-state seconds between calls (default 0.25)
	Burst: number?, -- calls allowed back-to-back (default 3)
	Args: { string }?, -- "number" | "integer" | "string" | "boolean" | "table" | "any", "?" suffix = optional
	MaxString: number?, -- max bytes for string args (default 64)
	Range: { [number]: { number } }?, -- per-arg inclusive numeric range
	RequireCharacter: boolean?,
	SkipProfileGate: boolean?,
}

local ValidateRemote = {
	Rejections = {} :: { [number]: number },
	ProfileGate = nil :: ((Player) -> boolean)?,
	_limiters = {} :: { RateLimiter.RateLimiter },
}

local function isFiniteNumber(value: any): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end
ValidateRemote.IsFiniteNumber = isFiniteNumber

function ValidateRemote.CheckArg(value: any, kind: string, maxString: number?): boolean
	if string.sub(kind, -1) == "?" then
		if value == nil then
			return true
		end
		kind = string.sub(kind, 1, -2)
	end
	if kind == "number" then
		return isFiniteNumber(value)
	elseif kind == "integer" then
		return isFiniteNumber(value) and math.floor(value) == value
	elseif kind == "string" then
		return type(value) == "string" and #value <= (maxString or 64) and utf8.len(value) ~= nil
	elseif kind == "boolean" then
		return type(value) == "boolean"
	elseif kind == "table" then
		return type(value) == "table"
	elseif kind == "any" then
		return true
	end
	return false
end

local function reject(player: Player, remoteName: string, reason: string)
	local count = (ValidateRemote.Rejections[player.UserId] or 0) + 1
	ValidateRemote.Rejections[player.UserId] = count
	-- Log the first few and then every 100th so spammers cannot flood output.
	if count <= 3 or count % 100 == 0 then
		warn(("[Voidline] rejected %s from %s (%s) x%d"):format(remoteName, player.Name, reason, count))
	end
end

function ValidateRemote.RootPart(player: Player): BasePart?
	local character = player.Character
	if not character then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

function ValidateRemote.NearPosition(player: Player, position: Vector3, maxDistance: number): boolean
	local root = ValidateRemote.RootPart(player)
	if not root then
		return false
	end
	return (root.Position - position).Magnitude <= maxDistance
end

function ValidateRemote.NearPart(player: Player, part: BasePart?, maxDistance: number): boolean
	if not part then
		return false
	end
	-- Measure to the part's surface-ish envelope so large pads are fair.
	local slack = math.max(part.Size.X, part.Size.Z) * 0.5
	return ValidateRemote.NearPosition(player, part.Position, maxDistance + slack)
end

function ValidateRemote.AlivePlayer(player: Player?): boolean
	return player ~= nil and player.Parent ~= nil and player.Character ~= nil
end

function ValidateRemote.Bind(remoteName: string, spec: Spec, handler: (Player, ...any) -> ...any)
	local remote = Remotes.Get(remoteName)
	local limiter = RateLimiter.new(spec.Rate or 0.25, spec.Burst or 3)
	table.insert(ValidateRemote._limiters, limiter)
	local argKinds: { string } = spec.Args or {}
	local argCount = #argKinds
	remote.OnServerEvent:Connect(function(player: Player, ...: any)
		if not limiter:Allow(player.UserId) then
			reject(player, remoteName, "rate")
			return
		end
		if select("#", ...) > argCount then
			reject(player, remoteName, "extra args")
			return
		end
		local gate = ValidateRemote.ProfileGate
		if not spec.SkipProfileGate and gate and not gate(player) then
			return
		end
		if spec.RequireCharacter and not ValidateRemote.RootPart(player) then
			return
		end
		local args = table.pack(...)
		for i = 1, argCount do
			local kind = argKinds[i]
			local value = args[i]
			if not ValidateRemote.CheckArg(value, kind, spec.MaxString) then
				reject(player, remoteName, ("arg %d not %s"):format(i, kind))
				return
			end
			local range = spec.Range and spec.Range[i]
			if range and value ~= nil and (value < range[1] or value > range[2]) then
				reject(player, remoteName, ("arg %d out of range"):format(i))
				return
			end
		end
		local ok, err = pcall(handler, player, table.unpack(args, 1, argCount))
		if not ok then
			warn(("[Voidline] %s handler error for %s: %s"):format(remoteName, player.Name, tostring(err)))
		end
	end)
end

Players.PlayerRemoving:Connect(function(player)
	for _, limiter in ValidateRemote._limiters do
		limiter:Clear(player.UserId)
	end
	ValidateRemote.Rejections[player.UserId] = nil
end)

return ValidateRemote
