class_name Hotbar
extends Control
## 8-slot hotbar. Number keys 1-8 and the mouse wheel select the active slot;
## the selected slot decides which block right-click places.
##
## This is a stub inventory: every slot holds infinite blocks.
## TODO: real inventory with quantities, item pickups feeding it, and a
## Creative-only palette screen with every block.

const PALETTE: Array[int] = [
	BlockTypes.GRASS, BlockTypes.DIRT, BlockTypes.STONE, BlockTypes.SAND,
	BlockTypes.WOOD, BlockTypes.LEAVES, BlockTypes.BEDROCK, BlockTypes.WATER,
]

var selected := 0

var _slots: Array[Panel] = []
var _style_normal: StyleBoxFlat
var _style_selected: StyleBoxFlat


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

	for i in PALETTE.size():
		var slot := Panel.new()
		slot.custom_minimum_size = Vector2(46, 46)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icon := TextureRect.new()
		icon.texture = BlockLibrary.get_block_icon(PALETTE[i])
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
		num.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(num)
		row.add_child(slot)
		_slots.append(slot)

	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	for i in PALETTE.size():
		if event.is_action_pressed("hotbar_%d" % (i + 1)):
			select(i)
			return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			select(posmod(selected - 1, PALETTE.size()))
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			select(posmod(selected + 1, PALETTE.size()))


func select(index: int) -> void:
	selected = clampi(index, 0, PALETTE.size() - 1)
	_refresh()


func selected_block() -> int:
	return PALETTE[selected]


func _refresh() -> void:
	for i in _slots.size():
		_slots[i].add_theme_stylebox_override(
			"panel",
			_style_selected if i == selected else _style_normal
		)
