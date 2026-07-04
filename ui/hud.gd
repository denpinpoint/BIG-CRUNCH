extends CanvasLayer
## HUD root: builds all UI in code (crosshair, hotbar, survival stats,
## inventory + furnace screens, mode menu, death screen, debug overlay) and
## wires them to the player systems via signals.
## Block-breaking feedback is the in-world crack overlay (block_interaction),
## not a UI bar.

var hotbar: Hotbar
var stats_bar: StatsBar
var death_screen: DeathScreen
var debug_overlay: DebugOverlay
var inventory_screen: InventoryScreen
var furnace_screen: FurnaceScreen
var pause_menu: PauseMenu
var settings_menu: SettingsMenu

## True while a container screen (inventory/furnace) is on screen.
var ui_open: bool:
	get:
		return (
			(inventory_screen != null and inventory_screen.visible)
			or (furnace_screen != null and furnace_screen.visible)
		)

var _message: Label
var _message_tween: Tween
var _player: Node


func _ready() -> void:
	add_to_group("hud")

	var crosshair := Crosshair.new()
	crosshair.set_anchors_preset(Control.PRESET_FULL_RECT)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(crosshair)

	hotbar = Hotbar.new()
	hotbar.anchor_left = 0.5
	hotbar.anchor_right = 0.5
	hotbar.anchor_top = 1.0
	hotbar.anchor_bottom = 1.0
	hotbar.offset_left = -230
	hotbar.offset_right = 230
	hotbar.offset_top = -64
	hotbar.offset_bottom = -12
	hotbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hotbar)

	stats_bar = StatsBar.new()
	stats_bar.anchor_left = 0.5
	stats_bar.anchor_right = 0.5
	stats_bar.anchor_top = 1.0
	stats_bar.anchor_bottom = 1.0
	stats_bar.offset_left = -230
	stats_bar.offset_right = 230
	stats_bar.offset_top = -94
	stats_bar.offset_bottom = -68
	stats_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stats_bar)

	_message = Label.new()
	_message.anchor_left = 0.5
	_message.anchor_right = 0.5
	_message.anchor_top = 1.0
	_message.anchor_bottom = 1.0
	_message.offset_left = -220
	_message.offset_right = 220
	_message.offset_top = -130
	_message.offset_bottom = -104
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.modulate.a = 0.0
	_message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_message)

	debug_overlay = DebugOverlay.new()
	debug_overlay.position = Vector2(8, 8)
	debug_overlay.visible = false
	add_child(debug_overlay)

	# Container screens sit under the death screen so dying wins visually.
	inventory_screen = InventoryScreen.new()
	inventory_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(inventory_screen)

	furnace_screen = FurnaceScreen.new()
	furnace_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(furnace_screen)

	death_screen = DeathScreen.new()
	death_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(death_screen)

	pause_menu = PauseMenu.new()
	pause_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(pause_menu)

	# --- Wiring ---
	_player = get_tree().get_first_node_in_group("player")
	if _player != null:
		var stats: Node = _player.get_node("Stats")
		stats.health_changed.connect(func(h: float) -> void: stats_bar.set_health(h))
		stats.hunger_changed.connect(func(h: float) -> void: stats_bar.set_hunger(h))
		stats.died.connect(_on_player_died)
		death_screen.respawn_requested.connect(stats.respawn)

	GameMode.mode_changed.connect(_on_mode_changed)
	_on_mode_changed(GameMode.mode)

	# Pick Survival/Creative at world start.
	var menu := ModeMenu.new()
	menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(menu)

	# Settings last = topmost, and it registers behind-most in the input
	# order, so its Esc handling wins while it's open.
	settings_menu = SettingsMenu.new()
	settings_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(settings_menu)
	pause_menu.settings_menu = settings_menu
	menu.settings_menu = settings_menu


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_debug"):
		debug_overlay.visible = not debug_overlay.visible
	elif event.is_action_pressed("inventory"):
		if ui_open:
			close_ui()
			get_viewport().set_input_as_handled()
		elif _can_open_ui():
			inventory_screen.open()
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		# Esc during play: close container UIs first, otherwise pause.
		# (While the game IS paused this handler never runs — the pause and
		# settings menus process their own Esc in ALWAYS mode.)
		if ui_open:
			close_ui()
			get_viewport().set_input_as_handled()
		elif _can_open_ui():
			pause_menu.open()
			get_viewport().set_input_as_handled()


## Furnace right-clicks land here (from block_interaction).
func open_furnace(bp: Vector3i) -> void:
	if _can_open_ui() and not ui_open:
		furnace_screen.open_at(bp)


func close_ui() -> void:
	if inventory_screen.visible:
		inventory_screen.close()
	if furnace_screen.visible:
		furnace_screen.close()
	# Hand the mouse back to the game.
	if _player != null and _player.get_node("Stats").alive and not get_tree().paused:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _can_open_ui() -> bool:
	if get_tree().paused or _player == null:
		return false
	return not _player.frozen and _player.get_node("Stats").alive


func _on_player_died() -> void:
	close_ui()
	death_screen.open()


func _on_mode_changed(_mode: int) -> void:
	# Health/hunger are Survival-only UI.
	stats_bar.visible = GameMode.is_survival()
	show_message("Mode: %s" % GameMode.mode_name())


func show_message(text: String) -> void:
	_message.text = text
	if _message_tween != null:
		_message_tween.kill()
	_message.modulate.a = 1.0
	_message_tween = create_tween()
	_message_tween.tween_interval(1.4)
	_message_tween.tween_property(_message, "modulate:a", 0.0, 0.6)


## Simple crosshair drawn in the screen center.
class Crosshair:
	extends Control

	func _draw() -> void:
		var c := size / 2.0
		var col := Color(1, 1, 1, 0.75)
		draw_rect(Rect2(c + Vector2(-8, -1), Vector2(16, 2)), col)
		draw_rect(Rect2(c + Vector2(-1, -8), Vector2(2, 16)), col)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()
