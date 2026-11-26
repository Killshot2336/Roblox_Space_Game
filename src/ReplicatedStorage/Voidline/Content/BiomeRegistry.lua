--!strict
-- Anomaly biomes for the deep-space zone around the Monolith, plus the
-- hazards they spawn. Each anomaly rotates in with a sky/lighting profile, a
-- gravity modifier, ore-tier bias and 2 hazards.
-- FROZEN lists: ARCHETYPES (append-only), CODE_LETTERS, HAZARDS.
local ContentUtil = require(script.Parent.ContentUtil)

export type Hazard = {
	Id: string,
	Name: string,
	Effect: string,
	TelegraphSeconds: number,
	Duration: number,
	Radius: number,
	Color: Color3,
	Flavor: string,
}

export type Biome = {
	Id: string,
	Name: string,
	Archetype: string,
	ArchetypeName: string,
	Intensity: number,
	IntensityName: string,
	GravityMult: number,
	HazardIds: { string },
	HazardInterval: number,
	TierBias: { [number]: number },
	RelicMult: number,
	CreditMult: number,
	Sky: {
		Tint: Color3,
		Ambient: Color3,
		AtmosphereColor: Color3,
		AtmosphereDecay: Color3,
		Density: number,
		Haze: number,
		Glare: number,
		Bloom: number,
		Saturation: number,
		Contrast: number,
	},
	Flavor: string,
}

-- Effects are implemented by WorldEventService:
--   DronePause: drones in radius stop firing; StrikeBonus: lightning deals a
--   chunk of damage to a rock; Pull: rocks/pilots drift toward the centre;
--   OreSurge: rocks in radius drop +50% ore; SlowTow: tows in radius take
--   longer; LuckSurge: shard chance x2 in radius; Knockback: pilots are pushed.
local HAZARDS: { Hazard } = {
	{
		Id = "hazard.solar_flare",
		Name = "Solar Flare",
		Effect = "DronePause",
		TelegraphSeconds = 3,
		Duration = 4,
		Radius = 60,
		Color = Color3.fromRGB(255, 170, 60),
		Flavor = "Drones shut their optics until the flare passes.",
	},
	{
		Id = "hazard.gravity_well",
		Name = "Gravity Well",
		Effect = "Pull",
		TelegraphSeconds = 2,
		Duration = 6,
		Radius = 50,
		Color = Color3.fromRGB(140, 90, 255),
		Flavor = "Everything loose drifts toward the well.",
	},
	{
		Id = "hazard.void_lightning",
		Name = "Void Lightning",
		Effect = "StrikeBonus",
		TelegraphSeconds = 1.5,
		Duration = 1,
		Radius = 12,
		Color = Color3.fromRGB(190, 120, 255),
		Flavor = "A bolt splits whatever rock it touches.",
	},
	{
		Id = "hazard.ion_squall",
		Name = "Ion Squall",
		Effect = "SlowTow",
		TelegraphSeconds = 2,
		Duration = 8,
		Radius = 70,
		Color = Color3.fromRGB(90, 220, 255),
		Flavor = "Tow beams flicker in the charged wind.",
	},
	{
		Id = "hazard.cryo_burst",
		Name = "Cryo Burst",
		Effect = "SlowTow",
		TelegraphSeconds = 2,
		Duration = 5,
		Radius = 45,
		Color = Color3.fromRGB(170, 230, 255),
		Flavor = "Frost locks tow cables for a moment.",
	},
	{
		Id = "hazard.dark_matter_tide",
		Name = "Dark Matter Tide",
		Effect = "Pull",
		TelegraphSeconds = 3,
		Duration = 7,
		Radius = 80,
		Color = Color3.fromRGB(40, 30, 90),
		Flavor = "An invisible current drags the belt sideways.",
	},
	{
		Id = "hazard.plasma_geyser",
		Name = "Plasma Geyser",
		Effect = "OreSurge",
		TelegraphSeconds = 2,
		Duration = 6,
		Radius = 30,
		Color = Color3.fromRGB(255, 90, 200),
		Flavor = "Superheated rock spills extra ore.",
	},
	{
		Id = "hazard.magnetic_reversal",
		Name = "Magnetic Reversal",
		Effect = "Knockback",
		TelegraphSeconds = 2,
		Duration = 1,
		Radius = 40,
		Color = Color3.fromRGB(120, 160, 255),
		Flavor = "The field flips and throws pilots outward.",
	},
	{
		Id = "hazard.quantum_flicker",
		Name = "Quantum Flicker",
		Effect = "LuckSurge",
		TelegraphSeconds = 1,
		Duration = 6,
		Radius = 40,
		Color = Color3.fromRGB(220, 240, 255),
		Flavor = "Probability thins. Rare finds come easier.",
	},
	{
		Id = "hazard.radiation_bloom",
		Name = "Radiation Bloom",
		Effect = "DronePause",
		TelegraphSeconds = 3,
		Duration = 3,
		Radius = 35,
		Color = Color3.fromRGB(150, 255, 120),
		Flavor = "Drones retreat from the glow.",
	},
	{
		Id = "hazard.meteor_hail",
		Name = "Meteor Hail",
		Effect = "StrikeBonus",
		TelegraphSeconds = 2.5,
		Duration = 1,
		Radius = 20,
		Color = Color3.fromRGB(255, 140, 90),
		Flavor = "Pebbles at orbital speed crack open the big rocks.",
	},
	{
		Id = "hazard.tachyon_wake",
		Name = "Tachyon Wake",
		Effect = "LuckSurge",
		TelegraphSeconds = 1.5,
		Duration = 5,
		Radius = 50,
		Color = Color3.fromRGB(255, 240, 160),
		Flavor = "Echoes of finds that have not happened yet.",
	},
}

type Archetype = {
	Id: string,
	Name: string,
	Gravity: number,
	Hazards: { string },
	Bias: { [number]: number },
	RelicMult: number,
	CreditMult: number,
	Tint: Color3,
	Atmosphere: Color3,
	Flavor: string,
}

local ARCHETYPES: { Archetype } = {
	{
		Id = "magnetar_storm",
		Name = "Magnetar Storm",
		Gravity = 0.85,
		Hazards = { "hazard.void_lightning", "hazard.magnetic_reversal", "hazard.ion_squall" },
		Bias = { [3] = 1.5, [4] = 1.3 },
		RelicMult = 1,
		CreditMult = 1,
		Tint = Color3.fromRGB(150, 160, 255),
		Atmosphere = Color3.fromRGB(70, 60, 160),
		Flavor = "A dead star's magnetic field howls across the belt.",
	},
	{
		Id = "singularity_rift",
		Name = "Singularity Rift",
		Gravity = 1.35,
		Hazards = { "hazard.gravity_well", "hazard.tachyon_wake" },
		Bias = { [4] = 2.0, [6] = 1.5 },
		RelicMult = 1.2,
		CreditMult = 1,
		Tint = Color3.fromRGB(190, 140, 255),
		Atmosphere = Color3.fromRGB(50, 20, 80),
		Flavor = "Space folds inward around a seam of nothing.",
	},
	{
		Id = "diamond_nebula",
		Name = "Diamond Nebula",
		Gravity = 0.9,
		Hazards = { "hazard.cryo_burst", "hazard.radiation_bloom" },
		Bias = { [2] = 1.8, [5] = 1.4 },
		RelicMult = 1,
		CreditMult = 1.05,
		Tint = Color3.fromRGB(255, 220, 245),
		Atmosphere = Color3.fromRGB(200, 150, 220),
		Flavor = "Carbon rain crystallises into glittering fog.",
	},
	{
		Id = "solar_forge",
		Name = "Solar Forge",
		Gravity = 1.0,
		Hazards = { "hazard.solar_flare", "hazard.plasma_geyser" },
		Bias = { [2] = 1.4, [3] = 1.4 },
		RelicMult = 1,
		CreditMult = 1.1,
		Tint = Color3.fromRGB(255, 205, 140),
		Atmosphere = Color3.fromRGB(200, 110, 40),
		Flavor = "A star close enough to smelt ore in flight.",
	},
	{
		Id = "derelict_titan",
		Name = "Derelict Titan Wreck",
		Gravity = 0.7,
		Hazards = { "hazard.meteor_hail", "hazard.quantum_flicker" },
		Bias = { [2] = 1.5 },
		RelicMult = 2,
		CreditMult = 1,
		Tint = Color3.fromRGB(190, 220, 200),
		Atmosphere = Color3.fromRGB(60, 80, 70),
		Flavor = "The hull of something enormous drifts past, still humming.",
	},
	{
		Id = "antimatter_void",
		Name = "Antimatter Void",
		Gravity = 1.2,
		Hazards = { "hazard.dark_matter_tide", "hazard.void_lightning" },
		Bias = { [6] = 2.5, [4] = 1.4 },
		RelicMult = 1.3,
		CreditMult = 1,
		Tint = Color3.fromRGB(255, 140, 220),
		Atmosphere = Color3.fromRGB(30, 5, 35),
		Flavor = "Matter and its mirror meet here, briefly and brightly.",
	},
	{
		Id = "cryo_comet_field",
		Name = "Cryo Comet Field",
		Gravity = 0.8,
		Hazards = { "hazard.cryo_burst", "hazard.meteor_hail" },
		Bias = { [2] = 1.3, [5] = 1.2 },
		RelicMult = 1,
		CreditMult = 1,
		Tint = Color3.fromRGB(190, 235, 255),
		Atmosphere = Color3.fromRGB(110, 170, 210),
		Flavor = "Comet tails freeze into drifting ribbons.",
	},
	{
		Id = "plasma_reef",
		Name = "Plasma Reef",
		Gravity = 0.95,
		Hazards = { "hazard.plasma_geyser", "hazard.ion_squall" },
		Bias = { [3] = 1.6 },
		RelicMult = 1,
		CreditMult = 1.05,
		Tint = Color3.fromRGB(150, 255, 230),
		Atmosphere = Color3.fromRGB(30, 120, 120),
		Flavor = "Living arcs of plasma grow like coral.",
	},
	{
		Id = "crystal_lattice",
		Name = "Crystal Lattice Belt",
		Gravity = 1.0,
		Hazards = { "hazard.radiation_bloom", "hazard.quantum_flicker" },
		Bias = { [2] = 1.6, [5] = 1.3 },
		RelicMult = 1.1,
		CreditMult = 1,
		Tint = Color3.fromRGB(230, 240, 255),
		Atmosphere = Color3.fromRGB(150, 160, 210),
		Flavor = "Asteroids grown in perfect geometric shells.",
	},
	{
		Id = "dark_matter_tide",
		Name = "Dark Matter Tide",
		Gravity = 1.25,
		Hazards = { "hazard.dark_matter_tide", "hazard.gravity_well" },
		Bias = { [4] = 1.8 },
		RelicMult = 1.1,
		CreditMult = 1,
		Tint = Color3.fromRGB(140, 150, 220),
		Atmosphere = Color3.fromRGB(15, 15, 50),
		Flavor = "An unseen mass pulls the whole belt off course.",
	},
	{
		Id = "ion_aurora",
		Name = "Ion Aurora",
		Gravity = 0.9,
		Hazards = { "hazard.ion_squall", "hazard.solar_flare" },
		Bias = { [3] = 1.3, [5] = 1.2 },
		RelicMult = 1,
		CreditMult = 1.05,
		Tint = Color3.fromRGB(170, 255, 200),
		Atmosphere = Color3.fromRGB(30, 110, 80),
		Flavor = "Curtains of green light ripple between the rocks.",
	},
	{
		Id = "quantum_foam",
		Name = "Quantum Foam Shoal",
		Gravity = 0.75,
		Hazards = { "hazard.quantum_flicker", "hazard.tachyon_wake" },
		Bias = { [5] = 1.5, [6] = 1.3 },
		RelicMult = 1.4,
		CreditMult = 1,
		Tint = Color3.fromRGB(235, 245, 255),
		Atmosphere = Color3.fromRGB(120, 140, 200),
		Flavor = "Space bubbles at the smallest scale and nothing sits still.",
	},
	{
		Id = "pulsar_graveyard",
		Name = "Pulsar Graveyard",
		Gravity = 1.1,
		Hazards = { "hazard.radiation_bloom", "hazard.magnetic_reversal" },
		Bias = { [3] = 1.4, [4] = 1.4 },
		RelicMult = 1.2,
		CreditMult = 1,
		Tint = Color3.fromRGB(170, 200, 255),
		Atmosphere = Color3.fromRGB(30, 50, 100),
		Flavor = "Old pulsars tick like clocks over a field of wrecks.",
	},
	{
		Id = "gas_giant_shadow",
		Name = "Gas Giant Shadow",
		Gravity = 1.15,
		Hazards = { "hazard.meteor_hail", "hazard.dark_matter_tide" },
		Bias = { [2] = 1.3, [3] = 1.2 },
		RelicMult = 1,
		CreditMult = 1.05,
		Tint = Color3.fromRGB(255, 220, 170),
		Atmosphere = Color3.fromRGB(120, 80, 40),
		Flavor = "A banded giant blots out half the sky.",
	},
}

local VARIANTS_PER_ARCHETYPE = 4
local INTENSITY_NAMES = { "Calm", "Restless", "Raging", "Cataclysmic" }
local CODE_LETTERS = { "A", "C", "D", "E", "G", "H", "J", "K", "L", "M", "N", "P", "R", "S", "T", "V", "X", "Z" }

local list: { Biome } = {}

for _, archetype in ARCHETYPES do
	for n = 1, VARIANTS_PER_ARCHETYPE do
		local id = ("biome.%s.%d"):format(archetype.Id, n)
		local rng = ContentUtil.Rng("biome", id)
		local code = rng:Pick(CODE_LETTERS) .. rng:Pick(CODE_LETTERS) .. "-" .. tostring(rng:NextInteger(100, 999))
		local intensity = n
		local hazardIds = rng:Sample(archetype.Hazards, math.min(2, #archetype.Hazards))
		table.sort(hazardIds)
		local bias = {}
		for tier, mult in archetype.Bias do
			bias[tier] = ContentUtil.Round(1 + (mult - 1) * (0.7 + 0.15 * intensity), 3)
		end
		local tint = ContentUtil.ShiftColor(archetype.Tint, rng, 0.04)
		local atmosphere = ContentUtil.ShiftColor(archetype.Atmosphere, rng, 0.05)
		table.insert(list, {
			Id = id,
			Name = archetype.Name .. " " .. code,
			Archetype = archetype.Id,
			ArchetypeName = archetype.Name,
			Intensity = intensity,
			IntensityName = INTENSITY_NAMES[intensity],
			GravityMult = ContentUtil.Round(1 + (archetype.Gravity - 1) * (0.6 + 0.2 * intensity), 3),
			HazardIds = hazardIds,
			HazardInterval = math.floor(30 - intensity * 4 + rng:NextInteger(0, 4)),
			TierBias = bias,
			RelicMult = archetype.RelicMult,
			CreditMult = archetype.CreditMult,
			Sky = {
				Tint = tint,
				Ambient = atmosphere:Lerp(Color3.new(0, 0, 0), 0.4),
				AtmosphereColor = atmosphere,
				AtmosphereDecay = atmosphere:Lerp(Color3.new(0, 0, 0), 0.6),
				Density = ContentUtil.Round(0.25 + 0.06 * intensity + rng:NextNumber(0, 0.05), 3),
				Haze = ContentUtil.Round(1 + intensity * 0.4 + rng:NextNumber(0, 0.5), 3),
				Glare = ContentUtil.Round(rng:NextNumber(0, 0.6) + intensity * 0.1, 3),
				Bloom = ContentUtil.Round(0.8 + intensity * 0.15, 3),
				Saturation = ContentUtil.Round(0.05 + 0.04 * intensity, 3),
				Contrast = ContentUtil.Round(0.05 + 0.03 * intensity, 3),
			},
			Flavor = archetype.Flavor,
		})
	end
end

local registry = ContentUtil.Registry("biome", list) :: any
registry.Hazards = ContentUtil.Registry("hazard", HAZARDS)
registry.Archetypes = ARCHETYPES

-- Which anomaly is active for a given rotation slot. Seeded by slot number so
-- every server shows the same anomaly at the same time.
function registry.ForSlot(slot: number): Biome
	local rng = ContentUtil.Rng("biome-slot", tostring(slot))
	return list[rng:NextInteger(1, #list)]
end

return registry
