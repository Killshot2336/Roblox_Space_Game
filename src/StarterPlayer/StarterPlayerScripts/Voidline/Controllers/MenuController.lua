--!strict
-- The pilot menu: Pilot card + forge/rebirth/evolution, daily and weekly
-- quests, Codex progress, cosmetics locker, 7-day streak, squads, the Code
-- Terminal and settings. Also shows other pilots' cards (InspectResult) and
-- squad invites with Accept / Decline.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Voidline = ReplicatedStorage:WaitForChild("Voidline")
local DroneConfig = require(Voidline.Config.DroneConfig)
local DailyConfig = require(Voidline.Config.DailyConfig)
local RebirthConfig = require(Voidline.Config.RebirthConfig)
local ForgeConfig = require(Voidline.Config.ForgeConfig)
local SquadConfig = require(Voidline.Config.SquadConfig)
local EconomyRules = require(Voidline.Rules.EconomyRules)
local ProgressionRules = require(Voidline.Rules.ProgressionRules)
local ContentIndex = require(Voidline.Content.ContentIndex)
local DroneRegistry = require(Voidline.Content.DroneRegistry)
local TitleRegistry = require(Voidline.Content.TitleRegistry)
local CitadelRegistry = require(Voidline.Content.CitadelRegistry)
local AchievementRegistry = require(Voidline.Content.AchievementRegistry)
local Remotes = require(Voidline.Remotes)

local Client = script.Parent.Parent.Client
local Ui = require(Client.Ui)
local ClientState = require(Client.ClientState)

local MenuController = {}

local TABS = { "Pilot", "Quests", "Codex", "Locker", "Daily", "Squad", "Codes", "Settings" }
local INVITE_SECONDS = 30
local NEARBY_LIMIT = 8
local VOLUME_STEPS = { 0, 0.25, 0.5, 0.75, 1 }

local player = Players.LocalPlayer
local gui: ScreenGui
local panel: Frame
local content: ScrollingFrame
local tabButtons: { [string]: TextButton } = {}
local currentTab = "Pilot"
local codeBox: TextBox? = nil
local codeResult = ""
local cardGui: ScreenGui
local inviteGui: ScreenGui
local onOpened: (() -> ())? = nil

-- Small builders -------------------------------------------------------------------

local order = 0
local function nextOrder(): number
	order += 1
	return order
end

local function heading(text: string)
	Ui.Label({
		Name = "Heading",
		Size = UDim2.new(1, -8, 0, 26),
		Text = text,
		Font = Ui.Font.Title,
		TextSize = 15,
		TextColor3 = Ui.Colors.GoldBright,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = nextOrder(),
		Parent = content,
	})
end

local function line(text: string, color: Color3?)
	Ui.Label({
		Name = "Line",
		Size = UDim2.new(1, -8, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Text = text,
		TextSize = 14,
		TextColor3 = color or Ui.Colors.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = nextOrder(),
		Parent = content,
	})
end

local function rowFrame(height: number): Frame
	local frame = Ui.Make("Frame", {
		Name = "Row",
		Size = UDim2.new(1, -8, 0, height),
		BackgroundColor3 = Ui.Colors.GlassLight,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		LayoutOrder = nextOrder(),
		Parent = content,
	}) :: Frame
	Ui.Corner(frame, 10)
	return frame
end

local function rowLabel(frame: Frame, text: string, sub: string?, rightInset: number)
	Ui.Label({
		Name = "Text",
		Position = UDim2.fromOffset(12, if sub then 6 else 0),
		Size = UDim2.new(1, -(rightInset + 20), 0, if sub then 22 else frame.Size.Y.Offset),
		Text = text,
		Font = Ui.Font.Bold,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = frame,
	})
	if sub then
		Ui.Label({
			Name = "Sub",
			Position = UDim2.fromOffset(12, 28),
			Size = UDim2.new(1, -(rightInset + 20), 0, 18),
			Text = sub,
			TextSize = 12,
			TextColor3 = Ui.Colors.Muted,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = frame,
		})
	end
end

local function rowButton(frame: Frame, text: string, width: number, onActivate: () -> ()): TextButton
	return Ui.Button({
		Name = "Action",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(width, Ui.TOUCH),
		Text = text,
		TextSize = 14,
		Parent = frame,
	}, onActivate)
end

local function progressBar(frame: Frame, fraction: number, color: Color3)
	local track = Ui.Make("Frame", {
		Name = "Track",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -6),
		Size = UDim2.new(1, -24, 0, 6),
		BackgroundColor3 = Ui.Colors.Shadow,
		BorderSizePixel = 0,
		Parent = frame,
	}) :: Frame
	Ui.Corner(track, 3)
	local fill = Ui.Make("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Parent = track,
	}) :: Frame
	Ui.Corner(fill, 3)
end

local function count(map: { [any]: any }): number
	local n = 0
	for _ in map do
		n += 1
	end
	return n
end

-- Tabs ---------------------------------------------------------------------------------

local function renderPilot()
	local profile = ClientState.Profile
	local evolution = DroneRegistry.EvolutionFor(profile.DroneTier, profile.DroneBranch)
	local title = TitleRegistry.ById[profile.Cosmetics.Title]
	local citadel = CitadelRegistry.ForTier(profile.StationTier)
	heading(("%s%s"):format(player.DisplayName, if title then " · " .. title.Name else ""))
	line(("Citadel: %s (Station Tier %d)"):format(citadel.Name, profile.StationTier))
	line(
		("Drones: %s × %d · %s"):format(
			evolution.Name,
			(player:GetAttribute("DroneCount") or 1) :: number,
			DroneConfig.FormationLabels[profile.Formation] or ""
		)
	)
	line(
		("Rebirths: %d (x%.2f Credits) · Codex %d/%d · Relics %d · Achievements %d"):format(
			profile.Rebirths,
			RebirthConfig.CreditMultiplier(profile.Rebirths),
			ClientState.CodexCount,
			ContentIndex.CodexTotal,
			count(profile.Relics),
			count(profile.Achievements)
		),
		Ui.Colors.Muted
	)

	-- Branch choice right before the evolution tree splits.
	if profile.DroneTier == DroneConfig.BranchStage - 1 and profile.DroneBranch == "" then
		heading("CHOOSE YOUR EVOLUTION LINE")
		local cost = EconomyRules.UpgradeCost(profile, "DroneTier", ClientState.Ctx()) or 0
		for _, branchId in DroneConfig.BranchOrder do
			local frame = rowFrame(56)
			local branch = DroneConfig.Branches[branchId]
			local next = DroneRegistry.EvolutionFor(DroneConfig.BranchStage, branchId)
			rowLabel(frame, ("%s · %s"):format(branch.Label, next.Name), next.Flavor, 150)
			rowButton(frame, ("EVOLVE ◆%s"):format(Ui.Compact(cost)), 140, function()
				ClientState.Fire("RequestUpgrade", "DroneTier", branchId)
			end)
		end
	end

	heading("ARTIFACT FORGE")
	local shards = profile.VoidShards
	local forging = profile.ForgeJobEndsAt > 0
	local forgeRow = rowFrame(56)
	rowLabel(
		forgeRow,
		("Void Shards %d / %d per artifact"):format(shards, ForgeConfig.ShardsPerArtifact),
		if forging
			then "Forging… collect when the timer ends"
			else ("Artifacts %d · each turns into %d Tokens"):format(
				profile.Artifacts,
				ForgeConfig.TokensPerArtifact
			),
		260
	)
	local buttons = Ui.Make("Frame", {
		Name = "Buttons",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(252, Ui.TOUCH),
		BackgroundTransparency = 1,
		Parent = forgeRow,
	})
	Ui.List(buttons, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Right)
	Ui.Button({
		Name = "Forge",
		Size = UDim2.fromOffset(120, Ui.TOUCH),
		Text = if forging then "COLLECT" else "FORGE",
		Parent = buttons,
	}, function()
		ClientState.Fire("RequestForge")
	end)
	Ui.Button(
		{ Name = "TurnIn", Size = UDim2.fromOffset(120, Ui.TOUCH), Text = "TURN IN", Parent = buttons },
		function()
			ClientState.Fire("TurnInArtifact")
		end
	)
	if ProgressionRules.ForgeCooling(profile) then
		line("The forge is cooling for today: slower, never stopped.", Ui.Colors.Muted)
	end

	heading("VOID REBIRTH")
	local canRebirth = ProgressionRules.CanRebirth(profile)
	local rebirthRow = rowFrame(56)
	rowLabel(
		rebirthRow,
		("Rebirth %d → x%.2f Credits"):format(
			profile.Rebirths + 1,
			RebirthConfig.CreditMultiplier(profile.Rebirths + 1)
		),
		if canRebirth
			then "Resets station upgrades; keeps Codex, relics, titles and passes"
			else ("Needs Station Tier %d"):format(RebirthConfig.RequiredStationTier),
		150
	)
	local rebirthButton = rowButton(rebirthRow, "REBIRTH", 130, function()
		ClientState.Fire("RequestRebirth")
	end)
	Ui.SetEnabled(rebirthButton, canRebirth)
end

local function renderQuests()
	local quests = ClientState.Profile.Quests
	for _, section in { { "DAILY QUESTS", quests.Daily }, { "WEEKLY QUESTS", quests.Weekly } } do
		heading(section[1])
		local listed = section[2]
		if type(listed) ~= "table" or #listed == 0 then
			line("New quests arrive at the next reset.", Ui.Colors.Muted)
			continue
		end
		for _, quest in listed do
			local frame = rowFrame(58)
			local target = math.max(1, quest.Target or 1)
			local progress = math.min(quest.Progress or 0, target)
			rowLabel(
				frame,
				(if quest.Done then "✓ " else "") .. tostring(quest.Name),
				("%d / %d"):format(progress, target),
				12
			)
			progressBar(frame, progress / target, if quest.Done then Ui.Colors.Good else Ui.Colors.Gold)
		end
	end
end

local function renderCodex()
	local profile = ClientState.Profile
	local mult = ContentIndex.CodexMultiplier(ClientState.CodexCount)
	heading(("CODEX · %d / %d DISCOVERED"):format(ClientState.CodexCount, ContentIndex.CodexTotal))
	line(("Codex bonus: x%.2f Credits"):format(mult), Ui.Colors.GoldBright)
	for _, milestone in ContentIndex.CodexMilestones do
		if ClientState.CodexCount < milestone.Count then
			line(
				("Next milestone: %d discoveries (+%d%%)"):format(
					milestone.Count,
					math.floor(milestone.Bonus * 100 + 0.5)
				),
				Ui.Colors.Muted
			)
			break
		end
	end
	local found: { [string]: number } = {}
	for id in profile.Codex do
		local _, kind = ContentIndex.Get(id)
		if kind then
			found[kind] = (found[kind] or 0) + 1
		end
	end
	for _, info in ContentIndex.Registries do
		if not info.Codex then
			continue
		end
		local frame = rowFrame(52)
		local have = found[info.Kind] or 0
		rowLabel(frame, info.Label, ("%d / %d"):format(have, info.Registry.Count), 12)
		progressBar(frame, have / math.max(1, info.Registry.Count), Ui.Colors.Void)
	end
	heading(("ACHIEVEMENTS · %d / %d"):format(count(profile.Achievements), AchievementRegistry.Count))
end

local function equipRow(slot: string, id: string, name: string, sub: string, equipped: boolean)
	local frame = rowFrame(52)
	rowLabel(frame, name, sub, 130)
	rowButton(frame, if equipped then "UNEQUIP" else "EQUIP", 120, function()
		ClientState.Fire("EquipCosmetic", slot, if equipped then "" else id)
	end)
end

local function renderLocker()
	local profile = ClientState.Profile
	heading("TITLES")
	local any = false
	for _, title in TitleRegistry.List do
		if profile.Titles[title.Id] == true then
			any = true
			equipRow(
				"Title",
				title.Id,
				title.Name,
				title.Rarity .. " · " .. title.Source,
				profile.Cosmetics.Title == title.Id
			)
		end
	end
	if not any then
		line("Earn titles from achievements, rebirths, relic sets and codes.", Ui.Colors.Muted)
	end
	for _, slot in
		{
			{ "DroneMutation", "Mutation", "MUTATIONS" },
			{ "LaserShader", "Laser", "LASER SHADERS" },
			{ "HitEffect", "HitEffect", "HIT EFFECTS" },
			{ "Thruster", "Thruster", "THRUSTERS" },
		}
	do
		heading(slot[3])
		local owned = 0
		for _, cosmetic in DroneRegistry.ByCategory(slot[2]) do
			if profile.Unlocks[cosmetic.Id] == true then
				owned += 1
				equipRow(
					slot[1],
					cosmetic.Id,
					cosmetic.Name,
					cosmetic.Rarity,
					profile.Cosmetics[slot[1]] == cosmetic.Id
				)
			end
		end
		if owned == 0 then
			line("None yet: quests, achievements and evolutions unlock these.", Ui.Colors.Muted)
		end
	end
end

local function renderDaily()
	local profile = ClientState.Profile
	local canClaim = ProgressionRules.CanClaimDaily(profile, os.time())
	local today = math.max(1, profile.DailyStreak)
	heading(("7-DAY STREAK · DAY %d"):format(today))
	for day = 1, DailyConfig.CycleLength do
		local reward = DailyConfig.Rewards[day]
		local frame = rowFrame(52)
		local parts = { ("◆%d"):format(reward.Credits) }
		if reward.VoidShards > 0 then
			table.insert(parts, ("✦%d"):format(reward.VoidShards))
		end
		if reward.TrialPerk then
			table.insert(parts, ("%dh %s trial"):format(reward.TrialHours or 24, reward.TrialPerk))
		end
		local status = if day < today or (day == today and not canClaim) then "✓ " else ""
		rowLabel(frame, ("%sDay %d"):format(status, day), table.concat(parts, " · "), 130)
		if day == today then
			local button = rowButton(frame, if canClaim then "CLAIM" else "CLAIMED", 120, function()
				ClientState.Fire("RedeemDaily")
			end)
			Ui.SetEnabled(button, canClaim)
		end
	end
end

local function distanceTo(other: Player): number
	local a = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local b = other.Character and other.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if a and b then
		return (a.Position - b.Position).Magnitude
	end
	return math.huge
end

local function renderSquad()
	local squad = ClientState.Squad
	local members = if type(squad.Members) == "table" then squad.Members else {}
	local inSquad = squad.SquadId ~= nil and #members > 0
	local memberIds: { [number]: boolean } = {}
	if inSquad then
		heading(("YOUR SQUAD · %d / %d"):format(#members, SquadConfig.MaxSize))
		local leader = false
		for _, member in members do
			memberIds[member.UserId] = true
			if member.UserId == player.UserId and member.Leader then
				leader = true
			end
		end
		for _, member in members do
			local frame = rowFrame(52)
			rowLabel(frame, (if member.Leader then "★ " else "") .. tostring(member.Name), nil, 120)
			if leader and member.UserId ~= player.UserId then
				rowButton(frame, "KICK", 100, function()
					ClientState.Fire("SquadKick", member.UserId)
				end)
			end
		end
		local challenge = squad.Challenge
		if type(challenge) == "table" then
			local frame = rowFrame(58)
			rowLabel(
				frame,
				"SQUAD CHALLENGE",
				("%d / %d rocks together"):format(challenge.Progress or 0, challenge.Goal or 1),
				12
			)
			progressBar(frame, (challenge.Progress or 0) / math.max(1, challenge.Goal or 1), Ui.Colors.Cyan)
		end
		local leaveRow = rowFrame(52)
		rowLabel(
			leaveRow,
			("Linked squads find shards +%d%% more often"):format(
				math.floor((squad.LuckBonus or SquadConfig.LinkedShardLuckBonus) * 100 + 0.5)
			),
			nil,
			120
		)
		rowButton(leaveRow, "LEAVE", 100, function()
			ClientState.Fire("SquadLeave")
		end)
	else
		heading("SQUADS")
		line(
			("Team up with %d-%d pilots for shared challenges and shard luck."):format(
				SquadConfig.MinSize,
				SquadConfig.MaxSize
			),
			Ui.Colors.Muted
		)
	end
	heading("PILOTS NEARBY")
	local others = {}
	for _, other in Players:GetPlayers() do
		if other ~= player and not memberIds[other.UserId] then
			table.insert(others, other)
		end
	end
	table.sort(others, function(a, b)
		return distanceTo(a) < distanceTo(b)
	end)
	if #others == 0 then
		line("No other pilots in this server yet.", Ui.Colors.Muted)
	end
	for i, other in others do
		if i > NEARBY_LIMIT then
			break
		end
		local frame = rowFrame(52)
		local title = other:GetAttribute("Title")
		rowLabel(frame, other.DisplayName, if type(title) == "string" and title ~= "" then title else nil, 240)
		local buttons = Ui.Make("Frame", {
			Name = "Buttons",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.fromOffset(232, Ui.TOUCH),
			BackgroundTransparency = 1,
			Parent = frame,
		})
		Ui.List(buttons, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Right)
		Ui.Button({ Name = "Card", Size = UDim2.fromOffset(100, Ui.TOUCH), Text = "CARD", Parent = buttons }, function()
			ClientState.Fire("InspectPilot", other.UserId)
		end)
		Ui.Button(
			{ Name = "Invite", Size = UDim2.fromOffset(110, Ui.TOUCH), Text = "INVITE", Parent = buttons },
			function()
				ClientState.Fire("SquadInvite", other.UserId)
			end
		)
	end
end

local function renderCodes()
	heading("CODE TERMINAL")
	line("Enter a code from the community. Each code works once per pilot.", Ui.Colors.Muted)
	local frame = rowFrame(60)
	local box = Ui.Make("TextBox", {
		Name = "CodeBox",
		Position = UDim2.fromOffset(10, 6),
		Size = UDim2.new(1, -150, 0, Ui.TOUCH),
		BackgroundColor3 = Ui.Colors.Shadow,
		BackgroundTransparency = 0.2,
		Font = Ui.Font.Bold,
		TextSize = 18,
		TextColor3 = Ui.Colors.Text,
		PlaceholderText = "ENTER CODE",
		PlaceholderColor3 = Ui.Colors.Muted,
		ClearTextOnFocus = false,
		Text = "",
		Parent = frame,
	}) :: TextBox
	Ui.Corner(box, 8)
	codeBox = box
	local function submit()
		local text = string.sub(box.Text, 1, 64)
		if text ~= "" then
			ClientState.Fire("RedeemCode", text)
		end
	end
	box.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			submit()
		end
	end)
	rowButton(frame, "REDEEM", 120, submit)
	if codeResult ~= "" then
		line(codeResult, Ui.Colors.GoldBright)
	end
end

local function toggleRow(label: string, key: string, sub: string)
	local settings = ClientState.Profile.Settings
	local on = settings[key] == true
	local frame = rowFrame(56)
	rowLabel(frame, label, sub, 110)
	rowButton(frame, if on then "ON" else "OFF", 90, function()
		ClientState.Fire("SettingsUpdate", { [key] = not on })
	end)
end

local function stepRow(label: string, key: string)
	local settings = ClientState.Profile.Settings
	local value = settings[key]
	local current = if type(value) == "number" then value else 0.5
	local frame = rowFrame(56)
	rowLabel(frame, label, ("%d%%"):format(math.floor(current * 100 + 0.5)), 110)
	rowButton(frame, "CHANGE", 90, function()
		local nextValue = VOLUME_STEPS[1]
		for i, step in VOLUME_STEPS do
			if math.abs(step - current) < 0.01 then
				nextValue = VOLUME_STEPS[i % #VOLUME_STEPS + 1]
			end
		end
		ClientState.Fire("SettingsUpdate", { [key] = nextValue })
	end)
end

local function renderSettings()
	heading("SETTINGS")
	toggleRow("Performance Mode", "PerfMode", "Fewer particles, trails and distant drones")
	toggleRow("Clean Clip Mode", "ClipMode", "Hide the HUD for recording (K toggles)")
	toggleRow("Reduced Motion", "ReducedMotion", "No camera shake, calmer UI")
	stepRow("Music volume", "MusicVolume")
	stepRow("Effects volume", "SfxVolume")
	local settings = ClientState.Profile.Settings
	local frame = rowFrame(56)
	rowLabel(frame, "Laser colour", tostring(settings.LaserColor), 110)
	rowButton(frame, "CYCLE", 90, function()
		local colors = DroneConfig.LaserColorOrder
		local index = table.find(colors, settings.LaserColor) or 0
		ClientState.Fire("SettingsUpdate", { LaserColor = colors[index % #colors + 1] })
	end)
end

local RENDERERS: { [string]: () -> () } = {
	Pilot = renderPilot,
	Quests = renderQuests,
	Codex = renderCodex,
	Locker = renderLocker,
	Daily = renderDaily,
	Squad = renderSquad,
	Codes = renderCodes,
	Settings = renderSettings,
}

local function render()
	if not gui.Enabled then
		return
	end
	-- Do not rebuild under a pilot who is typing a code.
	if currentTab == "Codes" and codeBox and codeBox.Parent and codeBox:IsFocused() then
		return
	end
	Ui.ClearChildren(content)
	codeBox = nil
	order = 0
	for name, button in tabButtons do
		local selected = name == currentTab
		button.BackgroundColor3 = if selected then Ui.Colors.Gold else Ui.Colors.GlassLight
		button.TextColor3 = if selected then Ui.Colors.Shadow else Ui.Colors.Text
	end
	RENDERERS[currentTab]()
end

function MenuController.Open(tab: string?)
	if tab and RENDERERS[tab] then
		currentTab = tab
	end
	gui.Enabled = true
	Ui.Pop(panel, 0.9)
	render()
	if onOpened then
		onOpened()
	end
end

function MenuController.Close()
	gui.Enabled = false
end

function MenuController.Toggle(tab: string?)
	if gui.Enabled and (tab == nil or tab == currentTab) then
		MenuController.Close()
	else
		MenuController.Open(tab)
	end
end

function MenuController.IsOpen(): boolean
	return gui.Enabled
end

function MenuController.OnOpened(callback: () -> ())
	onOpened = callback
end

function MenuController.CodeResult(text: string)
	codeResult = text
	if currentTab == "Codes" then
		render()
	end
end

-- Pilot cards and invites ----------------------------------------------------------------

function MenuController.ShowCard(card: { [string]: any })
	Ui.ClearChildren(cardGui)
	local frame = Ui.Glass({
		Name = "PilotCard",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(340, 300),
		Parent = cardGui,
	})
	type CardLine = { text: string, font: Enum.Font, size: number, color: Color3 }
	local lines: { CardLine } = {
		{ text = tostring(card.Name or "Pilot"), font = Ui.Font.Title, size = 22, color = Ui.Colors.GoldBright },
		{ text = tostring(card.Title or ""), font = Ui.Font.Bold, size = 14, color = Ui.Colors.Void },
		{
			text = ("%s · Station Tier %s"):format(tostring(card.Citadel or ""), tostring(card.StationTier or 1)),
			font = Ui.Font.Body,
			size = 14,
			color = Ui.Colors.Text,
		},
		{
			text = ("%s × %s"):format(tostring(card.Drone or ""), tostring(card.Drones or 1)),
			font = Ui.Font.Body,
			size = 14,
			color = Ui.Colors.Text,
		},
		{
			text = ("Rebirths %s · Codex %s · Relics %s"):format(
				tostring(card.Rebirths or 0),
				tostring(card.Codex or 0),
				tostring(card.Relics or 0)
			),
			font = Ui.Font.Body,
			size = 14,
			color = Ui.Colors.Muted,
		},
		{
			text = ("Achievements %s · Streak day %s"):format(
				tostring(card.Achievements or 0),
				tostring(card.Streak or 0)
			),
			font = Ui.Font.Body,
			size = 14,
			color = Ui.Colors.Muted,
		},
	}
	local showcase = card.Showcase
	if type(showcase) == "table" and #showcase > 0 then
		table.insert(lines, {
			text = "Showcase: " .. table.concat(showcase, ", "),
			font = Ui.Font.Body,
			size = 13,
			color = Ui.Colors.GoldBright,
		})
	end
	local y = 16
	for _, entry in lines do
		Ui.Label({
			Position = UDim2.fromOffset(18, y),
			Size = UDim2.new(1, -36, 0, entry.size + 10),
			Text = entry.text,
			Font = entry.font,
			TextSize = entry.size,
			TextColor3 = entry.color,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = frame,
		})
		y += entry.size + 14
	end
	Ui.Button({
		Name = "Close",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.fromOffset(140, Ui.TOUCH),
		Text = "CLOSE",
		Parent = frame,
	}, function()
		Ui.ClearChildren(cardGui)
	end)
	Ui.Pop(frame, 0.85)
end

function MenuController.ShowInvite(fromUserId: number, fromName: string, seconds: number?)
	Ui.ClearChildren(inviteGui)
	local frame = Ui.Glass({
		Name = "Invite",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -96),
		Size = UDim2.fromOffset(360, 104),
		Parent = inviteGui,
	})
	Ui.Label({
		Position = UDim2.fromOffset(14, 8),
		Size = UDim2.new(1, -28, 0, 26),
		Text = ("%s invites you to a squad"):format(fromName),
		Font = Ui.Font.Title,
		TextSize = 16,
		TextColor3 = Ui.Colors.GoldBright,
		Parent = frame,
	})
	local buttons = Ui.Make("Frame", {
		Position = UDim2.fromOffset(14, 44),
		Size = UDim2.new(1, -28, 0, Ui.TOUCH),
		BackgroundTransparency = 1,
		Parent = frame,
	})
	Ui.List(buttons, Enum.FillDirection.Horizontal, 12)
	local function respond(accept: boolean)
		ClientState.Fire("SquadRespond", fromUserId, accept)
		Ui.ClearChildren(inviteGui)
	end
	Ui.Button({ Name = "Accept", Size = UDim2.fromOffset(150, Ui.TOUCH), Text = "ACCEPT", Parent = buttons }, function()
		respond(true)
	end)
	Ui.Button(
		{ Name = "Decline", Size = UDim2.fromOffset(150, Ui.TOUCH), Text = "DECLINE", Parent = buttons },
		function()
			respond(false)
		end
	)
	Ui.Pop(frame, 0.85)
	task.delay(seconds or INVITE_SECONDS, function()
		if frame.Parent then
			frame:Destroy()
		end
	end)
end

function MenuController.Init()
	gui = Ui.Screen("VoidlineMenu", 20)
	gui.Enabled = false
	cardGui = Ui.Screen("VoidlinePilotCard", 25)
	inviteGui = Ui.Screen("VoidlineInvite", 24)
	panel = Ui.Glass({
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.94, 0.86),
		Parent = gui,
	})
	Ui.Make("UISizeConstraint", { MaxSize = Vector2.new(720, 560), Parent = panel })
	Ui.Button({
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 8),
		Size = UDim2.fromOffset(Ui.TOUCH, Ui.TOUCH),
		Text = "✕",
		TextSize = 20,
		Parent = panel,
	}, MenuController.Close)
	local tabs = Ui.Make("ScrollingFrame", {
		Name = "Tabs",
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.new(1, -80, 0, Ui.TOUCH + 8),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 0,
		ScrollingDirection = Enum.ScrollingDirection.X,
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		CanvasSize = UDim2.new(),
		Parent = panel,
	})
	Ui.List(tabs, Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Left)
	for i, name in TABS do
		tabButtons[name] = Ui.Button({
			Name = name,
			Size = UDim2.fromOffset(96, Ui.TOUCH),
			Text = string.upper(name),
			TextSize = 13,
			LayoutOrder = i,
			Parent = tabs,
		}, function()
			currentTab = name
			render()
		end)
	end
	content = Ui.Make("ScrollingFrame", {
		Name = "Content",
		Position = UDim2.fromOffset(12, Ui.TOUCH + 24),
		Size = UDim2.new(1, -24, 1, -(Ui.TOUCH + 36)),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = panel,
	})
	Ui.List(content, Enum.FillDirection.Vertical, 6, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Top)

	ClientState.OnChanged(function()
		render()
	end)
	Remotes.Get("InspectResult").OnClientEvent:Connect(function(card: any)
		if type(card) == "table" then
			MenuController.ShowCard(card)
		end
	end)
	Players.PlayerAdded:Connect(function()
		if currentTab == "Squad" then
			render()
		end
	end)
	Players.PlayerRemoving:Connect(function()
		if currentTab == "Squad" then
			task.defer(render)
		end
	end)
end

return MenuController
