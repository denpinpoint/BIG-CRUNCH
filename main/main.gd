extends Node3D
## Root orchestrator: places the player once their spawn chunk has streamed
## in, and autosaves on window close.

@onready var _world: Node3D = $World
@onready var _player: CharacterBody3D = $Player

## True while waiting for the chunk under the player to load.
var _awaiting_spawn := true
## False on first run (compute a fresh surface spawn); true after load_game
## (player position came from the save file).
var _position_from_save := false


func _ready() -> void:
	add_to_group("main")
	# We handle the quit request ourselves so we can autosave first.
	get_tree().auto_accept_quit = false


func _process(_delta: float) -> void:
	if not _awaiting_spawn:
		return
	var bp := Constants.world_to_block(_player.global_position)
	if not _world.is_chunk_loaded(Constants.block_to_chunk(bp)):
		return
	if not _position_from_save:
		# Fresh world: spawn on the surface at the origin.
		var sy: int = _world.surface_y(0, 0)
		_player.spawn_point = Vector3(0.5, sy + 1.1, 0.5)
		_player.global_position = _player.spawn_point
	_player.frozen = false
	_awaiting_spawn = false


## Called by SaveManager after a load: wait for the saved position's chunk.
func await_spawn_chunk() -> void:
	_awaiting_spawn = true
	_position_from_save = true


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		SaveManager.save_game()  # autosave on quit
		get_tree().quit()
