class_name Recipes
## Crafting (shaped + shapeless) + smelting + fuel data.
##
## Shaped recipes have a "shape": rows of ids (0 = must be empty). A recipe
## matches when the bounding box of the filled crafting cells has the same
## dimensions and contents (position within the grid doesn't matter, shape
## does). Recipes bigger than 2x2 are therefore only craftable on a Crafting
## Table's 3x3 grid — automatically. "mirror": true also accepts the
## horizontally flipped shape (axes look the same both ways).
## Shapeless recipes have "ingredients": an unordered id list.
## Crafting always consumes ONE item from every occupied cell.

static var CRAFTING: Array = _build_recipes()

## Furnace: input id -> output id.
const SMELTING := {
	BlockTypes.IRON_ORE: BlockTypes.IRON_INGOT,
	BlockTypes.GOLD_ORE: BlockTypes.GOLD_INGOT,
	BlockTypes.COBBLESTONE: BlockTypes.STONE,
	BlockTypes.WOOD: BlockTypes.COAL,  # charcoal, close enough
	BlockTypes.SAND: BlockTypes.GLASS,
	BlockTypes.RAW_MUTTON: BlockTypes.COOKED_MUTTON,
}

## Fuel values: 1.0 = one smelt's worth of burn time.
const FUEL := {
	BlockTypes.COAL: 8.0,
	BlockTypes.WOOD: 1.0,
	BlockTypes.PLANKS: 1.0,
	BlockTypes.STICK: 0.5,
	BlockTypes.CRAFTING_TABLE: 1.5,
}


static func _build_recipes() -> Array:
	var p := BlockTypes.PLANKS
	var c := BlockTypes.COBBLESTONE
	var w := BlockTypes.WOOL
	var s := BlockTypes.STICK
	var recipes: Array = [
		# Basics (fit the inventory's 2x2 grid).
		{"ingredients": [BlockTypes.WOOD], "out": p, "count": 4},
		{"shape": [[p], [p]], "out": s, "count": 4},
		{"shape": [[p, p], [p, p]], "out": BlockTypes.CRAFTING_TABLE, "count": 1},
		# Crafting Table territory (3x3 shapes).
		{"shape": [[c, c, c], [c, 0, c], [c, c, c]], "out": BlockTypes.FURNACE, "count": 1},
		{"shape": [[w, w, w], [p, p, p]], "out": BlockTypes.BED, "count": 1},
		# Stairs: 6 material -> 4 stairs.
		{"shape": [[p, 0, 0], [p, p, 0], [p, p, p]], "out": BlockTypes.PLANK_STAIRS_N, "count": 4, "mirror": true},
		{"shape": [[c, 0, 0], [c, c, 0], [c, c, c]], "out": BlockTypes.COBBLE_STAIRS_N, "count": 4, "mirror": true},
	]

	# Mineral storage blocks: 3x3 of the mineral <-> unpack.
	var minerals := [
		[BlockTypes.IRON_INGOT, BlockTypes.IRON_BLOCK],
		[BlockTypes.GOLD_INGOT, BlockTypes.GOLD_BLOCK],
		[BlockTypes.DIAMOND, BlockTypes.DIAMOND_BLOCK],
	]
	for pair: Array in minerals:
		var m: int = pair[0]
		recipes.append({"shape": [[m, m, m], [m, m, m], [m, m, m]], "out": pair[1], "count": 1})
		recipes.append({"ingredients": [pair[1]], "out": m, "count": 9})

	# Tools per tier. Head material: planks, cobble, iron, gold, diamond.
	var mats := [p, c, BlockTypes.IRON_INGOT, BlockTypes.GOLD_INGOT, BlockTypes.DIAMOND]
	for tier in BlockTypes.TOOL_TIERS:
		var m: int = mats[tier]
		recipes.append({"shape": [[m, m, m], [0, s, 0], [0, s, 0]], "out": BlockTypes.PICKAXE_BASE + tier, "count": 1})
		recipes.append({"shape": [[m, m], [m, s], [0, s]], "out": BlockTypes.AXE_BASE + tier, "count": 1, "mirror": true})
		recipes.append({"shape": [[m], [s], [s]], "out": BlockTypes.SHOVEL_BASE + tier, "count": 1})
		recipes.append({"shape": [[m], [m], [s]], "out": BlockTypes.SWORD_BASE + tier, "count": 1})

	# Armor per material: iron, gold, diamond.
	var armor_mats := [BlockTypes.IRON_INGOT, BlockTypes.GOLD_INGOT, BlockTypes.DIAMOND]
	for mat in 3:
		var m: int = armor_mats[mat]
		recipes.append({"shape": [[m, m, m], [m, 0, m]], "out": BlockTypes.HELMET_BASE + mat, "count": 1})
		recipes.append({"shape": [[m, 0, m], [m, m, m], [m, m, m]], "out": BlockTypes.CHESTPLATE_BASE + mat, "count": 1})
		recipes.append({"shape": [[m, m, m], [m, 0, m], [m, 0, m]], "out": BlockTypes.LEGGINGS_BASE + mat, "count": 1})
		recipes.append({"shape": [[m, 0, m], [m, 0, m]], "out": BlockTypes.BOOTS_BASE + mat, "count": 1})
	return recipes


## cells = the crafting grid, row-major, 0 for empty; width = 2 or 3.
## Returns {"out": id, "count": n} or {} when nothing matches.
static func match_grid(cells: Array[int], width: int) -> Dictionary:
	@warning_ignore("integer_division")
	var height := cells.size() / width

	# Bounding box of the filled cells.
	var min_x := width
	var max_x := -1
	var min_y := height
	var max_y := -1
	for y in height:
		for x in width:
			if cells[y * width + x] != 0:
				min_x = mini(min_x, x)
				max_x = maxi(max_x, x)
				min_y = mini(min_y, y)
				max_y = maxi(max_y, y)
	if max_x < 0:
		return {}
	var w := max_x - min_x + 1
	var h := max_y - min_y + 1

	# Extract the trimmed sub-grid + the unordered item list.
	var sub: Array[int] = []
	var items: Array[int] = []
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var id := cells[y * width + x]
			sub.append(id)
			if id != 0:
				items.append(id)
	items.sort()

	for recipe: Dictionary in CRAFTING:
		if recipe.has("shape"):
			var shape: Array = recipe["shape"]
			var rh: int = shape.size()
			var rw: int = shape[0].size()
			if rw != w or rh != h:
				continue
			if _shape_matches(sub, shape, false):
				return {"out": recipe["out"], "count": recipe["count"]}
			if recipe.get("mirror", false) and _shape_matches(sub, shape, true):
				return {"out": recipe["out"], "count": recipe["count"]}
		else:
			var need: Array = recipe["ingredients"].duplicate()
			need.sort()
			if need == items:
				return {"out": recipe["out"], "count": recipe["count"]}
	return {}


static func _shape_matches(sub: Array[int], shape: Array, mirrored: bool) -> bool:
	var rh: int = shape.size()
	var rw: int = shape[0].size()
	for y in rh:
		for x in rw:
			var want: int = shape[y][rw - 1 - x] if mirrored else shape[y][x]
			if sub[y * rw + x] != want:
				return false
	return true


## 0 when the id can't be smelted.
static func smelt_result(id: int) -> int:
	return SMELTING.get(id, 0)


## 0.0 when the id isn't fuel.
static func fuel_value(id: int) -> float:
	return FUEL.get(id, 0.0)
