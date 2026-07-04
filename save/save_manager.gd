extends Node
## Autoloaded as "SaveManager". F5 saves, F9 loads; main.gd also autosaves on
## window close.
##
## Save format: one JSON file at user://voxelcraft_save.json containing
##   version, world seed, game mode, time of day,
##   player {position, yaw, pitch, health, hunger, spawn point},
##   the full 36-slot inventory + hotbar selection,
##   every furnace's contents/progress, and the EDIT OVERLAY ONLY — a dict
##   of "x,y,z" -> block id for every block the player changed.
## Terrain is never serialized: on load the world regenerates from the seed
## and re-applies the overlay, so save files stay tiny no matter how far you
## explore. Live mobs are intentionally NOT saved — the spawner repopulates
## the world naturally. TODO: persistent named mobs.

const SAVE_PATH := "user://voxelcraft_save.json"
const SAVE_VERSION := 2


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("save_game"):
		if save_game():
			_toast("Game saved")
	elif event.is_action_pressed("load_game"):
		if load_game():
			_toast("Game loaded")
		else:
			_toast("No save found")


func save_game() -> bool:
	var world: Node = get_tree().get_first_node_in_group("world")
	var player: Node3D = get_tree().get_first_node_in_group("player")
	var furnaces: Node = get_tree().get_first_node_in_group("furnaces")
	var daynight: Node = get_tree().get_first_node_in_group("daynight")
	if world == null or player == null or player.frozen:
		return false  # nothing sensible to save yet
	var stats: Node = player.get_node("Stats")

	var edits_out := {}
	for bp: Vector3i in world.edits.keys():
		edits_out["%d,%d,%d" % [bp.x, bp.y, bp.z]] = world.edits[bp]

	var data := {
		"version": SAVE_VERSION,
		"seed": world.world_seed,
		"mode": int(GameMode.mode),
		"time_of_day": daynight.time_of_day if daynight != null else 0.35,
		"player": {
			"position": _v3_to_array(player.global_position),
			"yaw": player.rotation.y,
			"pitch": player.get_node("Head").rotation.x,
			"health": stats.health,
			"hunger": stats.hunger,
			"spawn": _v3_to_array(player.spawn_point),
		},
		"inventory": Inventory.serialize(),
		"hotbar": Inventory.selected,
		"furnaces": furnaces.serialize() if furnaces != null else {},
		"edits": edits_out,
	}

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Voxelcraft: cannot write save file: %s" % SAVE_PATH)
		return false
	file.store_string(JSON.stringify(data))
	file.close()
	return true


func load_game() -> bool:
	if not has_save():
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary or int(parsed.get("version", 0)) != SAVE_VERSION:
		push_error("Voxelcraft: unreadable or incompatible save file")
		return false

	var world: Node = get_tree().get_first_node_in_group("world")
	var player: Node3D = get_tree().get_first_node_in_group("player")
	var furnaces: Node = get_tree().get_first_node_in_group("furnaces")
	var daynight: Node = get_tree().get_first_node_in_group("daynight")
	var main: Node = get_tree().get_first_node_in_group("main")
	var hud: Node = get_tree().get_first_node_in_group("hud")
	if world == null or player == null:
		return false

	# Rebuild the edit overlay with proper Vector3i keys.
	var edits: Dictionary[Vector3i, int] = {}
	for key: String in parsed["edits"].keys():
		var parts := key.split(",")
		if parts.size() != 3:
			continue
		edits[Vector3i(int(parts[0]), int(parts[1]), int(parts[2]))] = int(parsed["edits"][key])

	# Regenerate the world from seed + overlay.
	world.reset_world(int(parsed["seed"]), edits)

	var p: Dictionary = parsed["player"]
	player.global_position = _array_to_v3(p["position"])
	player.rotation.y = float(p["yaw"])
	player.get_node("Head").rotation.x = float(p["pitch"])
	player.spawn_point = _array_to_v3(p["spawn"])
	player.velocity = Vector3.ZERO
	player.flying = false
	player.get_node("Stats").restore(float(p["health"]), float(p["hunger"]))

	GameMode.set_mode(int(parsed["mode"]))
	Inventory.deserialize(parsed.get("inventory", []))
	Inventory.select(int(parsed.get("hotbar", 0)))
	if furnaces != null:
		furnaces.deserialize(parsed.get("furnaces", {}))
	if daynight != null:
		daynight.time_of_day = float(parsed.get("time_of_day", 0.35))

	# Loading while dead brings you back alive — clear the death screen, and
	# close any open container UI whose backing state just vanished.
	if hud != null:
		hud.close_ui()
		hud.death_screen.visible = false
	if not get_tree().paused:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# Freeze until the chunk under the player streams back in.
	player.frozen = true
	if main != null:
		main.await_spawn_chunk()
	return true


func _toast(text: String) -> void:
	var hud: Node = get_tree().get_first_node_in_group("hud")
	if hud != null:
		hud.show_message(text)


func _v3_to_array(v: Vector3) -> Array:
	return [v.x, v.y, v.z]


func _array_to_v3(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))
