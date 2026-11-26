--!strict
-- Squads of 2-4 pilots: invites by UserId (validated server-side), a shared
-- Squad Challenge, +10% shard luck while a squadmate flies nearby, and the
-- Beam-Link damage bonus for linked squadmates.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Voidline = ReplicatedStorage:WaitForChild("Voidline")
local SquadConfig = require(Voidline.Config.SquadConfig)
local Remotes = require(Voidline.Remotes)

local ValidateRemote = require(script.Parent.Parent.Security.ValidateRemote)
local PlayerDataService = require(script.Parent.PlayerDataService)
local JuiceService = require(script.Parent.JuiceService)
local StatService = require(script.Parent.StatService)
local EconomyService = require(script.Parent.EconomyService)
local WorldState = require(script.Parent.WorldState)
local DroneService = require(script.Parent.DroneService)

local SquadService = {}

local INVITE_SECONDS = 30
local LINK_RANGE = 60
local CHALLENGE_SECONDS = 600
local CHALLENGE_ROCKS_PER_MEMBER = 40
local CHALLENGE_COOLDOWN = 120

type Challenge = { Goal: number, Progress: number, EndsAt: number }
type Squad = { Id: number, Leader: number, Members: { number }, Challenge: Challenge?, NextChallengeAt: number }
type Invite = { From: number, Expires: number }

SquadService._squads = {} :: { [number]: Squad }
SquadService._byPlayer = {} :: { [number]: number }
SquadService._invites = {} :: { [number]: { Invite } }
local nextId = 0

local function squadOf(player: Player): Squad?
	local id = SquadService._byPlayer[player.UserId]
	return if id then SquadService._squads[id] else nil
end
SquadService.SquadOf = squadOf

local function memberPlayers(squad: Squad): { Player }
	local list = {}
	for _, userId in squad.Members do
		local p = Players:GetPlayerByUserId(userId)
		if p then
			table.insert(list, p)
		end
	end
	return list
end

local function broadcast(squad: Squad)
	local members = {}
	for _, p in memberPlayers(squad) do
		table.insert(members, { UserId = p.UserId, Name = p.DisplayName, Leader = p.UserId == squad.Leader })
	end
	local challenge = squad.Challenge
	for _, p in memberPlayers(squad) do
		Remotes.Get("SquadUpdate"):FireClient(p, {
			SquadId = squad.Id,
			Members = members,
			LuckBonus = SquadConfig.LinkedShardLuckBonus,
			Challenge = if challenge
				then { Goal = challenge.Goal, Progress = challenge.Progress, EndsAt = challenge.EndsAt }
				else nil,
		})
	end
end

local function clearClient(player: Player)
	Remotes.Get("SquadUpdate"):FireClient(player, { SquadId = nil, Members = {} })
end

local function startChallenge(squad: Squad, now: number)
	if #squad.Members < SquadConfig.MinSize or squad.Challenge or now < squad.NextChallengeAt then
		return
	end
	local goal = CHALLENGE_ROCKS_PER_MEMBER * #squad.Members
	squad.Challenge = { Goal = goal, Progress = 0, EndsAt = now + CHALLENGE_SECONDS }
	for _, p in memberPlayers(squad) do
		JuiceService.Banner(p, ("SQUAD CHALLENGE · mine %d rocks together"):format(goal), "gold")
	end
	broadcast(squad)
end

local function removeMember(squad: Squad, userId: number)
	local index = table.find(squad.Members, userId)
	if index then
		table.remove(squad.Members, index)
	end
	SquadService._byPlayer[userId] = nil
	if #squad.Members < SquadConfig.MinSize then
		for _, other in squad.Members do
			SquadService._byPlayer[other] = nil
			local p = Players:GetPlayerByUserId(other)
			if p then
				clearClient(p)
				JuiceService.Banner(p, "Squad disbanded", "info")
			end
		end
		SquadService._squads[squad.Id] = nil
		return
	end
	if squad.Leader == userId then
		squad.Leader = squad.Members[1]
	end
	broadcast(squad)
end

function SquadService.Invite(player: Player, targetUserId: number): (boolean, string?)
	local target = Players:GetPlayerByUserId(targetUserId)
	if not target or target == player then
		return false, "target"
	end
	if SquadService._byPlayer[target.UserId] then
		return false, "busy"
	end
	local squad = squadOf(player)
	if squad and #squad.Members >= SquadConfig.MaxSize then
		return false, "full"
	end
	if squad and squad.Leader ~= player.UserId then
		return false, "leader"
	end
	local now = os.clock()
	local pending = SquadService._invites[target.UserId] or {}
	for i = #pending, 1, -1 do
		if pending[i].Expires < now or pending[i].From == player.UserId then
			table.remove(pending, i)
		end
	end
	if #pending >= 3 then
		return false, "busy"
	end
	table.insert(pending, { From = player.UserId, Expires = now + INVITE_SECONDS })
	SquadService._invites[target.UserId] = pending
	JuiceService.Send(
		target,
		"SquadInvite",
		{ FromUserId = player.UserId, FromName = player.DisplayName, Seconds = INVITE_SECONDS }
	)
	JuiceService.Banner(player, ("Invite sent to %s"):format(target.DisplayName), "info")
	return true, nil
end

function SquadService.Respond(player: Player, fromUserId: number, accept: boolean): boolean
	local pending = SquadService._invites[player.UserId]
	if not pending then
		return false
	end
	local now = os.clock()
	local invite: Invite? = nil
	for i = #pending, 1, -1 do
		if pending[i].From == fromUserId then
			invite = table.remove(pending, i)
		elseif pending[i].Expires < now then
			table.remove(pending, i)
		end
	end
	if not invite or invite.Expires < now or not accept then
		return false
	end
	local inviter = Players:GetPlayerByUserId(fromUserId)
	if not inviter or SquadService._byPlayer[player.UserId] then
		return false
	end
	local squad = squadOf(inviter)
	if not squad then
		nextId += 1
		local created: Squad =
			{ Id = nextId, Leader = inviter.UserId, Members = { inviter.UserId }, Challenge = nil, NextChallengeAt = 0 }
		SquadService._squads[nextId] = created
		SquadService._byPlayer[inviter.UserId] = nextId
		squad = created
	end
	local current = squad :: Squad
	if #current.Members >= SquadConfig.MaxSize then
		JuiceService.Banner(player, "That squad is full", "warn")
		return false
	end
	table.insert(current.Members, player.UserId)
	SquadService._byPlayer[player.UserId] = current.Id
	SquadService._invites[player.UserId] = nil
	for _, p in memberPlayers(current) do
		JuiceService.Banner(p, ("%s joined the squad"):format(player.DisplayName), "good")
	end
	broadcast(current)
	startChallenge(current, now)
	return true
end

function SquadService.Leave(player: Player)
	local squad = squadOf(player)
	if squad then
		removeMember(squad, player.UserId)
		clearClient(player)
	end
end

function SquadService.Kick(player: Player, targetUserId: number)
	local squad = squadOf(player)
	if not squad or squad.Leader ~= player.UserId or targetUserId == player.UserId then
		return
	end
	if not table.find(squad.Members, targetUserId) then
		return
	end
	removeMember(squad, targetUserId)
	local target = Players:GetPlayerByUserId(targetUserId)
	if target then
		clearClient(target)
		JuiceService.Banner(target, "You left the squad", "info")
	end
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- Squadmates within `range` of `player` (server positions), optionally only
-- those flying Beam-Link.
function SquadService.NearbyMates(player: Player, range: number, beamLinkOnly: boolean?): number
	local squad = squadOf(player)
	local root = rootOf(player)
	if not squad or not root then
		return 0
	end
	local count = 0
	for _, mate in memberPlayers(squad) do
		if mate ~= player then
			local mateRoot = rootOf(mate)
			local profile = PlayerDataService.Get(mate)
			if mateRoot and profile and (mateRoot.Position - root.Position).Magnitude <= range then
				if not beamLinkOnly or profile.Formation == 2 then
					count += 1
				end
			end
		end
	end
	return count
end

local function onStat(player: Player, stat: string, amount: number)
	if stat ~= "RocksMined" then
		return
	end
	local squad = squadOf(player)
	local challenge = squad and squad.Challenge
	if not squad or not challenge then
		return
	end
	challenge.Progress += amount
	if challenge.Progress >= challenge.Goal then
		squad.Challenge = nil
		squad.NextChallengeAt = os.clock() + CHALLENGE_COOLDOWN
		for _, p in memberPlayers(squad) do
			local profile = PlayerDataService.Get(p)
			local reward = 150 * math.max(1, if profile then profile.StationTier else 1)
			EconomyService.AddCredits(p, reward, "SquadChallenge")
			EconomyService.AddShards(p, 5, "SquadChallenge")
			StatService.Bump(p, "SquadChallenges", 1)
			JuiceService.Send(p, "SquadChallenge", { Credits = reward, Shards = 5 })
		end
	end
	broadcast(squad)
end

function SquadService.TickMinute(now: number)
	for _, squad in SquadService._squads do
		local challenge = squad.Challenge
		if challenge and now >= challenge.EndsAt then
			squad.Challenge = nil
			squad.NextChallengeAt = now + CHALLENGE_COOLDOWN
			for _, p in memberPlayers(squad) do
				JuiceService.Banner(p, "Squad challenge expired · a new one starts soon", "info")
			end
			broadcast(squad)
		end
		startChallenge(squad, now)
		if #squad.Members >= SquadConfig.MinSize then
			for _, p in memberPlayers(squad) do
				StatService.Bump(p, "SquadMinutes", 1)
			end
		end
	end
end

function SquadService.Init()
	WorldState.SquadLinked = function(player: Player): boolean
		return SquadService.NearbyMates(player, LINK_RANGE) > 0
	end
	DroneService.LinkedSquadmates = function(player: Player, range: number): number
		return SquadService.NearbyMates(player, range, true)
	end
	StatService.Listen(onStat)

	ValidateRemote.Bind("SquadInvite", { Rate = 2, Burst = 3, Args = { "integer" } }, function(player, targetUserId)
		local ok, reason = SquadService.Invite(player, targetUserId)
		if not ok then
			JuiceService.Send(player, "SquadError", { Reason = reason })
		end
	end)
	ValidateRemote.Bind(
		"SquadRespond",
		{ Rate = 0.5, Burst = 3, Args = { "integer", "boolean" } },
		function(player, fromUserId, accept)
			SquadService.Respond(player, fromUserId, accept)
		end
	)
	ValidateRemote.Bind("SquadLeave", { Rate = 1, Burst = 2 }, function(player)
		SquadService.Leave(player)
	end)
	ValidateRemote.Bind("SquadKick", { Rate = 1, Burst = 2, Args = { "integer" } }, function(player, targetUserId)
		SquadService.Kick(player, targetUserId)
	end)

	Players.PlayerRemoving:Connect(function(player)
		local squad = squadOf(player)
		if squad then
			removeMember(squad, player.UserId)
		end
		SquadService._invites[player.UserId] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(60)
			SquadService.TickMinute(os.clock())
		end
	end)
end

return SquadService
