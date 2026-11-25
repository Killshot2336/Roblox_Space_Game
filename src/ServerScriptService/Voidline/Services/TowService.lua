--!strict
-- Gravity-Tether Towing. A tow is a server timeline written to the towed
-- part's attributes (start time on the server clock, duration, from, to).
-- The part stays anchored and is never moved or owned by a client on the
-- server; every client animates the same curve locally from those
-- attributes. Arrival (and its payout) happens on the server timer only.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local RockService = require(script.Parent.RockService)
local WorldState = require(script.Parent.WorldState)

local TowService = {}

export type TowSpec = {
	Player: Player,
	Part: BasePart,
	From: Vector3,
	To: Vector3,
	Duration: number,
	Ore: number?,
	OnArrive: () -> (),
}

local pendingOre: { [number]: number } = {}
local active = 0

function TowService.PendingOre(userId: number): number
	return pendingOre[userId] or 0
end

function TowService.ActiveCount(): number
	return active
end

function TowService.Start(spec: TowSpec)
	local part = spec.Part
	local userId = spec.Player.UserId
	local ore = spec.Ore or 0
	local duration = math.max(0.1, spec.Duration * WorldState.ZoneMult("SlowTow", spec.From, 1.5))
	part.CanCollide = false
	part.CanQuery = false
	part:SetAttribute("TowFrom", spec.From)
	part:SetAttribute("TowTo", spec.To)
	part:SetAttribute("TowDuration", duration)
	part:SetAttribute("TowOwner", userId)
	part:SetAttribute("TowStart", Workspace:GetServerTimeNow())
	pendingOre[userId] = (pendingOre[userId] or 0) + ore
	active += 1
	task.delay(duration, function()
		active -= 1
		pendingOre[userId] = math.max(0, (pendingOre[userId] or 0) - ore)
		if pendingOre[userId] == 0 then
			pendingOre[userId] = nil
		end
		RockService.ReleasePart(part)
		if spec.Player.Parent ~= Players then
			return
		end
		local ok, err = xpcall(spec.OnArrive :: () -> ...any, debug.traceback)
		if not ok then
			warn("[Voidline] tow arrival failed: " .. tostring(err))
		end
	end)
end

-- Tows a fresh chunk part (boss meteor / shared rock share) home.
function TowService.StartChunk(
	player: Player,
	oreId: string,
	from: Vector3,
	to: Vector3,
	duration: number,
	onArrive: () -> ()
)
	local chunk = RockService.Create({
		Kind = "Chunk",
		Position = from,
		Size = 2.4,
		OreId = oreId,
		Health = 1,
		OwnerUserId = player.UserId,
		Name = "TowedChunk",
	})
	RockService.Remove(chunk, true)
	chunk.Part:SetAttribute("Kind", "Chunk")
	TowService.Start({
		Player = player,
		Part = chunk.Part,
		From = from,
		To = to,
		Duration = duration,
		OnArrive = onArrive,
	})
end

function TowService.Init() end

return TowService
