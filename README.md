# Voxelcraft

A Minecraft-**inspired** voxel sandbox built from scratch in **Godot 4.3+**
with typed GDScript. Infinite procedural terrain with caves and trees,
threaded chunk streaming, mining & building, **Survival and Creative** modes,
original passive & hostile mobs, a day/night cycle, and save/load.

All assets are original: block textures are generated procedurally at
startup (flat colors + hash noise) and mobs are flat-colored voxel critters.
No trademarked names, textures, or sounds anywhere.

![Godot 4.3+](https://img.shields.io/badge/Godot-4.3%2B-478cbf) ![GDScript](https://img.shields.io/badge/language-GDScript-blue)

## Running it

1. Install [Godot 4.3 or newer](https://godotengine.org/download) (the
   standard build — no C# needed).
2. Open the project (`project.godot`) in the editor and press **F5**, or run
   `godot --path .` from this directory.
3. Pick **Survival** or **Creative** in the start menu and play.

The window opens at 1280×720; the renderer is Forward+.

## Controls

| Action | Input |
|---|---|
| Move | **W A S D** |
| Look | Mouse (click to capture, **Esc** to release) |
| Jump | **Space** (hold to bunny-hop) |
| Sprint | **Shift** |
| Crouch / fly down | **Ctrl** |
| Fly (Creative) | **Double-tap Space** to toggle, Space/Ctrl for up/down |
| Mine / attack | **Left mouse** (hold to mine in Survival) |
| Place block | **Right mouse** |
| Select block | **1–8** or **mouse wheel** |
| Switch Survival ⇄ Creative | **F4** |
| Save / Load | **F5** / **F9** (also autosaves on quit) |
| Debug overlay | **F3** |

## What's implemented

* **Chunked voxel world** — 16×64×16 chunks stored as flat `PackedByteArray`s,
  meshed with per-face culling into a single `ArrayMesh` per chunk (never one
  mesh per cube). Correct normals, clockwise winding, per-face atlas UVs with
  half-texel bleed protection.
* **Procedural terrain** — seeded `FastNoiseLite` heightmap + ridged mountain
  layer; grass/dirt/stone/sand layering, bedrock floor, sea-level water,
  hash-placed trees. Fully deterministic: same seed ⇒ same world.
* **Caves** — carved in the same deterministic world-space pass: 3D "cheese"
  caverns plus two intersected "spaghetti" worm fields, depth-biased so the
  surface isn't swiss-cheesed, never through bedrock, seamless across chunks.
* **Infinite streaming** — chunks generate & mesh on `WorkerThreadPool`
  threads; the main thread only attaches finished meshes within a per-frame
  time budget. Border culling is exact even against unloaded neighbors
  (truth = generator + edit overlay everywhere).
* **Player** — capsule `CharacterBody3D` vs. trimesh chunk colliders, sprint,
  crouch, gravity/terminal velocity, fall damage, void rescue.
* **Mining & building** — voxel DDA raycast (max reach 5), wireframe block
  highlight, hold-to-mine with per-block hardness (instant in Creative),
  placement with player-overlap rejection, minimal re-meshing (edited chunk +
  touched border neighbors only).
* **Modes** — Creative: fly, instant break, infinite blocks, invulnerable,
  ignored by mobs, stats hidden. Survival: health + hunger (sprint drains,
  full hunger regens, starvation hurts), timed mining, fall damage, death &
  respawn screen. Live-switchable with F4, no restart.
* **Mobs** — shared steering base (auto-jump 1-block steps, ledge caution,
  hurt flash, knockback, distance despawn). The **Woolback** (passive)
  wanders/grazes/flees; the **Gnasher** (hostile) chases on sight, bites on
  contact, ignores Creative players. Spawner enforces per-type + global caps,
  daylight-grass rules for passives, night/dark-cave rules for hostiles.
* **Day/night cycle** — rotating sun, blended sky/ambient, ties into hostile
  spawning.
* **Save/load** — JSON in `user://voxelcraft_save.json`: seed, mode, player
  state, spawn point, hotbar, time of day, and **only the edited blocks**
  (a diff vs. procedural generation), so files stay tiny.

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
7. **Hotbar** — 1–8/wheel changes the placed block; selection is highlighted.
8. **Modes** — F4 mid-game: stats bar, flight, invulnerability, and mob
   aggression all flip instantly.
9. **Mobs** — Woolbacks graze by day and flee when hit; Gnashers hunt at
   night (or in caves), hit you in Survival, ignore you in Creative.
10. **Save/load** — build, F5, quit, relaunch, Continue/F9: edits, position,
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
