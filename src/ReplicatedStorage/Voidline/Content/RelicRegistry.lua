--!strict
-- Relics: 16 themed sets of 10 plus hand-made mythic uniques. Relics are found
-- rarely while mining, from boss meteors and Starfalls, fill the Codex and can
-- be shown on citadel pedestals. Completing a set unlocks a curator title.
-- FROZEN lists: SETS (append-only), NOUNS, RARITY_BY_SLOT, UNIQUES.
local ContentUtil = require(script.Parent.ContentUtil)

export type Relic = {
	Id: string,
	Name: string,
	Set: string,
	SetName: string,
	Rarity: string,
	RarityIndex: number,
	Shape: string,
	Color: Color3,
	Glow: Color3,
	DropWeight: number,
	Flavor: string,
}

type SetDef = { Id: string, Name: string, Owner: string, Color: Color3, Flavor: string }

local SETS: { SetDef } = {
	{
		Id = "titan_wreck",
		Name = "Titan Wreck",
		Owner = "Titan Navigator's",
		Color = Color3.fromRGB(150, 180, 160),
		Flavor = "Salvaged from the hull of a ship the size of a moon.",
	},
	{
		Id = "solar_forge",
		Name = "Solar Forge",
		Owner = "Forgemaster's",
		Color = Color3.fromRGB(255, 160, 60),
		Flavor = "Tempered in starlight by smiths who never slept.",
	},
	{
		Id = "magnetar_choir",
		Name = "Magnetar Choir",
		Owner = "Choirwarden's",
		Color = Color3.fromRGB(120, 140, 255),
		Flavor = "Still hums with the song of a dead star.",
	},
	{
		Id = "singularity_monks",
		Name = "Singularity Monks",
		Owner = "Horizon Monk's",
		Color = Color3.fromRGB(150, 90, 220),
		Flavor = "Kept by an order that meditated at the edge of a black hole.",
	},
	{
		Id = "diamond_nebula",
		Name = "Diamond Nebula",
		Owner = "Gemcutter's",
		Color = Color3.fromRGB(240, 220, 255),
		Flavor = "Cut from the glittering fog of the Diamond Nebula.",
	},
	{
		Id = "antimatter_cult",
		Name = "Antimatter Cult",
		Owner = "Mirror Priest's",
		Color = Color3.fromRGB(255, 80, 200),
		Flavor = "Its reflection is always a little late.",
	},
	{
		Id = "first_expedition",
		Name = "First Voidline Expedition",
		Owner = "Pathfinder's",
		Color = Color3.fromRGB(232, 186, 74),
		Flavor = "Carried by the first crews to cross the Void.",
	},
	{
		Id = "eclipse_navy",
		Name = "Eclipse Navy",
		Owner = "Eclipse Admiral's",
		Color = Color3.fromRGB(70, 70, 110),
		Flavor = "Issued to a fleet that only sailed in shadow.",
	},
	{
		Id = "starfall_pilgrims",
		Name = "Starfall Pilgrims",
		Owner = "Pilgrim's",
		Color = Color3.fromRGB(255, 220, 150),
		Flavor = "Pilgrims followed falling stars to find these.",
	},
	{
		Id = "quasar_archive",
		Name = "Quasar Archive",
		Owner = "Archivist's",
		Color = Color3.fromRGB(150, 230, 255),
		Flavor = "Indexed in a library lit by a quasar.",
	},
	{
		Id = "comet_nomads",
		Name = "Comet Nomads",
		Owner = "Nomad's",
		Color = Color3.fromRGB(180, 240, 255),
		Flavor = "Traded from tail to tail across a thousand comets.",
	},
	{
		Id = "aurora_court",
		Name = "Aurora Court",
		Owner = "Aurora Regent's",
		Color = Color3.fromRGB(120, 255, 190),
		Flavor = "Worn at a court that met beneath the aurora.",
	},
	{
		Id = "pulsar_clockmakers",
		Name = "Pulsar Clockmakers",
		Owner = "Clockmaker's",
		Color = Color3.fromRGB(200, 210, 255),
		Flavor = "Calibrated to the tick of a pulsar.",
	},
	{
		Id = "obsidian_guild",
		Name = "Obsidian Guild",
		Owner = "Guildmaster's",
		Color = Color3.fromRGB(40, 40, 55),
		Flavor = "Struck in obsidian and gold, the guild's colours.",
	},
	{
		Id = "gilded_armada",
		Name = "Gilded Armada",
		Owner = "Armada Captain's",
		Color = Color3.fromRGB(255, 200, 80),
		Flavor = "The armada never lost a battle, or a single bolt.",
	},
	{
		Id = "deep_cartographers",
		Name = "Deep Cartographers",
		Owner = "Cartographer's",
		Color = Color3.fromRGB(110, 200, 210),
		Flavor = "Maps of places that have since moved.",
	},
}

-- { noun, pedestal shape }
local NOUNS: { { string } } = {
	{ "Astrolabe", "Device" },
	{ "Compass", "Device" },
	{ "Crown", "Crown" },
	{ "Engine Core", "Orb" },
	{ "Lens", "Ring" },
	{ "Codex Page", "Tablet" },
	{ "Idol", "Idol" },
	{ "Key", "Shard" },
	{ "Bell", "Idol" },
	{ "Chalice", "Idol" },
	{ "Map Fragment", "Tablet" },
	{ "Medal", "Ring" },
	{ "Helm", "Crown" },
	{ "Lantern", "Orb" },
	{ "Sextant", "Device" },
	{ "Signet Ring", "Ring" },
	{ "Hourglass", "Device" },
	{ "Prism", "Shard" },
	{ "Tuning Fork", "Shard" },
	{ "Gauntlet", "Idol" },
	{ "Beacon", "Orb" },
	{ "Orrery", "Device" },
	{ "Seal", "Tablet" },
	{ "Reliquary", "Idol" },
	{ "Mask", "Idol" },
	{ "Circlet", "Crown" },
	{ "Spindle", "Shard" },
	{ "Censer", "Orb" },
	{ "Scepter", "Shard" },
	{ "Locket", "Ring" },
	{ "Horn", "Idol" },
	{ "Mirror", "Tablet" },
	{ "Anchor", "Idol" },
	{ "Quill", "Shard" },
	{ "Fossil", "Tablet" },
	{ "Dial", "Ring" },
	{ "Totem", "Idol" },
	{ "Star Chart", "Tablet" },
	{ "Gyroscope", "Device" },
	{ "Heartstone", "Orb" },
}

local RARITIES = {
	{ Name = "Rare", Weight = 60 },
	{ Name = "Epic", Weight = 28 },
	{ Name = "Legendary", Weight = 10 },
	{ Name = "Mythic", Weight = 2 },
}

-- Rarity of set slot 1..10.
local RARITY_BY_SLOT = { 1, 1, 1, 1, 2, 2, 2, 3, 3, 4 }
local ITEMS_PER_SET = 10

local UNIQUES: { { any } } = {
	{ "First Voidline Beacon", "Orb", Color3.fromRGB(255, 220, 120), "The light that guided the first crossing." },
	{ "Heart of the Monolith", "Orb", Color3.fromRGB(200, 160, 255), "It beats once every time the Monolith splits." },
	{
		"Creator's Golden Blueprint",
		"Tablet",
		Color3.fromRGB(232, 186, 74),
		"Signed by the architect of the Voidline.",
	},
	{
		"Event Horizon Compass",
		"Device",
		Color3.fromRGB(120, 90, 255),
		"Points at the one place you cannot return from.",
	},
	{ "Sovereign Halo Fragment", "Ring", Color3.fromRGB(255, 240, 180), "A piece of the first drone halo ever flown." },
	{ "Starforged Crown", "Crown", Color3.fromRGB(255, 200, 140), "Forged in a star and cooled in the Void." },
	{ "Antimatter Teardrop", "Shard", Color3.fromRGB(255, 90, 210), "Weighs less than nothing." },
	{ "Silent Choir Bell", "Idol", Color3.fromRGB(150, 170, 255), "Rings only when no one is listening." },
	{ "Obsidian Gate Key", "Shard", Color3.fromRGB(40, 40, 60), "Opens a gate no one has found." },
	{ "Comet Rider's Spur", "Shard", Color3.fromRGB(170, 240, 255), "Worn by the first pilot to ride a comet tail." },
}

local list: { Relic } = {}
local sets: { [string]: { string } } = {}

for _, set in SETS do
	local setRng = ContentUtil.Rng("relic-set", set.Id)
	local nouns = setRng:Sample(NOUNS, ITEMS_PER_SET)
	sets[set.Id] = {}
	for slot = 1, ITEMS_PER_SET do
		local id = ("relic.%s.%02d"):format(set.Id, slot)
		local rng = ContentUtil.Rng("relic", id)
		local noun = nouns[slot]
		local rarityIndex = RARITY_BY_SLOT[slot]
		local color = ContentUtil.ShiftColor(set.Color, rng, 0.05)
		table.insert(list, {
			Id = id,
			Name = set.Owner .. " " .. noun[1],
			Set = set.Id,
			SetName = set.Name,
			Rarity = RARITIES[rarityIndex].Name,
			RarityIndex = rarityIndex,
			Shape = noun[2],
			Color = color,
			Glow = color:Lerp(Color3.new(1, 1, 1), 0.35),
			DropWeight = RARITIES[rarityIndex].Weight,
			Flavor = set.Flavor,
		})
		table.insert(sets[set.Id], id)
	end
end

for _, unique in UNIQUES do
	local id = "relic.mythic." .. ContentUtil.Slug(unique[1])
	table.insert(list, {
		Id = id,
		Name = unique[1],
		Set = "mythic",
		SetName = "Mythic Uniques",
		Rarity = "Mythic",
		RarityIndex = 4,
		Shape = unique[2],
		Color = unique[3],
		Glow = unique[3]:Lerp(Color3.new(1, 1, 1), 0.4),
		DropWeight = 0.5,
		Flavor = unique[4],
	})
end

local registry = ContentUtil.Registry("relic", list) :: any
registry.Sets = SETS
registry.SetMembers = sets
registry.Rarities = RARITIES

local totalWeight = 0
for _, relic in list do
	totalWeight += relic.DropWeight
end

-- Weighted roll over every relic. `rng` exposes NextNumber() in [0, 1).
function registry.Roll(rng: any): Relic
	local pick = rng:NextNumber() * totalWeight
	for _, relic in list do
		pick -= relic.DropWeight
		if pick < 0 then
			return relic
		end
	end
	return list[#list]
end

-- Probability that a single relic roll yields `relicId`.
function registry.Odds(relicId: string): number
	local relic = registry.ById[relicId]
	return if relic then relic.DropWeight / totalWeight else 0
end

function registry.SetComplete(owned: { [string]: any }, setId: string): boolean
	local members = sets[setId]
	if not members then
		return false
	end
	for _, id in members do
		if not owned[id] then
			return false
		end
	end
	return true
end

return registry
