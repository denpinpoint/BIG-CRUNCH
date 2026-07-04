extends CanvasLayer
## HUD root: builds all UI in code (crosshair, hotbar, survival stats, break
## progress, mode menu, death screen, debug overlay) and wires them to the
## player systems via signals.

var hotbar: Hotbar
var stats_bar: StatsBar
var death_screen: DeathScreen
var debug_overlay: DebugOverlay

var _progress: ProgressBar
var _message: Label
var _message_tween: Tween


func _ready() -> void:
	add_to_group("hud")

	var crosshair := Crosshair.new()
	crosshair.set_anchors_preset(Control.PRESET_FULL_RECT)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(crosshair)

	_progress = ProgressBar.new()
	_progress.min_value = 0.0
	_progress.max_value = 1.0
	_progress.show_percentage = false
	_progress.anchor_left = 0.5
	_progress.anchor_right = 0.5
	_progress.anchor_top = 0.5
	_progress.anchor_bottom = 0.5
	_progress.offset_left = -60
	_progress.offset_right = 60
	_progress.offset_top = 26
	_progress.offset_bottom = 36
	_progress.visible = false
	_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_progress)

	hotbar = Hotbar.new()
	hotbar.anchor_left = 0.5
	hotbar.anchor_right = 0.5
	hotbar.anchor_top = 1.0
	hotbar.anchor_bottom = 1.0
	hotbar.offset_left = -196
	hotbar.offset_right = 196
	hotbar.offset_top = -64
	hotbar.offset_bottom = -12
	hotbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hotbar)

	stats_bar = StatsBar.new()
	stats_bar.anchor_left = 0.5
	stats_bar.anchor_right = 0.5
	stats_bar.anchor_top = 1.0
	stats_bar.anchor_bottom = 1.0
	stats_bar.offset_left = -196
	stats_bar.offset_right = 196
	stats_bar.offset_top = -94
	stats_bar.offset_bottom = -68
	stats_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stats_bar)

	_message = Label.new()
	_message.anchor_left = 0.5
	_message.anchor_right = 0.5
	_message.anchor_top = 1.0
	_message.anchor_bottom = 1.0
	_message.offset_left = -200
	_message.offset_right = 200
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

	death_screen = DeathScreen.new()
	death_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(death_screen)

	# --- Wiring ---
	var player: Node = get_tree().get_first_node_in_group("player")
	if player != null:
		var stats: Node = player.get_node("Stats")
		stats.health_changed.connect(func(h: float) -> void: stats_bar.set_health(h))
		stats.hunger_changed.connect(func(h: float) -> void: stats_bar.set_hunger(h))
		stats.died.connect(death_screen.open)
		death_screen.respawn_requested.connect(stats.respawn)
		var interaction: Node = player.get_node("BlockInteraction")
		interaction.breaking.connect(_on_breaking)

	GameMode.mode_changed.connect(_on_mode_changed)
	_on_mode_changed(GameMode.mode)

	# Pick Survival/Creative at world start.
	var menu := ModeMenu.new()
	menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(menu)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_debug"):
		debug_overlay.visible = not debug_overlay.visible


func _on_breaking(progress: float) -> void:
	_progress.visible = progress > 0.0
	_progress.value = progress


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
