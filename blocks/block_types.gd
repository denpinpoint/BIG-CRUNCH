class_name BlockTypes
## Block AND item ids + registry. Block ids live in chunk PackedByteArrays,
## so they must stay within 0..255; ids >= ITEM_ID_BASE are non-placeable
## items (ingots, tools, armor, food, ...) that only exist in inventories.
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
	WOOL = 19,
	BED = 20,
	CRAFTING_TABLE = 21,
	GLASS = 22,
	# Stairs carry their facing in the id (no per-block metadata exists).
	# Variant order is always N(-Z), E(+X), S(+Z), W(-X).
	PLANK_STAIRS_N = 23,
	PLANK_STAIRS_E = 24,
	PLANK_STAIRS_S = 25,
	PLANK_STAIRS_W = 26,
	COBBLE_STAIRS_N = 27,
	COBBLE_STAIRS_E = 28,
	COBBLE_STAIRS_S = 29,
	COBBLE_STAIRS_W = 30,
}

# Non-block items (inventory only).
const ITEM_ID_BASE := 100
const STICK := 100
const COAL := 101
const IRON_INGOT := 102
const GOLD_INGOT := 103
const DIAMOND := 104
const GLOOM_SHARD := 106  # dropped by Gnashers
const RAW_MUTTON := 107   # dropped by Woolbacks; furnace-cookable
const COOKED_MUTTON := 108

# Tools: id = BASE + tier. Tier order everywhere: wood, stone, iron, gold, diamond.
const TOOL_TIERS := 5
const PICKAXE_BASE := 110
const AXE_BASE := 115
const SHOVEL_BASE := 120
const SWORD_BASE := 125
# Armor: id = BASE + material. Material order: iron, gold, diamond.
const HELMET_BASE := 130
const CHESTPLATE_BASE := 133
const LEGGINGS_BASE := 136
const BOOTS_BASE := 139

const TIER_NAMES := ["Wooden", "Stone", "Iron", "Golden", "Diamond"]
const TOOL_SPEEDS := [2.0, 4.0, 6.0, 8.0, 12.0]      # mining multiplier per tier
const SWORD_DAMAGE := [4.0, 5.0, 6.0, 7.0, 8.0]
const ARMOR_MATERIAL_NAMES := ["Iron", "Golden", "Diamond"]
# Defense points per piece x material (helmet/chest/legs/boots rows).
const ARMOR_DEFENSE := [
	[2, 2, 3],
	[6, 5, 8],
	[5, 3, 6],
	[2, 1, 3],
]
const ARMOR_PIECE_NAMES := ["Helmet", "Chestplate", "Leggings", "Boots"]

# Texture atlas layout: ATLAS_TILES x ATLAS_TILES grid of TILE_PIXELS tiles.
const ATLAS_TILES: int = 16
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
const TILE_GLOOM_SHARD := 27
const TILE_WOOL := 28
const TILE_BED_TOP := 29
const TILE_BED_SIDE := 30
const TILE_CRAFTING_TOP := 31
const TILE_CRAFTING_SIDE := 32
const TILE_GLASS := 33
const TILE_STAIR_PLANK := 34   # icon only; faces reuse the material tile
const TILE_STAIR_COBBLE := 35  # icon only
const TILE_MUTTON_RAW := 36
const TILE_MUTTON_COOKED := 37
const TILE_TOOL_BASE := 40   # + tool_type * 5 + tier (pick/axe/shovel/sword rows)
const TILE_ARMOR_BASE := 60  # + piece * 3 + material

const STAIR_DIRS := [Vector3i(0, 0, -1), Vector3i(1, 0, 0), Vector3i(0, 0, 1), Vector3i(-1, 0, 0)]

## Registry: id -> properties. Built once at class load (static var so the
## tool/armor/stair families can be generated in loops).
##   block:    true = placeable world block
##   solid:    blocks movement, physics and targeting
##   occludes: hides neighboring faces (false for glass/stairs -> they render)
##   fluid:    transparent, non-collidable, non-targetable
##   hardness: mining time scale in Survival; < 0 = unbreakable
##   tool:     which tool class mines this block fast ("pickaxe"/"axe"/"shovel")
##   tiles:    atlas tile per face group {top, bottom, side} (blocks only)
##   drop:     id given when mined in Survival (AIR = nothing; default self)
##   icon:     atlas tile for inventory icons (items; blocks use side tile)
##   stack:    max stack size (default Constants.STACK_MAX; tools/armor = 1)
##   food:     hunger restored when eaten
##   stair_dir/stair_base: stair geometry + family info
##   tool_type/tier/speed/damage: tool stats
##   armor_slot/defense: armor stats (slot 0=helmet..3=boots)
static var DEFS: Dictionary = _build_defs()
static var CREATIVE_CATEGORIES: Array = _build_categories()


static func _build_defs() -> Dictionary:
	var d := {
		AIR: {
			"name": "Air", "block": false, "solid": false, "fluid": false, "hardness": 0.0,
			"tiles": {"top": 0, "bottom": 0, "side": 0},
		},
		GRASS: {
			"name": "Grass", "block": true, "solid": true, "fluid": false, "hardness": 0.9,
			"tiles": {"top": TILE_GRASS_TOP, "bottom": TILE_DIRT, "side": TILE_GRASS_SIDE},
			"drop": DIRT, "tool": "shovel",
		},
		DIRT: {
			"name": "Dirt", "block": true, "solid": true, "fluid": false, "hardness": 0.75,
			"tiles": {"top": TILE_DIRT, "bottom": TILE_DIRT, "side": TILE_DIRT},
			"tool": "shovel",
		},
		STONE: {
			"name": "Stone", "block": true, "solid": true, "fluid": false, "hardness": 3.0,
			"tiles": {"top": TILE_STONE, "bottom": TILE_STONE, "side": TILE_STONE},
			"drop": COBBLESTONE, "tool": "pickaxe",
		},
		SAND: {
			"name": "Sand", "block": true, "solid": true, "fluid": false, "hardness": 0.75,
			"tiles": {"top": TILE_SAND, "bottom": TILE_SAND, "side": TILE_SAND},
			"tool": "shovel",
		},
		WOOD: {
			"name": "Wood Log", "block": true, "solid": true, "fluid": false, "hardness": 2.0,
			"tiles": {"top": TILE_WOOD_TOP, "bottom": TILE_WOOD_TOP, "side": TILE_WOOD_SIDE},
			"tool": "axe",
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
			"tool": "pickaxe",
		},
		PLANKS: {
			"name": "Planks", "block": true, "solid": true, "fluid": false, "hardness": 1.4,
			"tiles": {"top": TILE_PLANKS, "bottom": TILE_PLANKS, "side": TILE_PLANKS},
			"tool": "axe",
		},
		COAL_ORE: {
			"name": "Coal Ore", "block": true, "solid": true, "fluid": false, "hardness": 3.2,
			"tiles": {"top": TILE_COAL_ORE, "bottom": TILE_COAL_ORE, "side": TILE_COAL_ORE},
			"drop": COAL, "tool": "pickaxe",
		},
		IRON_ORE: {
			"name": "Iron Ore", "block": true, "solid": true, "fluid": false, "hardness": 3.5,
			"tiles": {"top": TILE_IRON_ORE, "bottom": TILE_IRON_ORE, "side": TILE_IRON_ORE},
			"tool": "pickaxe",
		},
		GOLD_ORE: {
			"name": "Gold Ore", "block": true, "solid": true, "fluid": false, "hardness": 3.5,
			"tiles": {"top": TILE_GOLD_ORE, "bottom": TILE_GOLD_ORE, "side": TILE_GOLD_ORE},
			"tool": "pickaxe",
		},
		DIAMOND_ORE: {
			"name": "Diamond Ore", "block": true, "solid": true, "fluid": false, "hardness": 4.0,
			"tiles": {"top": TILE_DIAMOND_ORE, "bottom": TILE_DIAMOND_ORE, "side": TILE_DIAMOND_ORE},
			"drop": DIAMOND, "tool": "pickaxe",
		},
		FURNACE: {
			"name": "Furnace", "block": true, "solid": true, "fluid": false, "hardness": 3.5,
			"tiles": {"top": TILE_FURNACE_TOP, "bottom": TILE_FURNACE_TOP, "side": TILE_FURNACE_FRONT},
			"tool": "pickaxe",
		},
		IRON_BLOCK: {
			"name": "Iron Block", "block": true, "solid": true, "fluid": false, "hardness": 4.0,
			"tiles": {"top": TILE_IRON_BLOCK, "bottom": TILE_IRON_BLOCK, "side": TILE_IRON_BLOCK},
			"tool": "pickaxe",
		},
		GOLD_BLOCK: {
			"name": "Gold Block", "block": true, "solid": true, "fluid": false, "hardness": 4.0,
			"tiles": {"top": TILE_GOLD_BLOCK, "bottom": TILE_GOLD_BLOCK, "side": TILE_GOLD_BLOCK},
			"tool": "pickaxe",
		},
		DIAMOND_BLOCK: {
			"name": "Diamond Block", "block": true, "solid": true, "fluid": false, "hardness": 4.5,
			"tiles": {"top": TILE_DIAMOND_BLOCK, "bottom": TILE_DIAMOND_BLOCK, "side": TILE_DIAMOND_BLOCK},
			"tool": "pickaxe",
		},
		WOOL: {
			"name": "Wool", "block": true, "solid": true, "fluid": false, "hardness": 0.7,
			"tiles": {"top": TILE_WOOL, "bottom": TILE_WOOL, "side": TILE_WOOL},
		},
		BED: {
			"name": "Bed", "block": true, "solid": true, "fluid": false, "hardness": 0.8,
			"tiles": {"top": TILE_BED_TOP, "bottom": TILE_PLANKS, "side": TILE_BED_SIDE},
			"tool": "axe",
			# TODO: half-height mesh + two-block footprint like the original.
		},
		CRAFTING_TABLE: {
			"name": "Crafting Table", "block": true, "solid": true, "fluid": false, "hardness": 1.6,
			"tiles": {"top": TILE_CRAFTING_TOP, "bottom": TILE_PLANKS, "side": TILE_CRAFTING_SIDE},
			"tool": "axe",
		},
		GLASS: {
			"name": "Glass", "block": true, "solid": true, "occludes": false, "fluid": false,
			"hardness": 0.4,
			"tiles": {"top": TILE_GLASS, "bottom": TILE_GLASS, "side": TILE_GLASS},
			# Deviation from the classic: glass drops itself (friendlier).
		},
		STICK: {"name": "Stick", "block": false, "solid": false, "fluid": false, "hardness": 0.0, "icon": TILE_STICK},
		COAL: {"name": "Coal", "block": false, "solid": false, "fluid": false, "hardness": 0.0, "icon": TILE_COAL_ITEM},
		IRON_INGOT: {"name": "Iron Ingot", "block": false, "solid": false, "fluid": false, "hardness": 0.0, "icon": TILE_IRON_INGOT},
		GOLD_INGOT: {"name": "Gold Ingot", "block": false, "solid": false, "fluid": false, "hardness": 0.0, "icon": TILE_GOLD_INGOT},
		DIAMOND: {"name": "Diamond", "block": false, "solid": false, "fluid": false, "hardness": 0.0, "icon": TILE_DIAMOND_ITEM},
		GLOOM_SHARD: {"name": "Gloom Shard", "block": false, "solid": false, "fluid": false, "hardness": 0.0, "icon": TILE_GLOOM_SHARD},
		RAW_MUTTON: {
			"name": "Raw Mutton", "block": false, "solid": false, "fluid": false, "hardness": 0.0,
			"icon": TILE_MUTTON_RAW, "food": 2.0,
		},
		COOKED_MUTTON: {
			"name": "Cooked Mutton", "block": false, "solid": false, "fluid": false, "hardness": 0.0,
			"icon": TILE_MUTTON_COOKED, "food": 6.0,
		},
	}

	# Stairs: 4 facing variants per material, ids consecutive N/E/S/W.
	var stair_specs := [
		{"base": PLANK_STAIRS_N, "name": "Plank Stairs", "tile": TILE_PLANKS, "hardness": 1.4, "tool": "axe", "icon": TILE_STAIR_PLANK},
		{"base": COBBLE_STAIRS_N, "name": "Cobblestone Stairs", "tile": TILE_COBBLE, "hardness": 3.0, "tool": "pickaxe", "icon": TILE_STAIR_COBBLE},
	]
	for spec: Dictionary in stair_specs:
		for i in 4:
			d[spec["base"] + i] = {
				"name": spec["name"], "block": true, "solid": true, "occludes": false,
				"fluid": false, "hardness": spec["hardness"], "tool": spec["tool"],
				"tiles": {"top": spec["tile"], "bottom": spec["tile"], "side": spec["tile"]},
				"icon": spec["icon"],
				"drop": spec["base"],  # any orientation mines into the N variant
				"stair_base": spec["base"],
				"stair_dir": STAIR_DIRS[i],  # horizontal direction of the HIGH half
			}

	# Tools: 4 classes x 5 tiers. No durability yet (TODO), so they don't stack.
	var tool_bases := {"pickaxe": PICKAXE_BASE, "axe": AXE_BASE, "shovel": SHOVEL_BASE, "sword": SWORD_BASE}
	for tool_type: String in tool_bases.keys():
		for tier in TOOL_TIERS:
			var entry := {
				"name": "%s %s" % [TIER_NAMES[tier], tool_type.capitalize()],
				"block": false, "solid": false, "fluid": false, "hardness": 0.0,
				"icon": _tool_tile(tool_type, tier),
				"tool_type": tool_type, "tier": tier, "stack": 1,
			}
			if tool_type == "sword":
				entry["damage"] = SWORD_DAMAGE[tier]
			else:
				entry["speed"] = TOOL_SPEEDS[tier]
			d[tool_bases[tool_type] + tier] = entry

	# Armor: 4 pieces x 3 materials, flat defense points (no durability, TODO).
	var piece_bases := [HELMET_BASE, CHESTPLATE_BASE, LEGGINGS_BASE, BOOTS_BASE]
	for piece in 4:
		for mat in 3:
			d[piece_bases[piece] + mat] = {
				"name": "%s %s" % [ARMOR_MATERIAL_NAMES[mat], ARMOR_PIECE_NAMES[piece]],
				"block": false, "solid": false, "fluid": false, "hardness": 0.0,
				"icon": TILE_ARMOR_BASE + piece * 3 + mat,
				"armor_slot": piece, "defense": ARMOR_DEFENSE[piece][mat], "stack": 1,
			}
	return d


static func _tool_tile(tool_type: String, tier: int) -> int:
	# Explicit int: indexing a Dictionary yields Variant, which Godot 4.4+
	# refuses to infer with ":=".
	var row: int = {"pickaxe": 0, "axe": 1, "shovel": 2, "sword": 3}[tool_type]
	return TILE_TOOL_BASE + row * 5 + tier


static func _build_categories() -> Array:
	var tools: Array = []
	for base: int in [PICKAXE_BASE, AXE_BASE, SHOVEL_BASE, SWORD_BASE]:
		for tier in TOOL_TIERS:
			tools.append(base + tier)
	for base: int in [HELMET_BASE, CHESTPLATE_BASE, LEGGINGS_BASE, BOOTS_BASE]:
		for mat in 3:
			tools.append(base + mat)
	return [
		{
			"name": "Blocks",
			"items": [
				GRASS, DIRT, STONE, COBBLESTONE, SAND, PLANKS, WOOD, LEAVES,
				WOOL, GLASS, CRAFTING_TABLE, FURNACE, BED,
				PLANK_STAIRS_N, COBBLE_STAIRS_N, BEDROCK, WATER,
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
			"items": [STICK, COAL, IRON_INGOT, GOLD_INGOT, DIAMOND, GLOOM_SHARD, RAW_MUTTON, COOKED_MUTTON],
		},
		{"name": "Gear", "items": tools},
	]


static func is_block(id: int) -> bool:
	return DEFS[id]["block"]


static func is_solid(id: int) -> bool:
	return DEFS[id]["solid"]


## Does this block hide the faces of its neighbors? (Glass/stairs don't.)
static func occludes(id: int) -> bool:
	var def: Dictionary = DEFS[id]
	return def.get("occludes", def["solid"])


static func is_fluid(id: int) -> bool:
	return DEFS[id]["fluid"]


static func is_stairs(id: int) -> bool:
	return DEFS[id].has("stair_dir")


static func hardness(id: int) -> float:
	return DEFS[id]["hardness"]


static func block_name(id: int) -> String:
	return DEFS[id]["name"]


static func stack_max(id: int) -> int:
	return DEFS[id].get("stack", Constants.STACK_MAX)


static func food_value(id: int) -> float:
	return DEFS[id].get("food", 0.0)


static func armor_slot_of(id: int) -> int:
	return DEFS[id].get("armor_slot", -1)


static func armor_defense(id: int) -> int:
	return DEFS[id].get("defense", 0)


## Mining speed multiplier the held item grants against this block.
static func tool_speed(held_id: int, block_id: int) -> float:
	var held: Dictionary = DEFS.get(held_id, {})
	if not held.has("tool_type") or not held.has("speed"):
		return 1.0
	if DEFS[block_id].get("tool", "") == held["tool_type"]:
		return held["speed"]
	return 1.0


## Melee damage of the held item (fists otherwise).
static func attack_damage(held_id: int) -> float:
	return DEFS.get(held_id, {}).get("damage", Constants.PLAYER_ATTACK_DAMAGE)


## Pick the stair variant whose HIGH side points along `forward` (the player's
## look direction when placing — so stairs ascend away from you).
static func stair_variant(any_stair_id: int, forward: Vector3) -> int:
	var base: int = DEFS[any_stair_id]["stair_base"]
	if absf(forward.x) > absf(forward.z):
		return base + (1 if forward.x > 0.0 else 3)  # E / W
	return base + (2 if forward.z > 0.0 else 0)      # S / N


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


## Resource-pack contract: atlas tile index -> canonical PNG filename (no
## extension). A resource pack is a folder of 16x16 PNGs named like these;
## any present file overrides that tile (see block_library._apply_resource_pack).
static func tile_names() -> Dictionary:
	var m := {
		TILE_GRASS_TOP: "grass_top", TILE_GRASS_SIDE: "grass_side", TILE_DIRT: "dirt",
		TILE_STONE: "stone", TILE_SAND: "sand", TILE_WOOD_SIDE: "log_side",
		TILE_WOOD_TOP: "log_top", TILE_LEAVES: "leaves", TILE_WATER: "water",
		TILE_BEDROCK: "bedrock", TILE_COBBLE: "cobblestone", TILE_PLANKS: "planks",
		TILE_COAL_ORE: "coal_ore", TILE_IRON_ORE: "iron_ore", TILE_GOLD_ORE: "gold_ore",
		TILE_DIAMOND_ORE: "diamond_ore", TILE_FURNACE_FRONT: "furnace_front",
		TILE_FURNACE_TOP: "furnace_top", TILE_IRON_BLOCK: "iron_block",
		TILE_GOLD_BLOCK: "gold_block", TILE_DIAMOND_BLOCK: "diamond_block",
		TILE_STICK: "stick", TILE_COAL_ITEM: "coal", TILE_IRON_INGOT: "iron_ingot",
		TILE_GOLD_INGOT: "gold_ingot", TILE_DIAMOND_ITEM: "diamond",
		TILE_GLOOM_SHARD: "gloom_shard", TILE_WOOL: "wool", TILE_BED_TOP: "bed_top",
		TILE_BED_SIDE: "bed_side", TILE_CRAFTING_TOP: "crafting_table_top",
		TILE_CRAFTING_SIDE: "crafting_table_side", TILE_GLASS: "glass",
		TILE_STAIR_PLANK: "plank_stairs_icon", TILE_STAIR_COBBLE: "cobblestone_stairs_icon",
		TILE_MUTTON_RAW: "mutton_raw", TILE_MUTTON_COOKED: "mutton_cooked",
	}
	var classes := ["pickaxe", "axe", "shovel", "sword"]
	for row in classes.size():
		for tier in TOOL_TIERS:
			m[TILE_TOOL_BASE + row * 5 + tier] = "%s_%s" % [TIER_NAMES[tier].to_lower(), classes[row]]
	var pieces := ["helmet", "chestplate", "leggings", "boots"]
	for piece in pieces.size():
		for mat in ARMOR_MATERIAL_NAMES.size():
			m[TILE_ARMOR_BASE + piece * 3 + mat] = "%s_%s" % [ARMOR_MATERIAL_NAMES[mat].to_lower(), pieces[piece]]
	return m
