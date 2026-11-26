--!strict
-- Nameplate titles. Rebirth titles VOID I..L, owner-named titles, pass/code
-- titles, achievement ladder titles, relic-set curators and anomaly witnesses.
-- FROZEN lists: append-only (see ContentUtil).
local ContentUtil = require(script.Parent.ContentUtil)
local RelicRegistry = require(script.Parent.RelicRegistry)
local BiomeRegistry = require(script.Parent.BiomeRegistry)

export type Title = {
	Id: string,
	Name: string,
	Source: string,
	Rarity: string,
	Color: Color3,
}

local GOLD = Color3.fromRGB(255, 215, 110)
local VOID = Color3.fromRGB(170, 110, 255)
local CYAN = Color3.fromRGB(110, 220, 255)
local WHITE = Color3.fromRGB(235, 235, 245)

local VOID_TITLES = 50

local HANDMADE: { { string } } = {
	-- id, name, source, rarity
	{ "title.star_breaker", "STAR BREAKER", "Top contributor on 10 boss meteors", "Legendary" },
	{ "title.monolith_architect", "MONOLITH ARCHITECT", "Reach Station Tier 25", "Legendary" },
	{ "title.event_horizon", "EVENT HORIZON", "Evolve to Omega Antimatter", "Mythic" },
	{ "title.pass.pioneer", "PIONEER", "Starter Bundle", "Rare" },
	{ "title.pass.void_sovereign", "VOID SOVEREIGN", "Void Sovereign VIP", "Legendary" },
	{ "title.pass.eternal_architect", "ETERNAL ARCHITECT", "Eternal Architect", "Legendary" },
	{ "title.code.voidline", "VOIDLINER", "Code VOIDLINE", "Common" },
	{ "title.code.killshot", "KILLSHOT'S CREW", "Code KILLSHOT", "Rare" },
	{ "title.code.launch", "LAUNCH CREW", "Code LAUNCH", "Rare" },
	{ "title.sector.nebula", "NEBULA DRIFTER", "Discover the Nebula Ring", "Common" },
	{ "title.sector.voidrim", "RIM WALKER", "Discover the Void Rim", "Rare" },
	{ "title.sector.celestial", "CELESTIAL", "Discover Celestial Orbit", "Epic" },
	{ "title.formation.scatter", "SCATTERSHOT", "Fly the Scatter formation", "Common" },
	{ "title.formation.beam_link", "BEAM-LINKED", "Fly the Orbital Beam-Link", "Common" },
	{ "title.formation.halo", "HALO BEARER", "Fly the Sovereign Halo", "Common" },
	{ "title.event.starfall", "STARFALL CHASER", "Join a Void Starfall", "Rare" },
	{ "title.event.rift", "RIFT RUNNER", "Clear the Void Rift 5 times", "Epic" },
	{ "title.squad.captain", "SQUAD CAPTAIN", "Fly 300 minutes in a squad", "Epic" },
	{ "title.streak.seven", "SEVEN SUNS", "Claim 7 daily rewards", "Rare" },
	{ "title.forge.smith", "VOIDSMITH", "Forge 10 artifacts", "Rare" },
	{ "title.codex.scholar", "CODEX SCHOLAR", "Log 100 Codex entries", "Epic" },
	{ "title.codex.archivist", "GRAND ARCHIVIST", "Log 650 Codex entries", "Mythic" },
	{ "title.branch.miner", "DEEP DRILLER", "Choose the Miner drone line", "Rare" },
	{ "title.branch.hauler", "GRAVITY HAULER", "Choose the Hauler drone line", "Rare" },
	{ "title.branch.swarm", "SWARM MIND", "Choose the Swarm drone line", "Rare" },
	{ "title.ladder.credits.1", "CREDIT BARON", "Earn 1M lifetime Credits", "Rare" },
	{ "title.ladder.credits.2", "TYCOON", "Earn 1B lifetime Credits", "Epic" },
	{ "title.ladder.credits.3", "STAR MAGNATE", "Earn 100B lifetime Credits", "Legendary" },
	{ "title.ladder.rocks.1", "ROCK BREAKER", "Break 100 rocks", "Common" },
	{ "title.ladder.rocks.2", "BELT BANE", "Break 5K rocks", "Rare" },
	{ "title.ladder.rocks.3", "ASTEROID REAPER", "Break 100K rocks", "Legendary" },
	{ "title.ladder.shards.1", "SHARD SEEKER", "Find 100 Void Shards", "Rare" },
	{ "title.ladder.shards.2", "SHARD HOARDER", "Find 5K Void Shards", "Epic" },
	{ "title.ladder.relics.1", "RELIC HUNTER", "Collect 25 relics", "Rare" },
	{ "title.ladder.relics.2", "RELIC LORD", "Collect 150 relics", "Legendary" },
	{ "title.ladder.meteors.1", "METEOR BRAWLER", "Qualify on 50 boss meteors", "Rare" },
}

local RARITY_COLORS = {
	Common = WHITE,
	Rare = CYAN,
	Epic = VOID,
	Legendary = GOLD,
	Mythic = Color3.fromRGB(255, 120, 200),
}

local list: { Title } = {}

for n = 1, VOID_TITLES do
	table.insert(list, {
		Id = "title.void." .. n,
		Name = "VOID " .. ContentUtil.Roman(n),
		Source = "Rebirth " .. n,
		Rarity = if n >= 25 then "Mythic" elseif n >= 10 then "Legendary" elseif n >= 5 then "Epic" else "Rare",
		Color = VOID:Lerp(GOLD, math.min(1, (n - 1) / 24)),
	})
end

for _, entry in HANDMADE do
	table.insert(list, {
		Id = entry[1],
		Name = entry[2],
		Source = entry[3],
		Rarity = entry[4],
		Color = RARITY_COLORS[entry[4]],
	})
end

for _, set in RelicRegistry.Sets do
	table.insert(list, {
		Id = "title.curator." .. set.Id,
		Name = string.upper(set.Name) .. " CURATOR",
		Source = "Complete the " .. set.Name .. " relic set",
		Rarity = "Epic",
		Color = set.Color:Lerp(WHITE, 0.3),
	})
end

for _, archetype in BiomeRegistry.Archetypes do
	table.insert(list, {
		Id = "title.witness." .. archetype.Id,
		Name = string.upper(archetype.Name) .. " WITNESS",
		Source = "Witness a " .. archetype.Name,
		Rarity = "Rare",
		Color = archetype.Tint,
	})
end

local registry = ContentUtil.Registry("title", list) :: any
registry.RarityColors = RARITY_COLORS

function registry.VoidTitleId(rebirths: number): string?
	if rebirths < 1 then
		return nil
	end
	return "title.void." .. math.min(rebirths, VOID_TITLES)
end

return registry
