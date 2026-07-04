extends Node
## Autoloaded as "BlockLibrary".
##
## Owns the block texture atlas, the chunk materials, and the mining crack
## overlay materials. The atlas is a single 128x128 image (8x8 grid of 16px
## tiles) generated procedurally at startup from flat base colors plus
## deterministic hash noise — completely original, no external image files.
## Item icons (stick, ingots, ...) are painted into the same atlas with
## transparent backgrounds. A copy is written to user://atlas_debug.png.
##
## Everything here is built once in _ready() and never mutated afterwards, so
## worker threads may safely read the materials and atlas texture.

const CRACK_STAGES := 10

var atlas_image: Image
var atlas_texture: ImageTexture
var opaque_material: StandardMaterial3D
var water_material: StandardMaterial3D
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
}

const _ORE_SPECK_COLORS := {
	BlockTypes.TILE_COAL_ORE: Color8(38, 38, 38),
	BlockTypes.TILE_IRON_ORE: Color8(216, 168, 124),
	BlockTypes.TILE_GOLD_ORE: Color8(252, 208, 60),
	BlockTypes.TILE_DIAMOND_ORE: Color8(92, 220, 215),
}

# Item icon tiles get a transparent background.
const _ITEM_TILES := [
	BlockTypes.TILE_STICK, BlockTypes.TILE_COAL_ITEM, BlockTypes.TILE_IRON_INGOT,
	BlockTypes.TILE_GOLD_INGOT, BlockTypes.TILE_DIAMOND_ITEM,
]


func _ready() -> void:
	_build_atlas()
	_build_materials()
	_build_crack_materials()


## Icon texture for UI (hotbar/inventory slots), cropped from the atlas.
func get_icon(id: int) -> AtlasTexture:
	var tex := AtlasTexture.new()
	tex.atlas = atlas_texture
	tex.region = BlockTypes.tile_pixel_region(BlockTypes.icon_tile(id))
	return tex


func _build_atlas() -> void:
	var px := BlockTypes.TILE_PIXELS
	var size := BlockTypes.ATLAS_TILES * px
	atlas_image = Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	atlas_image.fill(Color8(255, 0, 255))  # unused tiles scream magenta

	for tile: int in _TILE_COLORS.keys():
		var base: Color = _TILE_COLORS[tile]
		var region := BlockTypes.tile_pixel_region(tile)
		for y in px:
			for x in px:
				var c := _tile_pixel(tile, x, y, base)
				atlas_image.set_pixel(int(region.position.x) + x, int(region.position.y) + y, c)

	atlas_texture = ImageTexture.create_from_image(atlas_image)
	# Debug aid: inspect the generated atlas as a real PNG if you want.
	atlas_image.save_png("user://atlas_debug.png")


## Per-pixel tile shading. Deterministic (hash-based), so the atlas is
## identical on every run and every machine.
func _tile_pixel(tile: int, x: int, y: int, base: Color) -> Color:
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
			if y % 4 == 3:  # horizontal plank gaps
				c = c.darkened(0.35)
			@warning_ignore("integer_division")
			var seam := int(_hash01(y / 4 + 5, tile) * 15.0)
			if x == seam:  # one vertical seam per plank
				c = c.darkened(0.28)
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
		BlockTypes.TILE_STICK:
			return _stick_pixel(x, y, base, n)
		BlockTypes.TILE_COAL_ITEM:
			return _lump_pixel(x, y, base, n)
		BlockTypes.TILE_IRON_INGOT, BlockTypes.TILE_GOLD_INGOT:
			return _ingot_pixel(x, y, base)
		BlockTypes.TILE_DIAMOND_ITEM:
			return _gem_pixel(x, y, base)
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


func _stone_like(x: int, y: int, base: Color) -> Color:
	var n := _hash01(x + 311, y + 977)
	return base.darkened((n - 0.5) * 0.16)


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
