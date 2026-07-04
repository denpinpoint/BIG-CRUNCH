extends Node
## Furnace simulation. Each placed furnace block gets a state entry keyed by
## its world block position; furnaces keep smelting in the background (even
## while their chunk is unloaded — block truth is generator+edits, so the
## block still exists). State is saved/loaded with the world.
##
## State layout per furnace:
##   input / fuel / output: {"id": int, "count": int}
##   progress:  seconds into the current smelt (SMELT_TIME finishes one item)
##   burn_left: seconds of fuel burn remaining
##   burn_total: length of the current burn (for the UI flame bar)

var states: Dictionary[Vector3i, Dictionary] = {}

var _world: Node3D


func _ready() -> void:
	add_to_group("furnaces")
	_world = get_tree().get_first_node_in_group("world")


func _process(delta: float) -> void:
	for bp: Vector3i in states.keys():
		_tick(bp, states[bp], delta)


## Get-or-create the state for a furnace block (UI opens lazily).
func state_for(bp: Vector3i) -> Dictionary:
	if not states.has(bp):
		states[bp] = {
			"input": {"id": 0, "count": 0},
			"fuel": {"id": 0, "count": 0},
			"output": {"id": 0, "count": 0},
			"progress": 0.0,
			"burn_left": 0.0,
			"burn_total": 0.0,
		}
	return states[bp]


## A furnace block was mined: eject its contents and forget it. In Survival
## the contents scatter as drop entities; in Creative (where drops don't
## exist) they go straight to the inventory so nothing silently vanishes.
func on_broken(bp: Vector3i) -> void:
	if not states.has(bp):
		return
	var state: Dictionary = states[bp]
	var center := Vector3(bp) + Vector3.ONE * 0.5
	for key: String in ["input", "fuel", "output"]:
		var stack: Dictionary = state[key]
		if stack["id"] != 0 and stack["count"] > 0:
			if GameMode.is_survival():
				ItemDrop.spawn(_world, center, stack["id"], stack["count"])
			else:
				Inventory.add_item(stack["id"], stack["count"])
	states.erase(bp)


func _tick(bp: Vector3i, state: Dictionary, delta: float) -> void:
	# Stale state (block replaced by something else) cleans itself up.
	if _world != null and _world.get_block(bp) != BlockTypes.FURNACE:
		states.erase(bp)
		return

	var input: Dictionary = state["input"]
	var output: Dictionary = state["output"]
	var out_id := Recipes.smelt_result(input["id"]) if input["count"] > 0 else 0
	var output_fits: bool = (
		output["id"] == 0
		or (output["id"] == out_id and output["count"] < Constants.STACK_MAX)
	)
	var can_smelt := out_id != 0 and output_fits

	if state["burn_left"] > 0.0:
		state["burn_left"] = maxf(state["burn_left"] - delta, 0.0)

	# Light a new piece of fuel only when there's work to do.
	if can_smelt and state["burn_left"] <= 0.0:
		var fuel: Dictionary = state["fuel"]
		var value := Recipes.fuel_value(fuel["id"]) if fuel["count"] > 0 else 0.0
		if value > 0.0:
			fuel["count"] -= 1
			if fuel["count"] <= 0:
				state["fuel"] = {"id": 0, "count": 0}
			state["burn_total"] = value * Constants.FUEL_UNIT
			state["burn_left"] = state["burn_total"]

	if can_smelt and state["burn_left"] > 0.0:
		state["progress"] += delta
		if state["progress"] >= Constants.SMELT_TIME:
			state["progress"] = 0.0
			input["count"] -= 1
			if input["count"] <= 0:
				state["input"] = {"id": 0, "count": 0}
			if output["id"] == 0:
				state["output"] = {"id": out_id, "count": 1}
			else:
				output["count"] += 1
	else:
		# No work or no heat: progress decays instead of pausing forever.
		state["progress"] = maxf(state["progress"] - delta * 2.0, 0.0)


func serialize() -> Dictionary:
	var out := {}
	for bp: Vector3i in states.keys():
		var s: Dictionary = states[bp]
		out["%d,%d,%d" % [bp.x, bp.y, bp.z]] = {
			"in": [s["input"]["id"], s["input"]["count"]],
			"fuel": [s["fuel"]["id"], s["fuel"]["count"]],
			"out": [s["output"]["id"], s["output"]["count"]],
			"progress": s["progress"],
			"burn_left": s["burn_left"],
			"burn_total": s["burn_total"],
		}
	return out


func deserialize(data: Dictionary) -> void:
	states.clear()
	for key: String in data.keys():
		var parts := key.split(",")
		if parts.size() != 3:
			continue
		var bp := Vector3i(int(parts[0]), int(parts[1]), int(parts[2]))
		var s: Dictionary = data[key]
		states[bp] = {
			"input": {"id": int(s["in"][0]), "count": int(s["in"][1])},
			"fuel": {"id": int(s["fuel"][0]), "count": int(s["fuel"][1])},
			"output": {"id": int(s["out"][0]), "count": int(s["out"][1])},
			"progress": float(s["progress"]),
			"burn_left": float(s["burn_left"]),
			"burn_total": float(s["burn_total"]),
		}
