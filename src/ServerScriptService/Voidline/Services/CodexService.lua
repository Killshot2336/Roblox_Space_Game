--!strict
-- Voidline Codex: every ore, anomaly, hazard, relic, drone evolution,
-- cosmetic and world event a pilot has witnessed. Discoveries are permanent
-- and feed the Codex milestone credit multiplier.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Voidline = ReplicatedStorage:WaitForChild("Voidline")
local ContentIndex = require(Voidline.Content.ContentIndex)
local DroneRegistry = require(Voidline.Content.DroneRegistry)

local PlayerDataService = require(script.Parent.PlayerDataService)
local JuiceService = require(script.Parent.JuiceService)
local StatService = require(script.Parent.StatService)

local CodexService = {}

local function milestoneFor(count: number): number?
	for _, milestone in ContentIndex.CodexMilestones do
		if milestone.Count == count then
			return milestone.Bonus
		end
	end
	return nil
end

-- Records a discovery. Returns true the first time. `quiet` skips the toast
-- (used for back-filling things a pilot already owns).
function CodexService.Discover(player: Player, id: string, quiet: boolean?): boolean
	if not ContentIndex.IsCodexId(id) then
		return false
	end
	local session = PlayerDataService.Session(player)
	if not session or session.Profile.Codex[id] ~= nil then
		return false
	end
	session.Profile.Codex[id] = os.time()
	session.Dirty = true
	session.CodexCount += 1
	local entry, kind = ContentIndex.Get(id)
	if kind == "ore" then
		StatService.Bump(player, "OreTier:" .. tostring(entry.TierIndex), 1)
	end
	if not quiet then
		JuiceService.Send(player, "Codex", { Id = id, Count = session.CodexCount, Total = ContentIndex.CodexTotal })
	end
	local bonus = milestoneFor(session.CodexCount)
	if bonus then
		JuiceService.Send(player, "CodexMilestone", {
			Count = session.CodexCount,
			Multiplier = ContentIndex.CodexMultiplier(session.CodexCount),
		})
	end
	StatService.Check(player, "CodexCount")
	return true
end

function CodexService.Count(player: Player): number
	local session = PlayerDataService.Session(player)
	return if session then session.CodexCount else 0
end

-- Back-fills entries for things the pilot already has (evolutions reached,
-- unlocked cosmetics, owned relics) so old saves start with a fair Codex.
function CodexService.SyncOwned(player: Player)
	local profile = PlayerDataService.Get(player)
	if not profile then
		return
	end
	for stage = 1, profile.DroneTier do
		CodexService.Discover(player, DroneRegistry.EvolutionFor(stage, profile.DroneBranch).Id, true)
	end
	for id in profile.Unlocks do
		CodexService.Discover(player, id, true)
	end
	for id in profile.Relics do
		CodexService.Discover(player, id, true)
	end
end

function CodexService.Init()
	PlayerDataService.OnLoaded(function(player)
		task.defer(CodexService.SyncOwned, player)
	end)
end

return CodexService
