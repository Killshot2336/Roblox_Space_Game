--!strict
-- Every mineable target: personal belt rocks, shared deep-space rocks, boss
-- meteors and event cores. Rocks are anchored server parts (never
-- client-owned physics). Health and contributions live here; DroneService
-- deals damage, the owning service decides what a break pays.
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Voidline = ReplicatedStorage:WaitForChild("Voidline")
local OreRegistry = require(Voidline.Content.OreRegistry)

local RockService = {}

export type Rock = {
	Id: number,
	Kind: string, -- "Belt" | "Shared" | "Meteor" | "Core"
	Part: BasePart,
	Position: Vector3,
	Health: number,
	MaxHealth: number,
	OreId: string,
	Ore: number,
	Shards: number,
	OwnerUserId: number, -- 0 = anyone may mine it
	Reach: number,
	Priority: number,
	Damage: { [number]: number },
	Alive: boolean,
	SentHealth: number,
	OnBreak: ((Rock, Player?) -> ())?,
	Data: { [string]: any },
}

export type Spec = {
	Kind: string,
	Position: Vector3,
	Size: number,
	OreId: string,
	Health: number,
	Ore: number?,
	Shards: number?,
	OwnerUserId: number?,
	Reach: number?,
	Priority: number?,
	OnBreak: ((Rock, Player?) -> ())?,
	Data: { [string]: any }?,
	Name: string?,
}

local TAG = "VoidRock"
local HIDDEN_CFRAME = CFrame.new(0, 4000, 0)

local rocks: { [number]: Rock } = {}
local nextId = 0
local pool: { BasePart } = {}
local folder: Folder? = nil

local function getFolder(): Folder
	if folder and folder.Parent then
		return folder
	end
	local f = Instance.new("Folder")
	f.Name = "Rocks"
	f.Parent = Workspace
	folder = f
	return f
end

local function acquirePart(): BasePart
	local part = table.remove(pool)
	if part and part.Parent then
		return part
	end
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanTouch = false
	p.CastShadow = false
	p.Shape = Enum.PartType.Ball
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CFrame = HIDDEN_CFRAME
	p.Parent = getFolder()
	CollectionService:AddTag(p, TAG)
	return p
end

function RockService.ReleasePart(part: BasePart)
	for _, name in { "RockId", "Kind", "OreId", "Health", "MaxHealth", "Owner", "Hidden" } do
		part:SetAttribute(name, nil)
	end
	for _, name in { "TowStart", "TowDuration", "TowFrom", "TowTo", "TowOwner" } do
		part:SetAttribute(name, nil)
	end
	part:SetAttribute("Hidden", true)
	part.Transparency = 1
	part.CanCollide = false
	part.CanQuery = false
	part.CFrame = HIDDEN_CFRAME
	table.insert(pool, part)
end

-- Paints a part as an ore variant (also used for towed chunks).
function RockService.Paint(part: BasePart, oreId: string, size: number)
	local ore = OreRegistry.ById[oreId] or OreRegistry.ById[OreRegistry.TutorialOreId]
	part.Size = Vector3.new(size, size, size)
	part.Color = ore.Color
	part.Material = ore.Material
	part.Transparency = 0
	part.CanQuery = true
	part:SetAttribute("OreId", ore.Id)
	part:SetAttribute("Hidden", nil)
end

function RockService.Create(spec: Spec): Rock
	nextId += 1
	local part = acquirePart()
	RockService.Paint(part, spec.OreId, spec.Size)
	part.Name = spec.Name or (spec.Kind .. "Rock")
	part.CanCollide = spec.Kind ~= "Belt"
	part.CFrame = CFrame.new(spec.Position) * CFrame.Angles(math.rad(nextId * 37 % 360), math.rad(nextId * 53 % 360), 0)
	part:SetAttribute("RockId", nextId)
	part:SetAttribute("Kind", spec.Kind)
	part:SetAttribute("Health", spec.Health)
	part:SetAttribute("MaxHealth", spec.Health)
	part:SetAttribute("Owner", spec.OwnerUserId or 0)
	local rock: Rock = {
		Id = nextId,
		Kind = spec.Kind,
		Part = part,
		Position = spec.Position,
		Health = spec.Health,
		MaxHealth = spec.Health,
		OreId = spec.OreId,
		Ore = spec.Ore or 0,
		Shards = spec.Shards or 0,
		OwnerUserId = spec.OwnerUserId or 0,
		Reach = spec.Reach or 42,
		Priority = spec.Priority or 0,
		Damage = {},
		Alive = true,
		SentHealth = spec.Health,
		OnBreak = spec.OnBreak,
		Data = spec.Data or {},
	}
	rocks[rock.Id] = rock
	return rock
end

function RockService.Get(id: number): Rock?
	return rocks[id]
end

function RockService.All(): { [number]: Rock }
	return rocks
end

-- Removes a rock without breaking it (despawn, plot released, event ended).
-- `keepPart` hands the part to the caller (e.g. to tow it home first).
function RockService.Remove(rock: Rock, keepPart: boolean?)
	if rocks[rock.Id] == rock then
		rocks[rock.Id] = nil
	end
	rock.Alive = false
	if not keepPart then
		RockService.ReleasePart(rock.Part)
	end
end

-- Applies server-computed damage. Returns true if this hit broke the rock.
function RockService.Damage(rock: Rock, player: Player?, amount: number): boolean
	if not rock.Alive or amount ~= amount or amount <= 0 then
		return false
	end
	local dealt = math.min(amount, rock.Health)
	rock.Health -= dealt
	if player then
		rock.Damage[player.UserId] = (rock.Damage[player.UserId] or 0) + dealt
	end
	if rock.Health <= 1e-6 then
		rock.Health = 0
		rock.Alive = false
		rocks[rock.Id] = nil
		rock.Part:SetAttribute("Health", 0)
		rock.Part.CanQuery = false
		if rock.OnBreak then
			rock.OnBreak(rock, player)
		else
			RockService.ReleasePart(rock.Part)
		end
		return true
	end
	return false
end

-- Pushes changed health to the part attribute (called at the sim rate, not
-- per hit, to keep replication small).
function RockService.FlushHealth()
	for _, rock in rocks do
		if rock.Alive and rock.SentHealth ~= rock.Health then
			rock.SentHealth = rock.Health
			rock.Part:SetAttribute("Health", math.ceil(rock.Health))
		end
	end
end

-- Rocks `player` may target from `position`, nearest first.
function RockService.Candidates(position: Vector3, userId: number, onOwnPlot: boolean): { Rock }
	local out = {}
	local distances: { [Rock]: number } = {}
	for _, rock in rocks do
		if not rock.Alive then
			continue
		end
		if rock.Kind == "Belt" then
			if rock.OwnerUserId == userId and onOwnPlot then
				table.insert(out, rock)
				distances[rock] = (rock.Position - position).Magnitude
			end
		elseif rock.OwnerUserId == 0 or rock.OwnerUserId == userId then
			local distance = (rock.Position - position).Magnitude
			if distance <= rock.Reach then
				table.insert(out, rock)
				distances[rock] = distance
			end
		end
	end
	table.sort(out, function(a, b)
		if a.Priority ~= b.Priority then
			return a.Priority > b.Priority
		end
		local da, db = distances[a], distances[b]
		if da ~= db then
			return da < db
		end
		return a.Id < b.Id
	end)
	return out
end

-- Fraction of a contest each user dealt, sorted high to low (for HUD bars).
function RockService.TopContributors(rock: Rock, limit: number): { { UserId: number, Share: number } }
	local total = 0
	for _, dealt in rock.Damage do
		total += dealt
	end
	local list = {}
	if total <= 0 then
		return list
	end
	for userId, dealt in rock.Damage do
		table.insert(list, { UserId = userId, Share = dealt / total })
	end
	table.sort(list, function(a, b)
		if a.Share ~= b.Share then
			return a.Share > b.Share
		end
		return a.UserId < b.UserId
	end)
	while #list > limit do
		table.remove(list)
	end
	return list
end

-- Damages every live rock inside a sphere (hazard strikes). Unattributed.
function RockService.DamageInRadius(center: Vector3, radius: number, fraction: number)
	local hits = {}
	for _, rock in rocks do
		if rock.Alive and (rock.Position - center).Magnitude <= radius then
			table.insert(hits, rock)
		end
	end
	for _, rock in hits do
		-- Strikes never finish a rock off; someone still has to mine it.
		local amount = math.min(rock.MaxHealth * fraction, rock.Health - 1)
		if amount > 0 then
			RockService.Damage(rock, nil, amount)
		end
	end
end

function RockService.Init()
	getFolder()
end

return RockService
