--[[
	Voidline: Deep Space — server boot.
	Order: remotes -> map -> services (callbacks registered) -> start loading
	profiles. A service whose Init throws is logged and skipped so one broken
	feature cannot take the whole server down.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Voidline = ReplicatedStorage:WaitForChild("Voidline")
local Remotes = require(Voidline.Remotes)
Remotes.Ensure()

local Services = script.Parent.Services

require(Services.MapBuilder).Build()

local ORDER = {
	"PlayerDataService",
	"WorldState",
	"JuiceService",
	"StatService",
	"CodexService",
	"PlotService",
	"RockService",
	"TowService",
	"TutorialService",
	"EconomyService",
	"RelicService",
	"BeltService",
	"DroneService",
	"SoftContestService",
	"RiftService",
	"WorldEventService",
	"ForgeService",
	"RebirthService",
	"CodeService",
	"DailyStreakService",
	"SummonService",
	"MonetizationService",
	"LeaderboardService",
	"AfkService",
	"SquadService",
	"WarpService",
	"CosmeticService",
	"CitadelService",
	"InspectService",
}

local failed = {}
for _, name in ORDER do
	local service = require(Services[name])
	local ok, err = xpcall(service.Init, debug.traceback)
	if not ok then
		table.insert(failed, name)
		warn(("[Voidline] %s.Init failed: %s"):format(name, tostring(err)))
	end
end

require(Services.PlayerDataService).Start()

if #failed == 0 then
	print("[Voidline] Boot complete — Voidline: Deep Space online")
else
	warn("[Voidline] Boot finished with failures: " .. table.concat(failed, ", "))
end
