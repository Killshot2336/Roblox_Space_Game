--!strict
-- Equipping earned cosmetics (titles, laser shaders, hit effects, thrusters,
-- drone mutations), the overhead title tag, and the Star Overlook's calm
-- aura (purely cosmetic: a soft glow and quieter audio on the client).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Voidline = ReplicatedStorage:WaitForChild("Voidline")
local HubLayout = require(Voidline.Modules.HubLayout)
local TitleRegistry = require(Voidline.Content.TitleRegistry)
local DroneRegistry = require(Voidline.Content.DroneRegistry)

local ValidateRemote = require(script.Parent.Parent.Security.ValidateRemote)
local PlayerDataService = require(script.Parent.PlayerDataService)
local DroneService = require(script.Parent.DroneService)
local JuiceService = require(script.Parent.JuiceService)

local CosmeticService = {}

local AURA_RADIUS = 12
local AURA_HEIGHT = 14

-- Equip slot -> DroneRegistry category.
local SLOT_CATEGORY: { [string]: string } = {
	LaserShader = "Laser",
	HitEffect = "HitEffect",
	Thruster = "Thruster",
	DroneMutation = "Mutation",
}

local function titleTag(character: Model): BillboardGui?
	local head = character:FindFirstChild("Head")
	if not head then
		return nil
	end
	local tag = head:FindFirstChild("VoidlineTitle") :: BillboardGui?
	if tag then
		return tag
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "VoidlineTitle"
	gui.Size = UDim2.fromOffset(220, 26)
	gui.StudsOffset = Vector3.new(0, 2.6, 0)
	gui.MaxDistance = 80
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Name = "Title"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextStrokeTransparency = 0.6
	label.Parent = gui
	gui.Parent = head
	return gui
end

function CosmeticService.RefreshTitle(player: Player)
	local profile = PlayerDataService.Get(player)
	local character = player.Character
	if not profile or not character then
		return
	end
	local title = TitleRegistry.ById[profile.Cosmetics.Title]
	player:SetAttribute("Title", if title then title.Name else "")
	local tag = titleTag(character)
	if not tag then
		return
	end
	local label = tag:FindFirstChild("Title") :: TextLabel
	label.Text = if title then title.Name else ""
	label.TextColor3 = if title then title.Color else Color3.new(1, 1, 1)
	tag.Enabled = title ~= nil
end

function CosmeticService.Equip(player: Player, slot: string, id: string): (boolean, string?)
	local profile = PlayerDataService.Get(player)
	if not profile then
		return false, "loading"
	end
	if slot == "Title" then
		if id ~= "" and (not TitleRegistry.ById[id] or profile.Titles[id] ~= true) then
			return false, "locked"
		end
	elseif SLOT_CATEGORY[slot] then
		if id ~= "" then
			local cosmetic = DroneRegistry.ById[id]
			if not cosmetic or cosmetic.Category ~= SLOT_CATEGORY[slot] or profile.Unlocks[id] ~= true then
				return false, "locked"
			end
		end
	else
		return false, "slot"
	end
	PlayerDataService.Mutate(player, function(p)
		p.Cosmetics[slot] = id
	end)
	if slot == "Title" then
		CosmeticService.RefreshTitle(player)
	else
		DroneService.RefreshLook(player)
	end
	return true, nil
end

local function auraStep()
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local inside = false
		if root then
			local offset = root.Position - HubLayout.Overlook
			inside = Vector3.new(offset.X, 0, offset.Z).Magnitude <= AURA_RADIUS
				and offset.Y > -2
				and offset.Y < AURA_HEIGHT
		end
		if (player:GetAttribute("CalmAura") == true) ~= inside then
			player:SetAttribute("CalmAura", inside)
		end
	end
end

function CosmeticService.Init()
	ValidateRemote.Bind(
		"EquipCosmetic",
		{ Rate = 0.3, Burst = 5, Args = { "string", "string" }, MaxString = 64 },
		function(player, slot, id)
			local ok, reason = CosmeticService.Equip(player, slot, id)
			JuiceService.Send(player, "Equip", { Ok = ok, Slot = slot, Id = id, Reason = reason })
		end
	)
	PlayerDataService.OnSettingsChanged(function(player)
		DroneService.RefreshLook(player)
	end)
	PlayerDataService.OnLoaded(function(player)
		CosmeticService.RefreshTitle(player)
		player.CharacterAdded:Connect(function()
			task.defer(CosmeticService.RefreshTitle, player)
		end)
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			auraStep()
		end
	end)
end

return CosmeticService
