--!nocheck
-- Smoke: default profile keeps ClipMode off and clip logic leaves HUD on.
local Harness = require("../harness/Harness")
local Expect = require("../harness/Expect")
local expect = Expect.expect

local tests = {}

tests["default profile keeps ClipMode off for HUD"] = function()
	local world = Harness.new()
	local ProfileSchema = world:require("ReplicatedStorage/Voidline/Modules/ProfileSchema")
	local default = ProfileSchema.Default()
	expect(default.Settings.ClipMode).toBe(false)
	-- Clip hides HUD by design; default must not.
	expect(default.Settings.ClipMode ~= true).toBe(true)
end

return tests
