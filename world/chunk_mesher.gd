class_name ChunkMesher
## Turns a chunk's flat block array into an ArrayMesh (+ collision shape).
## Pure static code with no scene access, so it runs safely on worker threads.
##
## Face culling: a quad is emitted ONLY when the block behind that face does
## not OCCLUDE it (air, water, glass, stairs, any non-occluder). Interior
## faces never exist, which keeps vertex counts a tiny fraction of blocks*36.
##
## Chunk borders: when a face's neighbor lies outside this chunk, we resolve
## it through WorldSampler, which answers from (a) the player-edit overlay or
## (b) the deterministic terrain generator. Because a loaded neighbor chunk's
## data is BY CONSTRUCTION identical to generator+edits, this always matches
## what the neighbor actually renders — no seams, and no re-meshing needed
## when neighbors stream in later.
##
## Surfaces: up to three per chunk — opaque, glass (alpha-scissor cutout),
## and water (alpha blend). Stairs emit custom two-box geometry into the
## opaque surface with UVs cropped to each face's real extents (no texture
## stretching on half-height faces).
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

# Per face: outward normal + the 4 corner selectors (0 = box min on that
# axis, 1 = box max), in clockwise order as seen from outside. UVs are
# computed from the vertex coordinates (see _face_uv), which both matches
# the old per-face tables for unit cubes and crops correctly for sub-boxes.
const FACES := [
	{"dir": Vector3i(0, 1, 0), "verts": [Vector3(0, 1, 0), Vector3(1, 1, 0), Vector3(1, 1, 1), Vector3(0, 1, 1)]},
	{"dir": Vector3i(0, -1, 0), "verts": [Vector3(0, 0, 0), Vector3(0, 0, 1), Vector3(1, 0, 1), Vector3(1, 0, 0)]},
	{"dir": Vector3i(0, 0, -1), "verts": [Vector3(1, 0, 0), Vector3(1, 1, 0), Vector3(0, 1, 0), Vector3(0, 0, 0)]},
	{"dir": Vector3i(0, 0, 1), "verts": [Vector3(0, 0, 1), Vector3(0, 1, 1), Vector3(1, 1, 1), Vector3(1, 0, 1)]},
	{"dir": Vector3i(-1, 0, 0), "verts": [Vector3(0, 0, 0), Vector3(0, 1, 0), Vector3(0, 1, 1), Vector3(0, 0, 1)]},
	{"dir": Vector3i(1, 0, 0), "verts": [Vector3(1, 0, 1), Vector3(1, 1, 1), Vector3(1, 1, 0), Vector3(1, 0, 0)]},
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


## One growing surface (verts/normals/uvs/indices) plus collision triangles.
class MeshBucket:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()


## Result: { "mesh": ArrayMesh or null, "shape": ConcavePolygonShape3D or null }
## PERF: ~24k blocks x 6 neighbor checks per chunk in GDScript. Fine off the
## main thread; port to C#/GDExtension if you push render distance way up.
static func build(sampler: WorldSampler, opaque_mat: Material, glass_mat: Material, water_mat: Material) -> Dictionary:
	var opaque := MeshBucket.new()
	var glass := MeshBucket.new()
	var water := MeshBucket.new()
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

				if BlockTypes.is_stairs(id):
					_emit_stairs(sampler, l, id, opaque, collision_faces)
					continue

				var is_water := BlockTypes.is_fluid(id)
				var is_glass := id == BlockTypes.GLASS
				for face in 6:
					var neighbor: int = sampler.block_at_local(l + FACES[face]["dir"])
					if is_water:
						# Water surfaces only show against air.
						if neighbor != BlockTypes.AIR:
							continue
						_emit_face(l, id, face, Vector3.ZERO, Vector3.ONE, water)
					elif is_glass:
						# Glass hides faces shared with other glass; shows
						# against anything else that doesn't occlude it.
						if neighbor == BlockTypes.GLASS or BlockTypes.occludes(neighbor):
							continue
						_emit_face(l, id, face, Vector3.ZERO, Vector3.ONE, glass)
						_emit_collision_face(l, face, Vector3.ZERO, Vector3.ONE, collision_faces)
					else:
						if BlockTypes.occludes(neighbor):
							continue
						_emit_face(l, id, face, Vector3.ZERO, Vector3.ONE, opaque)
						_emit_collision_face(l, face, Vector3.ZERO, Vector3.ONE, collision_faces)

	var result := {"mesh": null, "shape": null}
	if opaque.verts.is_empty() and glass.verts.is_empty() and water.verts.is_empty():
		return result

	var mesh := ArrayMesh.new()
	for pair: Array in [[opaque, opaque_mat], [glass, glass_mat], [water, water_mat]]:
		var bucket: MeshBucket = pair[0]
		if bucket.verts.is_empty():
			continue
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = bucket.verts
		arrays[Mesh.ARRAY_NORMAL] = bucket.normals
		arrays[Mesh.ARRAY_TEX_UV] = bucket.uvs
		arrays[Mesh.ARRAY_INDEX] = bucket.indices
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, pair[1])
	result["mesh"] = mesh

	if not collision_faces.is_empty():
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(collision_faces)
		result["shape"] = shape
	return result


## Stairs = a full-footprint bottom slab + a half-depth top box on the
## block's "stair_dir" side. The slab top is emitted full-width (the top box
## simply sits on it — no coplanar duplicate face, so no z-fighting) and the
## top box skips its bottom face. Only the slab bottom is neighbor-culled;
## the rest is always visible from somewhere.
static func _emit_stairs(sampler: WorldSampler, l: Vector3i, id: int, bucket: MeshBucket, collision_faces: PackedVector3Array) -> void:
	var dir: Vector3i = BlockTypes.DEFS[id]["stair_dir"]

	# Bottom slab.
	var slab_min := Vector3(0, 0, 0)
	var slab_max := Vector3(1, 0.5, 1)
	var below: int = sampler.block_at_local(l + Vector3i(0, -1, 0))
	for face in 6:
		if face == FACE_BOTTOM and BlockTypes.occludes(below):
			_emit_collision_face(l, face, slab_min, slab_max, collision_faces)
			continue  # hidden, but still walkable geometry
		_emit_face(l, id, face, slab_min, slab_max, bucket)
		_emit_collision_face(l, face, slab_min, slab_max, collision_faces)

	# Top half-box on the high side.
	var top_min := Vector3(0, 0.5, 0)
	var top_max := Vector3(1, 1, 1)
	if dir.x > 0:
		top_min.x = 0.5
	elif dir.x < 0:
		top_max.x = 0.5
	elif dir.z > 0:
		top_min.z = 0.5
	else:
		top_max.z = 0.5
	for face in 6:
		if face == FACE_BOTTOM:
			continue  # rests on the slab
		_emit_face(l, id, face, top_min, top_max, bucket)
		_emit_collision_face(l, face, top_min, top_max, collision_faces)


## UV mapping per face, from vertex coordinates within the block:
##   +Y/-Y: u = x, v = z;  ±Z: u = x, v = 1-y;  ±X: u = z, v = 1-y.
## Matches the classic full-cube tables exactly and automatically crops the
## tile for sub-boxes (a half-height face samples half the tile — no stretch).
static func _face_uv(face: int, p: Vector3) -> Vector2:
	match face:
		FACE_TOP, FACE_BOTTOM:
			return Vector2(p.x, p.z)
		FACE_NORTH, FACE_SOUTH:
			return Vector2(p.x, 1.0 - p.y)
		_:
			return Vector2(p.z, 1.0 - p.y)


static func _emit_face(l: Vector3i, id: int, face: int, bmin: Vector3, bmax: Vector3, bucket: MeshBucket) -> void:
	var base_index := bucket.verts.size()
	var origin := Vector3(l)
	var normal := Vector3(FACES[face]["dir"])
	var rect := BlockTypes.uv_rect(BlockTypes.tile_for_face(id, face))
	var face_verts: Array = FACES[face]["verts"]
	for i in 4:
		var sel: Vector3 = face_verts[i]
		# Selector 0 -> box min, 1 -> box max, per axis.
		var p := Vector3(
			lerpf(bmin.x, bmax.x, sel.x),
			lerpf(bmin.y, bmax.y, sel.y),
			lerpf(bmin.z, bmax.z, sel.z)
		)
		bucket.verts.push_back(origin + p)
		bucket.normals.push_back(normal)
		bucket.uvs.push_back(rect.position + _face_uv(face, p) * rect.size)
	# Two clockwise triangles per quad.
	bucket.indices.push_back(base_index)
	bucket.indices.push_back(base_index + 1)
	bucket.indices.push_back(base_index + 2)
	bucket.indices.push_back(base_index)
	bucket.indices.push_back(base_index + 2)
	bucket.indices.push_back(base_index + 3)


static func _emit_collision_face(l: Vector3i, face: int, bmin: Vector3, bmax: Vector3, collision_faces: PackedVector3Array) -> void:
	var origin := Vector3(l)
	var face_verts: Array = FACES[face]["verts"]
	var corners: Array[Vector3] = []
	for i in 4:
		var sel: Vector3 = face_verts[i]
		corners.append(origin + Vector3(
			lerpf(bmin.x, bmax.x, sel.x),
			lerpf(bmin.y, bmax.y, sel.y),
			lerpf(bmin.z, bmax.z, sel.z)
		))
	collision_faces.push_back(corners[0])
	collision_faces.push_back(corners[1])
	collision_faces.push_back(corners[2])
	collision_faces.push_back(corners[0])
	collision_faces.push_back(corners[2])
	collision_faces.push_back(corners[3])
