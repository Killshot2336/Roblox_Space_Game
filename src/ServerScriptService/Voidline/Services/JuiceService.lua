--!strict
-- Server -> client feedback. Every message is a small table with a `Kind`;
-- the client turns kinds into banners, popups, sounds and camera nudges.
-- Gameplay never depends on these arriving.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Voidline").Remotes)

local JuiceService = {}

function JuiceService.Send(player: Player, kind: string, payload: { [string]: any }?)
	local message: { [string]: any } = payload or {}
	message.Kind = kind
	Remotes.Get("JuiceEvent"):FireClient(player, message)
end

function JuiceService.All(kind: string, payload: { [string]: any }?)
	local message: { [string]: any } = payload or {}
	message.Kind = kind
	Remotes.Get("JuiceEvent"):FireAllClients(message)
end

-- Style: "info" | "good" | "gold" | "void" | "warn"
function JuiceService.Banner(player: Player, text: string, style: string?)
	JuiceService.Send(player, "Banner", { Text = text, Style = style or "info" })
end

function JuiceService.BannerAll(text: string, style: string?)
	JuiceService.All("Banner", { Text = text, Style = style or "info" })
end

function JuiceService.Init() end

return JuiceService
