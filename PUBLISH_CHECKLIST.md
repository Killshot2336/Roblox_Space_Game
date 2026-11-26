# Voidline: Deep Space — 15-Minute Publish Checklist

Use this after `./scripts/verify.sh` is **GREEN** locally. Do not invent IDs — copy each number from the Creator Dashboard.

## 1. Monetization IDs (~8 min)

1. Open [Creator Dashboard](https://create.roblox.com/dashboard) → **Your Experience** → **Monetization**.
2. Create **10 Game Passes** and **2 Developer Products** exactly matching names and Robux prices in
   `src/ReplicatedStorage/Voidline/Config/MonetizationConfig.lua`.
3. Open that file and replace each `GamePassId = 0` / `ProductId = 0` with the Dashboard number.

| Config `Id` key | Dashboard type | Robux |
|-----------------|----------------|------:|
| `StarterBundle` | Game Pass | 79 |
| `AutoSellWarpLink` | Game Pass | 249 |
| `Credits2x` | Game Pass | 449 |
| `ShardRelicLuck2x` | Game Pass | 499 |
| `DroneSlots3` | Game Pass | 599 |
| `MegaSwarm5` | Game Pass | 999 |
| `LaserOverclock` | Game Pass | 349 |
| `DeepSpaceWarpPass` | Game Pass | 399 |
| `VoidSovereignVIP` | Game Pass | 899 |
| `EternalArchitect` | Game Pass | 1499 |
| `SummonVoidStarfall` | Dev Product | 199 |
| `ServerLuckSurge` | Dev Product | 149 |

4. Token prices in the same file stay as shipped (15–20% below Robux); no Dashboard step for tokens.

## 2. Place + API (~3 min)

1. `rojo serve` (or open `VoidlineDeepSpace.rbxlx`) → Play once to confirm map loads.
2. **File → Publish to Roblox** (or update existing place).
3. **Game Settings → Security → Enable Studio Access to API Services** (DataStores + OrderedDataStore boards).

## 3. Optional audio (~2 min)

1. Upload sting sounds to Roblox (Mine, Sell, Upgrade, Tow, Starfall, Rebirth, Store).
2. Paste `rbxassetid://…` into `src/ReplicatedStorage/Voidline/Config/AudioConfig.lua` (`AssetId = ""` = silent).

## 4. Ship

1. Re-run `scripts/verify.sh`.
2. Commit ID changes only when real numbers are in `MonetizationConfig.lua`.
3. Run the **11-item Studio playtest** in `BUILD_LOG.md` (first session ~10 min).

**Agent cap:** Code hides Robux buttons while IDs are `0`; Token purchases work without Dashboard wiring.