class_name Recipes
## Crafting (2x2, shapeless) + smelting + fuel data.
##
## Crafting: a recipe matches when the multiset of ids in the occupied grid
## slots equals the recipe's ingredient list (slot stack sizes don't matter —
## one item is consumed from every occupied slot per craft, like the game
## that inspired this). TODO: shaped recipes + a 3x3 crafting table.

const CRAFTING := [
	{"in": [BlockTypes.WOOD], "out": BlockTypes.PLANKS, "count": 4},
	{"in": [BlockTypes.PLANKS, BlockTypes.PLANKS], "out": BlockTypes.STICK, "count": 4},
	{
		"in": [BlockTypes.COBBLESTONE, BlockTypes.COBBLESTONE, BlockTypes.COBBLESTONE, BlockTypes.COBBLESTONE],
		"out": BlockTypes.FURNACE, "count": 1,
	},
	{
		"in": [BlockTypes.IRON_INGOT, BlockTypes.IRON_INGOT, BlockTypes.IRON_INGOT, BlockTypes.IRON_INGOT],
		"out": BlockTypes.IRON_BLOCK, "count": 1,
	},
	{
		"in": [BlockTypes.GOLD_INGOT, BlockTypes.GOLD_INGOT, BlockTypes.GOLD_INGOT, BlockTypes.GOLD_INGOT],
		"out": BlockTypes.GOLD_BLOCK, "count": 1,
	},
	{
		"in": [BlockTypes.DIAMOND, BlockTypes.DIAMOND, BlockTypes.DIAMOND, BlockTypes.DIAMOND],
		"out": BlockTypes.DIAMOND_BLOCK, "count": 1,
	},
	# Mineral blocks unpack back into their items.
	{"in": [BlockTypes.IRON_BLOCK], "out": BlockTypes.IRON_INGOT, "count": 4},
	{"in": [BlockTypes.GOLD_BLOCK], "out": BlockTypes.GOLD_INGOT, "count": 4},
	{"in": [BlockTypes.DIAMOND_BLOCK], "out": BlockTypes.DIAMOND, "count": 4},
]

## Furnace: input id -> output id.
const SMELTING := {
	BlockTypes.IRON_ORE: BlockTypes.IRON_INGOT,
	BlockTypes.GOLD_ORE: BlockTypes.GOLD_INGOT,
	BlockTypes.COBBLESTONE: BlockTypes.STONE,
	BlockTypes.WOOD: BlockTypes.COAL,  # charcoal, close enough
}

## Fuel values: 1.0 = one smelt's worth of burn time.
const FUEL := {
	BlockTypes.COAL: 8.0,
	BlockTypes.WOOD: 1.0,
	BlockTypes.PLANKS: 1.0,
	BlockTypes.STICK: 0.5,
}


## ids = ids of the OCCUPIED craft slots (any order). Returns
## {"out": id, "count": n} or an empty Dictionary when nothing matches.
static func match_craft(ids: Array[int]) -> Dictionary:
	var sorted_ids := ids.duplicate()
	sorted_ids.sort()
	for recipe: Dictionary in CRAFTING:
		var need: Array = recipe["in"].duplicate()
		need.sort()
		if need == sorted_ids:
			return {"out": recipe["out"], "count": recipe["count"]}
	return {}


## 0 when the id can't be smelted.
static func smelt_result(id: int) -> int:
	return SMELTING.get(id, 0)


## 0.0 when the id isn't fuel.
static func fuel_value(id: int) -> float:
	return FUEL.get(id, 0.0)
