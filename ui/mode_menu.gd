class_name ModeMenu
extends Control
## Start-of-world menu: pick Survival or Creative (or continue a saved game),
## or tweak settings before diving in. Pauses the tree while open; the world
## keeps streaming in behind it (World runs in PROCESS_MODE_ALWAYS), so play
## starts instantly. F4 live-toggles the mode later without touching this menu.

## Shared SettingsMenu instance, injected by hud.gd.
var settings_menu: SettingsMenu


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.08, 0.11, 0.94)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(box)

	var title := Label.new()
	title.text = "VOXELCRAFT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 52)
	box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "an original voxel sandbox — pick a mode"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.modulate = Color(1, 1, 1, 0.7)
	box.add_child(subtitle)

	box.add_child(_spacer(16))
	box.add_child(_button("Survival", func() -> void: _choose(GameMode.Mode.SURVIVAL)))
	box.add_child(_button("Creative", func() -> void: _choose(GameMode.Mode.CREATIVE)))

	if SaveManager.has_save():
		box.add_child(_button("Continue (load save)", _continue_save))

	box.add_child(_button("Settings", func() -> void: settings_menu.open()))

	box.add_child(_spacer(16))
	var hint := Label.new()
	hint.text = "WASD move · Space jump · LMB mine · RMB place · 1-9 hotbar · E inventory\nF4 switch mode · F5 save · F9 load · F3 debug · Esc frees the mouse"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate = Color(1, 1, 1, 0.55)
	box.add_child(hint)
	# TODO: seed entry field for custom worlds (world seed is Constants.DEFAULT_SEED).


func _button(text: String, on_pressed: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(240, 44)
	b.pressed.connect(on_pressed)
	return b


func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


func _choose(mode: int) -> void:
	GameMode.set_mode(mode)
	_close()


func _continue_save() -> void:
	if SaveManager.load_game():
		_close()


func _close() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	queue_free()
