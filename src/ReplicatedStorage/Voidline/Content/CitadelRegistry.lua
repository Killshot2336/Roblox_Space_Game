--!strict
-- Citadel tiers: one per Station Tier (1..30). Each tier adds structures that
-- CitadelBuilder renders on the pilot's plot (turrets, refinery towers, warp
-- docks, trophy halls, ...). Purely cosmetic flex plus relic pedestal slots.
-- FROZEN lists: ERAS, STRUCTURES (append-only).
local ContentUtil = require(script.Parent.ContentUtil)

export type Structure = { Kind: string, Count: number, Scale: number }

export type CitadelTier = {
	Id: string,
	Name: string,
	Tier: number,
	Era: string,
	Adds: { Structure },
	RelicSlots: number,
	Accent: Color3,
	Height: number,
	Flavor: string,
}

local ERAS: { { any } } = {
	{ "Outpost", Color3.fromRGB(200, 170, 110), "A beacon and a landing pad." },
	{ "Station", Color3.fromRGB(232, 186, 74), "Refinery towers rise over the plot." },
	{ "Bastion", Color3.fromRGB(255, 210, 120), "Turrets ring the bastion walls." },
	{ "Citadel", Color3.fromRGB(190, 150, 255), "Warp docks hum with traffic." },
	{ "Bulwark", Color3.fromRGB(120, 200, 255), "Shield rings lock around the spire." },
	{ "Sovereign Spire", Color3.fromRGB(255, 240, 190), "A spire visible from every plot." },
}

-- Structure kinds CitadelBuilder knows how to draw.
local STRUCTURES = {
	"beacon",
	"refinery_tower",
	"turret",
	"warp_dock",
	"trophy_hall",
	"shield_ring",
	"solar_array",
	"hangar",
	"gravity_anchor",
	"relic_vault",
}

-- Fixed signature structure per rank inside an era (rank 1..5).
local SIGNATURE = {
	{ "beacon", "solar_array", "refinery_tower", "hangar", "turret" },
	{ "refinery_tower", "turret", "solar_array", "warp_dock", "trophy_hall" },
	{ "turret", "shield_ring", "refinery_tower", "gravity_anchor", "trophy_hall" },
	{ "warp_dock", "relic_vault", "turret", "shield_ring", "hangar" },
	{ "shield_ring", "gravity_anchor", "warp_dock", "relic_vault", "turret" },
	{ "trophy_hall", "beacon", "shield_ring", "relic_vault", "gravity_anchor" },
}

local TIERS_PER_ERA = 5

local list: { CitadelTier } = {}

for eraIndex, era in ERAS do
	for rank = 1, TIERS_PER_ERA do
		local tier = (eraIndex - 1) * TIERS_PER_ERA + rank
		local id = "citadel.tier." .. tier
		local rng = ContentUtil.Rng("citadel", id)
		local adds: { Structure } = {
			{ Kind = SIGNATURE[eraIndex][rank], Count = 1 + math.floor(eraIndex / 3), Scale = 1 + 0.1 * eraIndex },
		}
		-- From the Bastion era on, each tier also adds a seeded secondary piece.
		if eraIndex >= 3 then
			table.insert(adds, {
				Kind = rng:Pick(STRUCTURES),
				Count = 1,
				Scale = ContentUtil.Round(0.8 + rng:NextNumber(0, 0.4), 3),
			})
		end
		table.insert(list, {
			Id = id,
			Name = era[1] .. " " .. ContentUtil.Roman(rank),
			Tier = tier,
			Era = era[1],
			Adds = adds,
			RelicSlots = 1 + math.floor(tier / 3),
			Accent = ContentUtil.ShiftColor(era[2], rng, 0.03),
			Height = ContentUtil.Round(6 + tier * 1.6, 2),
			Flavor = era[3],
		})
	end
end

local registry = ContentUtil.Registry("citadel", list) :: any
registry.StructureKinds = STRUCTURES

function registry.ForTier(tier: number): CitadelTier
	return list[math.clamp(math.floor(tier), 1, #list)]
end

-- Every structure up to and including `tier`, in build order.
function registry.StructuresUpTo(tier: number): { Structure }
	local out = {}
	for i = 1, math.clamp(math.floor(tier), 0, #list) do
		for _, structure in list[i].Adds do
			table.insert(out, structure)
		end
	end
	return out
end

return registry
