--!strict
-- Ore variants: 6 rarity tiers x tier-specific mineral roots x quality
-- modifiers. Base variants ("ore.<tier>.<root>") have exact tier values so the
-- tutorial stays deterministic; modifier variants get seeded stats.
-- FROZEN lists: TIERS, ROOTS, MODIFIERS (append-only; see ContentUtil).
local ContentUtil = require(script.Parent.ContentUtil)

export type Ore = {
	Id: string,
	Name: string,
	Tier: string,
	TierIndex: number,
	Root: string,
	Modifier: string,
	ValueMult: number,
	ShardChance: number,
	RelicChance: number,
	Weight: number,
	Color: Color3,
	Glow: Color3,
	Material: Enum.Material,
	MinSector: number,
	Flavor: string,
}

type TierDef = {
	Id: string,
	Label: string,
	Index: number,
	ValueMult: number,
	ShardChance: number,
	RelicChance: number,
	Weight: number,
	MinSector: number,
	Color: Color3,
	Glow: Color3,
	Material: Enum.Material,
}

local TIERS: { TierDef } = {
	{
		Id = "common",
		Label = "Common",
		Index = 1,
		ValueMult = 1.0,
		ShardChance = 0.006,
		RelicChance = 0.0002,
		Weight = 1000,
		MinSector = 1,
		Color = Color3.fromRGB(120, 112, 104),
		Glow = Color3.fromRGB(200, 180, 150),
		Material = Enum.Material.Rock,
	},
	{
		Id = "refined",
		Label = "Refined",
		Index = 2,
		ValueMult = 1.6,
		ShardChance = 0.014,
		RelicChance = 0.0005,
		Weight = 280,
		MinSector = 1,
		Color = Color3.fromRGB(150, 160, 175),
		Glow = Color3.fromRGB(190, 220, 255),
		Material = Enum.Material.Slate,
	},
	{
		Id = "isotope",
		Label = "Isotope",
		Index = 3,
		ValueMult = 2.6,
		ShardChance = 0.03,
		RelicChance = 0.001,
		Weight = 80,
		MinSector = 2,
		Color = Color3.fromRGB(90, 150, 80),
		Glow = Color3.fromRGB(150, 255, 120),
		Material = Enum.Material.Basalt,
	},
	{
		Id = "void_touched",
		Label = "Void-Touched",
		Index = 4,
		ValueMult = 4.2,
		ShardChance = 0.06,
		RelicChance = 0.002,
		Weight = 22,
		MinSector = 3,
		Color = Color3.fromRGB(60, 30, 90),
		Glow = Color3.fromRGB(170, 110, 255),
		Material = Enum.Material.Basalt,
	},
	{
		Id = "celestial",
		Label = "Celestial",
		Index = 5,
		ValueMult = 7.0,
		ShardChance = 0.1,
		RelicChance = 0.004,
		Weight = 6,
		MinSector = 4,
		Color = Color3.fromRGB(230, 220, 190),
		Glow = Color3.fromRGB(255, 230, 140),
		Material = Enum.Material.Glass,
	},
	{
		Id = "antimatter",
		Label = "Antimatter",
		Index = 6,
		ValueMult = 12.0,
		ShardChance = 0.18,
		RelicChance = 0.008,
		Weight = 1.5,
		MinSector = 4,
		Color = Color3.fromRGB(20, 10, 30),
		Glow = Color3.fromRGB(255, 80, 200),
		Material = Enum.Material.Glass,
	},
}

local ROOTS: { [string]: { string } } = {
	common = {
		"Ferrite",
		"Cobalt",
		"Nickel",
		"Silicate",
		"Basalt",
		"Olivine",
		"Pyroxene",
		"Magnetite",
		"Hematite",
		"Quartzite",
		"Bauxite",
		"Graphite",
	},
	refined = {
		"Titanium",
		"Iridium",
		"Palladium",
		"Osmium",
		"Rhodium",
		"Tungsten",
		"Chromium",
		"Vanadium",
		"Platinum",
		"Beryllium",
	},
	isotope = {
		"Uranium",
		"Thorium",
		"Plutonium",
		"Tritium",
		"Deuterium",
		"Helium-3",
		"Cesium",
		"Strontium",
		"Radium",
		"Polonium",
	},
	void_touched = { "Umbral", "Nullstone", "Shadeglass", "Eclipsite", "Duskium", "Gloomite", "Vantaite", "Abyssite" },
	celestial = { "Starfire", "Nebulite", "Aurorium", "Quasarite", "Pulsarine", "Cometite", "Lumenite", "Solarium" },
	antimatter = { "Antiferrite", "Positronium", "Antiproton", "Mirrorium", "Annihilite", "Exotic Matter" },
}

type ModifierDef = { Id: string, Label: string, ValueMult: number, Material: Enum.Material?, Tint: Color3? }

local MODIFIERS: { ModifierDef } = {
	{
		Id = "molten",
		Label = "Molten",
		ValueMult = 1.10,
		Material = Enum.Material.CrackedLava,
		Tint = Color3.fromRGB(255, 120, 40),
	},
	{
		Id = "glacial",
		Label = "Glacial",
		ValueMult = 1.05,
		Material = Enum.Material.Ice,
		Tint = Color3.fromRGB(150, 210, 255),
	},
	{
		Id = "prismatic",
		Label = "Prismatic",
		ValueMult = 1.25,
		Material = Enum.Material.Glass,
		Tint = Color3.fromRGB(255, 160, 255),
	},
	{ Id = "fractured", Label = "Fractured", ValueMult = 0.95, Material = Enum.Material.Slate },
	{ Id = "charged", Label = "Charged", ValueMult = 1.15, Tint = Color3.fromRGB(90, 230, 255) },
	{ Id = "radiant", Label = "Radiant", ValueMult = 1.2, Tint = Color3.fromRGB(255, 230, 120) },
	{ Id = "ancient", Label = "Ancient", ValueMult = 1.3, Material = Enum.Material.Granite },
	{
		Id = "gilded",
		Label = "Gilded",
		ValueMult = 1.35,
		Material = Enum.Material.Foil,
		Tint = Color3.fromRGB(240, 190, 70),
	},
	{ Id = "porous", Label = "Porous", ValueMult = 1.02, Material = Enum.Material.Sandstone },
	{ Id = "shimmering", Label = "Shimmering", ValueMult = 1.18, Tint = Color3.fromRGB(200, 255, 230) },
	{ Id = "ionized", Label = "Ionized", ValueMult = 1.22, Tint = Color3.fromRGB(120, 140, 255) },
	{ Id = "dense", Label = "Dense", ValueMult = 1.08, Material = Enum.Material.Basalt },
}

local INCLUDE_CHANCE = 0.42

local FLAVOR = {
	common = "Belt staple. Every citadel was built on it.",
	refined = "Purified in the tail of passing comets.",
	isotope = "Warm to the touch. Handle with drones only.",
	void_touched = "Pulled back from the edge of the Void.",
	celestial = "Fell from somewhere no map has reached.",
	antimatter = "Contained by nothing but your tow beam.",
}

local list: { Ore } = {}

for _, tier in TIERS do
	for _, rootLabel in ROOTS[tier.Id] do
		local root = ContentUtil.Slug(rootLabel)
		local baseId = ("ore.%s.%s"):format(tier.Id, root)
		local baseRng = ContentUtil.Rng("ore", baseId)
		local baseColor = ContentUtil.ShiftColor(tier.Color, baseRng, 0.06)
		table.insert(list, {
			Id = baseId,
			Name = rootLabel,
			Tier = tier.Label,
			TierIndex = tier.Index,
			Root = root,
			Modifier = "",
			ValueMult = tier.ValueMult,
			ShardChance = tier.ShardChance,
			RelicChance = tier.RelicChance,
			Weight = tier.Weight,
			Color = baseColor,
			Glow = tier.Glow,
			Material = tier.Material,
			MinSector = tier.MinSector,
			Flavor = FLAVOR[tier.Id],
		})
		for _, modifier in MODIFIERS do
			if ContentUtil.Include(baseId .. "+" .. modifier.Id, INCLUDE_CHANCE) then
				local id = baseId .. "." .. modifier.Id
				local rng = ContentUtil.Rng("ore", id)
				local color = if modifier.Tint then baseColor:Lerp(modifier.Tint, 0.35) else baseColor
				table.insert(list, {
					Id = id,
					Name = modifier.Label .. " " .. rootLabel,
					Tier = tier.Label,
					TierIndex = tier.Index,
					Root = root,
					Modifier = modifier.Id,
					ValueMult = ContentUtil.Round(
						ContentUtil.Jitter(rng, tier.ValueMult * modifier.ValueMult, 0.05),
						3
					),
					ShardChance = ContentUtil.Round(ContentUtil.Jitter(rng, tier.ShardChance * 1.15, 0.1), 5),
					RelicChance = ContentUtil.Round(tier.RelicChance * 1.2, 5),
					Weight = ContentUtil.Round(tier.Weight * rng:NextNumber(0.25, 0.6), 3),
					Color = ContentUtil.ShiftColor(color, rng, 0.03),
					Glow = if modifier.Tint then tier.Glow:Lerp(modifier.Tint, 0.5) else tier.Glow,
					Material = modifier.Material or tier.Material,
					MinSector = tier.MinSector,
					Flavor = FLAVOR[tier.Id],
				})
			end
		end
	end
end

local registry = ContentUtil.Registry("ore", list) :: any
registry.Tiers = TIERS
registry.TutorialOreId = "ore.common.ferrite"

local byTier: { [number]: { Ore } } = {}
for _, ore in list do
	byTier[ore.TierIndex] = byTier[ore.TierIndex] or {}
	table.insert(byTier[ore.TierIndex], ore)
end
registry.ByTier = byTier

-- Server-side roll. `rng` is any object with NextNumber() in [0, 1);
-- `sectorIndex` 1..4; `luck` scales the rare-tier weights.
function registry.Roll(rng: any, sectorIndex: number, luck: number, tierBias: { [number]: number }?): Ore
	local weights = {}
	local total = 0
	for _, tier in TIERS do
		local weight = 0
		if sectorIndex >= tier.MinSector then
			weight = tier.Weight
			if tier.Index >= 3 then
				weight *= luck
			end
			if tierBias and tierBias[tier.Index] then
				weight *= tierBias[tier.Index]
			end
		end
		weights[tier.Index] = weight
		total += weight
	end
	local roll = rng:NextNumber() * total
	local chosen = 1
	for index = 1, #TIERS do
		roll -= weights[index]
		if roll < 0 then
			chosen = index
			break
		end
	end
	local pool = byTier[chosen]
	local poolTotal = 0
	for _, ore in pool do
		poolTotal += ore.Weight
	end
	local pick = rng:NextNumber() * poolTotal
	for _, ore in pool do
		pick -= ore.Weight
		if pick < 0 then
			return ore
		end
	end
	return pool[#pool]
end

return registry
