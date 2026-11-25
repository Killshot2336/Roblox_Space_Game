--[[
	Voidline: Deep Space — server boot
	Init order matches GAME_DESIGN.md architecture.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Voidline = ReplicatedStorage:WaitForChild("Voidline")
local Remotes = require(Voidline.Remotes)
Remotes.Ensure()

local Services = script.Parent.Services

local MapBuilder = require(Services.MapBuilder)
MapBuilder.Build()

local PlayerDataService = require(Services.PlayerDataService)
local PlotService = require(Services.PlotService)
local EconomyService = require(Services.EconomyService)
local SoftContestService = require(Services.SoftContestService)
local TowService = require(Services.TowService)
local DroneService = require(Services.DroneService)
local WorldEventService = require(Services.WorldEventService)
local ForgeService = require(Services.ForgeService)
local RebirthService = require(Services.RebirthService)
local SquadService = require(Services.SquadService)
local MonetizationService = require(Services.MonetizationService)
local CodeService = require(Services.CodeService)
local DailyStreakService = require(Services.DailyStreakService)
local AfkService = require(Services.AfkService)
local JuiceService = require(Services.JuiceService)
local LeaderboardService = require(Services.LeaderboardService)
local CodexService = require(Services.CodexService)
local WarpService = require(Services.WarpService)

PlayerDataService.Init()
PlotService.Init()
EconomyService.Init()
SoftContestService.Init()
TowService.Init()
DroneService.Init()
WorldEventService.Init()
ForgeService.Init()
RebirthService.Init()
SquadService.Init()
MonetizationService.Init()
CodeService.Init()
DailyStreakService.Init()
AfkService.Init()
JuiceService.Init()
LeaderboardService.Init()
CodexService.Init()
WarpService.Init()

print("[Voidline] Boot complete — Voidline: Deep Space v1 online")
