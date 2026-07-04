class_name InputSetup
## Registers the whole input map from code at startup (called by the GameMode
## autoload before anything else runs). Doing it in code instead of in
## project.godot keeps the project file tiny and makes the bindings
## self-documenting. TODO: expose a rebinding UI that edits InputMap at runtime.
##
## Input map:
##   move_forward  W          move_back  S
##   move_left     A          move_right D
##   jump          Space      sprint     Shift
##   crouch        Ctrl       (fly down while flying)
##   break         Left mouse  place     Right mouse
##   hotbar_1..8   1..8        (mouse wheel also cycles)
##   toggle_mode   F4          toggle_debug F3
##   save_game     F5          load_game  F9
##   Esc releases the mouse (built-in ui_cancel), click recaptures.


static func register_actions() -> void:
	if InputMap.has_action("move_forward"):
		return  # already registered (e.g. scene reload)
	_key("move_forward", KEY_W)
	_key("move_back", KEY_S)
	_key("move_left", KEY_A)
	_key("move_right", KEY_D)
	_key("jump", KEY_SPACE)
	_key("sprint", KEY_SHIFT)
	_key("crouch", KEY_CTRL)
	_key("toggle_mode", KEY_F4)
	_key("toggle_debug", KEY_F3)
	_key("save_game", KEY_F5)
	_key("load_game", KEY_F9)
	for i in range(1, 9):
		_key("hotbar_%d" % i, KEY_1 + i - 1)
	_mouse("break", MOUSE_BUTTON_LEFT)
	_mouse("place", MOUSE_BUTTON_RIGHT)


static func _key(action: String, keycode: Key) -> void:
	InputMap.add_action(action)
	var ev := InputEventKey.new()
	# Physical keycodes so WASD stays WASD on non-QWERTY layouts.
	ev.physical_keycode = keycode
	InputMap.action_add_event(action, ev)


static func _mouse(action: String, button: MouseButton) -> void:
	InputMap.add_action(action)
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)
