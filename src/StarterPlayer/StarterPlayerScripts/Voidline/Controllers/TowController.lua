--!strict
-- Gravity-Tether tows: the server writes a timeline (start, duration, from,
-- to) on the towed part; every client flies the part along the same arc
-- locally. The server never moves it, so nothing here can affect payouts.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local TowController = {}

export type Tow = {
	Part: BasePart,
	Owner: number,
	From: Vector3,
	To: Vector3,
	Start: number,
	Duration: number,
	Position: Vector3,
	Alpha: number,
	Spin: number,
}

local TAG = "VoidRock"

local tows: { [BasePart]: Tow } = {}
local byOwner: { [number]: { Tow } } = {}
local arrivalCallbacks: { (Tow) -> () } = {}

local function readTow(part: BasePart): Tow?
	local start = part:GetAttribute("TowStart")
	local duration = part:GetAttribute("TowDuration")
	local from = part:GetAttribute("TowFrom")
	local to = part:GetAttribute("TowTo")
	local owner = part:GetAttribute("TowOwner")
	if
		type(start) ~= "number"
		or type(duration) ~= "number"
		or typeof(from) ~= "Vector3"
		or typeof(to) ~= "Vector3"
		or type(owner) ~= "number"
	then
		return nil
	end
	return {
		Part = part,
		Owner = owner,
		From = from :: Vector3,
		To = to :: Vector3,
		Start = start,
		Duration = math.max(0.1, duration),
		Position = from :: Vector3,
		Alpha = 0,
		Spin = (part:GetAttribute("RockId") or 0) :: number,
	}
end

local function refresh(part: BasePart)
	local tow = readTow(part)
	if tow then
		tows[part] = tow
	else
		tows[part] = nil
	end
end

local function watch(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	local part = instance :: BasePart
	part:GetAttributeChangedSignal("TowStart"):Connect(function()
		refresh(part)
	end)
	refresh(part)
end

-- Quadratic arc lifted above the straight line so tows read as "towed".
function TowController.Curve(from: Vector3, to: Vector3, alpha: number): Vector3
	local lift = math.min(18, (to - from).Magnitude * 0.25 + 4)
	local mid = (from + to) / 2 + Vector3.new(0, lift, 0)
	local a = from:Lerp(mid, alpha)
	local b = mid:Lerp(to, alpha)
	return a:Lerp(b, alpha)
end

function TowController.ForUser(userId: number): { Tow }
	return byOwner[userId] or {}
end

function TowController.OnArrive(callback: (Tow) -> ())
	table.insert(arrivalCallbacks, callback)
end

local function step()
	local now = Workspace:GetServerTimeNow()
	table.clear(byOwner)
	local parts: { BasePart } = {}
	local cframes: { CFrame } = {}
	for part, tow in tows do
		if not part.Parent then
			tows[part] = nil
			continue
		end
		local alpha = math.clamp((now - tow.Start) / tow.Duration, 0, 1)
		if alpha >= 1 and tow.Alpha < 1 then
			for _, callback in arrivalCallbacks do
				task.spawn(callback, tow)
			end
		end
		tow.Alpha = alpha
		local eased = alpha * alpha * (3 - 2 * alpha)
		tow.Position = TowController.Curve(tow.From, tow.To, eased)
		local list = byOwner[tow.Owner]
		if not list then
			list = {}
			byOwner[tow.Owner] = list
		end
		table.insert(list, tow)
		table.insert(parts, part)
		local spin = now * 1.5 + tow.Spin
		table.insert(cframes, CFrame.new(tow.Position) * CFrame.Angles(spin, spin * 0.7, 0))
	end
	if #parts > 0 then
		Workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

function TowController.Init()
	CollectionService:GetInstanceAddedSignal(TAG):Connect(watch)
	for _, part in CollectionService:GetTagged(TAG) do
		watch(part)
	end
	RunService.RenderStepped:Connect(step)
end

return TowController
