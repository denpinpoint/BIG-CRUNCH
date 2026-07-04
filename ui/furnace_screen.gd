class_name FurnaceScreen
extends ContainerScreen
## Furnace UI: input above fuel, an arrow progress bar toward the output
## slot, a flame bar for remaining burn time, and the player inventory below
## for shuffling items in and out. The furnace itself keeps smelting whether
## or not this screen is open (see world/furnaces.gd).

var _state: Dictionary = {}
var _root: VBoxContainer
var _smelt_bar: ProgressBar
var _burn_bar: ProgressBar


func _build() -> void:
	_root = make_panel_skeleton("Furnace")

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	_root.add_child(top)

	var in_col := VBoxContainer.new()
	in_col.add_theme_constant_override("separation", 6)
	top.add_child(in_col)
	in_col.add_child(_state_slot("furnace_in", "input"))
	in_col.add_child(_state_slot("furnace_fuel", "fuel"))

	var mid := VBoxContainer.new()
	mid.add_theme_constant_override("separation", 4)
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_child(mid)
	_smelt_bar = _bar()
	mid.add_child(_smelt_bar)
	var flame := Label.new()
	flame.text = "fuel"
	flame.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	flame.modulate = Color(1, 0.7, 0.4)
	mid.add_child(flame)
	_burn_bar = _bar()
	_burn_bar.modulate = Color(1, 0.6, 0.3)
	mid.add_child(_burn_bar)

	top.add_child(make_slot("furnace_out", func() -> Dictionary: return _out_stack()))

	_root.add_child(HSeparator.new())
	add_inventory_grids(_root)


func open_at(bp: Vector3i) -> void:
	var furnaces: Node = get_tree().get_first_node_in_group("furnaces")
	_state = furnaces.state_for(bp)
	open()


func _process(delta: float) -> void:
	super(delta)
	if not visible or _state.is_empty():
		return
	_smelt_bar.value = _state["progress"] / Constants.SMELT_TIME
	var total: float = _state["burn_total"]
	_burn_bar.value = (_state["burn_left"] / total) if total > 0.0 else 0.0


func _state_slot(kind: String, key: String) -> ItemSlot:
	return make_slot(
		kind,
		func() -> Dictionary: return _stack(key),
		func(id: int, count: int) -> void:
			_state[key] = {"id": id, "count": count} if count > 0 and id != 0 else {"id": 0, "count": 0}
	)


func _stack(key: String) -> Dictionary:
	if _state.is_empty():
		return {"id": 0, "count": 0}
	return _state[key]


func _out_stack() -> Dictionary:
	return _stack("output")


## Output is take-only: you can't shove items into the result of a smelt.
func _special_click(slot: ItemSlot, button_index: int) -> bool:
	if slot.kind != "furnace_out":
		return false
	var out := _out_stack()
	if out["id"] == 0 or out["count"] <= 0:
		return true
	if button_index == MOUSE_BUTTON_LEFT:
		if cursor_id == 0:
			cursor_id = out["id"]
			cursor_count = out["count"]
			_state["output"] = {"id": 0, "count": 0}
		elif cursor_id == out["id"]:
			var moved: int = mini(Constants.STACK_MAX - cursor_count, out["count"])
			cursor_count += moved
			out["count"] -= moved
			if out["count"] <= 0:
				_state["output"] = {"id": 0, "count": 0}
	return true


func _bar() -> ProgressBar:
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(90, 10)
	return bar
