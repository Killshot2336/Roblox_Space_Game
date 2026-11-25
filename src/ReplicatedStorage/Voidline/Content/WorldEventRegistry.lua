--!strict
-- Server-wide world events (every 6 min, 90 s; spec §7). Event kinds map to
-- WorldEventService handlers:
--   Monolith  - the Monolith splits, gravity/lighting shift, Void Core contest
--   Shower    - boss meteors fall around the Monolith (soft contest each)
--   Contest   - a single big core to contest (e.g. a Titan wreck)
--   Modifier  - server-wide multipliers for the duration
--   Rift      - the Void Rift parkour gate opens
-- FROZEN list: append-only.
local ContentUtil = require(script.Parent.ContentUtil)

export type WorldEvent = {
	Id: string,
	Name: string,
	Kind: string,
	Duration: number,
	Weight: number,
	Banner: string,
	Color: Color3,
	CoreHealth: number,
	Meteors: number,
	MeteorHealth: number,
	CreditMult: number,
	LuckMult: number,
	GravityMult: number,
	CelestialBias: number,
	RelicGuaranteed: boolean,
	Flavor: string,
}

local function event(fields: { [string]: any }): WorldEvent
	return {
		Id = fields.Id,
		Name = fields.Name,
		Kind = fields.Kind,
		Duration = fields.Duration or 90,
		Weight = fields.Weight or 1,
		Banner = fields.Banner,
		Color = fields.Color,
		CoreHealth = fields.CoreHealth or 0,
		Meteors = fields.Meteors or 0,
		MeteorHealth = fields.MeteorHealth or 0,
		CreditMult = fields.CreditMult or 1,
		LuckMult = fields.LuckMult or 1,
		GravityMult = fields.GravityMult or 1,
		CelestialBias = fields.CelestialBias or 1,
		RelicGuaranteed = fields.RelicGuaranteed or false,
		Flavor = fields.Flavor,
	}
end

local list: { WorldEvent } = {
	event({
		Id = "event.monolith_split",
		Name = "Monolith Split",
		Kind = "Monolith",
		Weight = 3,
		Banner = "THE MONOLITH SPLITS · VOID CORE EXPOSED",
		Color = Color3.fromRGB(170, 110, 255),
		CoreHealth = 12000,
		GravityMult = 0.6,
		Flavor = "The Monolith opens and gravity loosens its grip.",
	}),
	event({
		Id = "event.meteor_shower",
		Name = "Boss Meteor Shower",
		Kind = "Shower",
		Weight = 3,
		Banner = "BOSS METEORS INBOUND",
		Color = Color3.fromRGB(255, 150, 80),
		Meteors = 3,
		MeteorHealth = 5000,
		Flavor = "Three giants fall. Everyone who helps gets paid.",
	}),
	event({
		Id = "event.ion_storm",
		Name = "Ion Storm",
		Kind = "Modifier",
		Weight = 2,
		Banner = "ION STORM · SHARD LUCK x1.5",
		Color = Color3.fromRGB(90, 220, 255),
		LuckMult = 1.5,
		Flavor = "Charged dust shakes Void Shards loose.",
	}),
	event({
		Id = "event.solar_tide",
		Name = "Solar Tide",
		Kind = "Modifier",
		Weight = 2,
		Banner = "SOLAR TIDE · CREDITS x1.25",
		Color = Color3.fromRGB(255, 200, 90),
		CreditMult = 1.25,
		Flavor = "Refineries run hot and pay out more.",
	}),
	event({
		Id = "event.gravity_inversion",
		Name = "Gravity Inversion",
		Kind = "Modifier",
		Weight = 1,
		Banner = "GRAVITY INVERSION · MOON JUMPS",
		Color = Color3.fromRGB(140, 120, 255),
		GravityMult = 0.35,
		Flavor = "Every jump becomes a launch.",
	}),
	event({
		Id = "event.void_rift",
		Name = "Void Rift Opens",
		Kind = "Rift",
		Weight = 2,
		Banner = "THE VOID RIFT IS OPEN",
		Color = Color3.fromRGB(190, 120, 255),
		Flavor = "A path of floating shards leads to a reward cache.",
	}),
	event({
		Id = "event.comet_pass",
		Name = "Comet Pass",
		Kind = "Shower",
		Weight = 2,
		Banner = "COMET PASS · CELESTIAL FRAGMENTS",
		Color = Color3.fromRGB(180, 240, 255),
		Meteors = 5,
		MeteorHealth = 2500,
		CelestialBias = 4,
		Flavor = "A comet sheds glittering fragments as it passes.",
	}),
	event({
		Id = "event.derelict_titan",
		Name = "Derelict Titan Drift",
		Kind = "Contest",
		Weight = 1,
		Banner = "A DERELICT TITAN DRIFTS IN · RELIC GUARANTEED",
		Color = Color3.fromRGB(150, 200, 170),
		CoreHealth = 15000,
		RelicGuaranteed = true,
		Flavor = "Salvage the wreck; the top salvager keeps a relic.",
	}),
}

local registry = ContentUtil.Registry("event", list) :: any

-- Event for a rotation slot (same on every server at the same time).
function registry.ForSlot(slot: number): WorldEvent
	local total = 0
	for _, e in list do
		total += e.Weight
	end
	local rng = ContentUtil.Rng("event-slot", tostring(slot))
	local pick = rng:NextNumber() * total
	for _, e in list do
		pick -= e.Weight
		if pick < 0 then
			return e
		end
	end
	return list[#list]
end

return registry
