--!strict
-- Shared hub / deep-space geometry (world space, Monolith at the origin).
local HubLayout = {}

HubLayout.HubSize = Vector3.new(96, 2, 96)
HubLayout.MonolithSize = Vector3.new(18, 72, 18)
HubLayout.MonolithCenter = Vector3.new(0, 37, 0)
HubLayout.VoidCore = Vector3.new(0, 40, 0)
HubLayout.RebirthPad = Vector3.new(21, 1.5, 0)
HubLayout.ForgePad = Vector3.new(-21, 1.5, 0)
HubLayout.CodeTerminal = Vector3.new(0, 6, 25)
HubLayout.SummonPad = Vector3.new(0, 1.5, -25)
HubLayout.VipLounge = Vector3.new(34, 1.5, 34)
HubLayout.Monument = Vector3.new(-34, 1, 34)
HubLayout.OverlookGate = Vector3.new(-34, 1.5, -34)
HubLayout.RiftGate = Vector3.new(34, 1.5, -34)
HubLayout.Spawn = Vector3.new(0, 1.5, 38)

-- Leaderboards sit on the hub rim, facing outward so the Monolith center
-- is not a wall of SurfaceGui text.
HubLayout.BoardRadius = 52
HubLayout.Boards = {
	{ Id = "TopCredits", Title = "TOP CREDITS", Angle = 15 },
	{ Id = "TopRebirths", Title = "TOP REBIRTHS", Angle = 105 },
	{ Id = "CodexDiscoveries", Title = "CODEX DISCOVERIES", Angle = 195 },
	{ Id = "TopSummoners", Title = "TOP SUMMONERS", Angle = 285 },
}

function HubLayout.BoardCFrame(angleDegrees: number): CFrame
	local a = math.rad(angleDegrees)
	local pos = Vector3.new(math.cos(a) * HubLayout.BoardRadius, 10, math.sin(a) * HubLayout.BoardRadius)
	local outward = Vector3.new(pos.X, 0, pos.Z)
	if outward.Magnitude < 0.01 then
		outward = Vector3.new(0, 0, 1)
	else
		outward = outward.Unit
	end
	return CFrame.lookAt(pos, pos + outward)
end

-- Shared deep-space rocks float in a ring just beyond the hub edge, in drone
-- range (42 studs) of a pilot standing at the hub rim.
HubLayout.SharedRockRadius = 64
HubLayout.SharedRockHeight = 16

function HubLayout.SharedRockSlot(slot: number, slots: number): Vector3
	local a = (slot - 0.5) / slots * math.pi * 2 + math.rad(15)
	return Vector3.new(
		math.cos(a) * HubLayout.SharedRockRadius,
		HubLayout.SharedRockHeight,
		math.sin(a) * HubLayout.SharedRockRadius
	)
end

-- Boss meteors hover above the hub so everyone on it can reach them.
function HubLayout.MeteorSlot(slot: number, slots: number): Vector3
	local a = (slot - 1) / math.max(1, slots) * math.pi * 2
	return Vector3.new(math.cos(a) * 30, 28, math.sin(a) * 30)
end

-- Deep-space zone: where anomaly hazards land and witnesses are counted.
HubLayout.ZoneRadius = 100

-- Void Rift parkour: a spiral of floating shards up the Monolith.
HubLayout.RiftPlatforms = 18
function HubLayout.RiftPlatform(i: number): Vector3
	local t = (i - 1) / (HubLayout.RiftPlatforms - 1)
	local a = math.rad(45) + t * math.pi * 3.5
	local radius = 22 - t * 6
	return Vector3.new(math.cos(a) * radius, 6 + t * 64, math.sin(a) * radius)
end
HubLayout.RiftCache = Vector3.new(0, 74.5, 0)

-- The quiet star overlook (cosmetic aura only).
HubLayout.Overlook = Vector3.new(180, 60, -180)

return HubLayout
