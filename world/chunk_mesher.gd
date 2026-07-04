class_name ChunkMesher
## Turns a chunk's flat block array into an ArrayMesh (+ collision shape).
## Pure static code with no scene access, so it runs safely on worker threads.
##
## Face culling: a quad is emitted ONLY when the block behind that face does
## not occlude it (air, water, or any non-solid). Interior faces never exist,
## which keeps vertex counts a tiny fraction of blocks*36.
##
## Chunk borders: when a face's neighbor lies outside this chunk, we resolve
## it through WorldSampler, which answers from (a) the player-edit overlay or
## (b) the deterministic terrain generator. Because a loaded neighbor chunk's
## data is BY CONSTRUCTION identical to generator+edits, this always matches
## what the neighbor actually renders — no seams, and no re-meshing needed
## when neighbors stream in later.
##
## Vertex layout: plain indexed triangles. For every visible face we append
## 4 vertices (position/normal/UV) and 6 indices (two triangles 0-1-2, 0-2-3).
## Godot front faces wind CLOCKWISE, and the FACES table below is written in
## clockwise order as seen from outside each face — verified so lighting and
## back-face culling behave.

const FACE_TOP := 0
const FACE_BOTTOM := 1
const FACE_NORTH := 2  # -Z
const FACE_SOUTH := 3  # +Z
const FACE_WEST := 4   # -X
const FACE_EAST := 5   # +X

# Per face: outward normal, the 4 corner offsets (clockwise from outside),
# and the matching UV corners (u/v in tile space; v grows downward so side
# faces keep grass strips on top).
const FACES := [
	{  # top (+Y)
		"dir": Vector3i(0, 1, 0),
		"verts": [Vector3(0, 1, 0), Vector3(1, 1, 0), Vector3(1, 1, 1), Vector3(0, 1, 1)],
		"uvs": [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)],
	},
	{  # bottom (-Y)
		"dir": Vector3i(0, -1, 0),
		"verts": [Vector3(0, 0, 0), Vector3(0, 0, 1), Vector3(1, 0, 1), Vector3(1, 0, 0)],
		"uvs": [Vector2(0, 0), Vector2(0, 1), Vector2(1, 1), Vector2(1, 0)],
	},
	{  # north (-Z)
		"dir": Vector3i(0, 0, -1),
		"verts": [Vector3(1, 0, 0), Vector3(1, 1, 0), Vector3(0, 1, 0), Vector3(0, 0, 0)],
		"uvs": [Vector2(1, 1), Vector2(1, 0), Vector2(0, 0), Vector2(0, 1)],
	},
	{  # south (+Z)
		"dir": Vector3i(0, 0, 1),
		"verts": [Vector3(0, 0, 1), Vector3(0, 1, 1), Vector3(1, 1, 1), Vector3(1, 0, 1)],
		"uvs": [Vector2(0, 1), Vector2(0, 0), Vector2(1, 0), Vector2(1, 1)],
	},
	{  # west (-X)
		"dir": Vector3i(-1, 0, 0),
		"verts": [Vector3(0, 0, 0), Vector3(0, 1, 0), Vector3(0, 1, 1), Vector3(0, 0, 1)],
		"uvs": [Vector2(0, 1), Vector2(0, 0), Vector2(1, 0), Vector2(1, 1)],
	},
	{  # east (+X)
		"dir": Vector3i(1, 0, 0),
		"verts": [Vector3(1, 0, 1), Vector3(1, 1, 1), Vector3(1, 1, 0), Vector3(1, 0, 0)],
		"uvs": [Vector2(1, 1), Vector2(1, 0), Vector2(0, 0), Vector2(0, 1)],
	},
]


## Resolves block ids during meshing, including outside this chunk's bounds.
class WorldSampler:
	var chunk_pos: Vector2i
	var data: PackedByteArray                 # this chunk's blocks snapshot
	var edits: Dictionary[Vector3i, int]      # player-edit overlay snapshot
	var generator: TerrainGenerator           # shared, read-only, thread-safe
	var _base: Vector3i

	func _init(p_chunk_pos: Vector2i, p_data: PackedByteArray, p_edits: Dictionary[Vector3i, int], p_gen: TerrainGenerator) -> void:
		chunk_pos = p_chunk_pos
		data = p_data
		edits = p_edits
		generator = p_gen
		_base = Vector3i(chunk_pos.x * Constants.CHUNK_SIZE_X, 0, chunk_pos.y * Constants.CHUNK_SIZE_Z)

	## local coordinate may be 1 step outside the chunk on any axis.
	func block_at_local(l: Vector3i) -> int:
		if l.y < 0:
			return BlockTypes.BEDROCK  # below the world: treat as solid, cull bottoms
		if l.y >= Constants.CHUNK_SIZE_Y:
			return BlockTypes.AIR
		if Constants.local_in_bounds(l):
			return data[Constants.local_block_index(l)]
		# Outside this chunk: edits overlay wins, then pure generation.
		var wp := _base + l
		if edits.has(wp):
			return edits[wp]
		return generator.generate_block(wp.x, wp.y, wp.z)


## Result: { "mesh": ArrayMesh or null, "shape": ConcavePolygonShape3D or null }
## PERF: ~16k blocks x 6 neighbor checks per chunk in GDScript. Fine off the
## main thread; port to C#/GDExtension if you push render distance way up.
static func build(sampler: WorldSampler, opaque_mat: Material, water_mat: Material) -> Dictionary:
	var solid_verts := PackedVector3Array()
	var solid_normals := PackedVector3Array()
	var solid_uvs := PackedVector2Array()
	var solid_indices := PackedInt32Array()
	var water_verts := PackedVector3Array()
	var water_normals := PackedVector3Array()
	var water_uvs := PackedVector2Array()
	var water_indices := PackedInt32Array()
	# Collision uses non-indexed triangle soup (ConcavePolygonShape3D wants
	# every 3 vertices = 1 triangle). Solid blocks only — water isn't walkable.
	var collision_faces := PackedVector3Array()

	for lz in Constants.CHUNK_SIZE_Z:
		for ly in Constants.CHUNK_SIZE_Y:
			for lx in Constants.CHUNK_SIZE_X:
				var l := Vector3i(lx, ly, lz)
				var id := sampler.data[Constants.local_block_index(l)]
				if id == BlockTypes.AIR:
					continue
				var is_water := BlockTypes.is_fluid(id)
				for face in 6:
					var neighbor: int = sampler.block_at_local(l + FACES[face]["dir"])
					if is_water:
						# Water surfaces only show against air.
						if neighbor != BlockTypes.AIR:
							continue
					else:
						# Solid faces show against anything that doesn't occlude
						# (air, water, other non-solids).
						if BlockTypes.is_solid(neighbor):
							continue
					if is_water:
						_emit_face(l, id, face, water_verts, water_normals, water_uvs, water_indices)
					else:
						_emit_face(l, id, face, solid_verts, solid_normals, solid_uvs, solid_indices)
						_emit_collision(l, face, collision_faces)

	var result := {"mesh": null, "shape": null}
	if solid_verts.is_empty() and water_verts.is_empty():
		return result

	var mesh := ArrayMesh.new()
	if not solid_verts.is_empty():
		mesh.add_surface_from_arrays(
			Mesh.PRIMITIVE_TRIANGLES,
			_surface_arrays(solid_verts, solid_normals, solid_uvs, solid_indices)
		)
		mesh.surface_set_material(mesh.get_surface_count() - 1, opaque_mat)
	if not water_verts.is_empty():
		mesh.add_surface_from_arrays(
			Mesh.PRIMITIVE_TRIANGLES,
			_surface_arrays(water_verts, water_normals, water_uvs, water_indices)
		)
		mesh.surface_set_material(mesh.get_surface_count() - 1, water_mat)
	result["mesh"] = mesh

	if not collision_faces.is_empty():
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(collision_faces)
		result["shape"] = shape
	return result


static func _surface_arrays(verts: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array, indices: PackedInt32Array) -> Array:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	return arrays


static func _emit_face(l: Vector3i, id: int, face: int, verts: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array, indices: PackedInt32Array) -> void:
	var base_index := verts.size()
	var origin := Vector3(l)
	var normal := Vector3(FACES[face]["dir"])
	var rect := BlockTypes.uv_rect(BlockTypes.tile_for_face(id, face))
	var face_verts: Array = FACES[face]["verts"]
	var face_uvs: Array = FACES[face]["uvs"]
	for i in 4:
		verts.push_back(origin + face_verts[i])
		normals.push_back(normal)
		uvs.push_back(rect.position + face_uvs[i] * rect.size)
	# Two clockwise triangles per quad.
	indices.push_back(base_index)
	indices.push_back(base_index + 1)
	indices.push_back(base_index + 2)
	indices.push_back(base_index)
	indices.push_back(base_index + 2)
	indices.push_back(base_index + 3)


static func _emit_collision(l: Vector3i, face: int, collision_faces: PackedVector3Array) -> void:
	var origin := Vector3(l)
	var face_verts: Array = FACES[face]["verts"]
	collision_faces.push_back(origin + face_verts[0])
	collision_faces.push_back(origin + face_verts[1])
	collision_faces.push_back(origin + face_verts[2])
	collision_faces.push_back(origin + face_verts[0])
	collision_faces.push_back(origin + face_verts[2])
	collision_faces.push_back(origin + face_verts[3])
