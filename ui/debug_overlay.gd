class_name DebugOverlay
extends Label
## F3 debug overlay: FPS, coordinates, chunk/mob counts, mode, clock.

var _timer := 0.0


func _ready() -> void:
	add_theme_font_size_override("font_size", 13)
	add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	add_theme_constant_override("shadow_offset_x", 1)
	add_theme_constant_override("shadow_offset_y", 1)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if not visible:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = 0.25

	var world: Node = get_tree().get_first_node_in_group("world")
	var player: Node3D = get_tree().get_first_node_in_group("player")
	var daynight: Node = get_tree().get_first_node_in_group("daynight")
	if world == null or player == null:
		return

	var bp := Constants.world_to_block(player.global_position)
	var cpos := Constants.block_to_chunk(bp)
	var s: Dictionary = world.stats()
	text = "\n".join([
		"FPS: %d" % Engine.get_frames_per_second(),
		"pos: (%.1f, %.1f, %.1f)  block: %s  chunk: %s" % [
			player.global_position.x, player.global_position.y, player.global_position.z,
			bp, cpos,
		],
		"chunks: %d loaded, %d building, %d queued" % [s["loaded"], s["pending"], s["queued"]],
		"edits: %d   mobs: %d (%d passive / %d hostile)" % [
			s["edits"],
			get_tree().get_nodes_in_group("mobs").size(),
			get_tree().get_nodes_in_group("passive_mobs").size(),
			get_tree().get_nodes_in_group("hostile_mobs").size(),
		],
		"mode: %s   time: %s%s" % [
			GameMode.mode_name(),
			daynight.clock_string() if daynight != null else "?",
			" (night)" if daynight != null and daynight.is_night() else "",
		],
		"seed: %d" % world.world_seed,
	])
