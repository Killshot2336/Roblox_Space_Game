--!nocheck
-- Self-tests for the headless harness so later failures are trustworthy.
local Harness = require("../harness/Harness")
local Expect = require("../harness/Expect")
local expect = Expect.expect

local tests = {}

tests["resolves script.Parent requires through the sourcemap"] = function()
	local world = Harness.new()
	local OreMath = world:require("ReplicatedStorage/Voidline/Modules/OreMath")
	expect(type(OreMath.SellValue)).toBe("function")
end

tests["caches modules per world and isolates worlds"] = function()
	local a = Harness.new()
	local b = Harness.new()
	local m1 = a:require("ReplicatedStorage/Voidline/Config/GameConfig")
	local m2 = a:require("ReplicatedStorage/Voidline/Config/GameConfig")
	local m3 = b:require("ReplicatedStorage/Voidline/Config/GameConfig")
	expect(m1).toBe(m2)
	expect(m1 == m3).toBe(false)
end

tests["scheduler advances fake time for task.wait and os.clock"] = function()
	local world = Harness.new()
	local env = world.envPrototype
	local woke = nil
	world:run(function()
		local start = env.os.clock()
		env.task.wait(2)
		woke = env.os.clock() - start
	end)
	expect(woke).toBeNil()
	world:advance(1.9)
	expect(woke).toBeNil()
	world:advance(0.2)
	expect(woke).toBeCloseTo(2, 1e-6)
	world:assertNoErrors()
end

tests["attributes reject tables and NaN like a strict Roblox"] = function()
	local world = Harness.new()
	local part = world:newInstance("Part")
	part:SetAttribute("Health", 10)
	expect(part:GetAttribute("Health")).toBe(10)
	expect(function()
		part:SetAttribute("Bad", {})
	end).toThrow("not a supported attribute type")
	expect(function()
		part:SetAttribute("Nan", 0 / 0)
	end).toThrow("NaN")
end

tests["BasePart Position follows CFrame"] = function()
	local world = Harness.new()
	local part = world:newInstance("Part")
	part.CFrame = Harness.roblox.CFrame.new(1, 2, 3)
	expect(part.Position.X).toBe(1)
	part.Position = Harness.roblox.Vector3.new(4, 5, 6)
	expect(part.CFrame.Position.Z).toBe(6)
end

tests["fake players fire PlayerAdded and get a character"] = function()
	local world = Harness.new()
	local Players = world:service("Players")
	local seen = nil
	Players.PlayerAdded:Connect(function(p)
		seen = p
	end)
	local player = world:addPlayer(101, "Tester")
	expect(seen).toBe(player)
	expect(player.Character ~= nil).toBe(true)
	expect(player.Character:FindFirstChild("HumanoidRootPart") ~= nil).toBe(true)
	expect(Players:GetPlayerByUserId(101)).toBe(player)
	world:assertNoErrors()
end

return tests
