extends Node3D
## Chunk manager: streams an infinite world around the player.
##
## Threading model (how we avoid data races):
##  * Generation + meshing run on WorkerThreadPool tasks. Each task gets an
##    immutable job snapshot: the chunk position, the shared read-only
##    TerrainGenerator, and a duplicate() of the player-edit overlay (packed
##    arrays / dictionaries are value-snapshotted, so the main thread can keep
##    mutating its own copies freely).
##  * Workers build the ArrayMesh and ConcavePolygonShape3D entirely off-tree
##    (Resources are safe to construct on any thread), then push the finished
##    result into a Mutex-guarded queue.
##  * ONLY the main thread touches the scene tree: each frame it pops finished
##    results within a small time budget (MESH_APPLY_BUDGET_USEC) and
##    instantiates/attaches chunk nodes — no hitches, no cross-thread node
##    access.
##  * Player edits re-mesh synchronously on the main thread (a click is rare
##    and a single chunk re-mesh is fast enough); a per-chunk revision counter
##    makes any in-flight stale async result get discarded on arrival.
##
## Block truth is ALWAYS "deterministic generator + edits overlay". Loaded
## chunk arrays are just a cache of that, which is why border culling against
## unloaded neighbors is exact and needs no re-mesh when neighbors arrive.

signal chunk_ready(cpos: Vector2i)

var world_seed: int = Constants.DEFAULT_SEED
var generator: TerrainGenerator
## Player edits: world block pos -> block id. This is the entire delta
## between the procedural world and the actual world — it's also exactly
## what gets saved to disk.
var edits: Dictionary[Vector3i, int] = {}
var chunks: Dictionary[Vector2i, Chunk] = {}

var _to_generate: Array[Vector2i] = []
var _pending: Dictionary[Vector2i, bool] = {}  # submitted to a worker
var _results: Array = []
var _results_mutex := Mutex.new()
var _task_ids: Array[int] = []
var _max_inflight: int = 4
## Bumped when the whole world resets (load game): results from a previous
## world are recognized and dropped.
var _epoch: int = 0
var _stream_timer := 0.0


func _ready() -> void:
	add_to_group("world")
	# Keep streaming terrain even while the start menu has the tree paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	generator = TerrainGenerator.new(world_seed)
	_max_inflight = clampi(OS.get_processor_count() - 1, 2, 8)


func _exit_tree() -> void:
	# Never leave worker tasks running against a freed node: block until every
	# in-flight generation task has finished before this world goes away.
	for id in _task_ids:
		WorkerThreadPool.wait_for_task_completion(id)
	_task_ids.clear()


func _process(_delta: float) -> void:
	_reap_finished_tasks()
	_apply_results_within_budget()

	_stream_timer -= _delta
	if _stream_timer <= 0.0:
		_stream_timer = 0.25
		_update_desired_chunks()
	_submit_jobs()


# --- Streaming --------------------------------------------------------------

func _center_chunk() -> Vector2i:
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if player == null:
		return Vector2i.ZERO
	return Constants.block_to_chunk(Constants.world_to_block(player.global_position))


func _update_desired_chunks() -> void:
	var center := _center_chunk()
	var r := Constants.RENDER_DISTANCE

	# Queue missing chunks inside the render circle...
	_to_generate.clear()
	for dz in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if Vector2(dx, dz).length() > float(r) + 0.01:
				continue
			var cpos := center + Vector2i(dx, dz)
			if chunks.has(cpos) or _pending.has(cpos):
				continue
			_to_generate.append(cpos)
	# ...nearest first.
	_to_generate.sort_custom(
		func(a: Vector2i, b: Vector2i) -> bool:
			return Vector2(a - center).length_squared() < Vector2(b - center).length_squared()
	)

	# Unload chunks beyond the unload ring (mesh + data freed; the edits
	# overlay keeps every player change, so nothing is lost).
	var unload_r := float(Constants.UNLOAD_DISTANCE)
	for cpos: Vector2i in chunks.keys():
		if Vector2(cpos - center).length() > unload_r:
			chunks[cpos].queue_free()
			chunks.erase(cpos)
	for cpos: Vector2i in _pending.keys():
		if Vector2(cpos - center).length() > unload_r:
			_pending.erase(cpos)  # in-flight result will be discarded on arrival


func _submit_jobs() -> void:
	while _pending.size() < _max_inflight and not _to_generate.is_empty():
		var cpos: Vector2i = _to_generate.pop_front()
		if chunks.has(cpos) or _pending.has(cpos):
			continue
		_pending[cpos] = true
		var job := {
			"cpos": cpos,
			"epoch": _epoch,
			"edits": edits.duplicate(),  # snapshot; main thread keeps mutating its own
			"generator": generator,
			"opaque_mat": BlockLibrary.opaque_material,
			"water_mat": BlockLibrary.water_material,
		}
		_task_ids.append(WorkerThreadPool.add_task(_worker_build.bind(job), false, "voxel chunk build"))


## Runs on a WorkerThreadPool thread. Touches no scene state.
func _worker_build(job: Dictionary) -> void:
	var cpos: Vector2i = job["cpos"]
	var data: PackedByteArray = job["generator"].generate_chunk_data(cpos)

	# Overlay player edits that fall inside this chunk.
	var job_edits: Dictionary[Vector3i, int] = job["edits"]
	for wp: Vector3i in job_edits.keys():
		if Constants.block_to_chunk(wp) == cpos:
			data[Constants.local_block_index(Constants.block_to_local(wp))] = job_edits[wp]

	var sampler := ChunkMesher.WorldSampler.new(cpos, data, job_edits, job["generator"])
	var built := ChunkMesher.build(sampler, job["opaque_mat"], job["water_mat"])

	_results_mutex.lock()
	_results.append({
		"cpos": cpos,
		"epoch": job["epoch"],
		"data": data,
		"mesh": built["mesh"],
		"shape": built["shape"],
	})
	_results_mutex.unlock()


func _reap_finished_tasks() -> void:
	# WorkerThreadPool tasks must be waited on to free their bookkeeping.
	var i := 0
	while i < _task_ids.size():
		if WorkerThreadPool.is_task_completed(_task_ids[i]):
			WorkerThreadPool.wait_for_task_completion(_task_ids[i])
			_task_ids.remove_at(i)
		else:
			i += 1


func _apply_results_within_budget() -> void:
	var start := Time.get_ticks_usec()
	while true:
		_results_mutex.lock()
		var result: Variant = _results.pop_front() if not _results.is_empty() else null
		_results_mutex.unlock()
		if result == null:
			return

		if result["epoch"] != _epoch:
			continue  # from a world that no longer exists
		var cpos: Vector2i = result["cpos"]
		if not _pending.has(cpos) or chunks.has(cpos):
			continue  # unloaded (or superseded) while the worker ran
		_pending.erase(cpos)

		var chunk := Chunk.new()
		chunk.setup(cpos, result["data"])
		add_child(chunk)
		chunk.apply_mesh(result["mesh"], result["shape"])
		chunks[cpos] = chunk
		chunk_ready.emit(cpos)

		# Frame budget: attaching meshes/colliders isn't free; spread the work
		# over frames instead of hitching.
		if Time.get_ticks_usec() - start > Constants.MESH_APPLY_BUDGET_USEC:
			return


# --- Block access -----------------------------------------------------------

## Block id at a world block position. Loaded chunks answer from their cached
## data; unloaded positions answer from edits + deterministic generation, so
## this is valid ANYWHERE in the infinite world.
func get_block(bp: Vector3i) -> int:
	if bp.y < 0:
		return BlockTypes.BEDROCK
	if bp.y >= Constants.CHUNK_SIZE_Y:
		return BlockTypes.AIR
	var cpos := Constants.block_to_chunk(bp)
	if chunks.has(cpos):
		return chunks[cpos].get_block_local(Constants.block_to_local(bp))
	if edits.has(bp):
		return edits[bp]
	return generator.generate_block(bp.x, bp.y, bp.z)


func is_solid(bp: Vector3i) -> bool:
	return BlockTypes.is_solid(get_block(bp))


## Sets a block (player edit). Records the edit overlay, updates the chunk
## cache, and synchronously re-meshes the edited chunk plus any neighbor
## chunk whose border face visibility changed — the minimal re-mesh set.
func set_block(bp: Vector3i, id: int) -> void:
	if bp.y < 0 or bp.y >= Constants.CHUNK_SIZE_Y:
		return
	# TODO: prune entries that happen to match procedural generation again
	# (e.g. place stone where stone generated) to keep save files minimal.
	edits[bp] = id

	var cpos := Constants.block_to_chunk(bp)
	if not chunks.has(cpos):
		return  # applied lazily when the chunk generates
	chunks[cpos].set_block_local(Constants.block_to_local(bp), id)
	_remesh_now(cpos)

	# A block on a chunk border also changes the neighbor's face culling.
	var l := Constants.block_to_local(bp)
	if l.x == 0:
		_remesh_now(cpos + Vector2i(-1, 0))
	elif l.x == Constants.CHUNK_SIZE_X - 1:
		_remesh_now(cpos + Vector2i(1, 0))
	if l.z == 0:
		_remesh_now(cpos + Vector2i(0, -1))
	elif l.z == Constants.CHUNK_SIZE_Z - 1:
		_remesh_now(cpos + Vector2i(0, 1))


func _remesh_now(cpos: Vector2i) -> void:
	if not chunks.has(cpos):
		return
	var chunk: Chunk = chunks[cpos]
	var sampler := ChunkMesher.WorldSampler.new(cpos, chunk.data, edits, generator)
	var built := ChunkMesher.build(sampler, BlockLibrary.opaque_material, BlockLibrary.water_material)
	chunk.apply_mesh(built["mesh"], built["shape"])


## Y of the highest solid block in a column (-1 if none). Respects edits.
func surface_y(wx: int, wz: int) -> int:
	for y in range(Constants.CHUNK_SIZE_Y - 1, -1, -1):
		if is_solid(Vector3i(wx, y, wz)):
			return y
	return -1


func is_chunk_loaded(cpos: Vector2i) -> bool:
	return chunks.has(cpos)


# --- World lifecycle --------------------------------------------------------

## Rebuild the world from a seed + edit overlay (used by load, and by "new
## world" flows). Terrain regenerates from the seed; edits re-apply on top.
func reset_world(new_seed: int, new_edits: Dictionary[Vector3i, int]) -> void:
	_epoch += 1
	for chunk: Chunk in chunks.values():
		chunk.queue_free()
	chunks.clear()
	_pending.clear()
	_to_generate.clear()
	_results_mutex.lock()
	_results.clear()
	_results_mutex.unlock()
	world_seed = new_seed
	edits = new_edits
	generator = TerrainGenerator.new(new_seed)
	_stream_timer = 0.0


# --- Debug ------------------------------------------------------------------

func stats() -> Dictionary:
	return {
		"loaded": chunks.size(),
		"pending": _pending.size(),
		"queued": _to_generate.size(),
		"edits": edits.size(),
	}
