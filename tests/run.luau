--!nocheck
-- Voidline headless test runner (Lune).
-- Usage: lune run tests/run.luau [filter]
-- Each spec module returns { [testName] = function(ctx) ... end }.

local fs = require("@lune/fs")
local process = require("@lune/process")

local Expect = require("./harness/Expect")

local filter = process.args[1]

local specDir = "tests/specs"
local files = {}
for _, name in fs.readDir(specDir) do
	if string.match(name, "%.spec%.luau$") then
		table.insert(files, name)
	end
end
table.sort(files)

local passed, failed, specCount = 0, 0, 0
local failures = {}
local started = os.clock()

for _, file in files do
	local moduleName = string.gsub(file, "%.luau$", "")
	local ok, spec = pcall(require, "./specs/" .. moduleName)
	if not ok then
		failed += 1
		table.insert(failures, ("%s: failed to load spec: %s"):format(file, tostring(spec)))
		continue
	end
	specCount += 1
	local names = {}
	for testName in spec do
		table.insert(names, testName)
	end
	table.sort(names)
	for _, testName in names do
		local fullName = moduleName .. " :: " .. testName
		if filter and not string.find(fullName, filter, 1, true) then
			continue
		end
		local testOk, err = xpcall(spec[testName], debug.traceback)
		if testOk then
			passed += 1
			print("  PASS  " .. fullName)
		else
			failed += 1
			print("  FAIL  " .. fullName)
			table.insert(failures, fullName .. "\n" .. tostring(err))
		end
	end
end

local elapsed = os.clock() - started
if #failures > 0 then
	print("")
	print("Failures:")
	for _, f in failures do
		print("----------------------------------------")
		print(f)
	end
end
print("")
print(
	("TESTS: %d passed, %d failed, %d specs, %d assertions (%.2fs)"):format(
		passed,
		failed,
		specCount,
		Expect.assertions,
		elapsed
	)
)
if failed > 0 then
	process.exit(1)
end
