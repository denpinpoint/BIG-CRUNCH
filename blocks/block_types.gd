class_name BlockTypes
## Block ids + registry. Block ids are stored directly in each chunk's
## PackedByteArray, so keep them within 0..255.
##
## Face indices used by the mesher and by tile lookups:
##   0 = +Y (top), 1 = -Y (bottom), 2 = -Z, 3 = +Z, 4 = -X, 5 = +X

enum {
	AIR = 0,
	GRASS = 1,
	DIRT = 2,
	STONE = 3,
	SAND = 4,
	WOOD = 5,
	LEAVES = 6,
	WATER = 7,
	BEDROCK = 8,
}

# Texture atlas layout: ATLAS_TILES x ATLAS_TILES grid of TILE_PIXELS tiles.
const ATLAS_TILES: int = 4
const TILE_PIXELS: int = 16

# Tile indices into the atlas (row-major).
const TILE_GRASS_TOP := 0
const TILE_GRASS_SIDE := 1
const TILE_DIRT := 2
const TILE_STONE := 3
const TILE_SAND := 4
const TILE_WOOD_SIDE := 5
const TILE_WOOD_TOP := 6
const TILE_LEAVES := 7
const TILE_WATER := 8
const TILE_BEDROCK := 9

## Registry: id -> properties.
##   solid:    blocks movement & occludes neighbor faces
##   fluid:    rendered transparent, not collidable, not targetable
##   hardness: seconds-ish scale for survival mining; < 0 = unbreakable
##   tiles:    atlas tile per face group {top, bottom, side}
const DEFS := {
	AIR: {
		"name": "Air", "solid": false, "fluid": false, "hardness": 0.0,
		"tiles": {"top": 0, "bottom": 0, "side": 0},
	},
	GRASS: {
		"name": "Grass", "solid": true, "fluid": false, "hardness": 0.9,
		"tiles": {"top": TILE_GRASS_TOP, "bottom": TILE_DIRT, "side": TILE_GRASS_SIDE},
	},
	DIRT: {
		"name": "Dirt", "solid": true, "fluid": false, "hardness": 0.75,
		"tiles": {"top": TILE_DIRT, "bottom": TILE_DIRT, "side": TILE_DIRT},
	},
	STONE: {
		"name": "Stone", "solid": true, "fluid": false, "hardness": 3.0,
		"tiles": {"top": TILE_STONE, "bottom": TILE_STONE, "side": TILE_STONE},
	},
	SAND: {
		"name": "Sand", "solid": true, "fluid": false, "hardness": 0.75,
		"tiles": {"top": TILE_SAND, "bottom": TILE_SAND, "side": TILE_SAND},
	},
	WOOD: {
		"name": "Wood", "solid": true, "fluid": false, "hardness": 2.0,
		"tiles": {"top": TILE_WOOD_TOP, "bottom": TILE_WOOD_TOP, "side": TILE_WOOD_SIDE},
	},
	LEAVES: {
		"name": "Leaves", "solid": true, "fluid": false, "hardness": 0.3,
		"tiles": {"top": TILE_LEAVES, "bottom": TILE_LEAVES, "side": TILE_LEAVES},
	},
	WATER: {
		"name": "Water", "solid": false, "fluid": true, "hardness": -1.0,
		"tiles": {"top": TILE_WATER, "bottom": TILE_WATER, "side": TILE_WATER},
	},
	BEDROCK: {
		"name": "Bedrock", "solid": true, "fluid": false, "hardness": -1.0,
		"tiles": {"top": TILE_BEDROCK, "bottom": TILE_BEDROCK, "side": TILE_BEDROCK},
	},
}


static func is_solid(id: int) -> bool:
	return DEFS[id]["solid"]


static func is_fluid(id: int) -> bool:
	return DEFS[id]["fluid"]


static func hardness(id: int) -> float:
	return DEFS[id]["hardness"]


static func block_name(id: int) -> String:
	return DEFS[id]["name"]


## Atlas tile for a block face (face index documented at the top).
static func tile_for_face(id: int, face: int) -> int:
	var tiles: Dictionary = DEFS[id]["tiles"]
	match face:
		0:
			return tiles["top"]
		1:
			return tiles["bottom"]
		_:
			return tiles["side"]


## UV rect for an atlas tile, inset by half a texel on every edge so that
## NEAREST sampling can never bleed the neighboring tile in (the classic
## atlas bleeding fix — see chunk_mesher.gd).
static func uv_rect(tile: int) -> Rect2:
	var ts := 1.0 / float(ATLAS_TILES)
	var inset := 0.5 / float(ATLAS_TILES * TILE_PIXELS)
	@warning_ignore("integer_division")
	var row := tile / ATLAS_TILES
	var col := tile % ATLAS_TILES
	return Rect2(
		col * ts + inset, row * ts + inset,
		ts - 2.0 * inset, ts - 2.0 * inset
	)


## Pixel-space region of a tile inside the atlas image (for UI icons).
static func tile_pixel_region(tile: int) -> Rect2:
	@warning_ignore("integer_division")
	var row := tile / ATLAS_TILES
	var col := tile % ATLAS_TILES
	return Rect2(col * TILE_PIXELS, row * TILE_PIXELS, TILE_PIXELS, TILE_PIXELS)
