class_name SettingsMenu
extends Control
## Settings overlay, reachable from both the start menu and the Esc pause
## menu. Video (fullscreen, vsync, render distance, FOV, shadows), Audio
## (master volume, mute — governs the Master bus; sound assets are a TODO),
## and Controls (mouse sensitivity, invert Y). Every change applies live and
## persists instantly through the Settings autoload.

signal closed


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS  # usable while the tree is paused
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.05, 0.08, 0.92)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 18)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	margin.add_child(box)

	var title := Label.new()
	title.text = "Settings"
	title.add_theme_font_size_override("font_size", 26)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	_section(box, "Video")
	_check(box, "Fullscreen", "fullscreen")
	_check(box, "VSync", "vsync")
	_slider(box, "Render distance", "render_distance", 4.0, 12.0, 1.0, "%d chunks")
	_slider(box, "Field of view", "fov", 60.0, 110.0, 1.0, "%d°")
	_check(box, "Shadows", "shadows")

	_section(box, "Audio")
	_slider(box, "Master volume", "master_volume", 0.0, 1.0, 0.05, "%d%%", 100.0)
	_check(box, "Mute", "muted")
	var note := Label.new()
	note.text = "(sound effects & music are still on the roadmap)"
	note.add_theme_font_size_override("font_size", 11)
	note.modulate = Color(1, 1, 1, 0.45)
	box.add_child(note)

	_section(box, "Controls")
	_slider(box, "Mouse sensitivity", "mouse_sensitivity", 0.2, 3.0, 0.1, "x%.1f")
	_check(box, "Invert mouse Y", "invert_y")

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 10)
	box.add_child(gap)

	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(220, 40)
	back.pressed.connect(close)
	box.add_child(back)


func open() -> void:
	visible = true


func close() -> void:
	visible = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


# --- Row builders -------------------------------------------------------------

func _section(parent: BoxContainer, text: String) -> void:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 8)
	parent.add_child(gap)
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	label.modulate = Color(0.8, 0.9, 1.0)
	parent.add_child(label)
	parent.add_child(HSeparator.new())


func _check(parent: BoxContainer, text: String, key: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	row.add_child(_row_label(text))
	var check := CheckBox.new()
	check.button_pressed = Settings.get(key)
	check.toggled.connect(func(on: bool) -> void: Settings.set_value(key, on))
	row.add_child(check)


func _slider(parent: BoxContainer, text: String, key: String, minv: float, maxv: float, step: float, fmt: String, display_scale: float = 1.0) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	row.add_child(_row_label(text))

	var slider := HSlider.new()
	slider.min_value = minv
	slider.max_value = maxv
	slider.step = step
	slider.custom_minimum_size = Vector2(180, 0)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.value = float(Settings.get(key))
	row.add_child(slider)

	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(76, 0)
	row.add_child(value_label)

	var update_label := func(v: float) -> void:
		if fmt.contains("%d"):
			value_label.text = fmt % int(roundf(v * display_scale))
		else:
			value_label.text = fmt % (v * display_scale)
	update_label.call(slider.value)

	slider.value_changed.connect(func(v: float) -> void:
		# render_distance is an int setting; sliders hand out floats.
		if key == "render_distance":
			Settings.set_value(key, int(v))
		else:
			Settings.set_value(key, v)
		update_label.call(v))


func _row_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(170, 0)
	return label
