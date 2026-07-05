# Texture packs

Voxelcraft's textures are a single atlas generated procedurally at startup
(see `blocks/block_library.gd`). A **texture pack** lets you override any of
those tiles with your own 16×16 PNGs — no code changes, applied live from the
in-game settings menu.

**We ship no third-party textures.** The repo stays 100% original art. A pack
lets *you* substitute images you have the right to use (your own, or a
CC-licensed pack). Please don't drop in copyrighted textures from other games.

## Where packs live

A pack is a folder of PNGs. Two search roots, `user://` first:

```
user://resource_packs/<YourPack>/    ← drop packs here (works in exported builds)
res://resource_packs/<YourPack>/     ← bundled with the project (this folder)
```

`user://` is the game's writable data dir — on desktop, typically
`~/.local/share/godot/app_userdata/Voxelcraft/` (Linux),
`%APPDATA%\Godot\app_userdata\Voxelcraft\` (Windows),
`~/Library/Application Support/Godot/app_userdata/Voxelcraft/` (macOS).

## Making a pack

1. Run the game once. It writes a **`_template`** pack to
   `user://resource_packs/_template/` containing every tile as a correctly
   named 16×16 PNG (the exact default textures).
2. Copy that folder and rename it, e.g. `user://resource_packs/MyPack/`.
3. Replace any PNGs you like — keep the filenames. 16×16 is ideal; other
   square sizes are downscaled with nearest-neighbour. Only the files you
   change need to exist; missing ones fall back to the procedural default.
4. In game: **Settings → Resource pack → MyPack**. It applies instantly
   (no restart, no re-mesh — the atlas texture is hot-swapped in place).

## Tile filenames

Blocks: `grass_top`, `grass_side`, `dirt`, `stone`, `sand`, `log_side`,
`log_top`, `leaves`, `water`, `bedrock`, `cobblestone`, `planks`, `coal_ore`,
`iron_ore`, `gold_ore`, `diamond_ore`, `furnace_front`, `furnace_top`,
`iron_block`, `gold_block`, `diamond_block`, `wool`, `bed_top`, `bed_side`,
`crafting_table_top`, `crafting_table_side`, `glass`.

Items: `stick`, `coal`, `iron_ingot`, `gold_ingot`, `diamond`, `gloom_shard`,
`mutton_raw`, `mutton_cooked`, `plank_stairs_icon`, `cobblestone_stairs_icon`.

Tools: `<tier>_<class>` where tier ∈ {wooden, stone, iron, golden, diamond}
and class ∈ {pickaxe, axe, shovel, sword} — e.g. `iron_pickaxe`.

Armor: `<material>_<piece>` where material ∈ {iron, golden, diamond} and
piece ∈ {helmet, chestplate, leggings, boots} — e.g. `diamond_chestplate`.

The authoritative list is `BlockTypes.tile_names()`.
