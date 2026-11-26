# Voidline: Deep Space

Premium Roblox space mining tycoon by **Killshot2336**.

Players command autonomous mining drones, gravity-tether asteroids to their Station Grinder, soft-contest rare Deep-Space cores around **The Voidline Monolith**, and progress through Galaxy Sectors into optional Void Rebirths.

## Design

See [`GAME_DESIGN.md`](./GAME_DESIGN.md) for the locked v1 specification.

## Install Rojo (Windows)

**Option A — local `rojo.exe` in this folder (recommended):**

```powershell
cd Roblox_Space_Game
powershell -ExecutionPolicy Bypass -File .\download-rojo.ps1
```

That downloads the latest `*-windows-x86_64.zip` from `rojo-rbx/rojo` and extracts `rojo.exe` here.

**One-liner (same result):**

```powershell
cd Roblox_Space_Game; $r=Invoke-RestMethod https://api.github.com/repos/rojo-rbx/rojo/releases/latest -Headers @{'User-Agent'='Voidline'}; $a=$r.assets|?{$_.name -like '*-windows-x86_64.zip'}|Select -First 1; Invoke-WebRequest $a.browser_download_url -OutFile rojo-windows.zip; Expand-Archive rojo-windows.zip -DestinationPath _rojo_extract -Force; Copy-Item (Get-ChildItem _rojo_extract -Recurse -Filter rojo.exe | Select -First 1).FullName .\rojo.exe -Force; Remove-Item rojo-windows.zip,_rojo_extract -Recurse -Force; .\rojo.exe --version
```

**Option B — winget (system install):**

```powershell
winget install Rojo.Rojo
```

Also install the **Rojo plugin** in Roblox Studio.

## Install Rojo (Linux / macOS)

Download the `rojo-*-linux-x86_64.zip` (or macOS) asset from
[rojo-rbx/rojo releases](https://github.com/rojo-rbx/rojo/releases) and put `rojo` on your `PATH`
(e.g. `/usr/local/bin/rojo`), then `rojo --version`.

## Run + Play in Studio

From this folder (`Roblox_Space_Game`):

```powershell
.\rojo.exe serve
```

(or `rojo serve` if installed via winget; on Linux/macOS run `./serve.sh` or `rojo serve default.project.json`)

1. Open Roblox Studio (empty baseplate or your Voidline place).
2. Rojo plugin → **Connect** (default `localhost:34872`).
3. Press **Play (F5)**.

On Play, server `Boot.server.lua` runs `MapBuilder.Build()`, which creates:

- **12** personal station plots in a ring  
- **Energy bridges** to the hub  
- **The Voidline Monolith** (forge, rebirth, codes, summons)  
- **Killshot2336** monument  
- **Hidden Kyria Star Overlook**  
- Deep-Space rare asteroids + all **v1 systems** (drones, economy, events, store, etc.)

Optional one-shot place file:

```powershell
rojo build default.project.json -o VoidlineDeepSpace.rbxlx
```

Then open `VoidlineDeepSpace.rbxlx` in Studio and Play.

## Verify (lint + types + headless tests)

```bash
scripts/verify.sh
```

Runs [selene](https://github.com/Kampfkarren/selene), `luau-lsp analyze` (Roblox types + Rojo sourcemap),
a StyLua format check, the [Lune](https://github.com/lune-org/lune) headless tests in `tests/`, the
content report, and a Rojo build. Exit code `0` = green. Tools expected on `PATH`: `rojo`, `selene`,
`stylua`, `luau-lsp`, `lune` (Linux x86_64 release binaries). Roblox type definitions and the selene
Roblox std are fetched/generated into the gitignored `tools/` folder on first run.

Run a subset of tests: `lune run tests/run.luau ContributionSplit`.

Build history, owner TODOs and the Studio playtest checklist live in [`BUILD_LOG.md`](./BUILD_LOG.md).

## Project layout

```
Roblox_Space_Game/
  GAME_DESIGN.md
  BUILD_LOG.md
  default.project.json
  README.md
  scripts/verify.sh                 lint + types + tests + build
  tests/                            Lune headless harness + specs
  src/
    ReplicatedStorage/Voidline/     Config, Remotes, Modules, Assets
    ServerScriptService/Voidline/   Boot + MapBuilder + Services
    ServerStorage/Voidline/
    StarterPlayer/.../Voidline/     ClientBoot + Controllers
```

## Owner TODOs before publish

1. **Creator Dashboard → Monetization**
   - Create **10 game passes** and **2 developer products** matching the names and Robux prices in
     [`src/ReplicatedStorage/Voidline/Config/MonetizationConfig.lua`](src/ReplicatedStorage/Voidline/Config/MonetizationConfig.lua).
   - Paste each Roblox numeric id into the matching `GamePassId` or `ProductId` field (replace `0`).
     Keys: `StarterBundle`, `AutoSellWarpLink`, `Credits2x`, `ShardRelicLuck2x`, `DroneSlots3`,
     `MegaSwarm5`, `LaserOverclock`, `DeepSpaceWarpPass`, `VoidSovereignVIP`, `EternalArchitect`;
     products `SummonVoidStarfall`, `ServerLuckSurge`.
2. **Publish the place** and open **Game Settings → Security → Enable Studio Access to API Services** so
   DataStores and OrderedDataStore leaderboards work.
3. **Optional audio** — paste real `rbxassetid://…` strings into
   [`src/ReplicatedStorage/Voidline/Config/AudioConfig.lua`](src/ReplicatedStorage/Voidline/Config/AudioConfig.lua)
   (`AssetId = ""` means silent).

While ids are `0`, **Robux purchase buttons stay hidden** (`Coming soon` on summons; no Robux button on passes).
**Voidline Token purchases still work** for passes in Studio/local play for testing perks.

Full Studio playtest steps: [`BUILD_LOG.md`](./BUILD_LOG.md).

## Roadmap

- **v1** — playable core (this repo)
- **v1.5** — Codex, Relics, 4 global leaderboards
- **v2** — Warp Gate + procedural Anomaly Sectors
