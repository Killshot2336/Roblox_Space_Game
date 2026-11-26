--!strict
-- Four holographic OrderedDataStore boards on the hub, refreshed every
-- ~90 s (never per change). Writes are budget-checked; if DataStores are
-- unavailable (Studio without API access) the boards show this server only.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Voidline = ReplicatedStorage:WaitForChild("Voidline")
local GameConfig = require(Voidline.Config.GameConfig)
local HubLayout = require(Voidline.Modules.HubLayout)
local FormatNumber = require(Voidline.Modules.FormatNumber)

local PlayerDataService = require(script.Parent.PlayerDataService)

local LeaderboardService = {}

local ROWS = 10
local STORE_PREFIX = "VoidlineBoard_"

type Row = { UserId: number, Value: number }

local VALUE_OF: { [string]: (any, any) -> number } = {
	TopCredits = function(profile)
		return profile.LifetimeCredits
	end,
	TopRebirths = function(profile)
		return profile.Rebirths
	end,
	CodexDiscoveries = function(_profile, session)
		return session.CodexCount
	end,
	TopSummoners = function(profile)
		return profile.Stats.Summons or 0
	end,
}

local stores: { [string]: any } = {}
local names: { [number]: string } = {}
local storesAvailable = true

local function getStore(boardId: string): any
	if not storesAvailable then
		return nil
	end
	if stores[boardId] then
		return stores[boardId]
	end
	local ok, store = pcall(function()
		return DataStoreService:GetOrderedDataStore(STORE_PREFIX .. boardId)
	end)
	if ok and store then
		stores[boardId] = store
		return store
	end
	storesAvailable = false
	return nil
end

local function nameFor(userId: number): string
	local cached = names[userId]
	if cached then
		return cached
	end
	local online = Players:GetPlayerByUserId(userId)
	if online then
		names[userId] = online.DisplayName
		return online.DisplayName
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	local resolved = if ok and type(name) == "string" then name else "Pilot"
	names[userId] = resolved
	return resolved
end

local function budget(): number
	local ok, value = pcall(function()
		return DataStoreService:GetRequestBudgetForRequestType(Enum.DataStoreRequestType.SetIncrementSortedAsync)
	end)
	return if ok then value else 0
end

local function writeOnline(boardId: string)
	local store = getStore(boardId)
	if not store then
		return
	end
	for _, session in PlayerDataService._sessions do
		if budget() < 4 then
			return
		end
		local value = math.floor(VALUE_OF[boardId](session.Profile, session))
		if value > 0 then
			pcall(function()
				store:SetAsync(tostring(session.UserId), value)
			end)
		end
	end
end

local function readTop(boardId: string): { Row }
	local rows: { Row } = {}
	local store = getStore(boardId)
	if store then
		local ok, pages = pcall(function()
			return store:GetSortedAsync(false, ROWS)
		end)
		if ok and pages then
			local okPage, page = pcall(function()
				return pages:GetCurrentPage()
			end)
			if okPage and page then
				for _, entry in page do
					local userId = tonumber(entry.key)
					if userId then
						table.insert(rows, { UserId = userId, Value = entry.value })
					end
				end
			end
		end
	end
	if #rows == 0 then
		-- Fallback: this server's pilots.
		for _, session in PlayerDataService._sessions do
			table.insert(
				rows,
				{ UserId = session.UserId, Value = math.floor(VALUE_OF[boardId](session.Profile, session)) }
			)
		end
		table.sort(rows, function(a, b)
			if a.Value ~= b.Value then
				return a.Value > b.Value
			end
			return a.UserId < b.UserId
		end)
		while #rows > ROWS do
			table.remove(rows)
		end
	end
	return rows
end

local function boardGui(board: BasePart, title: string): Frame
	local existing = board:FindFirstChild("BoardGui")
	if existing then
		return (existing :: any).List
	end
	local gui = Instance.new("SurfaceGui")
	gui.Name = "BoardGui"
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 0
	gui.PixelsPerStud = 30
	gui.Parent = board
	local header = Instance.new("TextLabel")
	header.Name = "Header"
	header.BackgroundTransparency = 1
	header.Size = UDim2.fromScale(1, 0.12)
	header.Font = Enum.Font.GothamBlack
	header.TextScaled = true
	header.TextColor3 = GameConfig.Colors.GoldBright
	header.Text = title
	header.Parent = gui
	local list = Instance.new("Frame")
	list.Name = "List"
	list.BackgroundTransparency = 1
	list.Position = UDim2.fromScale(0.05, 0.14)
	list.Size = UDim2.fromScale(0.9, 0.84)
	list.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 2)
	layout.Parent = list
	return list
end

local function render(boardId: string, rows: { Row })
	local map = Workspace:FindFirstChild("VoidlineMap")
	local hub = map and map:FindFirstChild("Hub")
	local boards = hub and hub:FindFirstChild("Leaderboards")
	local board = boards and boards:FindFirstChild(boardId)
	if not board or not board:IsA("BasePart") then
		return
	end
	local title = board:GetAttribute("Title")
	local list = boardGui(board, if type(title) == "string" then title else boardId)
	for i = 1, ROWS do
		local label = list:FindFirstChild("Row" .. i) :: TextLabel?
		if not label then
			local newLabel = Instance.new("TextLabel")
			newLabel.Name = "Row" .. i
			newLabel.LayoutOrder = i
			newLabel.BackgroundTransparency = 1
			newLabel.Size = UDim2.fromScale(1, 0.095)
			newLabel.Font = Enum.Font.GothamMedium
			newLabel.TextScaled = true
			newLabel.TextXAlignment = Enum.TextXAlignment.Left
			newLabel.TextColor3 = if i <= 3 then GameConfig.Colors.Gold else Color3.fromRGB(220, 220, 235)
			newLabel.Parent = list
			label = newLabel
		end
		local row = rows[i]
		local target = label :: TextLabel
		target.Text = if row
			then ("%d. %s  ·  %s"):format(i, nameFor(row.UserId), FormatNumber.Compact(row.Value))
			else ""
	end
end

function LeaderboardService.Refresh()
	for _, def in HubLayout.Boards do
		writeOnline(def.Id)
		render(def.Id, readTop(def.Id))
	end
end

function LeaderboardService.Init()
	task.spawn(function()
		task.wait(10)
		while true do
			local ok, err = pcall(function(): ...any
				return LeaderboardService.Refresh()
			end)
			if not ok then
				warn("[Voidline] leaderboard refresh failed: " .. tostring(err))
			end
			task.wait(GameConfig.LeaderboardRefreshSeconds)
		end
	end)
end

return LeaderboardService
