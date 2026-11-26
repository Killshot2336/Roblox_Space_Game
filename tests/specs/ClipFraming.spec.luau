--!nocheck
local Harness = require("../harness/Harness")
local Expect = require("../harness/Expect")
local expect = Expect.expect

local tests = {}

tests["ClipFramingConfig defines clip FOV and hero shots"] = function()
	local world = Harness.new()
	local cfg = world:require("ReplicatedStorage/Voidline/Config/ClipFramingConfig")
	expect(cfg.ClipFov).toBeGreaterThan(70)
	expect(#cfg.Shots).toBeGreaterThanOrEqual(4)
	for _, shot in cfg.Shots do
		expect(type(shot.Id)).toBe("string")
		expect(#shot.Id > 0).toBe(true)
		expect(type(shot.Stand)).toBe("userdata")
		expect(type(shot.LookAt)).toBe("userdata")
	end
end

return tests
