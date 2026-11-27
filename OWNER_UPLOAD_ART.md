# Voidline — Owner art upload (5 minutes)

You do **not** need code or Open Cloud for this. PNGs are already generated under  
`/opt/cursor/artifacts/art/` on the agent machine (also in the run artifacts panel).

After upload, icons appear in-game automatically — no other file changes except pasting IDs into `ArtConfig.lua` (or run `./scripts/upload_art_open_cloud.sh` if you add API keys later).

## Before you start

1. Open [Creator Dashboard](https://create.roblox.com/dashboard/creations) → sign in.
2. Open this repo’s `src/ReplicatedStorage/Voidline/Config/ArtConfig.lua` in Cursor or Studio sync.

## Upload each PNG (Images)

For **every row** in the table below:

1. Dashboard → **Development Items** → **Images** → **Upload Asset**.
2. Choose the PNG from the art folder (128×128 icons, 512×512 decals/textures).
3. Wait for moderation (usually fast for simple icons).
4. Click the asset → copy the numeric **Asset ID** (not the rbxassetid URL prefix).
5. In `ArtConfig.lua`, find the **ArtConfig key** and set `AssetId = YOUR_ID` (replace `0`).

| PNG file | Paste into `ArtConfig` path |
|----------|-----------------------------|
| `icon_hotbar_upgrade.png` | `UI.Hotbar.Upgrade.AssetId` |
| `icon_formation_orbit.png` | `UI.Hotbar.Formation1.AssetId` |
| `icon_formation_wedge.png` | `UI.Hotbar.Formation2.AssetId` |
| `icon_formation_crown.png` | `UI.Hotbar.Formation3.AssetId` |
| `icon_hotbar_store.png` | `UI.Hotbar.Store.AssetId` |
| `icon_hotbar_menu.png` | `UI.Hotbar.Menu.AssetId` |
| `icon_hotbar_home.png` | `UI.Hotbar.Home.AssetId` |
| `icon_hotbar_sell.png` | `UI.Hotbar.Sell.AssetId` |
| `icon_hotbar_clip.png` | `UI.Hotbar.Clip.AssetId` |
| `icon_hud_credits.png` | `UI.Hud.Credits.AssetId` |
| `icon_hud_ore.png` | `UI.Hud.Ore.AssetId` |
| `icon_hud_shards.png` | `UI.Hud.Shards.AssetId` |
| `icon_hud_tokens.png` | `UI.Hud.Tokens.AssetId` |
| `icon_store_gamepass.png` | `UI.Store.GamePass.AssetId` |
| `icon_store_devproduct.png` | `UI.Store.DevProduct.AssetId` |
| `icon_store_summon.png` | `UI.Store.Summon.AssetId` |

**Example** — after upload id `9876543210`:

```lua
Upgrade = { AssetId = 9876543210, Label = "UPGRADE" },
```

## Optional floor decals (Decals upload)

Use these for world dressing when you are ready (still keep procedural fallbacks at `0` until swapped):

| PNG file | `ArtConfig` key | Field |
|----------|-----------------|-------|
| `decal_voidline_sigil.png` | `Decals.VoidlineSigil` | `DecalId` |
| `decal_plot_sector_mark.png` | `Decals.PlotSectorMark` | `DecalId` |

Dashboard → **Development Items** → **Decals** → upload → paste `DecalId`.

## Optional textures (Images)

| PNG file | `ArtConfig` key | Field |
|----------|-----------------|-------|
| `texture_obsidian_plate.png` | `Textures.ObsidianPlate` | `TextureId` |

## Concept stills (reference only — no paste)

These guide Meshy / Blender hero meshes later; they are **not** wired in code:

- `concept_monolith_half.png`
- `concept_bridge_spine.png`
- `concept_grinder_core.png`

See `ART_PIPELINE.md` for mesh keys (`MonolithHalf`, `GrinderCore`, etc.).

## Finish

1. Save `ArtConfig.lua`.
2. In repo root: `./scripts/verify.sh` (must say **GREEN**).
3. Rebuild place: `rojo build default.project.json -o VoidlineDeepSpace.rbxlx`
4. Play in Studio — hotbar and top HUD should show your icons (gold glyph fallback disappears per slot).

## Optional: automatic upload

If you create an Open Cloud key with **asset read/write**:

```bash
export ROBLOX_OPEN_CLOUD_API_KEY='your-key'
export ROBLOX_USER_ID='your-numeric-user-id'
./scripts/upload_art_open_cloud.sh
```

Commit the updated `ArtConfig.lua` when verify is GREEN.