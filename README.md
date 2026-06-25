# Event Horizon: Eat the Universe

> You are a living singularity. Move through space, consume matter, collapse
> stars, and reshape reality across increasingly impossible cosmic scales.

A polished, production-ready 2D arcade + idle + growth web game built for the
**CrazyGames Basic Launch**. Custom TypeScript engine on HTML5 Canvas — no game
engine, no heavy libraries, no backend.

```
MOVE → ATTRACT → ORBIT → CONSUME → GROW → UPGRADE → DISCOVER
```

---

## Quick start

```bash
npm install
npm run dev        # local dev server (Vite)
npm run build      # typecheck (tsc) + production build → dist/
npm run preview    # serve the production build
```

The build output in `dist/` is a static bundle (3 files, ~108 KB total) that
can be uploaded directly to CrazyGames or any static host.

---

## What's in the game

| System | Detail |
| --- | --- |
| **Matter** | 10 object tiers — Stardust → Neutron Star — each with a consume gate, orbit tier, rarity and procedural glow sprite. |
| **Upgrades** | 44 upgrades across Gravity, Mobility, Efficiency, Automation (idle), Discovery and Utility. Geometric cost curves, no runaway growth. |
| **Idle** | Four passive engines (Gravity Beacon, Mass Compressor, Dark Collector, Nebula Harvester) + offline progress capped at 8 h. |
| **Events** | 6 universe events (Meteor Shower, Nebula Bloom, Solar Collapse, Galaxy Drift, Temporal Distortion, Universe Tear) that reshape spawns, physics and visuals. |
| **Sectors** | 5 streaming sectors (1500² → 12000²) that unlock by mass; no loading screens. |
| **Prestige** | "Big Crunch" resets the run for Singularity Cores spent on 7 permanent Cosmic Laws. Lands around 60–90 min. |
| **Meta** | 15 achievements, ambient discovery narrative, autosave, import/export, full settings. |

---

## Architecture

Everything is hand-written TypeScript (strict mode) with a clean separation
between the simulation, rendering and DOM UI.

```
src/
  main.ts              Entry point: boot, loop wiring, lifecycle/save hooks
  config.ts            All balance & tuning constants in one place
  types.ts             Shared data contracts
  core/
    Game.ts            Orchestrator — owns the world & systems, drives sim+draw
    GameLoop.ts        Fixed-timestep loop (refresh-rate-independent physics)
    Camera.ts          Smoothed follow camera with zoom-out-on-growth & shake
    Input.ts           Keyboard (WASD/ZQSD/arrows) + mouse + touch joystick
    ObjectPool.ts      Allocation-free pooling (rolling cursor)
    SpatialGrid.ts     Uniform spatial hash (broad-phase infra)
    RNG.ts             Deterministic mulberry32 PRNG
  entities/            Player (black hole), cosmic objects, particle system
  systems/             Physics, Spawn, Idle, Event, Prestige, Achievement,
                       Narrative, Upgrade — pure logic, no rendering
  render/              Renderer, Background (parallax starfield/nebula),
                       SpriteCache (pre-rendered glowing orbs)
  audio/AudioEngine    Fully synthesized Web Audio (pad + procedural SFX)
  save/                IndexedDB + localStorage mirror, versioned & sanitized
  state/               GameState (persistent save + derived-stat engine)
  ui/                  HUD, upgrade drawer, modal stack, minimap, toasts
  sdk/CrazyGames       Defensive SDK wrapper (GameplayStart; Basic-Launch safe)
```

### Key engineering decisions

- **Fixed timestep (60 Hz).** Simulation always advances in `1/60 s` steps with
  a backlog cap, so physics is identical at 60/144/165 Hz — a CrazyGames
  requirement — while rendering runs at display rate.
- **Cached sprites + additive glow.** Every object and particle is drawn from a
  pre-rendered offscreen canvas scaled per frame. No per-object gradient
  construction and no `shadowBlur` in the hot loop — the single biggest win for
  steady 60 FPS on Chromebook-class hardware.
- **Pooling everywhere.** Objects (≤520) and particles (≤1400) are pre-allocated
  once; the hot loop never allocates, so there is no GC churn.
- **Culling.** Off-screen bodies and particles are skipped at draw time; idle
  bodies that drift far from the player are recycled.
- **Derived-stat engine.** Upgrade and Cosmic-Law levels are compiled into a
  flat `Derived` struct once on change; systems read plain numbers each frame.
- **Redundant saves.** IndexedDB is primary with a synchronous localStorage
  mirror; every load is sanitized against a fresh default, so progress survives
  corruption, a cleared DB, or private-mode restrictions.

---

## CrazyGames Basic Launch compliance

See [`docs/COMPLIANCE.md`](docs/COMPLIANCE.md) for the full requirement-by-
requirement mapping. Highlights:

- ✅ **Size:** ~108 KB total / 3 files (limits: 50 MB initial, 250 MB total, 1500 files).
- ✅ **Time-to-gameplay:** instant — the player lands directly in gameplay.
- ✅ **Responsive** and readable at DPR 1 across all CrazyGames iframe sizes,
  desktop + mobile + portrait.
- ✅ **Input:** mouse, keyboard (layout-tolerant) and touch; floating virtual joystick.
- ✅ **No custom fullscreen button**, **Escape never bound**, **relative paths only**.
- ✅ **English**, **PEGI 12** (abstract, non-violent), no prohibited content, no
  external assets or trackers.
- ✅ **No ads / monetization / account / multiplayer** (Basic Launch), but the
  SDK wrapper and system seams are in place for a clean Full-Launch upgrade.

### Designed for Full Launch later

`src/sdk/CrazyGames.ts` already initializes the SDK (best-effort) and fires the
`GameplayStart` / `GameplayStop` events. The save layer is structured so the
CrazyGames `Data` module can drop in alongside the local store, and ad
placements (rewarded "double offline", midgame on prestige) have natural homes
without touching gameplay code.

---

## Controls

- **Move:** WASD / ZQSD / Arrow keys, or hold the mouse to steer; touch anywhere
  on mobile for a floating joystick.
- **Upgrades:** `U` or the ⬆ button.
- **Pause:** `P` or the ⏸ button.

## License & assets

All code, art and audio are original and generated procedurally. No copyrighted
material is used.
