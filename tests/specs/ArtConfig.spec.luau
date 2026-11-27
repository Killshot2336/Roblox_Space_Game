--!nocheck
local Harness = require("../harness/Harness")
local Expect = require("../harness/Expect")
local expect = Expect.expect

local tests = {}

tests["ArtConfig ships mesh keys with zero placeholders"] = function()
	local world = Harness.new()
	local ArtConfig = world:require("ReplicatedStorage/Voidline/Config/ArtConfig")
	expect(ArtConfig.Meshes.MonolithHalf.MeshId).toBe(0)
	expect(ArtConfig.Meshes.GrinderCore.MeshId).toBe(0)
	expect(ArtConfig.UI.FallbackImage:find("rbxasset")).toBeTruthy()
	expect(ArtConfig.UI.Hotbar.Store.AssetId).toBe(0)
end

tests["ArtResolve returns fallback image until upload"] = function()
	local world = Harness.new()
	local ArtResolve = world:require("ReplicatedStorage/Voidline/Modules/ArtResolve")
	local ArtConfig = world:require("ReplicatedStorage/Voidline/Config/ArtConfig")
	expect(ArtResolve.UiImage("Hotbar", "Store")).toBe(ArtConfig.UI.FallbackImage)
	expect(ArtResolve.HasUploadedMesh("MonolithHalf")).toBe(false)
	expect(ArtResolve.MeshContent("MonolithHalf")).toBeNil()
end

return tests
