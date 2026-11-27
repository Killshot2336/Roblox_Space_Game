--!strict
-- Compact HUD: a top pill (Credits, Ore, Shards, Tokens), a one-line world
-- clock under it, 3 s banners, a toast stack for rewards and the soft-contest
-- bar for boss meteors. Everything hides in Clean Clip Mode.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Voidline = ReplicatedStorage:WaitForChild("Voidline")
local JuiceConfig = require(Voidline.Config.JuiceConfig)
local EconomyRules = require(Voidline.Rules.EconomyRules)
local HudCueRules = require(Voidline.Rules.HudCueRules)
local ArtResolve = require(Voidline.Modules.ArtResolve)
local BiomeRegistry = require(Voidline.Content.BiomeRegistry)
local WorldEventRegistry = require(Voidline.Content.WorldEventRegistry)
local Remotes = require(Voidline.Remotes)

local Client = script.Parent.Parent.Client
local Ui = require(Client.Ui)
local ClientState = require(Client.ClientState)

local HUDController = {}

local BANNER_QUEUE_MAX = 4
local TOAST_SECONDS = 3.5
local TOAST_MAX = 3
local CONTEST_RANGE = 220
local CONTEST_TIMEOUT = 4

type Chip = {
	Frame: Frame,
	Value: TextLabel,
	Title: TextLabel,
	Shown: number,
	Target: number,
	Format: (number) -> string,
}

local gui: ScreenGui
local pill: Frame
local chips: { [string]: Chip } = {}
local worldLine: TextLabel
local eventLine: TextLabel
local goalLine: TextLabel
local comebackLine: TextLabel
local comebackFrame: Frame
local bannerFrame: Frame
local bannerText: TextLabel
local toastHolder: Frame
local contestFrame: Frame
local contestTitle: TextLabel
local contestFill: Frame
local contestTop: TextLabel
local cargoTag: TextLabel

local bannerQueue: { { Text: string, Style: string, Seconds: number } } = {}
local bannerBusy = false
local contest: { Id: number, Seen: number, Done: boolean }? = nil
local visible = true

local STAT_TITLES = { Credits = "CREDITS", Ore = "CARGO", Shards = "SHARDS", Tokens = "TOKENS" }

local function makeChip(order: number, icon: string, statKey: string, color: Color3, format: (number) -> string): Chip
	local frame = Ui.Make("Frame", {
		Name = "Chip" .. order,
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 46),
		LayoutOrder = order,
		Parent = pill,
	}) :: Frame
	Ui.List(frame, Enum.FillDirection.Horizontal, 6)
	Ui.ArtIcon(frame, "Hud", statKey, icon, 22)
	local textStack = Ui.Make("Frame", {
		Name = "TextStack",
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromOffset(0, 46),
		LayoutOrder = 2,
		Parent = frame,
	}) :: Frame
	Ui.List(textStack, Enum.FillDirection.Vertical, 0, Enum.HorizontalAlignment.Left)
	local title = Ui.Label({
		Name = "Title",
		Text = STAT_TITLES[statKey] or statKey,
		Font = Ui.Font.Bold,
		TextSize = 9,
		TextColor3 = Ui.Colors.Muted,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 12),
		LayoutOrder = 1,
		Parent = textStack,
		Visible = not ArtResolve.UiHasUpload("Hud", statKey),
	})
	local value = Ui.Label({
		Name = "Value",
		Text = "0",
		Font = Ui.Font.Title,
		TextSize = 22,
		TextWrapped = false,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 28),
		LayoutOrder = 2,
		Parent = textStack,
	})
	value.TextColor3 = color
	return {
		Frame = frame,
		Value = value,
		Title = title,
		Shown = 0,
		Target = 0,
		Format = format,
	}
end

local function build()
	gui = Ui.Screen("VoidlineHUD", 5)

	pill = Ui.Glass({
		Name = "TopPill",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 6),
		Size = UDim2.fromOffset(0, 52),
		AutomaticSize = Enum.AutomaticSize.X,
		CornerRadius = 24,
		Premium = true,
		Parent = gui,
	})
	Ui.Padding(pill, 18, 6)
	Ui.List(pill, Enum.FillDirection.Horizontal, 22)
	chips.Credits = makeChip(1, "◆", "Credits", Ui.Colors.GoldBright, Ui.Compact)
	chips.Ore = makeChip(2, "⬢", "Ore", Color3.fromRGB(255, 170, 90), function(n)
		return ("%d/%d"):format(n, EconomyRules.CargoCap(ClientState.Profile))
	end)
	chips.Shards = makeChip(3, "✦", "Shards", Ui.Colors.Void, Ui.Compact)
	chips.Tokens = makeChip(4, "⬡", "Tokens", Ui.Colors.Cyan, Ui.Compact)
	cargoTag = Ui.Label({
		Name = "CargoFull",
		Text = "FULL · REFINE",
		Font = Ui.Font.Title,
		TextSize = 12,
		TextColor3 = Ui.Colors.Shadow,
		BackgroundColor3 = Ui.Colors.GoldBright,
		BackgroundTransparency = 0,
		Size = UDim2.fromOffset(96, 20),
		Visible = false,
		LayoutOrder = 5,
		Parent = pill,
	})
	Ui.Corner(cargoTag, 10)

	worldLine = Ui.Label({
		Name = "WorldClock",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 60),
		Size = UDim2.new(0.9, 0, 0, 18),
		Font = Ui.Font.Bold,
		TextSize = 13,
		TextColor3 = Ui.Colors.Muted,
		TextStrokeTransparency = 0.6,
		Text = "",
		Parent = gui,
	})
	eventLine = Ui.Label({
		Name = "EventClock",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 78),
		Size = UDim2.new(0.9, 0, 0, 18),
		Font = Ui.Font.Bold,
		TextSize = 13,
		TextColor3 = Ui.Colors.GoldBright,
		TextStrokeTransparency = 0.6,
		Text = "",
		Parent = gui,
	})
	goalLine = Ui.Label({
		Name = "NextGoal",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 96),
		Size = UDim2.new(0.92, 0, 0, 18),
		Font = Ui.Font.Bold,
		TextSize = 14,
		TextColor3 = Ui.Colors.GoldBright,
		TextStrokeTransparency = 0.65,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "",
		Parent = gui,
	})
	comebackFrame = Ui.Glass({
		Name = "ComebackCue",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -72),
		Size = UDim2.fromOffset(0, 30),
		AutomaticSize = Enum.AutomaticSize.X,
		CornerRadius = 12,
		Visible = false,
		Parent = gui,
	})
	Ui.Padding(comebackFrame, 12, 6)
	comebackLine = Ui.Label({
		Name = "Text",
		Font = Ui.Font.Bold,
		TextSize = 13,
		TextColor3 = Ui.Colors.GoldBright,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 18),
		Text = "",
		Parent = comebackFrame,
	})

	bannerFrame = Ui.Glass({
		Name = "Banner",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 118),
		Size = UDim2.new(0.8, 0, 0, 46),
		Visible = false,
		Parent = gui,
	})
	Ui.Make("UISizeConstraint", { MaxSize = Vector2.new(560, 46), Parent = bannerFrame })
	bannerText = Ui.Label({
		Name = "Text",
		Size = UDim2.fromScale(1, 1),
		Font = Ui.Font.Title,
		TextSize = 18,
		TextWrapped = true,
		Parent = bannerFrame,
	})

	toastHolder = Ui.Make("Frame", {
		Name = "Toasts",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.45, 0),
		Size = UDim2.fromOffset(290, 240),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	Ui.List(toastHolder, Enum.FillDirection.Vertical, 8, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Top)

	contestFrame = Ui.Glass({
		Name = "Contest",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 170),
		Size = UDim2.fromOffset(340, 64),
		Visible = false,
		Parent = gui,
	})
	contestTitle = Ui.Label({
		Name = "Title",
		Position = UDim2.fromOffset(12, 4),
		Size = UDim2.new(1, -24, 0, 20),
		Font = Ui.Font.Title,
		TextSize = 14,
		TextColor3 = Ui.Colors.GoldBright,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = contestFrame,
	})
	local track = Ui.Make("Frame", {
		Name = "Track",
		Position = UDim2.fromOffset(12, 26),
		Size = UDim2.new(1, -24, 0, 10),
		BackgroundColor3 = Ui.Colors.Shadow,
		BorderSizePixel = 0,
		Parent = contestFrame,
	}) :: Frame
	Ui.Corner(track, 5)
	contestFill = Ui.Make("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Ui.Colors.Void,
		BorderSizePixel = 0,
		Parent = track,
	}) :: Frame
	Ui.Corner(contestFill, 5)
	contestTop = Ui.Label({
		Name = "Top",
		Position = UDim2.fromOffset(12, 40),
		Size = UDim2.new(1, -24, 0, 18),
		TextSize = 13,
		TextColor3 = Ui.Colors.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = contestFrame,
	})
end

-- Banners ---------------------------------------------------------------------

local function nextBanner()
	local entry = table.remove(bannerQueue, 1)
	if not entry then
		bannerBusy = false
		return
	end
	bannerBusy = true
	bannerText.Text = entry.Text
	bannerText.TextColor3 = Ui.StyleColors[entry.Style] or Ui.Colors.Text
	bannerFrame.Visible = visible
	bannerText.TextTransparency = 0
	Ui.Pop(bannerFrame, 0.9)
	task.delay(entry.Seconds, function()
		Ui.Tween(bannerText, 0.25, { TextTransparency = 1 })
		task.wait(Ui.Motion(0.25))
		bannerFrame.Visible = false
		nextBanner()
	end)
end

function HUDController.Banner(text: string, style: string?, seconds: number?)
	for _, queued in bannerQueue do
		if queued.Text == text then
			return
		end
	end
	if #bannerQueue >= BANNER_QUEUE_MAX then
		table.remove(bannerQueue, 1)
	end
	table.insert(
		bannerQueue,
		{ Text = text, Style = style or "info", Seconds = seconds or JuiceConfig.EventBannerSeconds }
	)
	if not bannerBusy then
		nextBanner()
	end
end

-- Toasts ----------------------------------------------------------------------

function HUDController.Toast(title: string, body: string?, color: Color3?)
	local toasts = {}
	for _, child in toastHolder:GetChildren() do
		if child:IsA("Frame") then
			table.insert(toasts, child)
		end
	end
	while #toasts >= TOAST_MAX do
		local oldest = table.remove(toasts, 1)
		if oldest then
			oldest:Destroy()
		end
	end
	local card = Ui.Glass({
		Name = "Toast",
		Size = UDim2.fromOffset(280, if body and body ~= "" then 62 else 40),
		Parent = toastHolder,
	})
	local accent = color or Ui.Colors.GoldBright
	Ui.Label({
		Name = "Title",
		Position = UDim2.fromOffset(12, 6),
		Size = UDim2.new(1, -24, 0, 24),
		Font = Ui.Font.Title,
		TextSize = 15,
		TextColor3 = accent,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = title,
		Parent = card,
	})
	if body and body ~= "" then
		Ui.Label({
			Name = "Body",
			Position = UDim2.fromOffset(12, 30),
			Size = UDim2.new(1, -24, 0, 24),
			TextSize = 13,
			TextColor3 = Ui.Colors.Text,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Text = body,
			Parent = card,
		})
	end
	Ui.Pop(card, 0.8)
	task.delay(TOAST_SECONDS, function()
		if card.Parent then
			Ui.Tween(card, 0.25, { BackgroundTransparency = 1 })
			task.wait(Ui.Motion(0.25))
			card:Destroy()
		end
	end)
end

-- Pill ------------------------------------------------------------------------

local function setTargets()
	local profile = ClientState.Profile
	chips.Credits.Target = profile.Credits
	chips.Ore.Target = profile.Ore
	chips.Shards.Target = profile.VoidShards
	chips.Tokens.Target = profile.VoidlineTokens
	local full = profile.Ore >= EconomyRules.CargoCap(profile) and profile.Ore > 0
	if full ~= cargoTag.Visible then
		cargoTag.Visible = full
		if full then
			Ui.Pop(cargoTag, 0.6)
		end
	end
	chips.Ore.Value.TextColor3 = if full then Ui.Colors.GoldBright else Ui.Colors.Text
end

local function stepChips(dt: number)
	local k = if Ui.ReducedMotion then 1 else 1 - math.exp(-dt * 10)
	for _, chip in chips do
		if chip.Shown ~= chip.Target then
			local diff = chip.Target - chip.Shown
			if math.abs(diff) < 1 then
				chip.Shown = chip.Target
			else
				chip.Shown += diff * k
			end
			chip.Value.Text = chip.Format(math.floor(chip.Shown + 0.5))
		end
	end
end

function HUDController.Pulse(statName: string)
	local chip = chips[statName]
	if chip then
		Ui.Pop(chip.Frame, 1.25)
	end
end

local function updateGoalAndCue()
	local profile = ClientState.Profile
	goalLine.Text = HudCueRules.NextGoalLine(profile, ClientState.Ctx())
	local cue = HudCueRules.ComebackCue(profile, os.time())
	local showCue = cue ~= nil and visible
	if showCue ~= comebackFrame.Visible then
		comebackFrame.Visible = showCue
		if showCue then
			Ui.Pop(comebackFrame, 0.9)
		end
	end
	if cue then
		comebackLine.Text = cue
	end
end

-- World clock -----------------------------------------------------------------

local function updateClock()
	local now = Workspace:GetServerTimeNow()
	local anomalyId = Workspace:GetAttribute("AnomalyId")
	local biome = if type(anomalyId) == "string" then BiomeRegistry.ById[anomalyId] else nil
	local anomalyEnds = Workspace:GetAttribute("AnomalyEndsAt")
	if biome then
		local left = if type(anomalyEnds) == "number" then anomalyEnds - now else 0
		worldLine.Text = ("ANOMALY · %s · %s"):format(string.upper(biome.Name), Ui.Clock(left))
	else
		worldLine.Text = ""
	end
	local parts = {}
	local eventId = Workspace:GetAttribute("EventId")
	local event = if type(eventId) == "string" and eventId ~= "" then WorldEventRegistry.ById[eventId] else nil
	if event then
		local ends = Workspace:GetAttribute("EventEndsAt")
		table.insert(
			parts,
			("EVENT · %s · %s"):format(
				string.upper(event.Name),
				Ui.Clock(if type(ends) == "number" then ends - now else 0)
			)
		)
	else
		local nextAt = Workspace:GetAttribute("NextEventAt")
		if type(nextAt) == "number" and nextAt > now then
			table.insert(parts, "NEXT EVENT " .. Ui.Clock(nextAt - now))
		end
	end
	local surge = Workspace:GetAttribute("LuckSurgeEndsAt")
	if type(surge) == "number" and surge > now then
		table.insert(parts, "LUCK SURGE " .. Ui.Clock(surge - now))
	end
	local starfall = Workspace:GetAttribute("StarfallEndsAt")
	if type(starfall) == "number" and starfall > now then
		table.insert(parts, "STARFALL " .. Ui.Clock(starfall - now))
	end
	eventLine.Text = table.concat(parts, "  ·  ")
end

-- Soft contests -----------------------------------------------------------------

local function rockPart(id: number): BasePart?
	for _, part in CollectionService:GetTagged("VoidRock") do
		if part:GetAttribute("RockId") == id and part:IsA("BasePart") then
			return part
		end
	end
	return nil
end

local function onContest(update: any)
	if type(update) ~= "table" or type(update.Id) ~= "number" then
		return
	end
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local part = rockPart(update.Id)
	if root and part and (part.Position - root.Position).Magnitude > CONTEST_RANGE and not update.Done then
		return
	end
	if contest and contest.Id ~= update.Id and not contest.Done and os.clock() - contest.Seen < 1 then
		-- Another contest is already on screen and fresh; keep it.
		return
	end
	contest = { Id = update.Id, Seen = os.clock(), Done = update.Done == true }
	contestFrame.Visible = visible
	local max = if type(update.Max) == "number" and update.Max > 0 then update.Max else 1
	local health = if type(update.Health) == "number" then update.Health else 0
	contestTitle.Text = ("%s · %d%%"):format(
		string.upper(tostring(update.Label or "Meteor")),
		math.ceil(health / max * 100)
	)
	Ui.Tween(contestFill, 0.2, { Size = UDim2.fromScale(math.clamp(health / max, 0, 1), 1) })
	local rows = {}
	if type(update.Top) == "table" then
		for i, row in update.Top do
			if type(row) == "table" then
				table.insert(
					rows,
					("%d. %s %d%%"):format(i, tostring(row.Name), math.floor((row.Share or 0) * 100 + 0.5))
				)
			end
		end
	end
	contestTop.Text = if #rows > 0 then table.concat(rows, "   ") else "Mine it to claim a share (5% qualifies)"
end

local function stepContest()
	local current = contest
	if not current then
		return
	end
	local age = os.clock() - current.Seen
	if (current.Done and age > 2.5) or age > CONTEST_TIMEOUT then
		contest = nil
		contestFrame.Visible = false
	end
end

function HUDController.SetVisible(on: boolean)
	visible = on
	gui.Enabled = on
end

function HUDController.Gui(): ScreenGui
	return gui
end

function HUDController.Init()
	build()
	gui.Enabled = true
	visible = true
	setTargets()
	updateGoalAndCue()
	ClientState.OnChanged(function(changed)
		if
			changed.Credits
			or changed.Ore
			or changed.VoidShards
			or changed.VoidlineTokens
			or changed.CargoLevel
			or changed.TutorialFlags
			or changed.TutorialComplete
			or changed.Quests
			or changed.ForgeJobEndsAt
			or changed.LastDailyClaimDay
			or changed.Loaded
		then
			setTargets()
			updateGoalAndCue()
		end
		if changed.Settings or changed.Loaded then
			HUDController.SetVisible(ClientState.Profile.Settings.ClipMode ~= true)
		end
	end)
	Remotes.GetUnreliable("SoftContestUpdate").OnClientEvent:Connect(onContest)
	RunService.RenderStepped:Connect(stepChips)
	task.spawn(function()
		while gui.Parent do
			updateClock()
			updateGoalAndCue()
			stepContest()
			task.wait(0.5)
		end
	end)
end

return HUDController
