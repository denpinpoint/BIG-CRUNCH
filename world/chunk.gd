class_name Chunk
extends StaticBody3D
## One loaded chunk: block data + its render mesh and trimesh collider.
##
## Block data lives in a flat PackedByteArray indexed by
##   index = x + y * SIZE_X + z * SIZE_X * SIZE_Y
## (x fastest, then y, then z — see Constants.local_block_index). A flat
## packed array is one contiguous allocation with byte elements; nested
## GDScript Arrays would be pointers-to-variants everywhere and ~10x the
## memory and cache misses.

var chunk_pos: Vector2i
var data := PackedByteArray()
## Bumped on every edit. Async mesh results carry the revision they were
## built from; stale results (an edit landed while the worker ran) are
## discarded instead of overwriting the newer synchronous re-mesh.
var revision: int = 0

var _mesh_instance: MeshInstance3D
var _collision_shape: CollisionShape3D


func setup(p_chunk_pos: Vector2i, p_data: PackedByteArray) -> void:
	chunk_pos = p_chunk_pos
	data = p_data
	position = Vector3(chunk_pos.x * Constants.CHUNK_SIZE_X, 0, chunk_pos.y * Constants.CHUNK_SIZE_Z)
	collision_layer = 1  # layer 1 = terrain
	collision_mask = 0
	_mesh_instance = MeshInstance3D.new()
	add_child(_mesh_instance)
	_collision_shape = CollisionShape3D.new()
	add_child(_collision_shape)


func apply_mesh(mesh: ArrayMesh, shape: ConcavePolygonShape3D) -> void:
	_mesh_instance.mesh = mesh
	_collision_shape.shape = shape


func get_block_local(l: Vector3i) -> int:
	return data[Constants.local_block_index(l)]


func set_block_local(l: Vector3i, id: int) -> void:
	data[Constants.local_block_index(l)] = id
	revision += 1


func vertex_count() -> int:
	if _mesh_instance.mesh == null:
		return 0
	var total := 0
	for s in _mesh_instance.mesh.get_surface_count():
		total += _mesh_instance.mesh.surface_get_array_len(s)
	return total
