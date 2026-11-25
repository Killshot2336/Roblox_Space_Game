--!nocheck
-- Content report: loads every registry through the headless harness and
-- prints per-registry counts plus a "CONTENT TOTAL" line (used by
-- scripts/verify.sh and BUILD_LOG.md).
--   lune run scripts/content_report.luau                  -- print totals
--   lune run scripts/content_report.luau --write-snapshot -- refresh the ID snapshot
local fs = require("@lune/fs")
local process = require("@lune/process")

local Harness = require("../tests/harness/Harness")

local SNAPSHOT = "tests/snapshots/content_ids.txt"

local world = Harness.new()
local ContentIndex = world:require("ReplicatedStorage/Voidline/Content/ContentIndex")

local rows, total = ContentIndex.Totals()
print("Voidline content registries")
print(string.rep("-", 44))
for _, row in rows do
	print(("%-30s %6d  (%s)"):format(row.Label, row.Count, row.Kind))
end
print(string.rep("-", 44))
print(("%-30s %6d"):format("Codex-trackable entries", ContentIndex.CodexTotal))

local function snapshotLines()
	local lines = {}
	for _, info in ContentIndex.Registries do
		for _, entry in info.Registry.List do
			table.insert(lines, ("%s\t%s\t%s"):format(info.Kind, entry.Id, entry.Name))
		end
	end
	table.sort(lines)
	return lines
end

if table.find(process.args, "--write-snapshot") then
	local lines = snapshotLines()
	fs.writeDir("tests/snapshots")
	fs.writeFile(SNAPSHOT, table.concat(lines, "\n") .. "\n")
	print(("wrote %d ids to %s"):format(#lines, SNAPSHOT))
end

print(("CONTENT TOTAL %d"):format(total))
