class_name Hotbar
extends Control
## The on-screen hotbar: a live view of Inventory slots 0-8. Number keys 1-9
## and the mouse wheel select the active slot; the selected slot is what
## right-click places (Survival consumes from it, Creative doesn't).

var _panels: Array[Panel] = []
var _icons: Array[TextureRect] = []
var _counts: Array[Label] = []
var _style_normal: StyleBoxFlat
var _style_selected: StyleBoxFlat
var _hud: Node


func _ready() -> void:
	add_to_group("hotbar")

	_style_normal = StyleBoxFlat.new()
	_style_normal.bg_color = Color(0, 0, 0, 0.35)
	_style_normal.set_border_width_all(2)
	_style_normal.border_color = Color(0.25, 0.25, 0.25, 0.9)

	_style_selected = StyleBoxFlat.new()
	_style_selected.bg_color = Color(0, 0, 0, 0.35)
	_style_selected.set_border_width_all(3)
	_style_selected.border_color = Color(1, 1, 1, 0.95)

	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)

	for i in Inventory.HOTBAR_SIZE:
		var slot := Panel.new()
		slot.custom_minimum_size = Vector2(46, 46)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icon := TextureRect.new()
		icon.stretch_mode = TextureRect.STRETCH_SCALE
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon.offset_left = 6
		icon.offset_top = 6
		icon.offset_right = -6
		icon.offset_bottom = -6
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(icon)
		var num := Label.new()
		num.text = str(i + 1)
		num.position = Vector2(3, 0)
		num.add_theme_font_size_override("font_size", 10)
		num.modulate = Color(1, 1, 1, 0.6)
		num.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(num)
		var count := Label.new()
		count.add_theme_font_size_override("font_size", 12)
		count.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
		count.add_theme_constant_override("shadow_offset_x", 1)
		count.add_theme_constant_override("shadow_offset_y", 1)
		count.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		count.offset_left = -26
		count.offset_top = -19
		count.offset_right = -4
		count.offset_bottom = -2
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(count)

		row.add_child(slot)
		_panels.append(slot)
		_icons.append(icon)
		_counts.append(count)

	Inventory.changed.connect(_refresh)
	Inventory.selection_changed.connect(func(_i: int) -> void: _refresh())
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if _ui_open():
		return  # inventory/furnace screens own the mouse and keys
	for i in Inventory.HOTBAR_SIZE:
		if event.is_action_pressed("hotbar_%d" % (i + 1)):
			Inventory.select(i)
			return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			Inventory.select(Inventory.selected - 1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			Inventory.select(Inventory.selected + 1)


func _refresh() -> void:
	for i in Inventory.HOTBAR_SIZE:
		var s: Dictionary = Inventory.slot(i)
		if s["id"] == 0 or s["count"] <= 0:
			_icons[i].texture = null
			_counts[i].text = ""
		else:
			_icons[i].texture = BlockLibrary.get_icon(s["id"])
			_counts[i].text = str(s["count"]) if s["count"] > 1 else ""
		_panels[i].add_theme_stylebox_override(
			"panel",
			_style_selected if i == Inventory.selected else _style_normal
		)


func _ui_open() -> bool:
	if _hud == null:
		_hud = get_tree().get_first_node_in_group("hud")
	return _hud != null and _hud.ui_open
