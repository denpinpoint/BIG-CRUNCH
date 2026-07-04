class_name InventoryScreen
extends ContainerScreen
## The E-key inventory.
##
## Survival: a single view — 2x2 crafting grid with result slot, then the
## 27-slot inventory and the hotbar row. Creative: tab buttons across the top
## ("Inventory" plus one tab per item category); category tabs show an
## infinite palette (click = grab a stack) above the hotbar row.

var _craft: Array[Dictionary] = []
var _tab := 0  # 0 = player inventory, 1.. = BlockTypes.CREATIVE_CATEGORIES[i-1]
var _root: VBoxContainer
var _content: VBoxContainer


func _build() -> void:
	for i in 4:
		_craft.append({"id": 0, "count": 0})
	_root = make_panel_skeleton("Inventory")
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 8)
	_root.add_child(_content)
	GameMode.mode_changed.connect(_on_mode_switched)


func _on_mode_switched(_mode: int) -> void:
	# The layout is mode-specific (tabs vs crafting grid), so rebuild live.
	if visible:
		_tab = 0
		_rebuild()


func open() -> void:
	super()
	_tab = 0
	_rebuild()


func close() -> void:
	_return_craft_grid()
	super()


func _rebuild() -> void:
	clear_slots()
	for child in _content.get_children():
		child.queue_free()

	if GameMode.is_creative():
		var tabs := HBoxContainer.new()
		tabs.add_theme_constant_override("separation", 6)
		_content.add_child(tabs)
		var names := ["Inventory"]
		for category: Dictionary in BlockTypes.CREATIVE_CATEGORIES:
			names.append(category["name"])
		for i in names.size():
			var b := Button.new()
			b.text = names[i]
			b.toggle_mode = true
			b.button_pressed = i == _tab
			b.custom_minimum_size = Vector2(92, 30)
			var tab_index := i
			b.pressed.connect(func() -> void:
				_tab = tab_index
				_rebuild())
			tabs.add_child(b)

	if _tab == 0:
		_build_player_tab()
	else:
		_build_palette_tab(BlockTypes.CREATIVE_CATEGORIES[_tab - 1])


func _build_player_tab() -> void:
	# Survival gets the 2x2 crafting grid; Creative crafts from the palette.
	if GameMode.is_survival():
		var craft_row := HBoxContainer.new()
		craft_row.add_theme_constant_override("separation", 10)
		craft_row.alignment = BoxContainer.ALIGNMENT_CENTER
		_content.add_child(craft_row)

		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 4)
		grid.add_theme_constant_override("v_separation", 4)
		craft_row.add_child(grid)
		for i in 4:
			var ci := i
			grid.add_child(make_slot(
				"craft",
				func() -> Dictionary: return _craft[ci],
				func(id: int, count: int) -> void:
					_craft[ci] = {"id": id, "count": count} if count > 0 and id != 0 else {"id": 0, "count": 0}
			))

		var arrow := Label.new()
		arrow.text = "→"
		arrow.add_theme_font_size_override("font_size", 28)
		craft_row.add_child(arrow)

		craft_row.add_child(make_slot("craft_result", func() -> Dictionary: return _craft_result()))

		var sep := HSeparator.new()
		_content.add_child(sep)

	add_inventory_grids(_content)


func _build_palette_tab(category: Dictionary) -> void:
	var grid := GridContainer.new()
	grid.columns = Inventory.HOTBAR_SIZE
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	_content.add_child(grid)
	for id: int in category["items"]:
		var slot := make_slot(
			"palette",
			func() -> Dictionary: return {"id": id, "count": 1}
		)
		slot.payload = id
		slot.tooltip_text = BlockTypes.block_name(id)
		grid.add_child(slot)

	_content.add_child(HSeparator.new())

	# Hotbar row so grabbed stacks have somewhere to go.
	var hotbar_row := GridContainer.new()
	hotbar_row.columns = Inventory.HOTBAR_SIZE
	hotbar_row.add_theme_constant_override("h_separation", 4)
	_content.add_child(hotbar_row)
	for i in Inventory.HOTBAR_SIZE:
		hotbar_row.add_child(_inventory_slot(i))


# --- Crafting ---------------------------------------------------------------

func _craft_result() -> Dictionary:
	var ids: Array[int] = []
	for s in _craft:
		if s["id"] != 0 and s["count"] > 0:
			ids.append(s["id"])
	if ids.is_empty():
		return {"id": 0, "count": 0}
	var recipe := Recipes.match_craft(ids)
	if recipe.is_empty():
		return {"id": 0, "count": 0}
	return {"id": recipe["out"], "count": recipe["count"]}


func _special_click(slot: ItemSlot, button_index: int) -> bool:
	match slot.kind:
		"palette":
			# Infinite source: left = grab a full stack, right = add one.
			if button_index == MOUSE_BUTTON_LEFT:
				cursor_id = slot.payload
				cursor_count = Constants.STACK_MAX
			elif button_index == MOUSE_BUTTON_RIGHT:
				if cursor_id == slot.payload:
					cursor_count = mini(cursor_count + 1, Constants.STACK_MAX)
				else:
					cursor_id = slot.payload
					cursor_count = 1
			return true
		"craft_result":
			var result := _craft_result()
			if result["id"] == 0:
				return true
			# Take into the cursor (merge when it already holds the same item).
			if cursor_id == 0:
				cursor_id = result["id"]
				cursor_count = result["count"]
			elif cursor_id == result["id"] and cursor_count + result["count"] <= Constants.STACK_MAX:
				cursor_count += result["count"]
			else:
				return true  # cursor can't hold it
			# Crafting consumes one item from every occupied grid slot.
			for i in 4:
				if _craft[i]["id"] != 0:
					_craft[i]["count"] -= 1
					if _craft[i]["count"] <= 0:
						_craft[i] = {"id": 0, "count": 0}
			return true
	return false


## Anything left on the 2x2 grid goes back to the inventory on close.
func _return_craft_grid() -> void:
	for i in 4:
		if _craft[i]["id"] != 0 and _craft[i]["count"] > 0:
			Inventory.add_item(_craft[i]["id"], _craft[i]["count"])
		_craft[i] = {"id": 0, "count": 0}
