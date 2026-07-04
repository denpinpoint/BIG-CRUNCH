class_name InventoryScreen
extends ContainerScreen
## The inventory / crafting-table screen.
##
## E (player inventory): a 2x2 crafting grid + result, four armor slots, and
## the 27-slot inventory + hotbar. Creative adds category tabs across the top
## whose palettes hand out infinite stacks. Right-clicking a Crafting Table
## opens the same screen in TABLE MODE: a 3x3 crafting grid + result over the
## inventory (no creative tabs), so advanced recipes (tools, armor, stairs,
## furnace) that don't fit 2x2 become craftable.
##
## Recipes are shape-based (Recipes.match_grid): the grid cells feed straight
## in, so position and pattern matter, not just ingredient counts.

var _craft: Array[Dictionary] = []
var _craft_width := 2
var _table_mode := false
var _tab := 0  # 0 = player inventory, 1.. = BlockTypes.CREATIVE_CATEGORIES[i-1]
var _root: VBoxContainer
var _content: VBoxContainer


func _build() -> void:
	_resize_craft(2)
	_root = make_panel_skeleton("Inventory")
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 8)
	_root.add_child(_content)
	GameMode.mode_changed.connect(_on_mode_switched)


func _resize_craft(width: int) -> void:
	_craft_width = width
	_craft.clear()
	for i in width * width:
		_craft.append({"id": 0, "count": 0})


func _on_mode_switched(_mode: int) -> void:
	# The layout is mode-specific (tabs vs crafting grid), so rebuild live.
	if visible:
		_tab = 0
		_rebuild()


## E key: personal inventory with the 2x2 grid.
func open() -> void:
	_table_mode = false
	_resize_craft(2)
	super()
	_tab = 0
	_rebuild()


## Right-clicking a Crafting Table: 3x3 grid over the inventory.
func open_table() -> void:
	_table_mode = true
	_resize_craft(3)
	super()
	_tab = 0
	_rebuild()


func close() -> void:
	_return_craft_grid()
	super()


func _title() -> String:
	return "Crafting Table" if _table_mode else "Inventory"


func _rebuild() -> void:
	clear_slots()
	for child in _content.get_children():
		child.queue_free()
	# Retitle the panel header (first label in _root).
	for child in _root.get_children():
		if child is Label:
			child.text = _title()
			break

	# Creative category tabs — but not while a table is open (table always
	# shows the 3x3 crafting layout).
	if GameMode.is_creative() and not _table_mode:
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
			b.custom_minimum_size = Vector2(88, 30)
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
	# Top row: [armor column] [crafting grid] -> [result]. The 2x2 grid needs
	# food/hands so it shows in every mode; the 3x3 only exists in table mode.
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	_content.add_child(top)

	# Armor column (only in the personal inventory, not the table screen).
	if not _table_mode:
		var armor_col := VBoxContainer.new()
		armor_col.add_theme_constant_override("separation", 4)
		top.add_child(armor_col)
		for i in Inventory.ARMOR_SLOTS:
			var ai := i
			var slot := make_slot(
				"armor",
				func() -> Dictionary: return Inventory.armor_slot(ai)
			)
			slot.payload = ai
			slot.tooltip_text = BlockTypes.ARMOR_PIECE_NAMES[i]
			armor_col.add_child(slot)

	var craft_row := HBoxContainer.new()
	craft_row.add_theme_constant_override("separation", 10)
	craft_row.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_child(craft_row)

	var grid := GridContainer.new()
	grid.columns = _craft_width
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	craft_row.add_child(grid)
	for i in _craft.size():
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

	_content.add_child(HSeparator.new())
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
	var cells: Array[int] = []
	for s in _craft:
		cells.append(s["id"] if s["count"] > 0 else 0)
	var recipe := Recipes.match_grid(cells, _craft_width)
	if recipe.is_empty():
		return {"id": 0, "count": 0}
	return {"id": recipe["out"], "count": recipe["count"]}


func _special_click(slot: ItemSlot, button_index: int) -> bool:
	match slot.kind:
		"palette":
			# Infinite source: left = grab a full stack, right = add one.
			var cap := BlockTypes.stack_max(slot.payload)
			if button_index == MOUSE_BUTTON_LEFT:
				cursor_id = slot.payload
				cursor_count = cap
			elif button_index == MOUSE_BUTTON_RIGHT:
				if cursor_id == slot.payload:
					cursor_count = mini(cursor_count + 1, cap)
				else:
					cursor_id = slot.payload
					cursor_count = 1
			return true
		"armor":
			_armor_click(slot.payload)
			return true
		"craft_result":
			_take_craft_result()
			return true
	return false


func _armor_click(idx: int) -> void:
	var s := Inventory.armor_slot(idx)
	var cur_id: int = s["id"]
	var cur_count: int = s["count"]
	if cursor_id == 0:
		if cur_count > 0:  # take the worn piece
			cursor_id = cur_id
			cursor_count = cur_count
			Inventory.set_armor(idx, 0, 0)
	elif Inventory.armor_fits(idx, cursor_id):
		# Equip; swap whatever was there back onto the cursor (armor stacks
		# to 1, so this is always a clean 1-for-1).
		Inventory.set_armor(idx, cursor_id, 1)
		cursor_id = cur_id
		cursor_count = cur_count
	# Wrong piece for this slot: do nothing (keeps the cursor item safe).


func _take_craft_result() -> void:
	var result := _craft_result()
	if result["id"] == 0:
		return
	var cap := BlockTypes.stack_max(result["id"])
	if cursor_id == 0:
		cursor_id = result["id"]
		cursor_count = result["count"]
	elif cursor_id == result["id"] and cursor_count + result["count"] <= cap:
		cursor_count += result["count"]
	else:
		return  # cursor can't hold it
	# Crafting consumes one item from every occupied grid slot.
	for i in _craft.size():
		if _craft[i]["id"] != 0:
			_craft[i]["count"] -= 1
			if _craft[i]["count"] <= 0:
				_craft[i] = {"id": 0, "count": 0}


## Anything left on the crafting grid goes back to the inventory on close.
func _return_craft_grid() -> void:
	for i in _craft.size():
		if _craft[i]["id"] != 0 and _craft[i]["count"] > 0:
			Inventory.add_item(_craft[i]["id"], _craft[i]["count"])
		_craft[i] = {"id": 0, "count": 0}
