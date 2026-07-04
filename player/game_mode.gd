extends Node
## Autoloaded as "GameMode" — the single source of truth for Survival vs
## Creative. Every system (player, stats, HUD, mobs, mining) reacts to
## mode_changed, so switching live via F4 needs no restart.

enum Mode { SURVIVAL, CREATIVE }

# Mode values travel as plain ints in signals/params so that other scripts
# don't need to reference this autoload's enum in type annotations.
signal mode_changed(mode: int)

var mode: int = Mode.SURVIVAL


func _init() -> void:
	# First code that runs in the game: build the input map (see input_setup.gd).
	InputSetup.register_actions()


func set_mode(new_mode: int) -> void:
	if new_mode == mode:
		return
	mode = new_mode
	mode_changed.emit(mode)


func toggle() -> void:
	set_mode(Mode.CREATIVE if mode == Mode.SURVIVAL else Mode.SURVIVAL)


func is_creative() -> bool:
	return mode == Mode.CREATIVE


func is_survival() -> bool:
	return mode == Mode.SURVIVAL


func mode_name() -> String:
	return "Creative" if is_creative() else "Survival"


func _unhandled_input(event: InputEvent) -> void:
	# Debug/cheat key: live-toggle the mode.
	if event.is_action_pressed("toggle_mode"):
		toggle()
