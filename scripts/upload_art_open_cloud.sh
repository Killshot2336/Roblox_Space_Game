#!/usr/bin/env bash
# Upload Voidline UI / decal PNGs from art pack and patch ArtConfig.lua AssetIds.
#
# Requires env:
#   ROBLOX_OPEN_CLOUD_API_KEY — Creator Dashboard → Open Cloud → API Keys
#                             (scopes: asset:read, asset:write)
#   ROBLOX_USER_ID            — Profile URL numeric id (or ROBLOX_GROUP_ID for group assets)
#
# Usage: ./scripts/upload_art_open_cloud.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ART_DIR="${ART_DIR:-/opt/cursor/artifacts/art}"
CONFIG="$ROOT/src/ReplicatedStorage/Voidline/Config/ArtConfig.lua"
API="https://apis.roblox.com/assets/v1/assets"

if [[ -z "${ROBLOX_OPEN_CLOUD_API_KEY:-}" ]]; then
	echo "ROBLOX_OPEN_CLOUD_API_KEY not set; skip upload." >&2
	exit 2
fi

CREATOR_JSON=""
if [[ -n "${ROBLOX_GROUP_ID:-}" ]]; then
	CREATOR_JSON="\"groupId\":\"${ROBLOX_GROUP_ID}\""
elif [[ -n "${ROBLOX_USER_ID:-}" ]]; then
	CREATOR_JSON="\"userId\":\"${ROBLOX_USER_ID}\""
else
	echo "Set ROBLOX_USER_ID or ROBLOX_GROUP_ID for asset creation context." >&2
	exit 2
fi

upload_image() {
	local file="$1"
	local display="$2"
	local desc="$3"
	local req
	req=$(printf '{"assetType":"Image","displayName":"%s","description":"%s","creationContext":{"creator":{%s}}}' \
		"$display" "$desc" "$CREATOR_JSON")
	curl -fsS -X POST -H "x-api-key: $ROBLOX_OPEN_CLOUD_API_KEY" \
		--form "request=$req" \
		--form "fileContent=@${file};type=image/png" \
		"$API"
}

poll_asset_id() {
	local op_json="$1"
	local op_id
	op_id=$(printf '%s' "$op_json" | python3 -c 'import json,sys; d=json.load(sys.stdin); p=d.get("path",""); print(p.split("/")[-1] if p else d.get("name","").split("/")[-1])')
	if [[ -z "$op_id" ]]; then
		return 1
	fi
	for _ in $(seq 1 30); do
		sleep 2
		local done
		done=$(curl -fsS -H "x-api-key: $ROBLOX_OPEN_CLOUD_API_KEY" \
			"https://apis.roblox.com/assets/v1/operations/${op_id}" || echo '{}')
		local aid
		aid=$(printf '%s' "$done" | python3 -c '
import json,sys
d=json.load(sys.stdin)
if d.get("done"):
 r=d.get("response") or {}
 print(r.get("assetId") or (r.get("asset") or {}).get("assetId") or "")
')
		if [[ -n "$aid" ]]; then
			echo "$aid"
			return 0
		fi
	done
	return 1
}

declare -A FILES=(
	["icon_hotbar_upgrade.png"]="Hotbar.Upgrade"
	["icon_formation_orbit.png"]="Hotbar.Formation1"
	["icon_formation_wedge.png"]="Hotbar.Formation2"
	["icon_formation_crown.png"]="Hotbar.Formation3"
	["icon_hotbar_store.png"]="Hotbar.Store"
	["icon_hotbar_clip.png"]="Hotbar.Clip"
	["icon_hotbar_menu.png"]="Hotbar.Menu"
	["icon_hotbar_home.png"]="Hotbar.Home"
	["icon_hotbar_sell.png"]="Hotbar.Sell"
	["icon_hud_credits.png"]="Hud.Credits"
	["icon_hud_ore.png"]="Hud.Ore"
	["icon_hud_shards.png"]="Hud.Shards"
	["icon_hud_tokens.png"]="Hud.Tokens"
	["icon_store_gamepass.png"]="Store.GamePass"
	["icon_store_devproduct.png"]="Store.DevProduct"
	["icon_store_summon.png"]="Store.Summon"
)

IDS_FILE="$(mktemp)"
trap 'rm -f "$IDS_FILE"' EXIT

for file in "${!FILES[@]}"; do
	path="$ART_DIR/$file"
	key="${FILES[$file]}"
	if [[ ! -f "$path" ]]; then
		echo "Missing $path" >&2
		continue
	fi
	echo "Uploading $file → $key ..."
	op=$(upload_image "$path" "Voidline $(basename "$file" .png)" "Voidline art pack — $key")
	id=$(poll_asset_id "$op" || true)
	if [[ -z "$id" ]]; then
		echo "Failed to resolve asset id for $file" >&2
		continue
	fi
	echo "${key}=${id}" >>"$IDS_FILE"
	echo "  → $id"
done

if [[ ! -s "$IDS_FILE" ]]; then
	echo "No assets uploaded." >&2
	exit 1
fi

python3 - "$CONFIG" "$IDS_FILE" <<'PY'
import pathlib, re, sys
config_path = pathlib.Path(sys.argv[1])
ids_path = pathlib.Path(sys.argv[2])
text = config_path.read_text()
mapping = {}
for line in ids_path.read_text().splitlines():
    key, aid = line.strip().split("=", 1)
    mapping[key] = aid
for dotted, asset_id in mapping.items():
    group, leaf = dotted.split(".", 1)
    pattern = rf"({re.escape(group)}\s*=\s*\{{[\s\S]*?{re.escape(leaf)}\s*=\s*\{{[^\}}]*?AssetId\s*=\s*)\d+"
    new, n = re.subn(pattern, rf"\g<1>{asset_id}", text, count=1)
    if n != 1:
        raise SystemExit(f"failed to patch {dotted}")
    text = new
config_path.write_text(text)
print(f"Patched {len(mapping)} AssetIds in {config_path}")
PY

echo "Run ./scripts/verify.sh then commit ArtConfig.lua."