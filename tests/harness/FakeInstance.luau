--!nocheck
-- Lightweight Roblox Instance double for headless tests.
-- Supports parenting, child lookup by index, attributes (with Roblox type
-- rules), tags, property/attribute change signals, BasePart CFrame/Position
-- coupling, Model pivots and RemoteEvent client/server plumbing.

local roblox = require("@lune/roblox")
local Signal = require("./Signal")

local CFrame = roblox.CFrame
local Vector3 = roblox.Vector3

local FakeInstance = {}

local IS_FAKE = setmetatable({}, { __mode = "k" })
FakeInstance.IS_FAKE = IS_FAKE

local CLASS_PARENT = {
	-- physical
	PVInstance = "Instance",
	BasePart = "PVInstance",
	FormFactorPart = "BasePart",
	Part = "FormFactorPart",
	WedgePart = "FormFactorPart",
	CornerWedgePart = "BasePart",
	TrussPart = "BasePart",
	SpawnLocation = "Part",
	Seat = "Part",
	MeshPart = "TriangleMeshPart",
	TriangleMeshPart = "BasePart",
	PartOperation = "TriangleMeshPart",
	UnionOperation = "PartOperation",
	Terrain = "BasePart",
	Model = "PVInstance",
	WorldRoot = "Model",
	Workspace = "WorldRoot",
	Actor = "Model",
	-- scripts
	LuaSourceContainer = "Instance",
	BaseScript = "LuaSourceContainer",
	Script = "BaseScript",
	LocalScript = "Script",
	ModuleScript = "LuaSourceContainer",
	-- networking
	BaseRemoteEvent = "Instance",
	RemoteEvent = "BaseRemoteEvent",
	UnreliableRemoteEvent = "BaseRemoteEvent",
	RemoteFunction = "Instance",
	BindableEvent = "Instance",
	BindableFunction = "Instance",
	-- values
	ValueBase = "Instance",
	ObjectValue = "ValueBase",
	IntValue = "ValueBase",
	NumberValue = "ValueBase",
	StringValue = "ValueBase",
	BoolValue = "ValueBase",
	Color3Value = "ValueBase",
	Vector3Value = "ValueBase",
	CFrameValue = "ValueBase",
	-- containers
	Folder = "Instance",
	Configuration = "Instance",
	Player = "Instance",
	Humanoid = "Instance",
	Attachment = "Instance",
	Bone = "Attachment",
	Camera = "PVInstance",
	-- constraints / joints
	JointInstance = "Instance",
	Weld = "JointInstance",
	Motor6D = "JointInstance",
	WeldConstraint = "Instance",
	Constraint = "Instance",
	AlignPosition = "Constraint",
	AlignOrientation = "Constraint",
	-- effects
	Beam = "Instance",
	Trail = "Instance",
	ParticleEmitter = "Instance",
	Fire = "Instance",
	Sparkles = "Instance",
	Smoke = "Instance",
	Highlight = "Instance",
	Light = "Instance",
	PointLight = "Light",
	SpotLight = "Light",
	SurfaceLight = "Light",
	Sound = "Instance",
	SoundGroup = "Instance",
	SoundEffect = "Instance",
	ReverbSoundEffect = "SoundEffect",
	EqualizerSoundEffect = "SoundEffect",
	PostEffect = "Instance",
	BloomEffect = "PostEffect",
	ColorCorrectionEffect = "PostEffect",
	SunRaysEffect = "PostEffect",
	BlurEffect = "PostEffect",
	DepthOfFieldEffect = "PostEffect",
	Atmosphere = "Instance",
	Sky = "Instance",
	Clouds = "Instance",
	ProximityPrompt = "Instance",
	ClickDetector = "Instance",
	Decal = "FaceInstance",
	Texture = "Decal",
	FaceInstance = "Instance",
	SpecialMesh = "FileMesh",
	FileMesh = "DataModelMesh",
	DataModelMesh = "Instance",
	-- gui
	GuiBase = "Instance",
	GuiBase2d = "GuiBase",
	LayerCollector = "GuiBase2d",
	ScreenGui = "LayerCollector",
	BillboardGui = "LayerCollector",
	SurfaceGui = "SurfaceGuiBase",
	SurfaceGuiBase = "LayerCollector",
	GuiObject = "GuiBase2d",
	Frame = "GuiObject",
	CanvasGroup = "GuiObject",
	ScrollingFrame = "GuiObject",
	TextLabel = "GuiObject",
	TextBox = "GuiObject",
	ImageLabel = "GuiObject",
	ViewportFrame = "GuiObject",
	GuiButton = "GuiObject",
	TextButton = "GuiButton",
	ImageButton = "GuiButton",
	UIComponent = "Instance",
	UIBase = "Instance",
	UICorner = "UIComponent",
	UIStroke = "UIComponent",
	UIGradient = "UIComponent",
	UIPadding = "UIComponent",
	UIScale = "UIComponent",
	UIAspectRatioConstraint = "UIComponent",
	UISizeConstraint = "UIComponent",
	UITextSizeConstraint = "UIComponent",
	UIGridStyleLayout = "UIComponent",
	UIListLayout = "UIGridStyleLayout",
	UIGridLayout = "UIGridStyleLayout",
	UIFlexItem = "UIComponent",
}
FakeInstance.CLASS_PARENT = CLASS_PARENT

local SIGNAL_NAMES = {
	Changed = true,
	ChildAdded = true,
	ChildRemoved = true,
	DescendantAdded = true,
	DescendantRemoving = true,
	AncestryChanged = true,
	AttributeChanged = true,
	Destroying = true,
	Touched = true,
	TouchEnded = true,
	OnServerEvent = true,
	OnClientEvent = true,
	Event = true,
	CharacterAdded = true,
	CharacterAppearanceLoaded = true,
	CharacterRemoving = true,
	Died = true,
	StateChanged = true,
	Completed = true,
	Triggered = true,
	TriggerEnded = true,
	PromptShown = true,
	PromptHidden = true,
	MouseButton1Click = true,
	MouseButton1Down = true,
	MouseButton1Up = true,
	MouseEnter = true,
	MouseLeave = true,
	Activated = true,
	InputBegan = true,
	InputEnded = true,
	InputChanged = true,
	FocusLost = true,
	Focused = true,
	Loaded = true,
	Ended = true,
	Played = true,
	Stopped = true,
	MouseClick = true,
	Idled = true,
}

local ATTRIBUTE_TYPES = {
	["nil"] = true,
	boolean = true,
	number = true,
	string = true,
	Vector2 = true,
	Vector3 = true,
	CFrame = true,
	Color3 = true,
	BrickColor = true,
	UDim = true,
	UDim2 = true,
	NumberRange = true,
	NumberSequence = true,
	ColorSequence = true,
	Rect = true,
	Font = true,
	EnumItem = true,
}

function FakeInstance.isA(className, target)
	if target == "Instance" then
		return true
	end
	local current = className
	while current do
		if current == target then
			return true
		end
		current = CLASS_PARENT[current]
	end
	return false
end

local Methods = {}
local InstanceMT = {}

local function props(self)
	return rawget(self, "_props")
end

local function children(self)
	return rawget(self, "_children")
end

local function world(self)
	return rawget(self, "_world")
end

local function signal(self, name)
	local signals = rawget(self, "_signals")
	local s = signals[name]
	if not s then
		s = Signal.new(world(self) and world(self).scheduler)
		signals[name] = s
	end
	return s
end

local function propSignal(self, name)
	local map = rawget(self, "_propSignals")
	local s = map[name]
	if not s then
		s = Signal.new(world(self) and world(self).scheduler)
		map[name] = s
	end
	return s
end

local function attrSignal(self, name)
	local map = rawget(self, "_attrSignals")
	local s = map[name]
	if not s then
		s = Signal.new(world(self) and world(self).scheduler)
		map[name] = s
	end
	return s
end

local function firePropChanged(self, key)
	local map = rawget(self, "_propSignals")
	if map[key] then
		map[key]:Fire()
	end
	local signals = rawget(self, "_signals")
	if signals.Changed then
		signals.Changed:Fire(key)
	end
end

function FakeInstance.new(w, className, name)
	local self = setmetatable({}, InstanceMT)
	rawset(self, "_world", w)
	rawset(self, "_props", { ClassName = className, Name = name or className, Archivable = true })
	rawset(self, "_children", {})
	rawset(self, "_attributes", {})
	rawset(self, "_attrSignals", {})
	rawset(self, "_propSignals", {})
	rawset(self, "_signals", {})
	rawset(self, "_tags", {})
	rawset(self, "_destroyed", false)
	IS_FAKE[self] = true
	local defaults = FakeInstance.defaultsFor(className)
	if defaults then
		for k, v in defaults do
			props(self)[k] = v
		end
	end
	if w and w.onInstanceCreated then
		w.onInstanceCreated(self)
	end
	return self
end

function FakeInstance.defaultsFor(className)
	if FakeInstance.isA(className, "BasePart") then
		return {
			CFrame = CFrame.new(),
			Size = Vector3.new(4, 1, 2),
			Anchored = false,
			CanCollide = true,
			CanTouch = true,
			CanQuery = true,
			Transparency = 0,
			LocalTransparencyModifier = 0,
			Massless = false,
			Color = roblox.Color3.new(0.6, 0.6, 0.6),
			Material = roblox.Enum.Material.Plastic,
			AssemblyLinearVelocity = Vector3.zero,
		}
	elseif className == "Model" then
		return { WorldPivot = CFrame.new() }
	elseif className == "Attachment" then
		return { CFrame = CFrame.new(), WorldPosition = Vector3.zero }
	elseif className == "Humanoid" then
		return { WalkSpeed = 16, JumpPower = 50, JumpHeight = 7.2, Health = 100, MaxHealth = 100, UseJumpPower = false }
	elseif className == "Sound" then
		return { Volume = 0.5, PlaybackSpeed = 1, IsPlaying = false, IsLoaded = true, TimePosition = 0, Looped = false }
	elseif className == "ObjectValue" then
		return { Value = nil }
	elseif className == "ScreenGui" or className == "BillboardGui" or className == "SurfaceGui" then
		return { Enabled = true }
	elseif className == "ParticleEmitter" or className == "Beam" or className == "Trail" then
		return { Enabled = true }
	end
	return nil
end

-- index / newindex ---------------------------------------------------------

InstanceMT.__index = function(self, key)
	local method = Methods[key]
	if method then
		return method
	end
	local p = props(self)
	local value = p[key]
	if value ~= nil then
		return value
	end
	if key == "Parent" then
		return nil
	end
	if FakeInstance.isA(p.ClassName, "BasePart") and key == "Position" then
		return p.CFrame.Position
	end
	if FakeInstance.isA(p.ClassName, "BasePart") and key == "Orientation" then
		return Vector3.zero
	end
	if SIGNAL_NAMES[key] then
		return signal(self, key)
	end
	local w = world(self)
	if w and w.extraMembers then
		local extra = w.extraMembers(self, key)
		if extra ~= nil then
			return extra
		end
	end
	for _, child in children(self) do
		if props(child).Name == key then
			return child
		end
	end
	return nil
end

local function isAncestorOf(ancestor, inst)
	local current = props(inst).Parent
	while current do
		if current == ancestor then
			return true
		end
		current = props(current).Parent
	end
	return false
end

local function fireDescendantAdded(node, added)
	local current = node
	while current do
		local signals = rawget(current, "_signals")
		if signals.DescendantAdded then
			signals.DescendantAdded:Fire(added)
		end
		current = props(current).Parent
	end
end

local function setParent(self, newParent)
	if rawget(self, "_destroyed") then
		error(("The Parent property of %s is locked"):format(props(self).Name), 3)
	end
	if newParent ~= nil and not IS_FAKE[newParent] then
		error("Parent must be an Instance", 3)
	end
	if newParent == self or (newParent and isAncestorOf(self, newParent)) then
		error("Attempt to set parent would result in circular reference", 3)
	end
	local old = props(self).Parent
	if old == newParent then
		return
	end
	if old then
		local list = children(old)
		for i, child in list do
			if child == self then
				table.remove(list, i)
				break
			end
		end
		local oldSignals = rawget(old, "_signals")
		if oldSignals.ChildRemoved then
			oldSignals.ChildRemoved:Fire(self)
		end
	end
	props(self).Parent = newParent
	if newParent then
		table.insert(children(newParent), self)
		local newSignals = rawget(newParent, "_signals")
		if newSignals.ChildAdded then
			newSignals.ChildAdded:Fire(self)
		end
		fireDescendantAdded(newParent, self)
	end
	local signals = rawget(self, "_signals")
	if signals.AncestryChanged then
		signals.AncestryChanged:Fire(self, newParent)
	end
	firePropChanged(self, "Parent")
	local w = world(self)
	if w and w.onParentChanged then
		w.onParentChanged(self, old, newParent)
	end
end

InstanceMT.__newindex = function(self, key, value)
	local p = props(self)
	if key == "Parent" then
		setParent(self, value)
		return
	end
	if key == "ClassName" then
		error("ClassName is read-only", 2)
	end
	if FakeInstance.isA(p.ClassName, "BasePart") then
		if key == "Position" then
			local old = p.CFrame
			p.CFrame = CFrame.new(value) * (old - old.Position)
			firePropChanged(self, "CFrame")
			firePropChanged(self, "Position")
			return
		end
	end
	local old = p[key]
	p[key] = value
	if old ~= value then
		firePropChanged(self, key)
		if key == "CFrame" and FakeInstance.isA(p.ClassName, "BasePart") then
			firePropChanged(self, "Position")
		end
	end
end

InstanceMT.__tostring = function(self)
	return props(self).Name
end

-- methods ------------------------------------------------------------------

function Methods.GetChildren(self)
	return table.clone(children(self))
end

function Methods.GetDescendants(self)
	local out = {}
	local function walk(node)
		for _, child in children(node) do
			table.insert(out, child)
			walk(child)
		end
	end
	walk(self)
	return out
end

function Methods.FindFirstChild(self, name, recursive)
	for _, child in children(self) do
		if props(child).Name == name then
			return child
		end
	end
	if recursive then
		for _, child in children(self) do
			local found = Methods.FindFirstChild(child, name, true)
			if found then
				return found
			end
		end
	end
	return nil
end

function Methods.FindFirstChildOfClass(self, className)
	for _, child in children(self) do
		if props(child).ClassName == className then
			return child
		end
	end
	return nil
end

function Methods.FindFirstChildWhichIsA(self, className, recursive)
	for _, child in children(self) do
		if FakeInstance.isA(props(child).ClassName, className) then
			return child
		end
	end
	if recursive then
		for _, child in children(self) do
			local found = Methods.FindFirstChildWhichIsA(child, className, true)
			if found then
				return found
			end
		end
	end
	return nil
end

function Methods.FindFirstAncestor(self, name)
	local current = props(self).Parent
	while current do
		if props(current).Name == name then
			return current
		end
		current = props(current).Parent
	end
	return nil
end

function Methods.FindFirstAncestorOfClass(self, className)
	local current = props(self).Parent
	while current do
		if props(current).ClassName == className then
			return current
		end
		current = props(current).Parent
	end
	return nil
end

function Methods.FindFirstAncestorWhichIsA(self, className)
	local current = props(self).Parent
	while current do
		if FakeInstance.isA(props(current).ClassName, className) then
			return current
		end
		current = props(current).Parent
	end
	return nil
end

function Methods.WaitForChild(self, name, timeout)
	local found = Methods.FindFirstChild(self, name)
	if found then
		return found
	end
	local w = world(self)
	if w and coroutine.isyieldable() then
		local deadline = w.scheduler.now + (timeout or 5)
		while w.scheduler.now < deadline do
			w.scheduler:wait(0.05)
			found = Methods.FindFirstChild(self, name)
			if found then
				return found
			end
		end
		if timeout then
			return nil
		end
	end
	if timeout then
		return nil
	end
	error(("Infinite yield: WaitForChild(%q) on %s"):format(tostring(name), Methods.GetFullName(self)), 2)
end

function Methods.IsA(self, className)
	return FakeInstance.isA(props(self).ClassName, className)
end

function Methods.IsDescendantOf(self, ancestor)
	return isAncestorOf(ancestor, self)
end

function Methods.IsAncestorOf(self, descendant)
	return isAncestorOf(self, descendant)
end

function Methods.GetFullName(self)
	local parts = {}
	local current = self
	while current do
		local p = props(current)
		if p.ClassName == "DataModel" then
			break
		end
		table.insert(parts, 1, p.Name)
		current = p.Parent
	end
	return table.concat(parts, ".")
end

function Methods.GetAttribute(self, name)
	return rawget(self, "_attributes")[name]
end

function Methods.GetAttributes(self)
	return table.clone(rawget(self, "_attributes"))
end

function Methods.SetAttribute(self, name, value)
	if type(name) ~= "string" or #name == 0 or #name > 100 then
		error("Attribute name must be a non-empty string of at most 100 characters", 2)
	end
	local kind = typeof(value)
	if not ATTRIBUTE_TYPES[kind] then
		error(("%s is not a supported attribute type (attribute %q)"):format(kind, name), 2)
	end
	if kind == "number" and value ~= value then
		-- Roblox accepts NaN, but it is always a bug in our code base.
		error(("NaN written to attribute %q"):format(name), 2)
	end
	local attributes = rawget(self, "_attributes")
	local old = attributes[name]
	attributes[name] = value
	if old ~= value then
		local s = rawget(self, "_attrSignals")[name]
		if s then
			s:Fire()
		end
		local signals = rawget(self, "_signals")
		if signals.AttributeChanged then
			signals.AttributeChanged:Fire(name)
		end
	end
end

function Methods.GetAttributeChangedSignal(self, name)
	return attrSignal(self, name)
end

function Methods.GetPropertyChangedSignal(self, name)
	return propSignal(self, name)
end

function Methods.AddTag(self, tag)
	rawget(self, "_tags")[tag] = true
	local w = world(self)
	if w and w.onTagAdded then
		w.onTagAdded(self, tag)
	end
end

function Methods.RemoveTag(self, tag)
	rawget(self, "_tags")[tag] = nil
	local w = world(self)
	if w and w.onTagRemoved then
		w.onTagRemoved(self, tag)
	end
end

function Methods.HasTag(self, tag)
	return rawget(self, "_tags")[tag] == true
end

function Methods.GetTags(self)
	local out = {}
	for tag in rawget(self, "_tags") do
		table.insert(out, tag)
	end
	table.sort(out)
	return out
end

function Methods.ClearAllChildren(self)
	for _, child in table.clone(children(self)) do
		Methods.Destroy(child)
	end
end

function Methods.Destroy(self)
	if rawget(self, "_destroyed") then
		return
	end
	local signals = rawget(self, "_signals")
	if signals.Destroying then
		signals.Destroying:Fire()
	end
	for _, child in table.clone(children(self)) do
		Methods.Destroy(child)
	end
	if props(self).Parent then
		setParent(self, nil)
	end
	rawset(self, "_destroyed", true)
	local w = world(self)
	if w and w.onDestroyed then
		w.onDestroyed(self)
	end
end

function Methods.Clone(self)
	local copy = FakeInstance.new(world(self), props(self).ClassName, props(self).Name)
	for k, v in props(self) do
		if k ~= "Parent" and k ~= "ClassName" then
			props(copy)[k] = v
		end
	end
	for k, v in rawget(self, "_attributes") do
		rawget(copy, "_attributes")[k] = v
	end
	for tag in rawget(self, "_tags") do
		rawget(copy, "_tags")[tag] = true
	end
	for _, child in children(self) do
		local childCopy = Methods.Clone(child)
		setParent(childCopy, copy)
	end
	return copy
end

function Methods.IsDestroyed(self)
	return rawget(self, "_destroyed")
end

-- PVInstance ---------------------------------------------------------------

function Methods.GetPivot(self)
	local p = props(self)
	if FakeInstance.isA(p.ClassName, "BasePart") then
		return p.CFrame
	end
	if p.PrimaryPart then
		return props(p.PrimaryPart).CFrame
	end
	return p.WorldPivot or CFrame.new()
end

function Methods.PivotTo(self, cf)
	local p = props(self)
	if FakeInstance.isA(p.ClassName, "BasePart") then
		InstanceMT.__newindex(self, "CFrame", cf)
		return
	end
	local current = Methods.GetPivot(self)
	local delta = cf * current:Inverse()
	for _, d in Methods.GetDescendants(self) do
		if FakeInstance.isA(props(d).ClassName, "BasePart") then
			InstanceMT.__newindex(d, "CFrame", delta * props(d).CFrame)
		end
	end
	p.WorldPivot = cf
end

function Methods.GetBoundingBox(self)
	return Methods.GetPivot(self), props(self).Size or Vector3.new(4, 4, 4)
end

function Methods.ScaleTo() end

function Methods.SetNetworkOwner(self, owner)
	local p = props(self)
	if p.Anchored then
		error("Cannot call SetNetworkOwner on an anchored part", 2)
	end
	rawset(self, "_networkOwner", owner)
	rawset(self, "_networkOwnerSet", true)
end

function Methods.GetNetworkOwner(self)
	return rawget(self, "_networkOwner")
end

function Methods.CanSetNetworkOwnership(self)
	if props(self).Anchored then
		return false, "Anchored"
	end
	return true, nil
end

function Methods.SetNetworkOwnershipAuto() end
function Methods.ApplyImpulse() end
function Methods.ApplyAngularImpulse() end

function Methods.GetMass()
	return 1
end

-- Player / Humanoid ---------------------------------------------------------

function Methods.Kick(self, message)
	rawset(self, "_kicked", message or "")
	local w = world(self)
	if w and w.onKick then
		w.onKick(self, message)
	end
end

function Methods.LoadCharacter(self)
	local w = world(self)
	if w and w.onLoadCharacter then
		w.onLoadCharacter(self)
	end
end

function Methods.MoveTo(self, position)
	rawset(self, "_moveTarget", position)
end

function Methods.ChangeState() end
function Methods.GetState()
	return roblox.Enum.HumanoidStateType.Running
end
function Methods.TakeDamage(self, amount)
	props(self).Health = math.max(0, (props(self).Health or 100) - amount)
end
function Methods.GetPlayingAnimationTracks()
	return {}
end
function Methods.LoadAnimation()
	return { Play = function() end, Stop = function() end }
end

-- Remote / Bindable ----------------------------------------------------------

function Methods.FireClient(self, player, ...)
	assert(IS_FAKE[player] and props(player).ClassName == "Player", "FireClient: argument 1 must be a Player")
	local w = world(self)
	if w and w.onFireClient then
		w.onFireClient(self, player, table.pack(...))
	end
end

function Methods.FireAllClients(self, ...)
	local w = world(self)
	if w and w.onFireAllClients then
		w.onFireAllClients(self, table.pack(...))
	end
end

function Methods.FireServer(self, ...)
	local w = world(self)
	if w and w.onFireServer then
		w.onFireServer(self, table.pack(...))
	end
end

function Methods.Fire(self, ...)
	signal(self, "Event"):Fire(...)
end

-- Sounds / tweens / effects -------------------------------------------------

function Methods.Play(self)
	props(self).IsPlaying = true
	local signals = rawget(self, "_signals")
	if signals.Played then
		signals.Played:Fire()
	end
end

function Methods.Stop(self)
	props(self).IsPlaying = false
end

function Methods.Pause(self)
	props(self).IsPlaying = false
end

function Methods.Resume(self)
	props(self).IsPlaying = true
end

function Methods.Emit(self, count)
	rawset(self, "_emitted", (rawget(self, "_emitted") or 0) + (count or 1))
end

function Methods.Clear() end

-- Gui helpers -----------------------------------------------------------------

function Methods.CaptureFocus() end
function Methods.ReleaseFocus() end
function Methods.TweenPosition()
	return true
end
function Methods.TweenSize()
	return true
end
function Methods.TweenSizeAndPosition()
	return true
end

FakeInstance.Methods = Methods
FakeInstance.MT = InstanceMT
FakeInstance.props = props
FakeInstance.children = children
FakeInstance.signal = signal

return FakeInstance
