extends Node
## Autoloaded as "BlockLibrary".
##
## Owns the block texture atlas and the chunk materials. The atlas is a single
## 64x64 image (4x4 grid of 16px tiles) generated procedurally at startup from
## flat base colors plus deterministic per-pixel noise — completely original,
## no external image files needed. This deviates from the spec's committed
## atlas.png on purpose: a generated atlas keeps the repo free of binary
## assets and sidesteps texture import settings entirely. If you want a real
## PNG, this node writes one to user://atlas_debug.png you can inspect.
##
## Everything here is built once in _ready() and never mutated afterwards, so
## worker threads may safely read the materials and atlas texture.

var atlas_image: Image
var atlas_texture: ImageTexture
var opaque_material: StandardMaterial3D
var water_material: StandardMaterial3D

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
}


func _ready() -> void:
	_build_atlas()
	_build_materials()


## Icon texture for UI (hotbar slots): the side tile of a block, cropped
## straight out of the atlas.
func get_block_icon(block_id: int) -> AtlasTexture:
	var tex := AtlasTexture.new()
	tex.atlas = atlas_texture
	tex.region = BlockTypes.tile_pixel_region(BlockTypes.tile_for_face(block_id, 2))
	return tex


func _build_atlas() -> void:
	var px := BlockTypes.TILE_PIXELS
	var size := BlockTypes.ATLAS_TILES * px
	atlas_image = Image.create(size, size, false, Image.FORMAT_RGBA8)
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
			# vertical bark striping
			if x % 4 == 0:
				c = c.darkened(0.22)
		BlockTypes.TILE_WOOD_TOP:
			# concentric growth rings
			var d := maxi(absi(x - 8), absi(y - 8))
			if d % 3 == 0:
				c = c.darkened(0.25)
		BlockTypes.TILE_BEDROCK:
			# chunky high-contrast noise
			if n > 0.5:
				c = c.darkened(0.35)
		BlockTypes.TILE_LEAVES:
			if n > 0.72:
				c = c.darkened(0.3)
	# Subtle noise on everything so flat colors read as texture.
	c = c.darkened((n - 0.5) * 0.16)
	if tile == BlockTypes.TILE_WATER:
		c.a = 0.78
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
