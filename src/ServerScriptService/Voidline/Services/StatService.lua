--!strict
-- Single entry point for "something happened" counters: bumps the stat,
-- advances daily/weekly quests and grants achievements, then tells the pilot.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Voidline = ReplicatedStorage:WaitForChild("Voidline")
local ProfileSchema = require(Voidline.Modules.ProfileSchema)
local AchievementRules = require(Voidline.Rules.AchievementRules)
local QuestRules = require(Voidline.Rules.QuestRules)

local PlayerDataService = require(script.Parent.PlayerDataService)
local JuiceService = require(script.Parent.JuiceService)

local StatService = {}

local rng = Random.new()
local listeners: { (Player, string, number) -> () } = {}

-- Server-side observers of counter bumps (squad challenges, etc.).
function StatService.Listen(fn: (Player, string, number) -> ())
	table.insert(listeners, fn)
end

local function announce(player: Player, grants: { AchievementRules.Grant }, completions: { QuestRules.Completion })
	for _, grant in grants do
		JuiceService.Send(player, "Achievement", {
			Name = grant.Name,
			Credits = grant.Credits,
			Shards = grant.Shards,
			Title = grant.Title,
			Unlock = grant.Unlock,
		})
	end
	for _, completion in completions do
		JuiceService.Send(player, "Quest", {
			Name = completion.Name,
			Credits = completion.Credits,
			Shards = completion.Shards,
			Unlock = completion.Unlock,
		})
	end
end

-- Adds `amount` to a counter stat and runs quests + achievements for it.
-- During onboarding only the counter moves: rewards wait until the bridge
-- is lit so the tutorial economy stays exact (CheckAll runs on completion).
function StatService.Bump(player: Player, stat: string, amount: number?)
	local n = amount or 1
	if n ~= n or n <= 0 then
		return
	end
	local grants: { AchievementRules.Grant } = {}
	local completions: { QuestRules.Completion } = {}
	PlayerDataService.Mutate(player, function(profile)
		ProfileSchema.Bump(profile, stat, n)
		if not profile.TutorialComplete then
			return
		end
		completions = QuestRules.Progress(profile, stat, n, rng)
		grants = AchievementRules.Check(profile, stat, os.time())
		-- Quest payouts move credits/shards; let those ladders catch up.
		if #completions > 0 then
			for _, follow in { "LifetimeCredits", "LifetimeShards" } do
				for _, grant in AchievementRules.Check(profile, follow, os.time()) do
					table.insert(grants, grant)
				end
			end
		end
	end)
	announce(player, grants, completions)
	for _, fn in listeners do
		task.spawn(fn, player, stat, n)
	end
end

-- Quest-only progress for values that live outside Stats (e.g. CreditsEarned).
function StatService.Quest(player: Player, stat: string, amount: number)
	StatService.Bump(player, stat, amount)
end

-- Re-checks achievements for a profile field that changed (Credits, StationTier...).
function StatService.Check(player: Player, ...: string)
	local stats = { ... }
	local grants: { AchievementRules.Grant } = {}
	PlayerDataService.Mutate(player, function(profile)
		if not profile.TutorialComplete then
			return
		end
		for _, stat in stats do
			for _, grant in AchievementRules.Check(profile, stat, os.time()) do
				table.insert(grants, grant)
			end
		end
	end)
	announce(player, grants, {})
end

function StatService.CheckAll(player: Player)
	StatService.Check(player, table.unpack(AchievementRules.AllStats()))
end

function StatService.Init()
	PlayerDataService.OnLoaded(function(player, profile)
		QuestRules.Refresh(profile, os.time(), player.UserId)
		PlayerDataService.MarkDirty(player)
		task.defer(StatService.CheckAll, player)
	end)
	-- Roll quests over at UTC midnight / Monday for pilots who stay online.
	task.spawn(function()
		while true do
			task.wait(30)
			for _, session in PlayerDataService._sessions do
				if QuestRules.Refresh(session.Profile, os.time(), session.UserId) then
					session.Dirty = true
					JuiceService.Banner(session.Player, "New quests are live", "gold")
				end
			end
		end
	end)
end

return StatService
