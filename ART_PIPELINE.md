# Voidline art pipeline (owner)

Code ships **procedural** cathedral geometry today. Uploaded meshes swap in via `ArtConfig.lua` without rewriting `MapBuilder`.

## Quick upload loop

1. Generate or sculpt the asset (Meshy / Blender / Studio).
2. **Home** → [Creator Dashboard](https://create.roblox.com/dashboard/creations) → **Development Items** → **Meshes** (or **Decals** / **Images** for UI).
3. Upload → wait for moderation → copy the numeric **Asset ID**.
4. Open `src/ReplicatedStorage/Voidline/Config/ArtConfig.lua` and paste:
   - Meshes: `MeshId = 123456789` (and `TextureId` if you have a texture asset).
   - UI: `AssetId = 123456789` under `ArtConfig.UI.Hotbar.*` etc.
5. Run `scripts/verify.sh` (GREEN).
6. `rojo build default.project.json -o VoidlineDeepSpace.rbxlx` → Play in Studio.

No Open Cloud API key is required for this flow.

## Hero assets (recommended order)

| Key | Role | Poly budget | Notes |
|-----|------|-------------|-------|
| `MonolithHalf` | Spawn silhouette | ≤ 8k tris / half | Tall obsidian slab, gold seam groove on split face |
| `GrinderCore` | Plot machine | ≤ 6k | Industrial grinder, not a flat pad |
| `RefineryStack` | Plot machine | ≤ 5k | Chimney + pipe bundle |
| `EnergyBridgeSegment` | Bridge visual | ≤ 2k | Matte spine with rib slots; collision stays on `WalkPlate` |
| `HubColonnade` | Hub dressing | ≤ 800 | Reusable column |
| `DeepSpaceAsteroid` | Environment | ≤ 400 | 3 variants, instanced |

## Meshy prompts (free plan — credit Meshy in game credits if required)

**MonolithHalf**

> Tall fractured obsidian monolith slab, vertical gold seam scar, cathedral sci-fi, hard vacuum, matte black stone, subtle foil gold inlay, no neon floor, game-ready low poly, single object, neutral pivot at base center.

**GrinderCore**

> Heavy space refinery grinder machine, diamond plate housing, obsidian and gunmetal, small gold seam accent, industrial aggressive silhouette, no bright yellow plastic, game asset low poly.

**RefineryStack**

> Vertical refinery tower with corroded pipes and cable bundles, obsidian base, cold vacuum lighting, gold trim lines only as thin seams.

**EnergyBridgeSegment**

> Rectangular sci-fi bridge deck segment, ribbed underside, matte slate top, thin gold energy spine groove, no emissive walk surface.

**DeepSpaceAsteroid**

> Jagged dark asteroid chunk, cratered basalt, no glow, low poly game prop.

Export **FBX** or **GLB** → import in Studio (Avatar / Mesh Importer) or upload to Dashboard as Mesh.

## Studio Cube (manual block-out)

For fast iteration without Meshy: block out in Studio, **File → Export Selection** (if available) or union parts → **Mesh** from parts → upload. Match approximate bounds in `HubLayout` / `PlotLayout` before replacing.

## UI icons (generated art pack)

PNG sources live under **`/opt/cursor/artifacts/art/`** (128×128 UI icons, 512×512 decals/textures, 1280×720 concept stills).  
Owner click-by-click steps: **`OWNER_UPLOAD_ART.md`**.  
Automatic Open Cloud batch: **`./scripts/upload_art_open_cloud.sh`** (needs `ROBLOX_OPEN_CLOUD_API_KEY` + `ROBLOX_USER_ID` or `ROBLOX_GROUP_ID` in the shell).

1. Dashboard → **Development Items** → **Images** → upload each PNG (or run the upload script).
2. Paste numeric Asset IDs into `ArtConfig.lua` — field is always `AssetId` under `ArtConfig.UI.*` (never invent IDs in code).
3. Until IDs exist, UI uses `rbxasset://textures/ui/GuiImagePlaceholder.png` with **gold glyph** fallback (hotbar + HUD).

### Hotbar (`ArtConfig.UI.Hotbar`)

| File | Key | Lua path |
|------|-----|----------|
| `icon_hotbar_upgrade.png` | Upgrade | `UI.Hotbar.Upgrade.AssetId` |
| `icon_formation_orbit.png` | Formation1 | `UI.Hotbar.Formation1.AssetId` |
| `icon_formation_wedge.png` | Formation2 | `UI.Hotbar.Formation2.AssetId` |
| `icon_formation_crown.png` | Formation3 | `UI.Hotbar.Formation3.AssetId` |
| `icon_hotbar_store.png` | Store | `UI.Hotbar.Store.AssetId` |
| `icon_hotbar_menu.png` | Menu | `UI.Hotbar.Menu.AssetId` |
| `icon_hotbar_home.png` | Home | `UI.Hotbar.Home.AssetId` |
| `icon_hotbar_sell.png` | Sell | `UI.Hotbar.Sell.AssetId` |
| `icon_hotbar_clip.png` | Clip | `UI.Hotbar.Clip.AssetId` |

### HUD chips (`ArtConfig.UI.Hud`)

| File | Key | Lua path |
|------|-----|----------|
| `icon_hud_credits.png` | Credits | `UI.Hud.Credits.AssetId` |
| `icon_hud_ore.png` | Ore | `UI.Hud.Ore.AssetId` |
| `icon_hud_shards.png` | Shards | `UI.Hud.Shards.AssetId` |
| `icon_hud_tokens.png` | Tokens | `UI.Hud.Tokens.AssetId` |

### Store (`ArtConfig.UI.Store`)

| File | Key | Lua path |
|------|-----|----------|
| `icon_store_gamepass.png` | GamePass | `UI.Store.GamePass.AssetId` |
| `icon_store_devproduct.png` | DevProduct | `UI.Store.DevProduct.AssetId` |
| `icon_store_summon.png` | Summon | `UI.Store.Summon.AssetId` |

### World decals & textures

| File | Key | Lua path | Upload type |
|------|-----|----------|-------------|
| `decal_voidline_sigil.png` | VoidlineSigil | `Decals.VoidlineSigil.DecalId` | Decal |
| `decal_plot_sector_mark.png` | PlotSectorMark | `Decals.PlotSectorMark.DecalId` | Decal |
| `texture_obsidian_plate.png` | ObsidianPlate | `Textures.ObsidianPlate.TextureId` | Image |

### Concept stills (mesh reference — no `ArtConfig` paste)

| File | Intended mesh key |
|------|-------------------|
| `concept_monolith_half.png` | `Meshes.MonolithHalf` |
| `concept_bridge_spine.png` | `Meshes.EnergyBridgeSegment` |
| `concept_grinder_core.png` | `Meshes.GrinderCore` |

## One-commit mesh swap

When all hero `MeshId` values are non-zero:

1. Set IDs in `ArtConfig.lua` only (no `MapBuilder` edits needed).
2. `MapBuilder` calls `ArtResolve.ApplyMeshPart` on named hero parts at build time.
3. Verify + commit → push → rebuild `VoidlineDeepSpace.rbxlx`.

## Performance

- Keep instance counts; meshes should **replace** procedural parts, not stack on top.
- Clip mode and VFX budgets unchanged — hero meshes are static anchored.
- Asteroids: use 1–3 mesh variants with `DeepSpaceAsteroid` key; code varies scale/rotation only.