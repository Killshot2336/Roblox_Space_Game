--!strict
-- Spec §5 Galaxy Sectors (no reset): a sector, once reached, stays discovered
-- in GalaxyFlags forever. The *active* belt sector follows current tiers so a
-- rebirth (which resets Station Tier) also resets belt richness.
local GalaxyConfig = {}

export type Sector = {
	Id: string,
	Label: string,
	StationTier: number,
	DroneTier: number,
	RequiresRebirthReady: boolean?,
}

GalaxyConfig.Sectors = {
	{ Id = "Starter", Label = "Starter Belt", StationTier = 0, DroneTier = 0 },
	{ Id = "Nebula", Label = "Nebula Ring", StationTier = 3, DroneTier = 0 },
	{ Id = "VoidRim", Label = "Void Rim", StationTier = 6, DroneTier = 2 },
	{
		Id = "Celestial",
		Label = "Celestial Orbit",
		StationTier = 10,
		DroneTier = 2,
		RequiresRebirthReady = true,
	},
} :: { Sector }

type TierHolder = { StationTier: number, DroneTier: number }

function GalaxyConfig.IsUnlocked(sectorId: string, data: TierHolder): boolean
	for _, sector in GalaxyConfig.Sectors do
		if sector.Id == sectorId then
			if data.StationTier < sector.StationTier then
				return false
			end
			if data.DroneTier < sector.DroneTier then
				return false
			end
			if sector.RequiresRebirthReady and data.StationTier < 10 then
				return false
			end
			return true
		end
	end
	return false
end

-- Highest sector the current tiers reach.
function GalaxyConfig.ActiveSector(data: TierHolder): string
	local best = "Starter"
	for _, sector in GalaxyConfig.Sectors do
		if GalaxyConfig.IsUnlocked(sector.Id, data) then
			best = sector.Id
		end
	end
	return best
end

function GalaxyConfig.Label(sectorId: string): string
	for _, sector in GalaxyConfig.Sectors do
		if sector.Id == sectorId then
			return sector.Label
		end
	end
	return sectorId
end

return GalaxyConfig
