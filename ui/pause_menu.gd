class_name PauseMenu
extends Control
## Esc pause menu: pauses the world and offers Resume / Settings / Save /
## Save & Quit. Esc again (or Resume) returns to the game.

## The shared SettingsMenu instance, injected by hud.gd.
var settings_menu: SettingsMenu

var _panel: Control
var _status: Label


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS  # runs while the tree is paused
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_panel = center

	var panel := PanelContainer.new()
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 20)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(box)

	var title := Label.new()
	title.text = "Paused"
	title.add_theme_font_size_override("font_size", 34)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	box.add_child(_button("Resume", resume))
	box.add_child(_button("Settings", _open_settings))
	box.add_child(_button("Save Game", _save))
	box.add_child(_button("Main Menu", _main_menu))
	box.add_child(_button("Save & Quit", _save_and_quit))

	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.modulate = Color(1, 1, 1, 0.0)
	box.add_child(_status)


func open() -> void:
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func resume() -> void:
	if settings_menu != null and settings_menu.visible:
		settings_menu.close()
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed("ui_cancel"):
		return
	# The settings overlay (registered after us in the tree) already consumed
	# Esc if it was open, so reaching here means: leave the pause menu.
	resume()
	get_viewport().set_input_as_handled()


func _open_settings() -> void:
	_panel.visible = false
	settings_menu.open()
	if not settings_menu.closed.is_connected(_on_settings_closed):
		settings_menu.closed.connect(_on_settings_closed)


func _on_settings_closed() -> void:
	if visible:
		_panel.visible = true


func _save() -> void:
	if SaveManager.save_game():
		_flash_status("Game saved.")
	else:
		_flash_status("Nothing to save yet.")


## Save & return to the title screen (like "Save and Quit to Title"). Saves,
## then reloads the scene so a fresh start menu appears; the world, mobs and
## furnaces are recreated and the inventory is cleared. "Continue" on the
## title screen reloads exactly what we just saved.
func _main_menu() -> void:
	SaveManager.save_game()
	get_tree().paused = false
	Inventory.clear()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().call_deferred("reload_current_scene")


func _save_and_quit() -> void:
	SaveManager.save_game()
	get_tree().quit()


func _flash_status(text: String) -> void:
	_status.text = text
	_status.modulate.a = 1.0
	var tween := create_tween()  # bound to this ALWAYS-processing node
	tween.tween_interval(1.2)
	tween.tween_property(_status, "modulate:a", 0.0, 0.5)


func _button(text: String, on_pressed: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(240, 42)
	b.pressed.connect(on_pressed)
	return b
