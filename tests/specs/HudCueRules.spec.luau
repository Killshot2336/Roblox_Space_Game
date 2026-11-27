--!nocheck
local Harness = require("../harness/Harness")
local Expect = require("../harness/Expect")
local expect = Expect.expect

local tests = {}

tests["HudCueRules surfaces daily comeback cue"] = function()
	local world = Harness.new()
	local ProfileSchema = world:require("ReplicatedStorage/Voidline/Modules/ProfileSchema")
	local HudCueRules = world:require("ReplicatedStorage/Voidline/Rules/HudCueRules")
	local profile = ProfileSchema.Default()
	profile.LastDailyClaimDay = ""
	local cue = HudCueRules.ComebackCue(profile, os.time())
	expect(cue ~= nil).toBe(true)
	expect(cue:find("DAILY")).toBeTruthy()
end

tests["HudCueRules builds next goal from tutorial"] = function()
	local world = Harness.new()
	local ProfileSchema = world:require("ReplicatedStorage/Voidline/Modules/ProfileSchema")
	local HudCueRules = world:require("ReplicatedStorage/Voidline/Rules/HudCueRules")
	local profile = ProfileSchema.Default()
	local line = HudCueRules.NextGoalLine(profile, { Perks = {}, CreditBoost = 1, CodexMult = 1 })
	expect(line:find("NEXT GOAL")).toBeTruthy()
end

return tests
