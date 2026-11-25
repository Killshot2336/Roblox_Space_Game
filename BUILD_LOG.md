# Voidline: Deep Space — Autonomous Build Log

Branch: `cursor/voidline-autonomous-build-dae3`. No Roblox Studio exists on the build machine, so every
entry below was verified with static analysis (selene, luau-lsp), headless Lune tests and a Rojo build.
Nothing here has been playtested; anything about feel or visuals is marked **needs Studio playtest**.

## Studio playtest checklist

Run `rojo serve` (or `./serve.sh`), connect the Rojo plugin in Studio, press Play (F5). Try these first:

1. **First 45 seconds** — fresh profile: plot auto-claims, ticker shows `[1/4]`, starter drone mines.
2. **Tow** — cracked rock is gravity-towed to the Grinder Core; ore lands in cargo.
3. **Formations 1–3** — keys 1/2/3 (or touch buttons); Beam-Link should pull the camera FOV back slightly.
4. **Boss meteor** — wait for (or Studio-summon) a Void Starfall; check the 40% / 60% split callout.
5. **Store** — buy a pass with Tokens and with Robux (placeholder IDs grant in Studio only).
6. **Forge** — 25 shards → artifact → 40 tokens; leave mid-forge and rejoin.
7. **Rebirth** — station tier 10 → rebirth; title `VOID I` and multiplier 1.25.
8. **Mobile emulator** — Studio device emulator (phone): every action reachable by touch.
9. **Clean Clip Mode** — hides HUD/hotbar for recording.

## Owner TODOs

- Create the 10 game passes and 2 developer products in the Creator Dashboard and paste their IDs into
  `src/ReplicatedStorage/Voidline/Config/MonetizationConfig.lua` (IDs stay `0` until then; `0` means
  "Studio-only test grant").
- Publish the place and enable **Game Settings → Security → Enable Studio Access to API Services** so
  DataStores/OrderedDataStores persist in Studio (without it the game runs on in-memory profiles).

## Content totals

_Filled in by `lune run scripts/content_report.luau` once the content registries land (Phase A)._

## Baseline (before Loop 1 changes, commit `a738cfc`)

| Check | Result |
|---|---|
| selene | 0 errors, 6 warnings (5 unused locals/imports, 2 empty `if`) |
| luau-lsp analyze | 1 error (`CodeService` passes `string.gsub`'s 2 returns to `string.upper`), 4 warnings |
| StyLua | 4 source files drift from the committed style |
| Lune tests (new) | 26 passed, 5 failed — real defects, see Phase 0 |
| Rojo build | OK (122,383 bytes) |

---

## Loop 1 · Phase 0 — Toolchain, headless harness, verify pipeline

**What changed**
- Toolchain (installed to `/usr/local/bin`, not committed): selene 0.32.0, StyLua 2.6.0, luau-lsp 1.70.1,
  Lune 0.11.1, Rojo 7.7.1. Roblox types: luau-lsp `globalTypes.None.d.luau` (script security level `None`,
  correct for game code) fetched into gitignored `tools/`; selene `roblox.yml` generated on demand.
- Configs: `selene.toml` (`std = "roblox"`), `stylua.toml` (tabs, 120 cols, matches existing code),
  `.luaurc` (nonstrict default; new pure modules opt into `--!strict`).
- `tests/harness/`: sourcemap-driven fake DataModel (`script.Parent`, child indexing, `WaitForChild`,
  `require(instance)` with per-world module cache and recursive-require detection), deterministic fake
  clock + `task` library, Roblox-strict attribute rules (rejects tables/NaN), fake Players/RunService/
  DataStore/Marketplace/Policy/Text/Tween/Collection services, remote-event logging.
- `tests/specs/`: locked-spec invariants (10 ore → 30 credits, 20/35/50 upgrades, +100 tutorial bonus,
  rebirth `1 + 0.25R` and `10 + 5R`, forge 25 → 1 → 40 and 500/day soft cool, store prices and 15–20%
  token discount, Robux-only summons, no shard packs, launch codes), ContributionSplit, RateLimiter,
  and a 10,000-split seeded stress test.
- `scripts/verify.sh`: selene + luau-lsp + StyLua drift + Lune tests + content report + Rojo build, with
  counts and a GREEN/RED result.
- Fixes for the defects the new tests exposed:
  - `ContributionSplit`: a non-finite damage entry made the total `inf`, so **nobody** was paid; ties for
    #1 depended on table iteration order; there was no integer payout helper. Now damage is sanitised,
    normalised by the max hit (overflow-safe), ties go to the lowest UserId, and `Allocate` does
    largest-remainder rounding that never exceeds the pool.
  - `RateLimiter`: now a token bucket (`new(interval, burst)`), backwards compatible.
  - `CodeService`: `string.upper(string.gsub(...))` passed two arguments; input length now capped.
- StyLua applied to the 4 drifting files as its own commit.

**Decision rules applied**
- *Server authority / never trust client numbers*: contest split must stay correct for hostile or
  degenerate inputs (NaN, inf, negative) — tested.
- *Data: stable IDs, deterministic content*: harness uses a fixed fake epoch so date-keyed logic is
  reproducible; Roblox's `Random` is intentionally not trusted for content generation (Lune lacks it and
  sequences may change), so registries will use a shared pure-Luau PRNG.

**Verification** — `scripts/verify.sh`

```
selene:    0 errors, 6 warnings
luau-lsp:  0 errors, 4 warnings
stylua:    0 files need formatting
tests:     31 passed, 0 failed, 170537 assertions
rojo:      OK (125498 bytes)
RESULT:    GREEN
```

**Needs Studio playtest**: nothing new (tooling and pure-module fixes only).

**Commits**: `45e8bcf` configs · `44c33eb` harness + specs · `fccb086` verify.sh · `c875836` StyLua ·
`fd6fbd5` ContributionSplit · `088f93e` RateLimiter · `4021fd6` CodeService · (this log + README).

---

## Next loop backlog

_Maintained at the end of each phase; see the latest entry._
