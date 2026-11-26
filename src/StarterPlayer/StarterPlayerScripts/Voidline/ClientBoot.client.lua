--!strict
-- Voidline: Deep Space — client boot. Controllers subscribe first; the
-- profile replica connects last so the queued first snapshot reaches all of them.
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local Client = script.Parent.Client
local Ui = require(Client.Ui)
local ClientState = require(Client.ClientState)

local Controllers = script.Parent.Controllers
local HUDController = require(Controllers.HUDController)
local HotbarController = require(Controllers.HotbarController)
local OnboardingController = require(Controllers.OnboardingController)
local CameraController = require(Controllers.CameraController)
local TowController = require(Controllers.TowController)
local DroneController = require(Controllers.DroneController)
local WorldController = require(Controllers.WorldController)
local VFXController = require(Controllers.VFXController)
local StoreController = require(Controllers.StoreController)
local MenuController = require(Controllers.MenuController)
local InteractController = require(Controllers.InteractController)
local JuiceController = require(Controllers.JuiceController)
local AudioController = require(Controllers.AudioController)

-- Input pings keep the server's idle detector honest without any anti-idle
-- tricks: they only fire on real player input.
local ACTIVITY_PING_SECONDS = 30

pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end)

local function systemReducedMotion(): boolean
	local ok, value = pcall(function()
		return GuiService.ReducedMotionEnabled
	end)
	return ok and value == true
end

local function applySettings()
	local settings = ClientState.Profile.Settings
	Ui.ReducedMotion = settings.ReducedMotion == true or systemReducedMotion()
	local perf = settings.PerfMode == true
	DroneController.SetPerfMode(perf)
	WorldController.SetPerfMode(perf)
	VFXController.SetPerfMode(perf)
end

local function applyClipMode()
	local clip = ClientState.Profile.Settings.ClipMode == true
	if clip then
		StoreController.Close()
		MenuController.Close()
	end
	VFXController.SetClipHidden(clip)
	HUDController.SetVisible(not clip)
	HotbarController.SetVisible(not clip)
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, not clip)
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, not clip)
	end)
end

local function toggleClip()
	ClientState.Fire("SettingsUpdate", { ClipMode = ClientState.Profile.Settings.ClipMode ~= true })
	task.defer(applyClipMode)
end

local function openStore(tab: string?)
	MenuController.Close()
	StoreController.Open(tab)
end

local function openMenu(tab: string?)
	StoreController.Close()
	MenuController.Toggle(tab)
end

HUDController.Init()
VFXController.Init()
CameraController.Init()
TowController.Init()
DroneController.Init()
WorldController.Init()
OnboardingController.Init()
StoreController.Init()
MenuController.Init()
HotbarController.Init({
	OpenStore = function()
		if StoreController.IsOpen() then
			StoreController.Close()
		else
			openStore(nil)
		end
	end,
	OpenMenu = openMenu,
	ToggleClip = toggleClip,
})
JuiceController.Init()
AudioController.Init()

TowController.OnArrive(function(tow)
	if tow.Owner ~= Players.LocalPlayer.UserId then
		return
	end
	VFXController.Popup("TOW HOME", Ui.Colors.GoldBright, tow.To)
	CameraController.Shake(0.28, 0.28)
end)
task.spawn(InteractController.Init, {
	OpenStore = openStore,
	OpenMenu = function(tab: string?)
		StoreController.Close()
		MenuController.Open(tab)
	end,
})

ClientState.OnChanged(function(changed)
	if changed.Settings or changed.Loaded then
		applySettings()
		applyClipMode()
	end
end)
applySettings()
applyClipMode()

local lastPing = -math.huge
UserInputService.InputBegan:Connect(function()
	local now = os.clock()
	if now - lastPing >= ACTIVITY_PING_SECONDS then
		lastPing = now
		ClientState.Fire("PlayerInput")
	end
end)

ClientState.Init()
print(("[Voidline] Client online for %s"):format(Players.LocalPlayer.Name))
