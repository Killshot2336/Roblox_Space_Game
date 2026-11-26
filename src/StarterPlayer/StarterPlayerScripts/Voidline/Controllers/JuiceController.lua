--!strict
-- Turns server JuiceEvent messages into feedback: banners, toasts, popups,
-- camera nudges and world VFX. Gameplay never depends on any of this.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Voidline = ReplicatedStorage:WaitForChild("Voidline")
local EconomyConfig = require(Voidline.Config.EconomyConfig)
local PlotLayout = require(Voidline.Modules.PlotLayout)
local ContentIndex = require(Voidline.Content.ContentIndex)
local OreRegistry = require(Voidline.Content.OreRegistry)
local RelicRegistry = require(Voidline.Content.RelicRegistry)
local DroneRegistry = require(Voidline.Content.DroneRegistry)
local Remotes = require(Voidline.Remotes)

local Client = script.Parent.Parent.Client
local Ui = require(Client.Ui)
local HUDController = require(script.Parent.HUDController)
local VFXController = require(script.Parent.VFXController)
local CameraController = require(script.Parent.CameraController)
local OnboardingController = require(script.Parent.OnboardingController)
local WorldController = require(script.Parent.WorldController)
local MenuController = require(script.Parent.MenuController)

local JuiceController = {}

local HAZARD_BANNER_RANGE = 140

local player = Players.LocalPlayer

local STORE_REASONS: { [string]: string } = {
	tokens = "Not enough Voidline Tokens",
	owned = "You already own that",
	unavailable = "Not available yet",
	restricted = "Not available in your region",
	unknown = "That item does not exist",
}

local UPGRADE_REASONS: { [string]: string } = {
	funds = "Not enough Credits",
	locked = "Raise your Station Tier first",
	max = "Already maxed",
	unknown = "Unknown upgrade",
}

local WARP_REASONS: { [string]: string } = {
	pass = "Use the hub gate, or get the Deep-Space Warp Pass to warp from anywhere",
	closed = "The Void Rift is closed until its event",
	unknown = "Unknown destination",
}

local CODE_REASONS: { [string]: string } = {
	invalid = "Codes are letters and numbers only",
	unknown = "That code is not valid",
	used = "You already redeemed that code",
}

local SQUAD_REASONS: { [string]: string } = {
	target = "That pilot is not here",
	busy = "That pilot is already in a squad or has pending invites",
	full = "Your squad is full",
	leader = "Only the squad leader can invite",
}

local FORGE_REASONS: { [string]: string } = {
	shards = "The forge needs 25 Void Shards",
	busy = "The forge is busy",
	artifacts = "No artifacts to turn in",
}

local function nameOf(id: any): string
	if type(id) ~= "string" then
		return ""
	end
	local entry = ContentIndex.Get(id)
	return if entry and entry.Name then entry.Name else id
end

local function rootPosition(): Vector3?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return if root then root.Position else nil
end

local function rewardText(credits: any, shards: any, extra: any): string
	local parts = {}
	if type(credits) == "number" and credits > 0 then
		table.insert(parts, "+◆" .. Ui.Compact(credits))
	end
	if type(shards) == "number" and shards > 0 then
		table.insert(parts, "+✦" .. Ui.Compact(shards))
	end
	if type(extra) == "string" and extra ~= "" then
		table.insert(parts, extra)
	end
	return table.concat(parts, "  ")
end

local HANDLERS: { [string]: (any) -> () } = {}

HANDLERS.Banner = function(m)
	HUDController.Banner(tostring(m.Text or ""), if type(m.Style) == "string" then m.Style else "info")
end

HANDLERS.Ore = function(m)
	local amount = if type(m.Amount) == "number" then m.Amount else 0
	local ore = if type(m.OreId) == "string" then OreRegistry.ById[m.OreId] else nil
	local position = if typeof(m.Position) == "Vector3"
		then m.Position
		else VFXController.OwnPlotWorld(PlotLayout.Grinder)
	if amount > 0 then
		VFXController.Popup(
			("+%d %s"):format(amount, if ore then ore.Name else "ore"),
			if ore then ore.Glow else nil,
			position
		)
		HUDController.Pulse("Ore")
		VFXController.GrinderPulse()
	end
	if type(m.Refined) == "number" and m.Refined > 0 then
		VFXController.Popup("+◆" .. Ui.Compact(m.Refined) .. " (overflow refined)", Ui.Colors.GoldBright, nil)
		HUDController.Pulse("Credits")
	end
end

HANDLERS.Sell = function(m)
	local credits = if type(m.Credits) == "number" then m.Credits else 0
	VFXController.Popup(
		"+◆" .. Ui.Compact(credits),
		Ui.Colors.GoldBright,
		VFXController.OwnPlotWorld(PlotLayout.Refinery)
	)
	HUDController.Pulse("Credits")
	CameraController.Shake(0.2, 0.15)
end

HANDLERS.Credits = function(m)
	if type(m.Amount) == "number" and m.Amount > 0 then
		VFXController.Popup("+◆" .. Ui.Compact(m.Amount), Ui.Colors.GoldBright, nil)
		HUDController.Pulse("Credits")
	end
end

HANDLERS.Shards = function(m)
	if type(m.Amount) == "number" and m.Amount > 0 then
		VFXController.Popup("+✦" .. Ui.Compact(m.Amount) .. " Void Shards", Ui.Colors.Void, nil)
		HUDController.Pulse("Shards")
	end
end

HANDLERS.Tokens = function(m)
	HUDController.Toast(
		"+⬡" .. tostring(m.Amount or 0) .. " VOIDLINE TOKENS",
		"Spend them in the Store (B)",
		Ui.Colors.Cyan
	)
	HUDController.Pulse("Tokens")
end

HANDLERS.Upgrade = function(m)
	local def = if type(m.Id) == "string" then EconomyConfig.Upgrades[m.Id] else nil
	local label = if def then def.Label else "Upgrade"
	VFXController.Popup(("%s · Lv %s"):format(label, tostring(m.Level or "")), Ui.Colors.Good, rootPosition())
	if type(m.Id) == "string" then
		VFXController.PadFlash(m.Id)
	end
	CameraController.Shake(0.15, 0.12)
end

HANDLERS.UpgradeFail = function(m)
	HUDController.Banner(UPGRADE_REASONS[tostring(m.Reason)] or "Cannot upgrade yet", "warn", 2)
end

HANDLERS.BridgeIgnite = function(m)
	VFXController.BridgeSweep()
	OnboardingController.Finale()
	local bonus = if type(m.Bonus) == "number" then m.Bonus else 0
	HUDController.Banner(("ENERGY BRIDGE ONLINE · +%d CREDITS"):format(bonus), "gold", 4)
	HUDController.Pulse("Credits")
end

HANDLERS.CargoFull = function()
	HUDController.Banner("Cargo full · refine at your gold pad", "gold")
end

HANDLERS.Evolution = function(m)
	local evolution = if type(m.Id) == "string" then DroneRegistry.ById[m.Id] else nil
	HUDController.Toast("DRONES EVOLVED", if evolution then evolution.Name else "", Ui.Colors.GoldBright)
	CameraController.Shake(0.35, 0.3)
	CameraController.Punch(4, 0.8)
end

HANDLERS.Mutation = function(m)
	local mutation = if type(m.Id) == "string" then DroneRegistry.ById[m.Id] else nil
	HUDController.Toast(
		"MUTATION · " .. (if mutation then string.upper(mutation.Name) else "?"),
		"Equip it in the Locker (C)",
		if mutation then mutation.Accent else Ui.Colors.Void
	)
end

HANDLERS.Achievement = function(m)
	HUDController.Toast(
		"ACHIEVEMENT · " .. tostring(m.Name or ""),
		rewardText(
			m.Credits,
			m.Shards,
			if type(m.Title) == "string" and m.Title ~= "" then "Title: " .. nameOf(m.Title) else nil
		),
		Ui.Colors.GoldBright
	)
end

HANDLERS.Quest = function(m)
	HUDController.Toast(
		"QUEST COMPLETE · " .. tostring(m.Name or ""),
		rewardText(m.Credits, m.Shards, if type(m.Unlock) == "string" and m.Unlock ~= "" then nameOf(m.Unlock) else nil),
		Ui.Colors.Good
	)
end

HANDLERS.Relic = function(m)
	local relic = if type(m.Id) == "string" then RelicRegistry.ById[m.Id] else nil
	if m.New then
		HUDController.Toast(
			"RELIC FOUND · " .. (if relic then relic.Name else "?"),
			if relic then relic.Rarity .. " · " .. relic.SetName else "",
			if relic then relic.Glow else Ui.Colors.Void
		)
		CameraController.Punch(3, 0.6)
	else
		HUDController.Toast(
			"DUPLICATE RELIC",
			("+✦%d Void Shards"):format(if type(m.DuplicateShards) == "number" then m.DuplicateShards else 0),
			Ui.Colors.Void
		)
	end
end

HANDLERS.Codex = function(m)
	VFXController.Popup(
		("CODEX +1 · %s (%s/%s)"):format(nameOf(m.Id), tostring(m.Count or "?"), tostring(m.Total or "?")),
		Ui.Colors.Cyan,
		nil
	)
end

HANDLERS.CodexMilestone = function(m)
	HUDController.Banner(
		("CODEX MILESTONE · %s ENTRIES · x%.2f CREDITS"):format(
			tostring(m.Count or "?"),
			if type(m.Multiplier) == "number" then m.Multiplier else 1
		),
		"gold"
	)
end

HANDLERS.ContestShare = function(m)
	local share = if type(m.Share) == "number" then math.floor(m.Share * 100 + 0.5) else 0
	HUDController.Banner(
		("%s%s · %d%% SHARE · %s"):format(
			if m.Top then "TOP CONTRIBUTOR · " else "",
			string.upper(tostring(m.Label or m.Kind or "Meteor")),
			share,
			rewardText(nil, m.Shards, ("+%d ore towed home"):format(if type(m.Ore) == "number" then m.Ore else 0))
		),
		if m.Top then "gold" else "good"
	)
end

HANDLERS.PassGranted = function(m)
	HUDController.Banner(tostring(m.Name or "Pass") .. " unlocked", "gold")
	VFXController.ScreenFlash(Ui.Colors.GoldBright, 0.5)
end

HANDLERS.Store = function(m)
	if m.Ok then
		HUDController.Banner(
			if m.Currency == "Robux" then "Summon queued · thank you!" else "Purchased · enjoy!",
			"good"
		)
	else
		HUDController.Banner(STORE_REASONS[tostring(m.Reason)] or "Purchase failed", "warn")
	end
end

HANDLERS.Equip = function(m)
	if m.Ok then
		VFXController.Popup(if m.Id == "" then "Unequipped" else "Equipped · " .. nameOf(m.Id), Ui.Colors.Good, nil)
	else
		HUDController.Banner("You have not unlocked that yet", "warn", 2)
	end
end

HANDLERS.SquadInvite = function(m)
	if type(m.FromUserId) == "number" then
		MenuController.ShowInvite(m.FromUserId, tostring(m.FromName or "A pilot"), m.Seconds)
	end
end

HANDLERS.SquadError = function(m)
	HUDController.Banner(SQUAD_REASONS[tostring(m.Reason)] or "Squad request failed", "warn", 2)
end

HANDLERS.SquadChallenge = function(m)
	HUDController.Toast("SQUAD CHALLENGE COMPLETE", rewardText(m.Credits, m.Shards, nil), Ui.Colors.Cyan)
end

HANDLERS.Warp = function()
	VFXController.ScreenFlash(Ui.Colors.Void, 0.5)
end

HANDLERS.WarpLocked = function(m)
	HUDController.Banner(WARP_REASONS[tostring(m.Reason)] or "Cannot warp there yet", "warn")
end

HANDLERS.VoidCatch = function()
	VFXController.ScreenFlash(Ui.Colors.Void, 0.6)
	HUDController.Banner("The Voidline caught you · warped home", "void")
end

HANDLERS.Code = function(m)
	local text = if m.Ok
		then ("%s  %s"):format(tostring(m.Message or "Code redeemed"), rewardText(m.Credits, m.Shards, nil))
		else CODE_REASONS[tostring(m.Reason)] or "That code did not work"
	MenuController.CodeResult(text)
	HUDController.Banner(text, if m.Ok then "gold" else "warn")
end

HANDLERS.Daily = function(m)
	if m.Ok then
		HUDController.Toast(
			("DAY %s STREAK CLAIMED"):format(tostring(m.Day or "?")),
			rewardText(m.Credits, m.Shards, if type(m.Trial) == "string" then m.Trial .. " trial (24h)" else nil),
			Ui.Colors.GoldBright
		)
	else
		HUDController.Banner("Already claimed today · come back tomorrow", "info", 2)
	end
end

HANDLERS.DailyReady = function(m)
	HUDController.Banner(("Daily streak ready · Day %s · open the menu (C)"):format(tostring(m.Day or 1)), "gold")
end

HANDLERS.Rebirth = function(m)
	if m.Ok then
		HUDController.Banner(
			("VOID REBIRTH %s · x%.2f CREDITS · +✦%s"):format(
				tostring(m.Count or "?"),
				if type(m.Multiplier) == "number" then m.Multiplier else 1,
				tostring(m.Shards or 0)
			),
			"void",
			4
		)
		VFXController.ScreenFlash(Ui.Colors.Void, 0.8)
		CameraController.Shake(0.6, 0.6)
	else
		HUDController.Banner(("Rebirth needs Station Tier %s"):format(tostring(m.Required or "?")), "warn")
	end
end

HANDLERS.Forge = function(m)
	if m.Phase == "start" then
		HUDController.Banner(
			("Forging an artifact · %ds%s"):format(
				math.ceil(if type(m.Seconds) == "number" then m.Seconds else 0),
				if m.Cooling then " (cooling)" else ""
			),
			"void"
		)
	elseif m.Phase == "done" then
		HUDController.Toast("ARTIFACT FORGED", "Turn it in for Voidline Tokens", Ui.Colors.Void)
	elseif m.Phase == "busy" then
		HUDController.Banner("The forge is still working", "info", 2)
	else
		HUDController.Banner(FORGE_REASONS[tostring(m.Reason)] or "The forge cannot start", "warn", 2)
	end
end

HANDLERS.LaserTuned = function()
	VFXController.Popup("Laser retuned", Ui.Colors.Cyan, rootPosition())
end

HANDLERS.AfkIdle = function()
	HUDController.Banner("Idle orbit · your drones rest until you move", "info", 4)
end

HANDLERS.AfkResume = function()
	HUDController.Banner("Welcome back, pilot", "good", 2)
end

HANDLERS.RiftCleared = function()
	HUDController.Toast("VOID RIFT CLEARED", "Cache claimed", Ui.Colors.Void)
	VFXController.ScreenFlash(Ui.Colors.Void, 0.5)
end

HANDLERS.Hazard = function(m)
	WorldController.Hazard(m)
	local position = rootPosition()
	if m.Phase == "telegraph" and position and typeof(m.Position) == "Vector3" then
		if (position - m.Position).Magnitude <= HAZARD_BANNER_RANGE then
			HUDController.Banner(string.upper(nameOf(m.Id)) .. " INCOMING", "warn", 2)
		end
	end
end

HANDLERS.WorldEvent = function(m)
	if m.Phase == "start" then
		CameraController.Punch(3, 0.8)
	end
end

function JuiceController.Handle(message: any)
	if type(message) ~= "table" or type(message.Kind) ~= "string" then
		return
	end
	local handler = HANDLERS[message.Kind]
	if handler then
		handler(message)
	end
end

function JuiceController.Kinds(): { string }
	local out = {}
	for kind in HANDLERS do
		table.insert(out, kind)
	end
	table.sort(out)
	return out
end

function JuiceController.Init()
	Remotes.Get("JuiceEvent").OnClientEvent:Connect(JuiceController.Handle)
end

return JuiceController
