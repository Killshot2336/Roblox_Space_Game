local EconomyConfig = require(script.Parent.Parent.Config.EconomyConfig)

local OreMath = {}

function OreMath.SellValue(oreAmount: number, sectorId: string, creditMult: number, has2x: boolean): number
	local per = EconomyConfig.OreValueBySector[sectorId] or EconomyConfig.CreditsPerOreBase
	local value = oreAmount * per * creditMult
	if has2x then
		value *= 2
	end
	return math.floor(value)
end

function OreMath.CargoCap(cargoLevel: number): number
	return EconomyConfig.CargoCapacityForLevel(cargoLevel)
end

return OreMath
