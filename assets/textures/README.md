# Textures

There are intentionally **no image files** here.

The texture atlas (a 16×16 grid of 16 px tiles: terrain blocks, ores,
furnace, glass, wool, bed, crafting table, stairs, mineral blocks, plus item
icons like sticks, ingots, food, and every tool/armour piece) is **generated
procedurally at startup** by `blocks/block_library.gd` from flat base colors
plus deterministic hash noise and small parametric shape painters — every
pixel is original, nothing is copied from any other game.

This deviates from the usual committed `atlas.png` on purpose:

* the repository stays free of binary assets (no import settings, no
  `.import` churn),
* the atlas is guaranteed to match the tile indices in
  `blocks/block_types.gd`, since both come from the same code.

Want to see or edit it as a real image? Run the game once — the atlas is
written to `user://atlas_debug.png` for inspection. Mob "textures" are flat
colored materials built in `entities/*_mob.gd`.
