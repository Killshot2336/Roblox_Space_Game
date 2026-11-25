-- Shared type documentation (Luau). Runtime tables use these shapes.
export type GalaxyFlags = {
	Starter: boolean,
	Nebula: boolean,
	VoidRim: boolean,
	Celestial: boolean,
}

export type PlayerProfile = {
	Credits: number,
	Ore: number,
	VoidShards: number,
	VoidlineTokens: number,
	Rebirths: number,
	CreditMult: number,
	StationTier: number,
	DrillLevel: number,
	CargoLevel: number,
	DroneSlots: number,
	DroneTier: number,
	GalaxyFlags: GalaxyFlags,
	OwnedPerks: { [string]: boolean },
	RedeemedCodes: { [string]: boolean },
	TutorialStep: number,
	TutorialComplete: boolean,
	Settings: {
		PerfMode: boolean,
		HideJetpack: boolean,
		ClipMode: boolean,
		LaserColor: string,
	},
	Cosmetics: { Title: string? },
	ForgeTokensEarnedToday: number,
	ForgeDayKey: string,
	DailyStreak: number,
	LastLoginDay: string,
	TrialVouchers: { [string]: number }, -- perkId -> expiry os.time
	Codex: { [string]: boolean },
	Relics: { [string]: boolean },
	PlotIndex: number?,
	Formation: number,
	Version: number,
}

return {}
