#!/usr/bin/env bash
# Voidline: Deep Space — full verification pass.
#   selene (lint) + luau-lsp analyze (types) + StyLua check + Lune tests
#   + content report + Rojo build.
# Usage: scripts/verify.sh
# Green (exit 0) = 0 selene errors, luau-lsp errors <= VERIFY_MAX_LSP_ERRORS
# (default 0), all tests pass, Rojo build succeeds.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

LUAU_LSP_TYPES_VERSION="${LUAU_LSP_TYPES_VERSION:-1.70.1}"
TOOLS_DIR="$ROOT/tools"
DEFS="$TOOLS_DIR/globalTypes.None.d.luau"
OUT_PLACE="${VERIFY_OUT:-/tmp/verify.rbxlx}"
LOG_DIR="${VERIFY_LOG_DIR:-/tmp/voidline-verify}"
MAX_LSP_ERRORS="${VERIFY_MAX_LSP_ERRORS:-0}"
MAX_SELENE_ERRORS="${VERIFY_MAX_SELENE_ERRORS:-0}"
mkdir -p "$LOG_DIR" "$TOOLS_DIR"

missing=0
for tool in rojo selene luau-lsp lune stylua; do
	if ! command -v "$tool" >/dev/null 2>&1; then
		echo "verify: missing tool '$tool' (see README.md > Toolchain)"
		missing=1
	fi
done
[ "$missing" -eq 0 ] || exit 2

if [ ! -s "$DEFS" ]; then
	echo "verify: fetching Roblox global types (luau-lsp $LUAU_LSP_TYPES_VERSION)"
	curl -fsSL -o "$DEFS" \
		"https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/$LUAU_LSP_TYPES_VERSION/scripts/globalTypes.None.d.luau" ||
		{
			echo "verify: could not download global types"
			exit 2
		}
fi
if [ ! -s "$ROOT/roblox.yml" ]; then
	echo "verify: generating selene roblox std"
	selene generate-roblox-std >/dev/null || exit 2
fi

count_lines() {
	# count_lines <file> <extended-regex>
	grep -Ec "$2" "$1" 2>/dev/null || true
}

status=0

# 0. Sourcemap (drives luau-lsp require resolution and the Lune harness).
if ! rojo sourcemap default.project.json -o sourcemap.json >"$LOG_DIR/sourcemap.log" 2>&1; then
	echo "verify: rojo sourcemap failed"
	cat "$LOG_DIR/sourcemap.log"
	exit 2
fi

# 1. selene
selene --display-style=quiet src >"$LOG_DIR/selene.log" 2>&1
SELENE_ERRORS=$(sed -n 's/^\([0-9][0-9]*\) errors$/\1/p' "$LOG_DIR/selene.log" | tail -1)
SELENE_WARNINGS=$(sed -n 's/^\([0-9][0-9]*\) warnings$/\1/p' "$LOG_DIR/selene.log" | tail -1)
SELENE_PARSE=$(sed -n 's/^\([0-9][0-9]*\) parse errors$/\1/p' "$LOG_DIR/selene.log" | tail -1)
SELENE_ERRORS=${SELENE_ERRORS:-0}
SELENE_WARNINGS=${SELENE_WARNINGS:-0}
SELENE_PARSE=${SELENE_PARSE:-0}
SELENE_ERRORS=$((SELENE_ERRORS + SELENE_PARSE))
if [ "$SELENE_ERRORS" -gt "$MAX_SELENE_ERRORS" ]; then status=1; fi

# 2. luau-lsp analyze (Roblox types at script security level "None").
luau-lsp analyze \
	--definitions=@roblox="$DEFS" \
	--sourcemap=sourcemap.json \
	--base-luaurc=.luaurc \
	src >"$LOG_DIR/luau-lsp.log" 2>&1
LSP_ERRORS=$(count_lines "$LOG_DIR/luau-lsp.log" '\): (TypeError|SyntaxError):')
LSP_TOTAL=$(count_lines "$LOG_DIR/luau-lsp.log" '^(/|src/).*\): [A-Za-z]+:')
LSP_WARNINGS=$((LSP_TOTAL - LSP_ERRORS))
if [ "$LSP_WARNINGS" -lt 0 ]; then LSP_WARNINGS=0; fi
if [ "$LSP_ERRORS" -gt "$MAX_LSP_ERRORS" ]; then status=1; fi

# 3. StyLua drift (informational unless VERIFY_STRICT_FORMAT=1).
stylua --check src tests scripts >"$LOG_DIR/stylua.log" 2>&1
STYLUA_DRIFT=$(count_lines "$LOG_DIR/stylua.log" '^Diff in ')
if [ "${VERIFY_STRICT_FORMAT:-0}" = "1" ] && [ "$STYLUA_DRIFT" -gt 0 ]; then status=1; fi

# 4. Lune headless tests.
lune run tests/run.luau >"$LOG_DIR/tests.log" 2>&1
TEST_EXIT=$?
TEST_LINE=$(grep -E '^TESTS: ' "$LOG_DIR/tests.log" | tail -1)
TESTS_PASSED=$(printf '%s' "$TEST_LINE" | sed -n 's/^TESTS: \([0-9]*\) passed.*/\1/p')
TESTS_FAILED=$(printf '%s' "$TEST_LINE" | sed -n 's/^TESTS: [0-9]* passed, \([0-9]*\) failed.*/\1/p')
TESTS_ASSERTIONS=$(printf '%s' "$TEST_LINE" | sed -n 's/.* specs, \([0-9]*\) assertions.*/\1/p')
TESTS_PASSED=${TESTS_PASSED:-0}
TESTS_FAILED=${TESTS_FAILED:-?}
TESTS_ASSERTIONS=${TESTS_ASSERTIONS:-0}
if [ "$TEST_EXIT" -ne 0 ] || [ -z "$TEST_LINE" ]; then status=1; fi

# 5. Content report (registry totals), when the content system exists.
CONTENT_LINE="n/a"
if [ -f scripts/content_report.luau ]; then
	if lune run scripts/content_report.luau >"$LOG_DIR/content.log" 2>&1; then
		CONTENT_LINE=$(grep -E '^CONTENT TOTAL' "$LOG_DIR/content.log" | tail -1)
	else
		CONTENT_LINE="FAILED (see $LOG_DIR/content.log)"
		status=1
	fi
fi

# 6. Rojo build.
if rojo build default.project.json -o "$OUT_PLACE" >"$LOG_DIR/rojo.log" 2>&1; then
	ROJO="OK ($(wc -c <"$OUT_PLACE" | tr -d ' ') bytes -> $OUT_PLACE)"
else
	ROJO="FAILED"
	status=1
fi

LUA_FILES=$(find src -name '*.lua' -o -name '*.luau' | wc -l | tr -d ' ')
LUA_LINES=$(find src \( -name '*.lua' -o -name '*.luau' \) -print0 | xargs -0 cat | wc -l | tr -d ' ')

echo "================ VOIDLINE VERIFY ================"
echo "source:    $LUA_FILES files, $LUA_LINES lines under src/"
echo "selene:    $SELENE_ERRORS errors, $SELENE_WARNINGS warnings"
echo "luau-lsp:  $LSP_ERRORS errors, $LSP_WARNINGS warnings"
echo "stylua:    $STYLUA_DRIFT files need formatting"
echo "tests:     $TESTS_PASSED passed, $TESTS_FAILED failed, $TESTS_ASSERTIONS assertions"
echo "content:   $CONTENT_LINE"
echo "rojo:      $ROJO"
if [ "$status" -eq 0 ]; then
	echo "RESULT:    GREEN"
else
	echo "RESULT:    RED (logs in $LOG_DIR)"
	if [ "$LSP_ERRORS" -gt 0 ]; then
		echo "--- luau-lsp errors ---"
		grep -E 'TypeError|SyntaxError' "$LOG_DIR/luau-lsp.log" | head -40
	fi
	if [ "$SELENE_ERRORS" -gt 0 ]; then
		echo "--- selene errors ---"
		grep -E ': error\[' "$LOG_DIR/selene.log" | head -40
	fi
	if [ "$TEST_EXIT" -ne 0 ]; then
		echo "--- failing tests ---"
		grep -E '^  FAIL' "$LOG_DIR/tests.log" | head -40
	fi
fi
echo "================================================="
exit "$status"
