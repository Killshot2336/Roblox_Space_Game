# Voidline: Deep Space — Autonomous Build Log

Branch: `cursor/voidline-autonomous-build-dae3`. No Roblox Studio on the build machine — verification is
static analysis (selene, luau-lsp), headless Lune tests, and Rojo build. **Nothing has been playtested**;
feel and visuals are **needs Studio playtest**.

**Owner stop (2026-11-26):** autonomous loop workers halted after this wrap. Further phases are backlog only
unless the owner starts a new run.

## Studio playtest checklist

Run `rojo serve` (or `./serve.sh`), connect the Rojo plugin in Studio, press Play (F5).

1. **First 45 seconds** — fresh profile: plot auto-claims, ticker `[1/4]`, starter drone mines.
2. **Tow** — cracked rock gravity-towed to Grinder Core; ore in cargo.
3. **Formations 1–3** — keys 1/2/3 (or touch); Beam-Link pulls camera FOV back.
4. **Boss meteor** — Void Starfall; 40% / 60% split callout.
5. **Store** — Token and Robux buys (pass/product IDs `0` = Studio-only test grant).
6. **Forge** — 25 shards → artifact → 40 tokens; rejoin mid-forge.
7. **Rebirth** — station tier 10 → rebirth; title `VOID I`, multiplier 1.25.
8. **Mobile emulator** — every action reachable by touch (48px targets).
9. **Clean Clip Mode** — hides HUD/hotbar for recording.
10. **Menus** — Codex, Quests, Squads, Pilot Card inspect, leaderboards.
11. **Energy Bridge sweep** — first warp/rebirth VFX along segmented bridge.

## Owner TODOs

- Create **10 game passes** and **2 developer products** in Creator Dashboard; paste IDs into
  `src/ReplicatedStorage/Voidline/Config/MonetizationConfig.lua` (`0` = Studio-only grant).
- Publish place; enable **Game Settings → Security → Enable Studio Access to API Services** for DataStores.
- Replace procedural map/placeholder visuals with authored assets when ready.
- Tune drone VFX perf on low-end mobile after first Studio session.

## Content totals

| Registry | Count |
|---|---:|
| Ore variants | 321 |
| Anomaly biomes | 56 |
| Hazards | 12 |
| Relics | 170 |
| Drone evolutions & cosmetics | 134 |
| World events | 8 |
| Titles | 116 |
| Achievements | 225 |
| Citadel tiers | 30 |
| Quests | 54 |
| **Codex-trackable** | **701** |
| **CONTENT TOTAL** | **1126** |

Source: `lune run scripts/content_report.luau` (frozen IDs in `tests/snapshots/content_ids.txt`).

---

## Loop 1 · Phase 0 — Toolchain, headless harness, verify

Configs, Lune harness, `scripts/verify.sh`, ContributionSplit / RateLimiter / CodeService fixes.
Baseline verification: 31 tests, GREEN on Phase 0 completion.

---

## Loop 1 · Phase A — Deterministic content

- Seeded PRNG registries: ores, biomes, hazards, relics, drones, titles, achievements, citadel, quests, events.
- `scripts/content_report.luau`, registry spec, content-id snapshot.
- **Commits:** `75df3bb`, `00ee6c5`.

---

## Loop 1 · Phase B — Rules & profile v2

- Economy, mining, store, progression, tutorial, achievement/quest rules.
- Profile schema v2 + locked rule tests.
- **Commits:** `1d060c8`, `e1226b0`.

---

## Loop 1 · Phase C — Server sim & map

- Validated remotes; PlayerDataService session locks + diff replication + SaveNow.
- MapBuilder: 12 plots, hub, split Monolith, segmented Energy Bridges.
- Mining loop, drones, tows, onboarding, contests, rifts, summons, monetization, forge/rebirth/social/meta services.
- **Commits:** `68e47f6` … `3bdcdfb`, `ea8e9b8`, `e092503`, `65930b0`, `4191769`, `1960616`, `41ec15e`.

---

## Loop 1 · Phase D — Headless E2E

- `ServerBoot.spec.luau`, onboarding path through attributed services (no Studio).
- **Commit:** `6a59818`.

---

## Loop 1 · Phase E — Client shell (shipped this wrap)

- `Client/Ui.lua` glass kit (touch-safe), `ClientState` replication consumer.
- Controllers: HUD, Hotbar, Store, Menu, Onboarding, Camera, VFX, Juice, Drone fleet visuals, Tow arc,
  World/Interact, ClientBoot wiring.
- Shared `ProfileSchema.REMOVED` tombstone for client diff decode.
- **Verification (finish wrap):**

```
selene:    0 errors, 1 warnings
luau-lsp:  0 errors, 1 warnings
stylua:    0 files need formatting
tests:     74 passed, 0 failed, 291420 assertions
content:   CONTENT TOTAL 1126
rojo:      OK (~499 KB place)
RESULT:    GREEN
```

**Needs Studio playtest:** entire client UI, drone rendering, tow arcs, store odds disclosure UI, mobile layout.

---

## Next loop backlog (not started — owner stopped loops)

- Authored environment art (Monolith interior, sector props, skybox).
- Live game pass / product IDs and receipt testing on a published place.
- Audio pass (mining hits, bridge sweep, Starfall).
- Anti-exploit Studio session (remote spam, economy edge cases).
- Optional: expand `VERIFY_STRICT_FORMAT=1` in CI; reduce remaining selene/lsp warnings.
- Performance budget pass on DroneController particle pools (10+ players).