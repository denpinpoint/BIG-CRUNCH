class_name BlockTypes
## Block AND item ids + registry. Block ids live in chunk PackedByteArrays,
## so they must stay within 0..255; ids >= ITEM_ID_BASE are non-placeable
## items (ingots, sticks, ...) that only exist in inventories.
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
	COBBLESTONE = 9,
	PLANKS = 10,
	COAL_ORE = 11,
	IRON_ORE = 12,
	GOLD_ORE = 13,
	DIAMOND_ORE = 14,
	FURNACE = 15,
	IRON_BLOCK = 16,
	GOLD_BLOCK = 17,
	DIAMOND_BLOCK = 18,
}

# Non-block items (inventory only).
const ITEM_ID_BASE := 100
const STICK := 100
const COAL := 101
const IRON_INGOT := 102
const GOLD_INGOT := 103
const DIAMOND := 104

# Texture atlas layout: ATLAS_TILES x ATLAS_TILES grid of TILE_PIXELS tiles.
const ATLAS_TILES: int = 8
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
const TILE_COBBLE := 10
const TILE_PLANKS := 11
const TILE_COAL_ORE := 12
const TILE_IRON_ORE := 13
const TILE_GOLD_ORE := 14
const TILE_DIAMOND_ORE := 15
const TILE_FURNACE_FRONT := 16
const TILE_FURNACE_TOP := 17
const TILE_IRON_BLOCK := 18
const TILE_GOLD_BLOCK := 19
const TILE_DIAMOND_BLOCK := 20
const TILE_STICK := 21
const TILE_COAL_ITEM := 22
const TILE_IRON_INGOT := 23
const TILE_GOLD_INGOT := 24
const TILE_DIAMOND_ITEM := 25

## Registry: id -> properties.
##   block:    true = placeable world block; false = inventory-only item
##   solid:    blocks movement & occludes neighbor faces
##   fluid:    rendered transparent, not collidable, not targetable
##   hardness: mining time scale in Survival; < 0 = unbreakable
##   tiles:    atlas tile per face group {top, bottom, side} (blocks only)
##   drop:     item/block id given when mined in Survival (defaults to self,
##             AIR = drops nothing)
##   icon:     atlas tile for the inventory icon (items; blocks use side tile)
const DEFS := {
	AIR: {
		"name": "Air", "block": false, "solid": false, "fluid": false, "hardness": 0.0,
		"tiles": {"top": 0, "bottom": 0, "side": 0},
	},
	GRASS: {
		"name": "Grass", "block": true, "solid": true, "fluid": false, "hardness": 0.9,
		"tiles": {"top": TILE_GRASS_TOP, "bottom": TILE_DIRT, "side": TILE_GRASS_SIDE},
		"drop": DIRT,
	},
	DIRT: {
		"name": "Dirt", "block": true, "solid": true, "fluid": false, "hardness": 0.75,
		"tiles": {"top": TILE_DIRT, "bottom": TILE_DIRT, "side": TILE_DIRT},
	},
	STONE: {
		"name": "Stone", "block": true, "solid": true, "fluid": false, "hardness": 3.0,
		"tiles": {"top": TILE_STONE, "bottom": TILE_STONE, "side": TILE_STONE},
		"drop": COBBLESTONE,
	},
	SAND: {
		"name": "Sand", "block": true, "solid": true, "fluid": false, "hardness": 0.75,
		"tiles": {"top": TILE_SAND, "bottom": TILE_SAND, "side": TILE_SAND},
	},
	WOOD: {
		"name": "Wood Log", "block": true, "solid": true, "fluid": false, "hardness": 2.0,
		"tiles": {"top": TILE_WOOD_TOP, "bottom": TILE_WOOD_TOP, "side": TILE_WOOD_SIDE},
	},
	LEAVES: {
		"name": "Leaves", "block": true, "solid": true, "fluid": false, "hardness": 0.3,
		"tiles": {"top": TILE_LEAVES, "bottom": TILE_LEAVES, "side": TILE_LEAVES},
		"drop": AIR,
	},
	WATER: {
		"name": "Water", "block": true, "solid": false, "fluid": true, "hardness": -1.0,
		"tiles": {"top": TILE_WATER, "bottom": TILE_WATER, "side": TILE_WATER},
	},
	BEDROCK: {
		"name": "Bedrock", "block": true, "solid": true, "fluid": false, "hardness": -1.0,
		"tiles": {"top": TILE_BEDROCK, "bottom": TILE_BEDROCK, "side": TILE_BEDROCK},
	},
	COBBLESTONE: {
		"name": "Cobblestone", "block": true, "solid": true, "fluid": false, "hardness": 3.0,
		"tiles": {"top": TILE_COBBLE, "bottom": TILE_COBBLE, "side": TILE_COBBLE},
	},
	PLANKS: {
		"name": "Planks", "block": true, "solid": true, "fluid": false, "hardness": 1.4,
		"tiles": {"top": TILE_PLANKS, "bottom": TILE_PLANKS, "side": TILE_PLANKS},
	},
	COAL_ORE: {
		"name": "Coal Ore", "block": true, "solid": true, "fluid": false, "hardness": 3.2,
		"tiles": {"top": TILE_COAL_ORE, "bottom": TILE_COAL_ORE, "side": TILE_COAL_ORE},
		"drop": COAL,
	},
	IRON_ORE: {
		"name": "Iron Ore", "block": true, "solid": true, "fluid": false, "hardness": 3.5,
		"tiles": {"top": TILE_IRON_ORE, "bottom": TILE_IRON_ORE, "side": TILE_IRON_ORE},
	},
	GOLD_ORE: {
		"name": "Gold Ore", "block": true, "solid": true, "fluid": false, "hardness": 3.5,
		"tiles": {"top": TILE_GOLD_ORE, "bottom": TILE_GOLD_ORE, "side": TILE_GOLD_ORE},
	},
	DIAMOND_ORE: {
		"name": "Diamond Ore", "block": true, "solid": true, "fluid": false, "hardness": 4.0,
		"tiles": {"top": TILE_DIAMOND_ORE, "bottom": TILE_DIAMOND_ORE, "side": TILE_DIAMOND_ORE},
		"drop": DIAMOND,
	},
	FURNACE: {
		"name": "Furnace", "block": true, "solid": true, "fluid": false, "hardness": 3.5,
		"tiles": {"top": TILE_FURNACE_TOP, "bottom": TILE_FURNACE_TOP, "side": TILE_FURNACE_FRONT},
	},
	IRON_BLOCK: {
		"name": "Iron Block", "block": true, "solid": true, "fluid": false, "hardness": 4.0,
		"tiles": {"top": TILE_IRON_BLOCK, "bottom": TILE_IRON_BLOCK, "side": TILE_IRON_BLOCK},
	},
	GOLD_BLOCK: {
		"name": "Gold Block", "block": true, "solid": true, "fluid": false, "hardness": 4.0,
		"tiles": {"top": TILE_GOLD_BLOCK, "bottom": TILE_GOLD_BLOCK, "side": TILE_GOLD_BLOCK},
	},
	DIAMOND_BLOCK: {
		"name": "Diamond Block", "block": true, "solid": true, "fluid": false, "hardness": 4.5,
		"tiles": {"top": TILE_DIAMOND_BLOCK, "bottom": TILE_DIAMOND_BLOCK, "side": TILE_DIAMOND_BLOCK},
	},
	STICK: {
		"name": "Stick", "block": false, "solid": false, "fluid": false, "hardness": 0.0,
		"icon": TILE_STICK,
	},
	COAL: {
		"name": "Coal", "block": false, "solid": false, "fluid": false, "hardness": 0.0,
		"icon": TILE_COAL_ITEM,
	},
	IRON_INGOT: {
		"name": "Iron Ingot", "block": false, "solid": false, "fluid": false, "hardness": 0.0,
		"icon": TILE_IRON_INGOT,
	},
	GOLD_INGOT: {
		"name": "Gold Ingot", "block": false, "solid": false, "fluid": false, "hardness": 0.0,
		"icon": TILE_GOLD_INGOT,
	},
	DIAMOND: {
		"name": "Diamond", "block": false, "solid": false, "fluid": false, "hardness": 0.0,
		"icon": TILE_DIAMOND_ITEM,
	},
}

## Creative inventory tabs: category name -> ordered item list.
const CREATIVE_CATEGORIES := [
	{
		"name": "Blocks",
		"items": [
			GRASS, DIRT, STONE, COBBLESTONE, SAND, PLANKS, WOOD, LEAVES,
			FURNACE, BEDROCK, WATER,
		],
	},
	{
		"name": "Minerals",
		"items": [
			COAL_ORE, IRON_ORE, GOLD_ORE, DIAMOND_ORE,
			IRON_BLOCK, GOLD_BLOCK, DIAMOND_BLOCK,
		],
	},
	{
		"name": "Items",
		"items": [STICK, COAL, IRON_INGOT, GOLD_INGOT, DIAMOND],
	},
]


static func is_block(id: int) -> bool:
	return DEFS[id]["block"]


static func is_solid(id: int) -> bool:
	return DEFS[id]["solid"]


static func is_fluid(id: int) -> bool:
	return DEFS[id]["fluid"]


static func hardness(id: int) -> float:
	return DEFS[id]["hardness"]


static func block_name(id: int) -> String:
	return DEFS[id]["name"]


## What mining this block yields in Survival (AIR = nothing).
static func drop_for(id: int) -> int:
	return DEFS[id].get("drop", id)


## Atlas tile used for the inventory/hotbar icon.
static func icon_tile(id: int) -> int:
	var def: Dictionary = DEFS[id]
	if def.has("icon"):
		return def["icon"]
	return tile_for_face(id, 2)


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
