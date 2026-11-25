local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Voidline = ReplicatedStorage:WaitForChild("Voidline")
local SquadConfig = require(Voidline.Config.SquadConfig)
local Remotes = require(Voidline.Remotes)
local RateLimiter = require(Voidline.Modules.RateLimiter)

local SquadService = {
	_squads = {} :: { [string]: { number } }, -- squadId -> userIds
	_byPlayer = {} :: { [number]: string },
	_limiter = RateLimiter.new(0.5),
}

local function replicate(squadId: string)
	local members = SquadService._squads[squadId] or {}
	local names = {}
	for _, userId in members do
		local p = Players:GetPlayerByUserId(userId)
		if p then
			table.insert(names, p.DisplayName)
		end
	end
	for _, userId in members do
		local p = Players:GetPlayerByUserId(userId)
		if p then
			Remotes.Get("SquadUpdate"):FireClient(p, {
				SquadId = squadId,
				Members = names,
				LuckBonus = SquadConfig.LinkedShardLuckBonus,
			})
		end
	end
end

function SquadService.GetLuckBonus(player: Player): number
	local sid = SquadService._byPlayer[player.UserId]
	if not sid then
		return 0
	end
	local members = SquadService._squads[sid]
	if members and #members >= SquadConfig.MinSize then
		return SquadConfig.LinkedShardLuckBonus
	end
	return 0
end

function SquadService.Init()
	Remotes.Get("SquadInvite").OnServerEvent:Connect(function(player, targetName)
		if not SquadService._limiter:Allow(player.UserId) then
			return
		end
		if typeof(targetName) ~= "string" then
			return
		end
		local target = nil
		for _, p in Players:GetPlayers() do
			if string.lower(p.Name) == string.lower(targetName)
				or string.lower(p.DisplayName) == string.lower(targetName) then
				target = p
				break
			end
		end
		if not target or target == player then
			return
		end
		local sid = SquadService._byPlayer[player.UserId]
		if not sid then
			sid = "squad_" .. player.UserId .. "_" .. tostring(os.time())
			SquadService._squads[sid] = { player.UserId }
			SquadService._byPlayer[player.UserId] = sid
		end
		local members = SquadService._squads[sid]
		if #members >= SquadConfig.MaxSize then
			return
		end
		if SquadService._byPlayer[target.UserId] then
			return
		end
		table.insert(members, target.UserId)
		SquadService._byPlayer[target.UserId] = sid
		replicate(sid)
	end)

	Remotes.Get("SquadLeave").OnServerEvent:Connect(function(player)
		local sid = SquadService._byPlayer[player.UserId]
		if not sid then
			return
		end
		local members = SquadService._squads[sid]
		if members then
			for i = #members, 1, -1 do
				if members[i] == player.UserId then
					table.remove(members, i)
				end
			end
			if #members == 0 then
				SquadService._squads[sid] = nil
			else
				replicate(sid)
			end
		end
		SquadService._byPlayer[player.UserId] = nil
		Remotes.Get("SquadUpdate"):FireClient(player, { SquadId = nil, Members = {} })
	end)

	Remotes.Get("SquadKick").OnServerEvent:Connect(function(player, targetName)
		local sid = SquadService._byPlayer[player.UserId]
		if not sid then
			return
		end
		-- Leader is creator (first member)
		local members = SquadService._squads[sid]
		if not members or members[1] ~= player.UserId then
			return
		end
		for _, p in Players:GetPlayers() do
			if p.Name == targetName or p.DisplayName == targetName then
				for i = #members, 1, -1 do
					if members[i] == p.UserId then
						table.remove(members, i)
					end
				end
				SquadService._byPlayer[p.UserId] = nil
				Remotes.Get("SquadUpdate"):FireClient(p, { SquadId = nil, Members = {} })
				replicate(sid)
				break
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		local sid = SquadService._byPlayer[player.UserId]
		if not sid then
			return
		end
		local members = SquadService._squads[sid]
		if members then
			for i = #members, 1, -1 do
				if members[i] == player.UserId then
					table.remove(members, i)
				end
			end
			if #members == 0 then
				SquadService._squads[sid] = nil
			else
				replicate(sid)
			end
		end
		SquadService._byPlayer[player.UserId] = nil
	end)
end

return SquadService
