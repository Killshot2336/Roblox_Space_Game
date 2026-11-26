--!strict
-- Diegetic ~45 s onboarding. TutorialRules owns the state machine; this
-- service relays step changes to the client (golden floor beams + ticker),
-- lights the Energy Bridge on completion and handles the tiny Skip button.
local AnalyticsService = game:GetService("AnalyticsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Voidline = ReplicatedStorage:WaitForChild("Voidline")
local TutorialRules = require(Voidline.Rules.TutorialRules)
local Remotes = require(Voidline.Remotes)

local ValidateRemote = require(script.Parent.Parent.Security.ValidateRemote)
local PlayerDataService = require(script.Parent.PlayerDataService)
local PlotService = require(script.Parent.PlotService)
local JuiceService = require(script.Parent.JuiceService)
local StatService = require(script.Parent.StatService)

local TutorialService = {}

-- The bridge ignition owns the screen; achievements earned during
-- onboarding are granted a beat later.
TutorialService.ACHIEVEMENT_DELAY = 3.5

local function funnel(player: Player, step: number, name: string)
	pcall(function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, step, name)
	end)
end

local function send(player: Player, profile: any, change: TutorialRules.Change?)
	Remotes.Get("TutorialProgress"):FireClient(player, {
		Step = profile.TutorialStep,
		Complete = profile.TutorialComplete,
		Skipped = profile.TutorialSkipped,
		Next = TutorialRules.NextUpgrade(profile),
		Bonus = if change then change.Bonus else 0,
	})
end

local function apply(player: Player, mutate: (any) -> TutorialRules.Change?)
	local profile = PlayerDataService.Get(player)
	if not profile or profile.TutorialComplete then
		return
	end
	local change: TutorialRules.Change? = nil
	PlayerDataService.Mutate(player, function(p)
		change = mutate(p)
	end)
	if not change then
		-- Flags may still have moved (e.g. an upgrade bought early).
		send(player, profile, nil)
		return
	end
	send(player, profile, change)
	local resolved = change :: TutorialRules.Change
	funnel(player, resolved.Step + 1, TutorialRules.Steps[resolved.Step].Ticker)
	if resolved.Completed then
		PlotService.IgniteBridge(player)
		JuiceService.Send(player, "BridgeIgnite", { Bonus = resolved.Bonus, Skipped = profile.TutorialSkipped })
		-- Persist the bonus right away so a quick leave cannot lose it.
		task.spawn(PlayerDataService.Save, player)
		task.delay(TutorialService.ACHIEVEMENT_DELAY, function()
			if PlayerDataService.IsLoaded(player) then
				StatService.CheckAll(player)
			end
		end)
	end
end

function TutorialService.OnOreStored(player: Player)
	apply(player, TutorialRules.OnOreStored)
end

function TutorialService.OnSold(player: Player)
	apply(player, TutorialRules.OnSold)
end

function TutorialService.OnUpgrade(player: Player, upgradeId: string)
	apply(player, function(profile)
		return TutorialRules.OnUpgrade(profile, upgradeId)
	end)
end

function TutorialService.Init()
	PlayerDataService.OnLoaded(function(player, profile)
		send(player, profile, nil)
		if not profile.TutorialComplete and profile.TutorialStep == 1 then
			funnel(player, 1, "Joined")
		end
	end)
	ValidateRemote.Bind("TutorialSkip", { Rate = 0.5, Burst = 2 }, function(player)
		apply(player, TutorialRules.Skip)
	end)
end

return TutorialService
