class_name ContainerScreen
extends Control
## Base class for the inventory and furnace screens: owns the cursor stack
## (the items "in hand" while rearranging), the standard slot click rules,
## and helpers to build the player's 27+9 inventory grids.
##
## Click rules (per slot that has a `store`):
##  * Left: pick up stack / put down stack / swap / merge same ids.
##  * Right: pick up half / put down exactly one.
## Special slots (palette, craft result, furnace output) are handled by the
## subclass via _special_click().

var cursor_id := 0
var cursor_count := 0

var _slots: Array[ItemSlot] = []
var _cursor_view: Control
var _cursor_icon: TextureRect
var _cursor_label: Label


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP  # swallow clicks aimed at the game
	_build()
	_build_cursor_view()


## Subclass hook: construct the panel layout.
func _build() -> void:
	pass


func _process(_delta: float) -> void:
	if not visible:
		return
	for s in _slots:
		s.refresh()
	_cursor_view.position = get_local_mouse_position() + Vector2(8, 8)
	_refresh_cursor_view()


func open() -> void:
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close() -> void:
	_return_cursor()
	visible = false


# --- Cursor -----------------------------------------------------------------

func _return_cursor() -> void:
	if cursor_id != 0 and cursor_count > 0:
		Inventory.add_item(cursor_id, cursor_count)  # leftovers vanish (TODO drops)
	cursor_id = 0
	cursor_count = 0


func _build_cursor_view() -> void:
	_cursor_view = Control.new()
	_cursor_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cursor_view.z_index = 100
	add_child(_cursor_view)
	_cursor_icon = TextureRect.new()
	_cursor_icon.stretch_mode = TextureRect.STRETCH_SCALE
	_cursor_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_cursor_icon.size = Vector2(32, 32)
	_cursor_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cursor_view.add_child(_cursor_icon)
	_cursor_label = Label.new()
	_cursor_label.position = Vector2(18, 18)
	_cursor_label.add_theme_font_size_override("font_size", 12)
	_cursor_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_cursor_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cursor_view.add_child(_cursor_label)


func _refresh_cursor_view() -> void:
	if cursor_id == 0 or cursor_count <= 0:
		_cursor_view.visible = false
		return
	_cursor_view.visible = true
	_cursor_icon.texture = BlockLibrary.get_icon(cursor_id)
	_cursor_label.text = str(cursor_count) if cursor_count > 1 else ""


# --- Slot plumbing ------------------------------------------------------------

## Create + register a slot. fetch/store bind it to its backing storage.
func make_slot(kind: String, fetch: Callable, store: Callable = Callable()) -> ItemSlot:
	var slot := ItemSlot.new(kind)
	slot.fetch = fetch
	slot.store = store
	slot.clicked.connect(_on_slot_clicked)
	_slots.append(slot)
	return slot


## Wipe registered slots (used when a screen rebuilds its layout).
func clear_slots() -> void:
	_slots.clear()


func _on_slot_clicked(slot: ItemSlot, button_index: int) -> void:
	if _special_click(slot, button_index):
		return
	if not slot.store.is_valid():
		return
	var s: Dictionary = slot.fetch.call()
	var id: int = s["id"]
	var count: int = s["count"]

	if button_index == MOUSE_BUTTON_LEFT:
		if cursor_id == 0:
			if count > 0:  # pick up the whole stack
				cursor_id = id
				cursor_count = count
				slot.store.call(0, 0)
		elif id == 0 or count == 0:  # put the whole stack down
			slot.store.call(cursor_id, cursor_count)
			cursor_id = 0
			cursor_count = 0
		elif id == cursor_id:  # merge
			var space := Constants.STACK_MAX - count
			var moved := mini(space, cursor_count)
			slot.store.call(id, count + moved)
			cursor_count -= moved
			if cursor_count <= 0:
				cursor_id = 0
				cursor_count = 0
		else:  # swap
			slot.store.call(cursor_id, cursor_count)
			cursor_id = id
			cursor_count = count
	elif button_index == MOUSE_BUTTON_RIGHT:
		if cursor_id == 0:
			if count > 0:  # take half (rounded up)
				var take := ceili(count / 2.0)
				cursor_id = id
				cursor_count = take
				slot.store.call(id, count - take)
		elif (id == 0 or id == cursor_id) and count < Constants.STACK_MAX:
			slot.store.call(cursor_id, count + 1)  # drop exactly one
			cursor_count -= 1
			if cursor_count <= 0:
				cursor_id = 0
				cursor_count = 0


## Subclass hook for palette/result/output slots. Return true when handled.
func _special_click(_slot: ItemSlot, _button_index: int) -> bool:
	return false


# --- Shared layout helpers ----------------------------------------------------

## The player's 27-slot main grid + 9-slot hotbar row, bound to Inventory.
func add_inventory_grids(parent: BoxContainer) -> void:
	var main := GridContainer.new()
	main.columns = Inventory.HOTBAR_SIZE
	main.add_theme_constant_override("h_separation", 4)
	main.add_theme_constant_override("v_separation", 4)
	parent.add_child(main)
	for i in range(Inventory.HOTBAR_SIZE, Inventory.SIZE):
		main.add_child(_inventory_slot(i))

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 8)
	parent.add_child(gap)

	var hotbar_row := GridContainer.new()
	hotbar_row.columns = Inventory.HOTBAR_SIZE
	hotbar_row.add_theme_constant_override("h_separation", 4)
	parent.add_child(hotbar_row)
	for i in Inventory.HOTBAR_SIZE:
		hotbar_row.add_child(_inventory_slot(i))


func _inventory_slot(i: int) -> ItemSlot:
	return make_slot(
		"inv",
		func() -> Dictionary: return Inventory.slot(i),
		func(id: int, count: int) -> void: Inventory.set_slot(i, id, count)
	)


func make_panel_skeleton(title: String) -> VBoxContainer:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := PanelContainer.new()
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)

	var label := Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 18)
	box.add_child(label)
	return box
