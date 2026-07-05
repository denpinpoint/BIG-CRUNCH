extends Node
## Autoloaded as "BlockLibrary".
##
## Owns the block texture atlas, the chunk materials, and the mining crack
## overlay materials. The atlas is a single 256x256 image (16x16 grid of
## 16px tiles) generated procedurally at startup from flat base colors plus
## deterministic hash noise — completely original, no external image files.
## Item icons (tools, armor, food, ...) are painted into the same atlas with
## transparent backgrounds. A copy is written to user://atlas_debug.png.
##
## Everything here is built once in _ready() and never mutated afterwards, so
## worker threads may safely read the materials and atlas texture.

const CRACK_STAGES := 10

var atlas_image: Image
var atlas_texture: ImageTexture
var opaque_material: StandardMaterial3D
var water_material: StandardMaterial3D
var glass_material: StandardMaterial3D
## Mining crack overlays, index 0 (light cracks) .. CRACK_STAGES-1 (shattered).
var crack_materials: Array[StandardMaterial3D] = []

# Base colors per tile index (see BlockTypes.TILE_*).
const _TILE_COLORS := {
	BlockTypes.TILE_GRASS_TOP: Color8(106, 170, 64),
	BlockTypes.TILE_GRASS_SIDE: Color8(134, 96, 67),  # dirt base; green strip added on top
	BlockTypes.TILE_DIRT: Color8(134, 96, 67),
	BlockTypes.TILE_STONE: Color8(125, 125, 125),
	BlockTypes.TILE_SAND: Color8(219, 207, 163),
	BlockTypes.TILE_WOOD_SIDE: Color8(104, 82, 50),
	BlockTypes.TILE_WOOD_TOP: Color8(155, 125, 78),
	BlockTypes.TILE_LEAVES: Color8(58, 138, 66),
	BlockTypes.TILE_WATER: Color8(58, 110, 220),
	BlockTypes.TILE_BEDROCK: Color8(70, 70, 70),
	BlockTypes.TILE_COBBLE: Color8(118, 118, 118),
	BlockTypes.TILE_PLANKS: Color8(178, 133, 83),
	BlockTypes.TILE_COAL_ORE: Color8(125, 125, 125),
	BlockTypes.TILE_IRON_ORE: Color8(125, 125, 125),
	BlockTypes.TILE_GOLD_ORE: Color8(125, 125, 125),
	BlockTypes.TILE_DIAMOND_ORE: Color8(125, 125, 125),
	BlockTypes.TILE_FURNACE_FRONT: Color8(105, 105, 105),
	BlockTypes.TILE_FURNACE_TOP: Color8(95, 95, 95),
	BlockTypes.TILE_IRON_BLOCK: Color8(222, 222, 222),
	BlockTypes.TILE_GOLD_BLOCK: Color8(250, 214, 72),
	BlockTypes.TILE_DIAMOND_BLOCK: Color8(110, 230, 225),
	BlockTypes.TILE_STICK: Color8(140, 100, 50),
	BlockTypes.TILE_COAL_ITEM: Color8(38, 38, 38),
	BlockTypes.TILE_IRON_INGOT: Color8(216, 216, 216),
	BlockTypes.TILE_GOLD_INGOT: Color8(250, 208, 60),
	BlockTypes.TILE_DIAMOND_ITEM: Color8(92, 220, 215),
	BlockTypes.TILE_GLOOM_SHARD: Color8(120, 70, 180),
	BlockTypes.TILE_WOOL: Color8(236, 232, 225),
	BlockTypes.TILE_BED_TOP: Color8(178, 44, 44),
	BlockTypes.TILE_BED_SIDE: Color8(140, 100, 60),
	BlockTypes.TILE_CRAFTING_TOP: Color8(168, 123, 73),
	BlockTypes.TILE_CRAFTING_SIDE: Color8(160, 115, 68),
	BlockTypes.TILE_GLASS: Color8(210, 235, 245),
	BlockTypes.TILE_STAIR_PLANK: Color8(178, 133, 83),
	BlockTypes.TILE_STAIR_COBBLE: Color8(118, 118, 118),
	BlockTypes.TILE_MUTTON_RAW: Color8(205, 85, 85),
	BlockTypes.TILE_MUTTON_COOKED: Color8(155, 92, 48),
}

const _ORE_SPECK_COLORS := {
	BlockTypes.TILE_COAL_ORE: Color8(38, 38, 38),
	BlockTypes.TILE_IRON_ORE: Color8(216, 168, 124),
	BlockTypes.TILE_GOLD_ORE: Color8(252, 208, 60),
	BlockTypes.TILE_DIAMOND_ORE: Color8(92, 220, 215),
}

# Tier/material accent colors shared by tool + armor icon painters.
const _TIER_COLORS := [
	Color8(178, 133, 83),   # wood
	Color8(125, 125, 125),  # stone
	Color8(216, 216, 216),  # iron
	Color8(250, 208, 60),   # gold
	Color8(92, 220, 215),   # diamond
]
const _ARMOR_COLORS := [Color8(216, 216, 216), Color8(250, 208, 60), Color8(92, 220, 215)]
const _HANDLE := Color8(110, 80, 45)


func _ready() -> void:
	_paint_procedural_atlas()
	_dump_template_pack()      # one-time: export defaults so users can edit them
	_apply_resource_pack()     # overlay the active pack's PNGs, if any
	atlas_texture = ImageTexture.create_from_image(atlas_image)
	atlas_image.save_png("user://atlas_debug.png")  # inspect the final atlas
	_build_materials()
	_build_crack_materials()


## Icon texture for UI (hotbar/inventory slots), cropped from the atlas.
func get_icon(id: int) -> AtlasTexture:
	var tex := AtlasTexture.new()
	tex.atlas = atlas_texture
	tex.region = BlockTypes.tile_pixel_region(BlockTypes.icon_tile(id))
	return tex


## Re-paint the procedural base + re-overlay the active pack, then hot-swap
## the texture data in place. Because every material and UI icon references
## the SAME atlas_texture resource with unchanged UVs, this repaints the whole
## game live — no chunk re-mesh needed. Called by the settings menu.
func reload_pack() -> void:
	_paint_procedural_atlas()
	_apply_resource_pack()
	atlas_texture.update(atlas_image)


func _paint_procedural_atlas() -> void:
	var px := BlockTypes.TILE_PIXELS
	var size := BlockTypes.ATLAS_TILES * px
	if atlas_image == null:
		atlas_image = Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	atlas_image.fill(Color8(255, 0, 255))  # unused tiles scream magenta

	var tiles: Array = _TILE_COLORS.keys()
	# Tool + armor icon tiles are computed, not listed.
	for t in 20:
		tiles.append(BlockTypes.TILE_TOOL_BASE + t)
	for a in 12:
		tiles.append(BlockTypes.TILE_ARMOR_BASE + a)

	for tile: int in tiles:
		var base: Color = _TILE_COLORS.get(tile, Color8(255, 255, 255))
		var region := BlockTypes.tile_pixel_region(tile)
		for y in px:
			for x in px:
				var c := _tile_pixel(tile, x, y, base)
				atlas_image.set_pixel(int(region.position.x) + x, int(region.position.y) + y, c)


## Overlay the active resource pack's PNGs onto the procedural atlas. Each
## tile whose "<name>.png" exists in the pack is resized to 16x16 (nearest)
## and blitted over its atlas cell; missing tiles keep the procedural look.
func _apply_resource_pack() -> void:
	var dir := ResourcePacks.pack_dir(Settings.resource_pack)
	if dir == "":
		return
	var px := BlockTypes.TILE_PIXELS
	var names := BlockTypes.tile_names()
	for tile: int in names:
		var path := "%s/%s.png" % [dir, names[tile]]
		if not FileAccess.file_exists(path):
			continue
		var img := Image.load_from_file(path)
		if img == null:
			push_warning("Resource pack: could not load %s" % path)
			continue
		if img.get_format() != Image.FORMAT_RGBA8:
			img.convert(Image.FORMAT_RGBA8)
		if img.get_width() != px or img.get_height() != px:
			img.resize(px, px, Image.INTERPOLATE_NEAREST)
		var region := BlockTypes.tile_pixel_region(tile)
		atlas_image.blit_rect(img, Rect2i(0, 0, px, px), Vector2i(int(region.position.x), int(region.position.y)))


## First run: write every default tile out to user://resource_packs/_template
## as a correctly-named 16x16 PNG, so players see the exact filenames a pack
## needs and can paint over the defaults. Skipped once the folder exists.
func _dump_template_pack() -> void:
	var dir := "%s/_template" % ResourcePacks.ROOT_USER
	if DirAccess.dir_exists_absolute(dir):
		return
	if DirAccess.make_dir_recursive_absolute(dir) != OK:
		return
	var px := BlockTypes.TILE_PIXELS
	var names := BlockTypes.tile_names()
	for tile: int in names:
		var region := BlockTypes.tile_pixel_region(tile)
		var sub := atlas_image.get_region(
			Rect2i(int(region.position.x), int(region.position.y), px, px)
		)
		sub.save_png("%s/%s.png" % [dir, names[tile]])
	var readme := FileAccess.open("%s/README.txt" % dir, FileAccess.WRITE)
	if readme != null:
		readme.store_string(_TEMPLATE_README)
		readme.close()


const _TEMPLATE_README := """Voxelcraft resource pack
========================

This folder was auto-generated with every block/item texture the game uses,
each a 16x16 PNG at its required filename. To make a pack:

1. Copy this folder and rename it, e.g.  user://resource_packs/MyPack/
2. Replace any PNGs you want (keep the filenames; 16x16 recommended, other
   square sizes are resized down with nearest-neighbour).
3. In-game: Settings -> Resource pack -> pick your pack. It applies live.

Only the files you change need to exist; missing tiles fall back to the
built-in procedural texture. Ships no third-party art — supply textures you
have the right to use.
"""


## Per-pixel tile shading. Deterministic (hash-based), so the atlas is
## identical on every run and every machine.
func _tile_pixel(tile: int, x: int, y: int, base: Color) -> Color:
	# Computed icon ranges first.
	if tile >= BlockTypes.TILE_TOOL_BASE and tile < BlockTypes.TILE_TOOL_BASE + 20:
		var rel := tile - BlockTypes.TILE_TOOL_BASE
		@warning_ignore("integer_division")
		var tool_row := rel / 5
		return _tool_pixel(tool_row, rel % 5, x, y)
	if tile >= BlockTypes.TILE_ARMOR_BASE and tile < BlockTypes.TILE_ARMOR_BASE + 12:
		var rel := tile - BlockTypes.TILE_ARMOR_BASE
		@warning_ignore("integer_division")
		var piece := rel / 3
		return _armor_pixel(piece, _ARMOR_COLORS[rel % 3], x, y)

	var n := _hash01(x + tile * 131, y + tile * 197)
	var c := base
	match tile:
		BlockTypes.TILE_GRASS_SIDE:
			if y < 4:  # green turf strip along the top of the tile
				c = _TILE_COLORS[BlockTypes.TILE_GRASS_TOP]
				n = _hash01(x + 977, y + 331)
		BlockTypes.TILE_WOOD_SIDE:
			if x % 4 == 0:  # vertical bark striping
				c = c.darkened(0.22)
		BlockTypes.TILE_WOOD_TOP:
			var d := maxi(absi(x - 8), absi(y - 8))
			if d % 3 == 0:  # concentric growth rings
				c = c.darkened(0.25)
		BlockTypes.TILE_BEDROCK:
			if n > 0.5:  # chunky high-contrast noise
				c = c.darkened(0.35)
		BlockTypes.TILE_LEAVES:
			if n > 0.72:
				c = c.darkened(0.3)
		BlockTypes.TILE_COBBLE, BlockTypes.TILE_FURNACE_TOP:
			c = _cobble_pixel(x, y, c)
		BlockTypes.TILE_PLANKS:
			c = _plank_pixel(x, y, c)
		BlockTypes.TILE_COAL_ORE, BlockTypes.TILE_IRON_ORE, \
		BlockTypes.TILE_GOLD_ORE, BlockTypes.TILE_DIAMOND_ORE:
			c = _stone_like(x, y, c)
			@warning_ignore("integer_division")
			if _hash01(x / 2 + tile * 31, y / 2 + tile * 17) > 0.66:
				c = _ORE_SPECK_COLORS[tile]
				c = c.darkened((n - 0.5) * 0.2)
		BlockTypes.TILE_FURNACE_FRONT:
			c = _cobble_pixel(x, y, c)
			if y >= 9 and y <= 13 and x >= 4 and x <= 11:  # dark mouth
				c = Color8(28, 24, 22)
				if y >= 12 and _hash01(x * 7, y * 3) > 0.45:  # ember glow
					c = Color8(232, 122, 32)
		BlockTypes.TILE_IRON_BLOCK, BlockTypes.TILE_GOLD_BLOCK, BlockTypes.TILE_DIAMOND_BLOCK:
			if x == 0 or y == 0 or x == 15 or y == 15:
				c = c.darkened(0.3)  # beveled edge
			elif x <= 4 and y <= 4:
				c = c.lightened(0.18)  # corner highlight
		BlockTypes.TILE_WOOL:
			# soft weave: diagonal ridges + fluffy noise
			if (x + y) % 4 == 0:
				c = c.darkened(0.08)
			if n > 0.8:
				c = c.darkened(0.12)
		BlockTypes.TILE_BED_TOP:
			c = _bed_top_pixel(x, y, c)
		BlockTypes.TILE_BED_SIDE:
			# blanket overhang above, wooden frame below, dark feet
			if y < 6:
				c = _TILE_COLORS[BlockTypes.TILE_BED_TOP]
				if y == 5:
					c = c.darkened(0.2)
			elif (x < 2 or x > 13) and y > 11:
				c = c.darkened(0.4)
		BlockTypes.TILE_CRAFTING_TOP:
			c = _plank_pixel(x, y, c)
			if x % 5 == 0 or y % 5 == 0:  # worktop grid
				c = c.darkened(0.35)
		BlockTypes.TILE_CRAFTING_SIDE:
			c = _plank_pixel(x, y, c)
			# tool silhouettes scribbled on the side
			if (x - 4) * (x - 4) + (y - 7) * (y - 7) <= 4 or (absi(x - 10) <= 1 and y >= 5 and y <= 10):
				c = c.darkened(0.45)
		BlockTypes.TILE_GLASS:
			return _glass_pixel(x, y, c)
		BlockTypes.TILE_STAIR_PLANK, BlockTypes.TILE_STAIR_COBBLE:
			return _stair_icon_pixel(x, y, c)
		BlockTypes.TILE_MUTTON_RAW, BlockTypes.TILE_MUTTON_COOKED:
			return _mutton_pixel(x, y, c, n)
		BlockTypes.TILE_STICK:
			return _stick_pixel(x, y, base, n)
		BlockTypes.TILE_COAL_ITEM:
			return _lump_pixel(x, y, base, n)
		BlockTypes.TILE_IRON_INGOT, BlockTypes.TILE_GOLD_INGOT:
			return _ingot_pixel(x, y, base)
		BlockTypes.TILE_DIAMOND_ITEM:
			return _gem_pixel(x, y, base)
		BlockTypes.TILE_GLOOM_SHARD:
			return _shard_pixel(x, y, base)
	# Subtle noise on everything so flat colors read as texture.
	c = c.darkened((n - 0.5) * 0.16)
	if tile == BlockTypes.TILE_WATER:
		c.a = 0.78
	return c


func _cobble_pixel(x: int, y: int, base: Color) -> Color:
	var c := base
	# 4x4 stone cells with darker mortar lines and per-cell value variation.
	if x % 5 == 0 or y % 5 == 0:
		c = c.darkened(0.3)
	else:
		@warning_ignore("integer_division")
		var cell := _hash01(x / 5 + 61, y / 5 + 13)
		c = c.darkened((cell - 0.5) * 0.3)
	return c


func _plank_pixel(x: int, y: int, base: Color) -> Color:
	var c := base
	if y % 4 == 3:  # horizontal plank gaps
		c = c.darkened(0.35)
	@warning_ignore("integer_division")
	var seam := int(_hash01(y / 4 + 5, 11) * 15.0)
	if x == seam:  # one vertical seam per plank
		c = c.darkened(0.28)
	return c


func _stone_like(x: int, y: int, base: Color) -> Color:
	var n := _hash01(x + 311, y + 977)
	return base.darkened((n - 0.5) * 0.16)


func _bed_top_pixel(x: int, y: int, base: Color) -> Color:
	var c := base
	if x == 0 or x == 15 or y == 0 or y == 15:
		return Color8(120, 85, 50)  # wooden frame rim
	if y <= 4:
		c = Color8(232, 228, 218)  # pillow
		if y == 4:
			c = c.darkened(0.18)
	elif y == 5:
		c = c.lightened(0.2)  # blanket fold
	return c


func _glass_pixel(x: int, y: int, base: Color) -> Color:
	# Light frame, transparent middle, one diagonal sparkle streak.
	if x == 0 or x == 15 or y == 0 or y == 15:
		return Color(base.r, base.g, base.b, 0.85)
	if x + y >= 8 and x + y <= 10 and x < 9:
		return Color(base.r, base.g, base.b, 0.5)
	return Color(0, 0, 0, 0)


func _stair_icon_pixel(x: int, y: int, base: Color) -> Color:
	# Side profile: low half in front, high half behind.
	var filled := (y >= 8) or (x >= 8 and y >= 2)
	if not filled:
		return Color(0, 0, 0, 0)
	var c := base
	if y == 8 and x < 8 or y == 2 and x >= 8 or x == 8 and y < 8:
		c = c.lightened(0.25)  # step edges
	return c.darkened((_hash01(x, y) - 0.5) * 0.16)


func _mutton_pixel(x: int, y: int, base: Color, n: float) -> Color:
	# Meaty chop with a bone sticking out the top-right.
	var dx := x - 7
	var dy := y - 9
	if dx * dx + dy * dy * 2 <= 26:
		var c := base.darkened((n - 0.5) * 0.3)
		if dx * dx + dy * dy * 2 <= 8:
			c = c.lightened(0.2)  # juicy center
		return c
	if absi(x - 12) <= 1 and y >= 3 and y <= 6:
		return Color8(235, 228, 210)  # bone
	if (x - 12) * (x - 12) + (y - 3) * (y - 3) <= 2:
		return Color8(245, 240, 226)  # bone knob
	return Color(0, 0, 0, 0)


func _stick_pixel(x: int, y: int, base: Color, n: float) -> Color:
	# Diagonal stick from bottom-left to top-right, transparent elsewhere.
	if absi((15 - y) - x) <= 1 and x >= 2 and x <= 13:
		return base.darkened((n - 0.5) * 0.3)
	return Color(0, 0, 0, 0)


func _lump_pixel(x: int, y: int, base: Color, n: float) -> Color:
	var dx := x - 8
	var dy := y - 8
	if dx * dx + dy * dy <= 27:
		var c := base.darkened((n - 0.5) * 0.5)
		if dx + dy < -4:
			c = c.lightened(0.25)  # glint
		return c
	return Color(0, 0, 0, 0)


func _ingot_pixel(x: int, y: int, base: Color) -> Color:
	# Two stacked bars with a lit top edge and shaded bottom edge.
	for bar_top: int in [3, 9]:
		if y >= bar_top and y <= bar_top + 4 and x >= 2 and x <= 13:
			if y == bar_top:
				return base.lightened(0.35)
			if y == bar_top + 4:
				return base.darkened(0.35)
			return base
	return Color(0, 0, 0, 0)


func _gem_pixel(x: int, y: int, base: Color) -> Color:
	var d := absi(x - 8) + absi(y - 8)
	if d <= 6:
		if d >= 5:
			return base.darkened(0.35)  # facet edge
		if x + y < 12:
			return base.lightened(0.25)  # sparkle side
		return base
	return Color(0, 0, 0, 0)


@warning_ignore("integer_division")
func _shard_pixel(x: int, y: int, base: Color) -> Color:
	# Narrow jagged sliver from bottom-left to top-right.
	var along := (x + (15 - y)) / 2  # 0..15 along the diagonal
	var off := absi(x - (15 - y))    # distance across it
	var half_width := 3 - absi(along - 8) / 3
	if off <= half_width and along >= 2 and along <= 13:
		if off == half_width:
			return base.darkened(0.4)  # edge facet
		if x % 3 == 0:
			return base.lightened(0.3)  # glinting streaks
		return base
	return Color(0, 0, 0, 0)


## Tool icons: shared anti-diagonal handle + a per-class head in the tier
## color. Rows: 0 pickaxe, 1 axe, 2 shovel, 3 sword.
func _tool_pixel(tool_row: int, tier: int, x: int, y: int) -> Color:
	var head: Color = _TIER_COLORS[tier]
	var d := x + y - 15  # 0..1 = on the anti-diagonal band
	var on_handle := d >= 0 and d <= 1
	match tool_row:
		0:  # pickaxe: curved head band + drooping tips
			if y >= 2 and y <= 3 and x >= 2 and x <= 13:
				return _edge_shade(head, x, y)
			if (x <= 3 or x >= 12) and y >= 4 and y <= 6:
				return _edge_shade(head, x, y)
			if on_handle and y >= 4 and y <= 13:
				return _HANDLE
		1:  # axe: blade block on the upper right
			if x >= 7 and x <= 12 and y >= 1 and y <= 6 and not (x >= 11 and y >= 5):
				return _edge_shade(head, x, y)
			if on_handle and y >= 3 and y <= 13:
				return _HANDLE
		2:  # shovel: spade at the top
			if x >= 9 and x <= 13 and y >= 1 and y <= 5 and absi(x - 11) + absi(y - 3) <= 3:
				return _edge_shade(head, x, y)
			if on_handle and y >= 5 and y <= 13:
				return _HANDLE
		3:  # sword: long blade, short cross-guard, stubby grip
			if on_handle and y >= 2 and y <= 10:
				return _edge_shade(head, x, y)
			if y == 11 and x >= 2 and x <= 6:
				return _HANDLE.darkened(0.2)  # guard
			if on_handle and y >= 12 and y <= 14:
				return _HANDLE
	return Color(0, 0, 0, 0)


func _armor_pixel(piece: int, color: Color, x: int, y: int) -> Color:
	match piece:
		0:  # helmet: dome + cheek guards
			if y >= 4 and y <= 6 and x >= 4 and x <= 11:
				return _edge_shade(color, x, y)
			if y >= 7 and y <= 10 and (x >= 4 and x <= 5 or x >= 10 and x <= 11):
				return _edge_shade(color, x, y)
		1:  # chestplate: shoulders + torso
			if y >= 3 and y <= 6 and (x >= 3 and x <= 5 or x >= 10 and x <= 12):
				return _edge_shade(color, x, y)
			if y >= 5 and y <= 12 and x >= 5 and x <= 10:
				return _edge_shade(color, x, y)
		2:  # leggings: belt + two legs
			if y >= 3 and y <= 5 and x >= 4 and x <= 11:
				return _edge_shade(color, x, y)
			if y >= 6 and y <= 13 and (x >= 4 and x <= 6 or x >= 9 and x <= 11):
				return _edge_shade(color, x, y)
		3:  # boots: two Ls with soles
			if y >= 6 and y <= 9 and (x >= 3 and x <= 5 or x >= 10 and x <= 12):
				return _edge_shade(color, x, y)
			if y >= 10 and y <= 12 and (x >= 3 and x <= 6 or x >= 9 and x <= 12):
				return _edge_shade(color.darkened(0.2), x, y)
	return Color(0, 0, 0, 0)


func _edge_shade(c: Color, x: int, y: int) -> Color:
	# Cheap top-left light / bottom-right shade so shapes read as 3D.
	if (x + y) % 7 == 0:
		return c.darkened(0.12)
	if x % 5 == 0 or y % 6 == 0:
		return c.lightened(0.12)
	return c


func _hash01(x: int, y: int) -> float:
	var h := x * 374761393 + y * 668265263
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(h & 0xFFFF) / 65535.0


func _build_materials() -> void:
	opaque_material = StandardMaterial3D.new()
	opaque_material.albedo_texture = atlas_texture
	# NEAREST filter = crisp pixel-art look and no mipmap smearing between
	# atlas tiles (pairs with the half-texel UV inset in BlockTypes.uv_rect).
	opaque_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	opaque_material.roughness = 1.0
	opaque_material.metallic_specular = 0.0

	water_material = StandardMaterial3D.new()
	water_material.albedo_texture = atlas_texture
	water_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	water_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_material.albedo_color = Color(1, 1, 1, 0.85)
	water_material.roughness = 0.15
	# Render both sides so the surface is visible from underwater too.
	water_material.cull_mode = BaseMaterial3D.CULL_DISABLED

	# Glass: alpha-scissor cutout — sharp fully-transparent panes with no
	# transparency sorting headaches.
	glass_material = StandardMaterial3D.new()
	glass_material.albedo_texture = atlas_texture
	glass_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	glass_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	glass_material.alpha_scissor_threshold = 0.4
	glass_material.roughness = 0.1


## Minecraft-style progressive crack overlay: one 16x16 alpha texture per
## stage. A single master list of crack strokes is generated once from a
## fixed seed; stage N draws a prefix of it, so cracks strictly ACCUMULATE
## from stage to stage instead of jumping around.
func _build_crack_materials() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 0xC7AC4  # deterministic cracks

	# Master stroke list: random walks starting near the center.
	var strokes: Array[PackedVector2Array] = []
	var total_strokes := 4 + CRACK_STAGES * 2
	for s in total_strokes:
		var walk := PackedVector2Array()
		var pos := Vector2(rng.randi_range(5, 10), rng.randi_range(5, 10))
		for step in rng.randi_range(5, 9):
			walk.push_back(pos)
			pos += Vector2(rng.randi_range(-1, 1), rng.randi_range(-1, 1)) * rng.randi_range(1, 2)
			pos = pos.clamp(Vector2.ZERO, Vector2(15, 15))
		strokes.push_back(walk)

	for stage in CRACK_STAGES:
		var img := Image.create_empty(16, 16, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		var visible_strokes := 4 + stage * 2
		for s in visible_strokes:
			var alpha := 0.5 + float(stage) / CRACK_STAGES * 0.35
			for p: Vector2 in strokes[s]:
				img.set_pixel(int(p.x), int(p.y), Color(0.05, 0.04, 0.04, alpha))

		var mat := StandardMaterial3D.new()
		mat.albedo_texture = ImageTexture.create_from_image(img)
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.render_priority = 1
		crack_materials.append(mat)
