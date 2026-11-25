--!strict
-- Shared plot geometry: 12 plots on a ring facing the hub. Local plot space:
-- +Y up, -Z toward the hub (Monolith). MapBuilder builds from these offsets,
-- server services validate distances with them and clients aim beams at them.
local GameConfig = require(script.Parent.Parent.Config.GameConfig)

local PlotLayout = {}

PlotLayout.BaseSize = Vector3.new(60, 2, 60)
PlotLayout.SurfaceY = 2
PlotLayout.Spawn = Vector3.new(0, 2.6, 8)
PlotLayout.Refinery = Vector3.new(-12, 2.2, -1)
PlotLayout.RefinerySize = Vector3.new(10, 1, 10)
PlotLayout.RefineryTower = Vector3.new(-12, 8, 9)
PlotLayout.Grinder = Vector3.new(13, 7, 6)
PlotLayout.LaserTuner = Vector3.new(-23, 2.2, 15)
PlotLayout.BridgeStart = Vector3.new(0, 1.6, -30)
PlotLayout.BridgeSegments = 12
PlotLayout.PadSize = Vector3.new(8, 1, 8)

-- Upgrade pads in a row toward the hub, in Quick-Upgrade order.
PlotLayout.Pads = {
	Drill = Vector3.new(-20, 2.2, -15),
	Cargo = Vector3.new(-10, 2.2, -15),
	DroneSlot = Vector3.new(0, 2.2, -15),
	StationTier = Vector3.new(10, 2.2, -15),
	DroneTier = Vector3.new(20, 2.2, -15),
} :: { [string]: Vector3 }

-- Relic pedestals along the back edge, centre outwards.
PlotLayout.PedestalCount = 11
function PlotLayout.Pedestal(slot: number): Vector3
	local offset = math.ceil((slot - 1) / 2) * (if slot % 2 == 0 then 4 else -4)
	return Vector3.new(offset, 3, 25)
end

-- Citadel structure anchors around the plot edge (back and sides).
PlotLayout.CitadelAnchors = {
	Vector3.new(-26, 2, 26),
	Vector3.new(26, 2, 26),
	Vector3.new(-26, 2, 10),
	Vector3.new(26, 2, 10),
	Vector3.new(-26, 2, -4),
	Vector3.new(26, 2, -4),
	Vector3.new(-14, 2, 20),
	Vector3.new(14, 2, 20),
	Vector3.new(-26, 2, -24),
	Vector3.new(26, 2, -24),
}

-- Belt rocks: a ring behind and beside the plot, never over the bridge.
PlotLayout.BeltRadius = 38
PlotLayout.BeltHeight = 12

function PlotLayout.PlotCFrame(index: number): CFrame
	local angle = ((index - 1) / GameConfig.PlotCount) * math.pi * 2
	local center =
		Vector3.new(math.cos(angle) * GameConfig.PlotRingRadius, 0, math.sin(angle) * GameConfig.PlotRingRadius)
	return CFrame.lookAt(center, Vector3.new(0, 0, 0))
end

function PlotLayout.World(index: number, localOffset: Vector3): Vector3
	return PlotLayout.PlotCFrame(index):PointToWorldSpace(localOffset)
end

-- Belt slot position. Slots spread over 240 degrees behind the plot.
function PlotLayout.BeltSlot(index: number, slot: number, slots: number, wobble: number?): Vector3
	local t = if slots > 1 then (slot - 1) / (slots - 1) else 0.5
	local angle = math.rad(60 + 240 * t)
	local radius = PlotLayout.BeltRadius + (wobble or 0)
	-- Local angle 0 points at the hub (-Z); sweep around the back.
	local localPos =
		Vector3.new(math.sin(angle) * radius, PlotLayout.BeltHeight + (wobble or 0) * 0.5, -math.cos(angle) * radius)
	return PlotLayout.World(index, localPos)
end

-- Where the bridge meets the hub ring.
function PlotLayout.BridgeEnd(index: number): Vector3
	local cf = PlotLayout.PlotCFrame(index)
	local outward = Vector3.new(cf.Position.X, 0, cf.Position.Z).Unit
	return outward * (GameConfig.HubRadius - 1) + Vector3.new(0, 1.6, 0)
end

return PlotLayout
