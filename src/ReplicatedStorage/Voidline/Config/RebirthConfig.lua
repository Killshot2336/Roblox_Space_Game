local RebirthConfig = {
	RequiredStationTier = 10,
	CreditMultPerRebirth = 0.25,
	ShardBase = 10,
	ShardPerRebirth = 5,
}

function RebirthConfig.CreditMultiplier(rebirths: number): number
	return 1 + RebirthConfig.CreditMultPerRebirth * rebirths
end

function RebirthConfig.ShardPayout(rebirthNumber: number): number
	return RebirthConfig.ShardBase + RebirthConfig.ShardPerRebirth * rebirthNumber
end

return RebirthConfig
