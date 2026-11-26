--!strict
-- Pilot Cards: a compact, read-only summary of another pilot in the server.
-- Only registry names and numbers are sent (no free text from players).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Voidline = ReplicatedStorage:WaitForChild("Voidline")
local Remotes = require(Voidline.Remotes)
local TitleRegistry = require(Voidline.Content.TitleRegistry)
local DroneRegistry = require(Voidline.Content.DroneRegistry)
local RelicRegistry = require(Voidline.Content.RelicRegistry)
local CitadelRegistry = require(Voidline.Content.CitadelRegistry)

local ValidateRemote = require(script.Parent.Parent.Security.ValidateRemote)
local PlayerDataService = require(script.Parent.PlayerDataService)

local InspectService = {}

local function count(map: { [any]: any }): number
	local n = 0
	for _ in map do
		n += 1
	end
	return n
end

function InspectService.Card(target: Player): { [string]: any }?
	local session = PlayerDataService.Session(target)
	if not session then
		return nil
	end
	local profile = session.Profile
	local title = TitleRegistry.ById[profile.Cosmetics.Title]
	local evolution = DroneRegistry.EvolutionFor(profile.DroneTier, profile.DroneBranch)
	local relics = {}
	for _, relicId in profile.RelicDisplay do
		local relic = RelicRegistry.ById[relicId]
		if relic and #relics < 3 then
			table.insert(relics, relic.Name)
		end
	end
	return {
		UserId = target.UserId,
		Name = target.DisplayName,
		Title = if title then title.Name else "",
		StationTier = profile.StationTier,
		Citadel = CitadelRegistry.ForTier(profile.StationTier).Name,
		Rebirths = profile.Rebirths,
		Codex = session.CodexCount,
		Relics = count(profile.Relics),
		Achievements = count(profile.Achievements),
		Drone = evolution.Name,
		Drones = target:GetAttribute("DroneCount") or 1,
		Formation = profile.Formation,
		Streak = profile.DailyStreak,
		Showcase = relics,
	}
end

function InspectService.Init()
	ValidateRemote.Bind("InspectPilot", { Rate = 1, Burst = 3, Args = { "integer" } }, function(player, targetUserId)
		local target = Players:GetPlayerByUserId(targetUserId)
		if not target then
			return
		end
		local card = InspectService.Card(target)
		if card then
			Remotes.Get("InspectResult"):FireClient(player, card)
		end
	end)
end

return InspectService
