# Voidline: Deep Space — Game Design Specification (LOCKED)

**Brand:** Voidline: Deep Space \[Space Mining Tycoon\]  
**Creator:** Killshot2336  
**Universe:** Voidline  
**Approach:** Phased Viral Core First (v1 → v1.5 → v2)  
**Status:** Design locked — implement v1 against this document  

---

## 1. Vision

A premium space mining tycoon with soft-contest Deep Space races, autonomous drone swarms, and TikTok-ready juice. Fair free progression + soft-exclusive monetization. Mixed ages. Obsidian, gold, nebula aesthetic. Target 60 FPS on all devices with a Performance Mode toggle.

---

## 2. Core Fantasy & Loop

**Loop:** Command drones → mine/tow asteroids → grind → sell at Station Refinery → upgrade → unlock Galaxy Sectors → optional Void Rebirth.

**Controls:** Walk/run on personal station; drones are autonomous. Low-G sprint with gold boot thrusters.

### Viral hooks (v1)
1. **Gravity-Tether Towing** — golden beams tow rocks/chunks to Station Grinder Core  
2. **Smart Swarm Formations** — Scatter / Orbital Beam-Link / Sovereign Halo (keys 1–3)  
3. **Living Voidline Monolith** — splits open, shifts lighting/gravity during world events  

---

## 3. World Layout (12-player servers)

12 personal station plots in a ring around central Deep Space + Voidline Monolith.

### Personal Station Plots (Safe)
- Private starter asteroid belt  
- Station Refinery (sell + sell-mult upgrades)  
- Station Grinder Core  
- Upgrade pads  
- Free Drone Laser Color Tuner  
- WarpGatePlaceholder (disabled until v2)  
- RelicPedestals (empty until v1.5)  
- Energy Bridge attach → hub  

### Central Deep Space (Soft Contest)
- Voidline Monolith: Rebirth, Artifact Forge, Code Terminal, paid summons, event host  
- Rare Cosmic/Void asteroids  
- VIP Lounge pad  
- Killshot2336 monument at spawn/hub  
- Leaderboard anchors (wired v1.5)  

### Kyria Star Overlook (Secret)
- Unbranded in all UI/HUD/leaderboards  
- Soft warm starlight + cosmic aura only  
- No economy ties  

### Dual-zone lighting
- Stations: calm obsidian-gold  
- Deep Space: higher contrast, bloom, event shifts  
- Nebula indigo/violet sky for thumbnails  

---

## 4. First 60 Seconds (Diegetic Tutorial)

- **0–3s:** Claim plot → starter drone auto-mines nearest asteroid  
- Golden floor beams (no text walls): Harvest → Refinery @ 10/10 → Upgrades  
- Ticker: `[1/4] HARVESTING ORE` → `[2/4] REFINE AT PAD` → `[3/4] DEPLOY 2ND DRONE` → `[4/4] ENERGY BRIDGE ONLINE`  
- First upgrades: +Drill **20**, +Cargo **35**, +2nd Drone **50** Credits  
- Starter cargo **10** ore; first sell **30** Credits  
- At 2nd drone: bridge ignition + `TUTORIAL COMPLETE — +100 CREDITS` + tiny Skip  

---

## 5. Galaxy Sectors (no reset)

1. **Starter Belt** — open at join  
2. **Nebula Ring** — Station Tier 3 (~5 min)  
3. **Void Rim** — Station Tier 6 + Drone Tier 2  
4. **Celestial Orbit** — Station Tier 10 + Rebirth Ready (UI name; Kyria stays private)  

---

## 6. Soft Contest (Deep Space)

- No PvP, no cargo steal  
- Shared damage on rare meteors/cores  
- Qualify at **≥5%** total damage  
- **Top contributor:** 40% bonus pool + `#1 TOP MINER` callout  
- Remaining **60%** proportional among qualifiers (including #1)  
- Chunks gravity-towed to each player’s Grinder  

**Personal belt:** whole-asteroid tow to Grinder.

---

## 7. Formations

| Key | Name | Behavior |
|-----|------|----------|
| 1 | Scatter | Multi-rock mining |
| 2 | Orbital Beam-Link | Ring + combined plasma beam; squad beams visually merge |
| 3 | Sovereign Halo | Drones lock behind player as wing/crown flex |

---

## 8. Void Rebirth

- **Requires:** Station Tier 10  
- **Resets:** Credits, Station Tier pads 1–9, basic drill/cargo levels  
- **Keeps:** Passes, Token perks, Shards/Artifacts, Relics, Codex, Squad, cosmetics/titles  
- **Mult:** `1 + 0.25 × Rebirths`  
- **Shards:** `10 + (5 × RebirthNumber)`  
- **Flex:** Overhead `VOID I+` + Monolith shockwave  

---

## 9. Artifact Forge → Voidline Tokens

- **25 Void Shards → 1 Forged Void Artifact** (10s, 100% success)  
- **1 Artifact → 40 Voidline Tokens**  
- Soft cool after **500 Tokens / 24h** (reduced speed, not hard lock)  
- Tokens: earn-only via Artifact turn-in; never Robux; never trade  

---

## 10. World Events & Squads

- Auto Void Starfall / Luck Surge every **6 min** if idle; duration **90s**  
- Robux summons queue if busy; gold username banner  
- Squads **2–4**; invite/leave/kick; **+10% Shard luck** when linked on same rock; no Credit sharing  

---

## 11. Monetization (Soft Exclusive)

### 10 permanent passes (Robux OR Tokens ~15–20% cheaper)

| Pass | Robux | Tokens (approx) |
|------|------:|----------------:|
| Starter Bundle | 79 | 65 |
| Auto-Sell Warp Link | 249 | 200 |
| 2x Credits | 449 | 370 |
| 2x Shard & Relic Luck | 499 | 410 |
| +3 Drone Slots | 599 | 490 |
| +5 Mega Swarm Slots | 999 | 820 |
| Laser Overclock | 349 | 285 |
| Deep-Space Warp Pass | 399 | 325 |
| Void Sovereign VIP | 899 | 740 |
| Eternal Architect | 1499 | 1230 |

### Robux-only Dev Products
- Summon Void Starfall — 199  
- Server Luck Surge — 149  

### Removed
- Shard Packs (shards are find-only)

### Access check
`OwnedPerks[id] OR MarketplaceService:UserOwnsGamePassAsync(passId)`

### Codes (Monolith Code Terminal)
`VOIDLINE`, `KILLSHOT`, `LAUNCH` — see `CodesConfig` + `CodeService` + `RedeemCode` remote  

### Daily streak
7-day login streak via `DailyStreakService` + `RedeemDaily` remote  
Day 7 grants 24h `Credits2x` trial voucher persisted in PlayerData  

### Touch / creator UX
Mobile Low-G Sprint, Quick-Upgrade (U), Clean Clip Mode (hide HUD), free station Laser Color Tuner  

---

## 12. Visual / Audio / Avatar

- Hybrid fidelity: low-poly world; hero detail on Monolith, VIP drones, event meteors, Kyria  
- Performance Mode toggle  
- Compact HUD: top pill + bottom hotbar; 3s event banners  
- Dual camera: normal walk; FOV pullback on Beam-Link/tow  
- Soft Voidline thruster pack on avatars; Hide Jetpack option; VIP Sovereign Wing Rig  
- Audio Hybrid: quiet ambient; stings on Starfall / Luck Surge / first Rebirth  
- Mobile: Low-G Sprint, Quick-Upgrade (U), Clean Clip Mode, Laser Color Tuner  

---

## 13. Security, Data, AFK (Fortress-lite)

- Server owns economy, HP, tow claims, forge, rebirth, perks  
- Validate remotes: ownership, distance, cooldown, rate limits  
- Autosave every 60s + leave + rebirth/purchase  
- AFK 8 min → drones Idle Orbit (no kick); resume on input  

### Profile fields
Credits, VoidShards, VoidlineTokens, Rebirths, CreditMult, StationTier, DrillLevel, CargoLevel, DroneSlots, DroneTier, GalaxyFlags, OwnedPerks, TutorialStep, Settings, Cosmetics/Titles, ForgeTokensEarnedToday, ForgeDayKey, DailyStreak, LastLoginDay, TrialVouchers, Codex/Relics stubs  

---

## 14. Roadmap

**v1:** Map, plots, drones, mining/tow, economy, tutorial, events, forge/rebirth, store, codes, daily streak, juice, perf mode  
**v1.5:** Codex, Relics, 4 OrderedDataStore boards  
**v2:** Warp Gate + Anomaly Sectors (endless discovery)  

---

## 15. Studio Architecture

See project `src/` mirroring:

- `Workspace/VoidlineMap` (runtime-built by MapBuilder if absent)  
- `ReplicatedStorage/Voidline` — Config, Remotes, Modules, Assets  
- `ServerScriptService/Voidline` — Boot + Services + Components + Security  
- `ServerStorage/Voidline` — templates  
- `StarterPlayerScripts/Voidline` — ClientBoot + Controllers  

---

*End of locked specification.*
