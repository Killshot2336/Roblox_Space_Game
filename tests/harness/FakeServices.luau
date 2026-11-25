--!nocheck
-- Fake Roblox services for headless tests. Each factory receives the world
-- and the bare FakeInstance service node and decorates it with members.

local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local FakeInstance = require("./FakeInstance")
local Signal = require("./Signal")

local props = FakeInstance.props

local FakeServices = {}

local function setMember(node, key, value)
	props(node)[key] = value
end

local function newSignal(world)
	return Signal.new(world.scheduler)
end

-- Players -----------------------------------------------------------------
function FakeServices.Players(world, node)
	setMember(node, "PlayerAdded", newSignal(world))
	setMember(node, "PlayerRemoving", newSignal(world))
	setMember(node, "MaxPlayers", 12)
	setMember(node, "LocalPlayer", nil)
	setMember(node, "GetPlayers", function(self)
		local out = {}
		for _, child in FakeInstance.children(self) do
			if props(child).ClassName == "Player" then
				table.insert(out, child)
			end
		end
		return out
	end)
	setMember(node, "GetPlayerByUserId", function(self, userId)
		for _, child in FakeInstance.children(self) do
			if props(child).ClassName == "Player" and props(child).UserId == userId then
				return child
			end
		end
		return nil
	end)
	setMember(node, "GetPlayerFromCharacter", function(self, character)
		for _, child in FakeInstance.children(self) do
			if props(child).ClassName == "Player" and props(child).Character == character then
				return child
			end
		end
		return nil
	end)
	setMember(node, "GetUserIdFromNameAsync", function()
		return 0
	end)
	setMember(node, "GetNameFromUserIdAsync", function()
		return "Unknown"
	end)
end

-- RunService ----------------------------------------------------------------
function FakeServices.RunService(world, node)
	setMember(node, "Heartbeat", newSignal(world))
	setMember(node, "Stepped", newSignal(world))
	setMember(node, "RenderStepped", newSignal(world))
	setMember(node, "PreSimulation", newSignal(world))
	setMember(node, "PostSimulation", newSignal(world))
	setMember(node, "PreRender", newSignal(world))
	setMember(node, "IsStudio", function()
		return world.isStudio
	end)
	setMember(node, "IsServer", function()
		return world.context == "server"
	end)
	setMember(node, "IsClient", function()
		return world.context == "client"
	end)
	setMember(node, "IsRunning", function()
		return true
	end)
	setMember(node, "IsRunMode", function()
		return false
	end)
	setMember(node, "BindToRenderStep", function(_, name, _priority, fn)
		world.renderSteps[name] = fn
	end)
	setMember(node, "UnbindFromRenderStep", function(_, name)
		world.renderSteps[name] = nil
	end)
end

-- DataStoreService ------------------------------------------------------------
-- In-memory, optionally failing. world.dataStoreFailures[name] = n makes the
-- next n calls on that store throw. world.dataStoresDisabled = true simulates
-- Studio without API access (GetDataStore throws).
local function makeStore(world, storeName, ordered)
	local data = world.dataStoreData[storeName]
	if not data then
		data = {}
		world.dataStoreData[storeName] = data
	end
	local store = { _name = storeName }
	local function maybeFail(op)
		world.dataStoreCalls += 1
		local failures = world.dataStoreFailures[storeName] or 0
		if failures > 0 then
			world.dataStoreFailures[storeName] = failures - 1
			error(("502: fake DataStore failure on %s (%s)"):format(storeName, op))
		end
	end
	local function deepCopy(v)
		if type(v) ~= "table" then
			return v
		end
		-- Round-trip through JSON like the real service (drops functions, etc.).
		return serde.decode("json", serde.encode("json", v))
	end
	function store.GetAsync(_, key)
		maybeFail("GetAsync")
		return deepCopy(data[key])
	end
	function store.SetAsync(_, key, value)
		maybeFail("SetAsync")
		data[key] = deepCopy(value)
	end
	function store.UpdateAsync(_, key, transform)
		maybeFail("UpdateAsync")
		local result = transform(deepCopy(data[key]), nil)
		if result ~= nil then
			if world.dataStoreMaxBytes then
				local size = #serde.encode("json", result)
				if size > world.dataStoreMaxBytes then
					error("413: value too large")
				end
			end
			data[key] = deepCopy(result)
		end
		return deepCopy(data[key])
	end
	function store.IncrementAsync(_, key, delta)
		maybeFail("IncrementAsync")
		data[key] = (data[key] or 0) + (delta or 1)
		return data[key]
	end
	function store.RemoveAsync(_, key)
		maybeFail("RemoveAsync")
		local old = data[key]
		data[key] = nil
		return old
	end
	if ordered then
		function store.GetSortedAsync(_, ascending, pageSize)
			maybeFail("GetSortedAsync")
			local entries = {}
			for key, value in data do
				table.insert(entries, { key = key, value = value })
			end
			table.sort(entries, function(a, b)
				if ascending then
					return a.value < b.value
				end
				return a.value > b.value
			end)
			local page = {}
			for i = 1, math.min(pageSize or 50, #entries) do
				page[i] = entries[i]
			end
			return {
				GetCurrentPage = function()
					return page
				end,
				IsFinished = true,
				AdvanceToNextPageAsync = function() end,
			}
		end
	end
	return store
end

function FakeServices.DataStoreService(world, node)
	setMember(node, "GetDataStore", function(_, name, scope)
		if world.dataStoresDisabled then
			error("Studio access to API services is not enabled")
		end
		return makeStore(world, name .. "/" .. (scope or "global"), false)
	end)
	setMember(node, "GetOrderedDataStore", function(_, name, scope)
		if world.dataStoresDisabled then
			error("Studio access to API services is not enabled")
		end
		return makeStore(world, "ordered:" .. name .. "/" .. (scope or "global"), true)
	end)
	setMember(node, "GetRequestBudgetForRequestType", function()
		return world.dataStoreBudget
	end)
end

-- MarketplaceService ----------------------------------------------------------
function FakeServices.MarketplaceService(world, node)
	setMember(node, "PromptGamePassPurchaseFinished", newSignal(world))
	setMember(node, "PromptProductPurchaseFinished", newSignal(world))
	setMember(node, "PromptPurchaseFinished", newSignal(world))
	setMember(node, "ProcessReceipt", nil)
	setMember(node, "UserOwnsGamePassAsync", function(_, userId, passId)
		if world.marketplaceFails then
			error("HTTP 500 (fake)")
		end
		local owned = world.ownedGamePasses[userId]
		return owned ~= nil and owned[passId] == true
	end)
	setMember(node, "PromptGamePassPurchase", function(_, player, passId)
		table.insert(world.prompts, { kind = "GamePass", player = player, id = passId })
	end)
	setMember(node, "PromptProductPurchase", function(_, player, productId)
		table.insert(world.prompts, { kind = "Product", player = player, id = productId })
	end)
	setMember(node, "GetProductInfo", function(_, id)
		return { Name = "Fake " .. tostring(id), PriceInRobux = 0 }
	end)
end

-- PolicyService -----------------------------------------------------------------
function FakeServices.PolicyService(world, node)
	setMember(node, "GetPolicyInfoForPlayerAsync", function(_, player)
		if world.policyFails then
			error("HTTP 500 (fake policy)")
		end
		local restricted = world.paidRandomRestricted[props(player).UserId] == true
		return {
			ArePaidRandomItemsRestricted = restricted,
			AllowedExternalLinkReferences = {},
			IsPaidItemTradingAllowed = true,
			IsSubjectToChinaPolicies = false,
		}
	end)
end

-- HttpService -------------------------------------------------------------------
function FakeServices.HttpService(world, node)
	setMember(node, "GenerateGUID", function(_, wrap)
		world.guidCounter += 1
		local id = string.format("00000000-0000-4000-8000-%012d", world.guidCounter)
		if wrap == false then
			return id
		end
		return "{" .. id .. "}"
	end)
	setMember(node, "JSONEncode", function(_, value)
		return serde.encode("json", value)
	end)
	setMember(node, "JSONDecode", function(_, value)
		return serde.decode("json", value)
	end)
end

-- TextService -------------------------------------------------------------------
function FakeServices.TextService(world, node)
	setMember(node, "FilterStringAsync", function(_, text, _fromUserId)
		if world.textFilterFails then
			error("Text filter unavailable (fake)")
		end
		local filtered = string.gsub(text, "[Bb][Aa][Dd]", "###")
		return {
			GetNonChatStringForBroadcastAsync = function()
				return filtered
			end,
			GetNonChatStringForUserAsync = function()
				return filtered
			end,
			GetChatForUserAsync = function()
				return filtered
			end,
		}
	end)
	setMember(node, "GetTextSize", function(_, text, size)
		return roblox.Vector2.new(#text * size * 0.5, size)
	end)
end

-- TweenService --------------------------------------------------------------------
function FakeServices.TweenService(world, node)
	setMember(node, "Create", function(_, instance, info, goals)
		local tween = {
			Instance = instance,
			Completed = newSignal(world),
			PlaybackState = roblox.Enum.PlaybackState.Begin,
		}
		function tween.Play(self)
			self.PlaybackState = roblox.Enum.PlaybackState.Playing
			local duration = (type(info) == "table" and info.Time) or 0
			world.scheduler:delay(duration, function()
				if self.PlaybackState ~= roblox.Enum.PlaybackState.Playing then
					return
				end
				for k, v in goals do
					instance[k] = v
				end
				self.PlaybackState = roblox.Enum.PlaybackState.Completed
				self.Completed:Fire(roblox.Enum.PlaybackState.Completed)
			end)
		end
		function tween.Cancel(self)
			self.PlaybackState = roblox.Enum.PlaybackState.Cancelled
		end
		function tween.Pause(self)
			self.PlaybackState = roblox.Enum.PlaybackState.Paused
		end
		function tween.Destroy() end
		world.tweenCount += 1
		return tween
	end)
	setMember(node, "GetValue", function(_, alpha)
		return alpha
	end)
end

-- CollectionService ----------------------------------------------------------------
function FakeServices.CollectionService(world, node)
	local added, removed = {}, {}
	setMember(node, "GetTagged", function(_, tag)
		local out = {}
		for inst in world.tagged[tag] or {} do
			if not FakeInstance.Methods.IsDestroyed(inst) then
				table.insert(out, inst)
			end
		end
		return out
	end)
	setMember(node, "AddTag", function(_, inst, tag)
		FakeInstance.Methods.AddTag(inst, tag)
	end)
	setMember(node, "RemoveTag", function(_, inst, tag)
		FakeInstance.Methods.RemoveTag(inst, tag)
	end)
	setMember(node, "HasTag", function(_, inst, tag)
		return FakeInstance.Methods.HasTag(inst, tag)
	end)
	setMember(node, "GetInstanceAddedSignal", function(_, tag)
		added[tag] = added[tag] or newSignal(world)
		return added[tag]
	end)
	setMember(node, "GetInstanceRemovedSignal", function(_, tag)
		removed[tag] = removed[tag] or newSignal(world)
		return removed[tag]
	end)
	world.onTagAdded = function(inst, tag)
		world.tagged[tag] = world.tagged[tag] or setmetatable({}, { __mode = "k" })
		world.tagged[tag][inst] = true
		if added[tag] then
			added[tag]:Fire(inst)
		end
	end
	world.onTagRemoved = function(inst, tag)
		if world.tagged[tag] then
			world.tagged[tag][inst] = nil
		end
		if removed[tag] then
			removed[tag]:Fire(inst)
		end
	end
end

-- Workspace ---------------------------------------------------------------------------
function FakeServices.Workspace(world, node)
	setMember(node, "Gravity", 60)
	setMember(node, "StreamingEnabled", false)
	setMember(node, "GetServerTimeNow", function()
		return world.scheduler.epoch + world.scheduler.now
	end)
	setMember(node, "Raycast", function()
		return nil
	end)
	setMember(node, "GetPartBoundsInRadius", function()
		return {}
	end)
	setMember(node, "GetPartBoundsInBox", function()
		return {}
	end)
	setMember(node, "BulkMoveTo", function(_, parts, cframes)
		for i, part in parts do
			part.CFrame = cframes[i]
		end
	end)
	local camera = FakeInstance.new(world, "Camera", "Camera")
	props(camera).FieldOfView = 70
	props(camera).CFrame = roblox.CFrame.new()
	props(camera).ViewportSize = roblox.Vector2.new(1280, 720)
	FakeInstance.MT.__newindex(camera, "Parent", node)
	setMember(node, "CurrentCamera", camera)
end

-- Lighting / Sound / misc ---------------------------------------------------------
function FakeServices.Lighting(_, node)
	setMember(node, "ClockTime", 0)
	setMember(node, "Brightness", 2)
	setMember(node, "ExposureCompensation", 0)
	setMember(node, "Ambient", roblox.Color3.new(0.05, 0.05, 0.12))
	setMember(node, "OutdoorAmbient", roblox.Color3.new(0.08, 0.06, 0.18))
	setMember(node, "FogColor", roblox.Color3.new(0.05, 0.02, 0.12))
	setMember(node, "FogStart", 400)
	setMember(node, "FogEnd", 2000)
end

function FakeServices.SoundService(_, node)
	setMember(node, "AmbientReverb", roblox.Enum.ReverbType.NoReverb)
	setMember(node, "PlayLocalSound", function() end)
end

function FakeServices.Debris(world, node)
	setMember(node, "AddItem", function(_, inst, lifetime)
		world.scheduler:delay(lifetime or 10, function()
			FakeInstance.Methods.Destroy(inst)
		end)
	end)
end

function FakeServices.ProximityPromptService(world, node)
	setMember(node, "PromptTriggered", newSignal(world))
	setMember(node, "PromptShown", newSignal(world))
	setMember(node, "PromptHidden", newSignal(world))
end

function FakeServices.UserInputService(world, node)
	setMember(node, "InputBegan", newSignal(world))
	setMember(node, "InputEnded", newSignal(world))
	setMember(node, "InputChanged", newSignal(world))
	setMember(node, "LastInputTypeChanged", newSignal(world))
	setMember(node, "TouchStarted", newSignal(world))
	setMember(node, "TouchEnabled", world.touchEnabled == true)
	setMember(node, "KeyboardEnabled", world.touchEnabled ~= true)
	setMember(node, "MouseEnabled", world.touchEnabled ~= true)
	setMember(node, "GamepadEnabled", false)
	setMember(node, "GetLastInputType", function()
		return roblox.Enum.UserInputType.Keyboard
	end)
	setMember(node, "GetFocusedTextBox", function()
		return nil
	end)
end

function FakeServices.ContextActionService(world, node)
	world.boundActions = {}
	setMember(node, "BindAction", function(_, name, fn, createTouchButton, ...)
		world.boundActions[name] = { fn = fn, touch = createTouchButton, inputs = table.pack(...) }
	end)
	setMember(node, "BindActionAtPriority", function(_, name, fn, createTouchButton, _priority, ...)
		world.boundActions[name] = { fn = fn, touch = createTouchButton, inputs = table.pack(...) }
	end)
	setMember(node, "UnbindAction", function(_, name)
		world.boundActions[name] = nil
	end)
	setMember(node, "SetTitle", function() end)
	setMember(node, "SetImage", function() end)
	setMember(node, "SetPosition", function() end)
	setMember(node, "SetDescription", function() end)
	setMember(node, "GetButton", function()
		return nil
	end)
end

function FakeServices.GuiService(world, node)
	setMember(node, "MenuOpened", newSignal(world))
	setMember(node, "MenuClosed", newSignal(world))
	setMember(node, "GetGuiInset", function()
		return roblox.Vector2.new(0, 36), roblox.Vector2.zero
	end)
	setMember(node, "ReducedMotionEnabled", false)
	setMember(node, "PreferredTransparency", 1)
end

function FakeServices.StarterGui(_, node)
	setMember(node, "SetCore", function() end)
	setMember(node, "GetCore", function()
		return nil
	end)
	setMember(node, "SetCoreGuiEnabled", function() end)
end

function FakeServices.BadgeService(world, node)
	setMember(node, "AwardBadge", function(_, userId, badgeId)
		table.insert(world.badges, { userId = userId, badgeId = badgeId })
		return true
	end)
	setMember(node, "UserHasBadgeAsync", function()
		return false
	end)
end

function FakeServices.MessagingService(_, node)
	setMember(node, "PublishAsync", function() end)
	setMember(node, "SubscribeAsync", function()
		return { Disconnect = function() end }
	end)
end

function FakeServices.TeleportService(_, node)
	setMember(node, "TeleportAsync", function() end)
end

function FakeServices.PhysicsService(world, node)
	world.collisionGroups = {}
	setMember(node, "RegisterCollisionGroup", function(_, name)
		world.collisionGroups[name] = world.collisionGroups[name] or {}
	end)
	setMember(node, "IsCollisionGroupRegistered", function(_, name)
		return world.collisionGroups[name] ~= nil
	end)
	setMember(node, "CollisionGroupSetCollidable", function() end)
end

function FakeServices.ContentProvider(_, node)
	setMember(node, "PreloadAsync", function() end)
end

function FakeServices.LocalizationService(_, node)
	setMember(node, "RobloxLocaleId", "en-us")
end

function FakeServices.AnalyticsService(world, node)
	setMember(node, "LogCustomEvent", function(_, player, name, value)
		table.insert(world.analytics, { player = player, name = name, value = value })
	end)
	setMember(node, "LogEconomyEvent", function(_, player, flowType, currency, amount, ending, transactionType, sku)
		table.insert(world.analytics, {
			player = player,
			flowType = flowType,
			currency = currency,
			amount = amount,
			ending = ending,
			transactionType = transactionType,
			sku = sku,
		})
	end)
	setMember(node, "LogOnboardingFunnelStepEvent", function(_, player, step, name)
		table.insert(world.analytics, { player = player, funnelStep = step, name = name })
	end)
	setMember(node, "LogProgressionEvent", function() end)
end

return FakeServices
