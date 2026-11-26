#!/usr/bin/env bash
# Create the two Voidline summon Developer Products via Open Cloud and paste
# ProductIds into MonetizationConfig.lua.
#
# Requires env:
#   ROBLOX_OPEN_CLOUD_API_KEY  — Creator Dashboard → Open Cloud → API Keys
#                                 (scope: developer-product:write on this universe)
#   ROBLOX_UNIVERSE_ID         — Experience → … → Copy Universe ID (not Place ID)
#
# Usage: ./scripts/wire_dev_products.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="$ROOT/src/ReplicatedStorage/Voidline/Config/MonetizationConfig.lua"
API_BASE="https://apis.roblox.com/developer-products/v2/universes"

if [[ -z "${ROBLOX_OPEN_CLOUD_API_KEY:-}" ]]; then
	echo "Missing ROBLOX_OPEN_CLOUD_API_KEY in this environment." >&2
	exit 2
fi
if [[ -z "${ROBLOX_UNIVERSE_ID:-}" ]]; then
	echo "Missing ROBLOX_UNIVERSE_ID in this environment." >&2
	exit 2
fi

KEY="$ROBLOX_OPEN_CLOUD_API_KEY"
UNIVERSE="$ROBLOX_UNIVERSE_ID"

list_products() {
	curl -fsS -H "x-api-key: $KEY" \
		"$API_BASE/$UNIVERSE/developer-products/creator?pageSize=100"
}

create_product() {
	local name="$1"
	local price="$2"
	local description="$3"
	curl -fsS -X POST -H "x-api-key: $KEY" \
		-F "name=$name" \
		-F "price=$price" \
		-F "isForSale=true" \
		-F "description=$description" \
		-F "isManagedPricingEnabled=false" \
		"$API_BASE/$UNIVERSE/developer-products"
}

find_id_by_name() {
	local name="$1"
	local json="$2"
	python3 - "$name" <<'PY' <<<"$json"
import json, sys
name = sys.argv[1]
raw = sys.stdin.read()
data = json.loads(raw) if raw.strip() else {}
items = data.get("developerProducts") or data.get("developerProductConfigs") or data.get("data") or []
if isinstance(data, list):
    items = data
for item in items:
    if item.get("name") == name:
        print(item.get("productId") or item.get("id") or "")
        raise SystemExit(0)
print("")
PY
}

extract_id() {
	python3 - <<'PY'
import json, sys
data = json.load(sys.stdin)
print(data.get("productId") or data.get("id") or "")
PY
}

echo "Listing existing developer products for universe $UNIVERSE ..."
LIST_JSON="$(list_products || echo '{}')"

ensure() {
	local name="$1"
	local price="$2"
	local blurb="$3"
	local existing
	existing="$(find_id_by_name "$name" "$LIST_JSON" || true)"
	if [[ -n "$existing" ]]; then
		echo "Exists: $name → $existing"
		echo "$existing"
		return
	fi
	echo "Creating: $name ($price R$) ..."
	local created
	created="$(create_product "$name" "$price" "$blurb")"
	local id
	id="$(printf '%s' "$created" | extract_id)"
	if [[ -z "$id" ]]; then
		echo "Create response missing productId: $created" >&2
		exit 1
	fi
	echo "Created: $name → $id"
	echo "$id"
}

STARFALL_ID="$(ensure "Summon Void Starfall" 199 "A meteor shower rains rich rocks on the whole server for 90 s.")"
LUCK_ID="$(ensure "Server Luck Surge" 149 "Everyone in the server finds shards and relics 2x as often for 10 min.")"

python3 - "$CONFIG" "$STARFALL_ID" "$LUCK_ID" <<'PY'
import pathlib, re, sys
path = pathlib.Path(sys.argv[1])
starfall, luck = sys.argv[2], sys.argv[3]
text = path.read_text()

def set_product(text: str, block_id: str, product_id: str) -> str:
    pattern = rf'(Id\s*=\s*"{re.escape(block_id)}"[\s\S]*?ProductId\s*=\s*)\d+'
    new, n = re.subn(pattern, rf"\g<1>{product_id}", text, count=1)
    if n != 1:
        raise SystemExit(f"failed to patch ProductId for {block_id}")
    return new

text = set_product(text, "SummonVoidStarfall", starfall)
text = set_product(text, "ServerLuckSurge", luck)
path.write_text(text)
print(f"Patched {path}")
print(f"  SummonVoidStarfall.ProductId = {starfall}")
print(f"  ServerLuckSurge.ProductId = {luck}")
PY

echo "Done. Commit MonetizationConfig.lua after verify."
