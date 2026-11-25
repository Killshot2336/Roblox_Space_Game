local GalaxyConfig = {
	Sectors = {
		{ Id = "Starter", Label = "Starter Belt", StationTier = 0, DroneTier = 0 },
		{ Id = "Nebula", Label = "Nebula Ring", StationTier = 3, DroneTier = 0 },
		{ Id = "VoidRim", Label = "Void Rim", StationTier = 6, DroneTier = 2 },
		{ Id = "Celestial", Label = "Celestial Orbit", StationTier = 10, DroneTier = 2, RequiresRebirthReady = true },
	},
}

function GalaxyConfig.IsUnlocked(sectorId: string, data): boolean
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

return GalaxyConfig
