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

## Run + Play in Studio

From this folder (`Roblox_Space_Game`):

```powershell
.\rojo.exe serve
```

(or `rojo serve` if installed via winget)

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

## Project layout

```
Roblox_Space_Game/
  GAME_DESIGN.md
  default.project.json
  README.md
  src/
    ReplicatedStorage/Voidline/     Config, Remotes, Modules, Assets
    ServerScriptService/Voidline/   Boot + MapBuilder + Services
    ServerStorage/Voidline/
    StarterPlayer/.../Voidline/     ClientBoot + Controllers
```

## Monetization placeholders

Pass / DevProduct IDs in `MonetizationConfig` are `0`. Replace with Creator Dashboard IDs before publishing. With ID `0`, Studio test grants still work for passes.

## Roadmap

- **v1** — playable core (this repo)
- **v1.5** — Codex, Relics, 4 global leaderboards
- **v2** — Warp Gate + procedural Anomaly Sectors
