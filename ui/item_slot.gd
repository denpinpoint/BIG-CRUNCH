class_name ItemSlot
extends Panel
## One inventory/crafting/furnace slot: icon + stack count + click reporting.
## The owning screen binds `fetch` (returns {"id", "count"}) and optionally
## `store` (writes id/count back); slots without a store are read-only for
## the standard click logic (palette entries, craft results, furnace output).

signal clicked(slot: ItemSlot, button_index: int)

var kind := "inv"          # semantic tag the owning screen dispatches on
var payload: int = 0       # e.g. the item id of a creative palette entry
var fetch: Callable = Callable()
var store: Callable = Callable()

var _icon: TextureRect
var _count: Label
var _last_id := -1
var _last_count := -1


func _init(p_kind: String) -> void:
	kind = p_kind


func _ready() -> void:
	custom_minimum_size = Vector2(40, 40)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.45)
	style.set_border_width_all(2)
	style.border_color = Color(0.35, 0.35, 0.35, 0.9)
	add_theme_stylebox_override("panel", style)

	_icon = TextureRect.new()
	_icon.stretch_mode = TextureRect.STRETCH_SCALE
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	_icon.offset_left = 5
	_icon.offset_top = 5
	_icon.offset_right = -5
	_icon.offset_bottom = -5
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icon)

	_count = Label.new()
	_count.add_theme_font_size_override("font_size", 12)
	_count.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_count.add_theme_constant_override("shadow_offset_x", 1)
	_count.add_theme_constant_override("shadow_offset_y", 1)
	_count.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_count.offset_left = -22
	_count.offset_top = -18
	_count.offset_right = -3
	_count.offset_bottom = -2
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_count)

	mouse_entered.connect(func() -> void: self_modulate = Color(1.3, 1.3, 1.3))
	mouse_exited.connect(func() -> void: self_modulate = Color(1, 1, 1))
	refresh()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT:
			clicked.emit(self, event.button_index)
			accept_event()


## Re-reads the bound stack and updates visuals only when it changed.
func refresh() -> void:
	if not fetch.is_valid() or _icon == null:
		return
	var s: Dictionary = fetch.call()
	var id: int = s["id"]
	var count: int = s["count"]
	if id == _last_id and count == _last_count:
		return
	_last_id = id
	_last_count = count
	if id == 0 or count <= 0:
		_icon.texture = null
		_count.text = ""
	else:
		_icon.texture = BlockLibrary.get_icon(id)
		_count.text = str(count) if count > 1 else ""
