local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Voidline = ReplicatedStorage:WaitForChild("Voidline")
local DroneConfig = require(Voidline.Config.DroneConfig)
local Remotes = require(Voidline.Remotes)
local PlayerDataService = require(script.Parent.PlayerDataService)
local PlotService = require(script.Parent.PlotService)
local EconomyService = require(script.Parent.EconomyService)

local DroneService = {
	_drones = {} :: { [number]: { Model } },
	_targets = {} :: { [number]: BasePart? },
	_afk = {} :: { [number]: boolean },
	_towing = {} :: { [number]: BasePart? },
}

local function laserColorFor(player: Player): Color3
	local data = PlayerDataService.Get(player)
	local key = (data and data.Settings.LaserColor) or DroneConfig.DefaultLaserColor
	return DroneConfig.LaserColors[key] or DroneConfig.LaserColors.Gold
end

local function makeDrone(player: Player, index: number): Model
	local model = Instance.new("Model")
	model.Name = "VoidlineDrone_" .. index
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Shape = Enum.PartType.Ball
	body.Size = Vector3.new(2.2, 2.2, 2.2)
	body.Material = Enum.Material.Metal
	body.Color = Color3.fromRGB(18, 18, 24)
	body.Anchored = true
	body.CanCollide = false
	body.Parent = model
	local trim = Instance.new("Part")
	trim.Name = "Trim"
	trim.Size = Vector3.new(2.6, 0.3, 2.6)
	trim.Material = Enum.Material.Neon
	trim.Color = Color3.fromRGB(232, 186, 74)
	trim.Anchored = true
	trim.CanCollide = false
	trim.Parent = model
	model.PrimaryPart = body
	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("Index", index)
	model.Parent = Workspace:FindFirstChild("VoidlineMap") or Workspace
	return model
end

function DroneService.SyncCount(player: Player)
	local data = PlayerDataService.Get(player)
	if not data then
		return
	end
	local list = DroneService._drones[player.UserId]
	if not list then
		list = {}
		DroneService._drones[player.UserId] = list
	end
	local bonus = 0
	if PlayerDataService.HasPerk(player, "DroneSlots3") then
		bonus += 3
	end
	if PlayerDataService.HasPerk(player, "MegaSwarm5") then
		bonus += 5
	end
	local want = data.DroneSlots + bonus
	while #list < want do
		table.insert(list, makeDrone(player, #list + 1))
	end
	while #list > want do
		local d = table.remove(list)
		if d then
			d:Destroy()
		end
	end
end

local function findNearestAsteroid(player: Player, origin: Vector3): BasePart?
	local plot = PlotService.GetPlayerPlot(player)
	local best: BasePart? = nil
	local bestDist = math.huge
	local function consider(folder: Instance?)
		if not folder then
			return
		end
		for _, child in folder:GetDescendants() do
			if child:IsA("BasePart") and child:GetAttribute("Health") and (child:GetAttribute("Health") :: number) > 0 then
				if child:GetAttribute("Shared") == true then
					-- deep space handled separately preference when formation beam-link
				end
				local dist = (child.Position - origin).Magnitude
				if dist < bestDist and dist <= DroneConfig.MineRange * 3 then
					best = child
					bestDist = dist
				end
			end
		end
	end
	if plot then
		consider(plot:FindFirstChild("PersonalBelt"))
	end
	local map = Workspace:FindFirstChild("VoidlineMap")
	local deep = map and map:FindFirstChild("DeepSpace")
	consider(deep and deep:FindFirstChild("RareAsteroidSpawns"))
	consider(deep and deep:FindFirstChild("EventMeteors"))
	return best
end

function DroneService.SetAfk(player: Player, isAfk: boolean)
	DroneService._afk[player.UserId] = isAfk
end

function DroneService.Init()
	Remotes.Get("SetFormation").OnServerEvent:Connect(function(player, formation)
		if typeof(formation) ~= "number" then
			return
		end
		formation = math.clamp(math.floor(formation), 1, 3)
		PlayerDataService.Mutate(player, function(d)
			d.Formation = formation
		end)
	end)

	Remotes.Get("SetLaserColor").OnServerEvent:Connect(function(player, colorName)
		if typeof(colorName) ~= "string" then
			return
		end
		if not DroneConfig.LaserColors[colorName] then
			return
		end
		PlayerDataService.Mutate(player, function(d)
			d.Settings.LaserColor = colorName
		end)
	end)

	Players.PlayerAdded:Connect(function(player)
		player:GetAttributeChangedSignal("VoidlineDroneSlots"):Connect(function()
			DroneService.SyncCount(player)
		end)
		task.defer(function()
			task.wait(1)
			DroneService.SyncCount(player)
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		local list = DroneService._drones[player.UserId]
		if list then
			for _, d in list do
				d:Destroy()
			end
		end
		DroneService._drones[player.UserId] = nil
		DroneService._targets[player.UserId] = nil
		DroneService._afk[player.UserId] = nil
	end)

	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.1 then
			return
		end
		local step = acc
		acc = 0
		for _, player in Players:GetPlayers() do
			if DroneService._afk[player.UserId] then
				local data = PlayerDataService.Get(player)
				local char = player.Character
				local hrp = char and char:FindFirstChild("HumanoidRootPart")
				local list = DroneService._drones[player.UserId]
				if data and hrp and list then
					for i, drone in list do
						local angle = os.clock() + i
						local pos = hrp.Position
							+ Vector3.new(math.cos(angle) * DroneConfig.IdleOrbitRadius, 3, math.sin(angle) * DroneConfig.IdleOrbitRadius)
						if drone.PrimaryPart then
							drone:PivotTo(CFrame.new(pos))
						end
					end
				end
			else
				DroneService.SyncCount(player)
				local data = PlayerDataService.Get(player)
				local list = DroneService._drones[player.UserId]
				local char = player.Character
				local hrp = char and char:FindFirstChild("HumanoidRootPart")
				if data and list and hrp then
					local formation = data.Formation or 1
					local target = DroneService._targets[player.UserId]
					if not target or not target.Parent or (target:GetAttribute("Health") :: number) <= 0 then
						target = findNearestAsteroid(player, hrp.Position)
						DroneService._targets[player.UserId] = target
						if data.TutorialStep == 1 and target then
							PlayerDataService.Mutate(player, function(d)
								if d.TutorialStep == 1 then
									d.TutorialStep = 2
								end
							end)
							Remotes.Get("TutorialProgress"):FireClient(player, 2)
						end
					end

					local dps = DroneConfig.BaseDamagePerSecond
						+ (data.DrillLevel - 1) * DroneConfig.DamagePerDrillLevel
					if PlayerDataService.HasPerk(player, "LaserOverclock") then
						dps *= 1.35
					end
					if formation == 2 then
						dps *= 1.5
					end
					dps *= #list

					for i, drone in list do
						local body = drone.PrimaryPart
						if body then
							local pos
							if formation == 3 then
								local back = -hrp.CFrame.LookVector
								pos = hrp.Position + back * 4 + Vector3.new((i - (#list + 1) / 2) * 1.6, 3 + i * 0.2, 0)
							elseif target then
								local orbit = (os.clock() * 2 + i) % (math.pi * 2)
								pos = target.Position
									+ Vector3.new(math.cos(orbit) * 6, 4, math.sin(orbit) * 6)
							else
								local angle = os.clock() + i
								pos = hrp.Position
									+ Vector3.new(math.cos(angle) * DroneConfig.IdleOrbitRadius, 3, math.sin(angle) * DroneConfig.IdleOrbitRadius)
							end
							drone:PivotTo(CFrame.new(pos))
							local trim = drone:FindFirstChild("Trim")
							if trim and trim:IsA("BasePart") then
								trim.Color = laserColorFor(player)
								trim.CFrame = body.CFrame
							end
						end
					end

					if target and formation ~= 3 then
						local hp = target:GetAttribute("Health") :: number
						local maxHp = target:GetAttribute("MaxHealth") :: number
						hp = math.max(0, hp - dps * step)
						target:SetAttribute("Health", hp)
						Remotes.Get("JuiceEvent"):FireClient(player, {
							Kind = "Laser",
							Target = target,
							Color = laserColorFor(player),
							Formation = formation,
						})
						if target:GetAttribute("Shared") == true then
							local SoftContestService = require(script.Parent.SoftContestService)
							SoftContestService.AddDamage(target, player, dps * step)
						end
						if hp <= 0 then
							local sector = target:GetAttribute("Sector") or "Starter"
							local oreGain = if sector == "Starter" then 10 else 25
							if target:GetAttribute("Shared") == true then
								local SoftContestService = require(script.Parent.SoftContestService)
								SoftContestService.Resolve(target)
							else
								EconomyService.AddOre(player, oreGain)
								Remotes.Get("JuiceEvent"):FireClient(player, {
									Kind = "Shatter",
									Position = target.Position,
									Ore = oreGain,
								})
								target:SetAttribute("Health", maxHp)
								target.Transparency = 0
								target.CFrame = target.CFrame * CFrame.Angles(0, math.rad(40), 0)
								if PlayerDataService.HasPerk(player, "AutoSellWarpLink") then
									EconomyService.Sell(player)
								end
							end
							DroneService._targets[player.UserId] = nil
						end
					end
				end
			end
		end
	end)
end

return DroneService
