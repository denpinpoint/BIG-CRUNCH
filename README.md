# Voxelcraft

A Minecraft-**inspired** voxel sandbox built from scratch in **Godot 4**
(4.4+ required, developed against **4.6**) with typed GDScript. Infinite
procedural terrain with cliffs, caves, ore veins and trees, threaded chunk
streaming, mining & building with a real inventory, 2x2 crafting, furnace
smelting, **Survival and Creative** modes, original mobs, a full day/night
cycle with a shader sky (stars, moon, sunsets), and save/load.

All assets are original: block textures are generated procedurally at
startup (flat colors + hash noise) and mobs are flat-colored voxel critters.
No trademarked names, textures, or sounds anywhere.

![Godot 4.4+](https://img.shields.io/badge/Godot-4.4%2B-478cbf) ![GDScript](https://img.shields.io/badge/language-GDScript-blue)

## Running it

1. Install [Godot 4.4 or newer](https://godotengine.org/download) — 4.6 is
   what it's developed against (the standard build, no C# needed). Typed
   dictionaries put the floor at 4.4.
2. Open the project (`project.godot`) in the editor and press **F5**, or run
   `godot --path .` from this directory.
3. Pick **Survival** or **Creative** in the start menu and play.

The window opens at 1280×720; the renderer is Forward+.

## Controls

| Action | Input |
|---|---|
| Move | **W A S D** |
| Look | Mouse (click to capture) |
| Jump | **Space** (hold to bunny-hop) |
| Sprint | **Shift** |
| Crouch / fly down | **Ctrl** |
| Fly (Creative) | **Double-tap Space** to toggle, Space/Ctrl for up/down |
| Mine / attack | **Left mouse** (hold to mine in Survival — watch the cracks grow) |
| Place block / use furnace | **Right mouse** (crouch to build against a furnace) |
| Inventory | **E** (Creative: category tabs; Survival: 2x2 crafting) |
| Select hotbar slot | **1–9** or **mouse wheel** |
| Switch Survival ⇄ Creative | **F4** |
| Pause menu | **Esc** (resume, settings, save, save & quit) |
| Save / Load | **F5** / **F9** (also autosaves on quit) |
| Debug overlay | **F3** |

## What's implemented

* **Chunked voxel world** — 16×96×16 chunks stored as flat `PackedByteArray`s,
  meshed with per-face culling into a single `ArrayMesh` per chunk (never one
  mesh per cube). Correct normals, clockwise winding, per-face atlas UVs with
  half-texel bleed protection.
* **Procedural terrain** — seeded `FastNoiseLite` heightmap + ridged mountains
  + terraced cliff noise (random sheer walls and plateaus); grass/dirt/stone
  layering, bedrock floor, sea-level water, hash-placed trees, and sand that
  only forms on real shorelines (columns at water height with water nearby).
  Fully deterministic: same seed ⇒ same world.
* **Caves & ores** — carved in the same deterministic world-space pass: 3D
  "cheese" caverns plus two intersected "spaghetti" worm fields, depth-biased,
  never through bedrock, seamless across chunks. Sparse "entrance regions"
  let SOME worm tunnels breach the crust into walk-in cave mouths while most
  of the network stays sealed. Stone hides ore veins (coal anywhere, iron
  below y=52, gold below y=26, diamond below y=14), each blob a single
  consistent ore type.
* **Infinite streaming** — chunks generate & mesh on `WorkerThreadPool`
  threads; the main thread only attaches finished meshes within a per-frame
  time budget. Border culling is exact even against unloaded neighbors
  (truth = generator + edit overlay everywhere).
* **Player** — capsule `CharacterBody3D` vs. trimesh chunk colliders, sprint,
  crouch, gravity/terminal velocity, fall damage, void rescue.
* **Mining & building** — voxel DDA raycast (max reach 5), wireframe block
  highlight, hold-to-mine with per-block hardness and a progressive **crack
  overlay on the block itself** (instant in Creative), placement with
  player-overlap rejection, minimal re-meshing (edited chunk + touched border
  neighbors only). In Survival, mined blocks pop out as pickup drops
  (grass→dirt, stone→cobblestone, ores→minerals).
* **Inventory, crafting & smelting** — you spawn with nothing. 36-slot
  inventory (9-slot hotbar) with drag/split/merge stack handling; E opens it.
  Survival gets a 2x2 shapeless crafting grid (planks, sticks, furnace,
  mineral blocks); Creative gets category palette tabs with infinite stacks.
  Placeable furnaces smelt ores/cobble/logs using coal or wood as fuel — in
  the background, even while you wander off.
* **Item drops (Survival)** — mined blocks and slain mobs spawn real pickup
  entities (billboard sprites with voxel physics) that pop out, magnet
  toward you, and auto-collect; Woolbacks drop wool tufts, Gnashers drop
  gloom shards. Creative keeps its instant, dropless breaking.
* **Pause & settings** — Esc pauses with resume/settings/save/quit; the
  settings screen (also on the start menu) covers video (fullscreen, vsync,
  render distance, FOV, shadows), audio (master volume/mute — the bus is
  wired, sound assets are a TODO), and controls (mouse sensitivity, invert
  Y), all applied live and persisted to user://settings.cfg.
* **Modes** — Creative: fly, instant break, infinite blocks, invulnerable,
  ignored by mobs, stats hidden. Survival: health + hunger (sprint drains,
  full hunger regens, starvation hurts), timed mining, fall damage, death &
  respawn screen. Live-switchable with F4, no restart.
* **Mobs** — shared steering base (auto-jump 1-block steps, ledge caution,
  hurt flash, knockback, distance despawn). The **Woolback** (passive)
  wanders/grazes/flees; the **Gnasher** (hostile) chases on sight, bites on
  contact, ignores Creative players. Spawner enforces per-type + global caps,
  daylight-grass rules for passives, night/dark-cave rules for hostiles.
* **Day/night cycle & sky** — custom sky shader with a visible sun disc,
  sunrise/sunset horizon glow, a moon, and a twinkling star field; warm/cool
  light temperature, blue moonlight fill at night, filmic tonemapping, and
  fog that tracks the sky. Hostile spawning keys off the cycle.
* **Save/load** — JSON in `user://voxelcraft_save.json`: seed, mode, player
  state, spawn point, the full inventory, furnace contents/progress, time of
  day, and **only the edited blocks** (a diff vs. procedural generation), so
  files stay tiny.

## Project layout

```
main/       Main.tscn, orchestrator, constants, input map (registered in code)
world/      chunk manager (threading), chunk node, mesher, terrain generator, day/night
blocks/     block ids/registry + atlas/material library (procedural atlas)
player/     controller, DDA block interaction, mode singleton, survival stats
entities/   mob base + Woolback + Gnasher + spawner
ui/         HUD, hotbar, stats bar, start menu, death screen, debug overlay
save/       save/load manager
```

Coordinate conventions, chunk indexing math, threading hand-off, and the DDA
raycast are documented in comments where they live (`main/constants.gd`,
`world/chunk_mesher.gd`, `world/world.gd`, `player/block_interaction.gd`).

## Verifying each phase

1. **Meshing** — F3: with render distance 8 you'll see vertex counts far
   below `blocks × 36`; interior faces are never emitted.
2. **Texturing** — grass shows green top / dirt bottom / striped side; no
   seams (half-texel UV inset + NEAREST filtering).
3. **Terrain & caves** — same seed reproduces the same world; walk into a
   cave mouth on a hillside or mine down: tunnels continue seamlessly across
   chunk borders.
4. **Streaming** — walk any direction: chunks appear with no border holes and
   no frame hitches (F3 shows loaded/building/queued).
5. **Player** — you can't clip into terrain, jumps clear 1 block, falls hurt
   (Survival).
6. **Edits** — mine a tunnel across a chunk border and build a tower; only
   affected chunks re-mesh; you can't place a block inside yourself.
7. **Inventory & hotbar** — you spawn empty-handed; mine wood/dirt and watch
   them stack in the hotbar. E opens the inventory: drag stacks around,
   right-click splits. Creative shows Blocks/Minerals/Items palette tabs.
8. **Crafting & smelting** — log → 4 planks → sticks; 4 cobblestone → furnace;
   place it, right-click it, smelt iron ore with coal into ingots.
9. **Modes** — F4 mid-game: stats bar, flight, invulnerability, and mob
   aggression all flip instantly.
10. **Mobs** — Woolbacks graze by day and flee when hit; Gnashers hunt at
   night (or in caves), hit you in Survival, ignore you in Creative.
11. **Save/load** — build, F5, quit, relaunch, Continue/F9: edits, position,
    mode, stats, and time of day are all back; the save stores only changed
    blocks.

## Performance notes

Targets 60+ FPS at render distance 8 on a mid-range desktop. Known
bottlenecks, all marked with `# PERF:` comments at the exact spot:

* Chunk generation + meshing are pure GDScript — fast enough off the main
  thread, but a C#/GDExtension port of `chunk_mesher.gd` and
  `terrain_generator.gd` is the first thing to do for bigger view distances.
* 3D cave noise is ~3 samples per underground block; coarse-grid sampling
  with trilinear interpolation is the documented next step.
* Trees sample a 5×5 column neighborhood near the surface (cached per chunk
  build).

## License / attribution

Original code and procedural assets created for this repository. Inspired by
Minecraft; contains no Mojang assets, textures, sounds, or trademarks.
