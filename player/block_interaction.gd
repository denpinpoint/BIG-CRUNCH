extends Node
## Block targeting, breaking, placing, and melee combat.
##
## Block targeting uses a manual voxel DDA raycast (Amanatides & Woo) rather
## than PhysicsRayQuery: it walks the exact grid cells the eye ray passes
## through, so the targeted block and hit face are always precise regardless
## of collider tessellation. Mobs, on the other hand, ARE physics bodies, so
## melee attacks use a physics ray on the mob layer; whichever hit is closer
## (mob vs block) wins the click.

signal breaking(progress: float)  # 0..1, 0 = not breaking (HUD progress bar)

@onready var _player: CharacterBody3D = get_parent()
@onready var _camera: Camera3D = get_parent().get_node("Head/Camera")

var _world: Node3D
var _hotbar: Control
var _highlight: MeshInstance3D

var _break_target := Vector3i(0, -1000, 0)
var _break_progress := 0.0
var _attack_cd := 0.0
var _place_cd := 0.0
var _creative_break_cd := 0.0


func _ready() -> void:
	# Siblings registered their groups in their own _ready (scene order puts
	# World before Player under Main).
	_world = get_tree().get_first_node_in_group("world")
	_build_highlight()


func _physics_process(delta: float) -> void:
	_attack_cd = maxf(_attack_cd - delta, 0.0)
	_place_cd = maxf(_place_cd - delta, 0.0)
	_creative_break_cd = maxf(_creative_break_cd - delta, 0.0)

	if not _player.can_interact():
		_highlight.visible = false
		_reset_break()
		return

	var origin := _camera.global_position
	var dir := -_camera.global_transform.basis.z

	var mob_hit := _ray_mob(origin, dir)
	var block_hit := _voxel_raycast(origin, dir, Constants.REACH)

	# A mob in front of the targeted block soaks the click.
	if not mob_hit.is_empty() and (block_hit.is_empty() or mob_hit["dist"] < block_hit["dist"]):
		_highlight.visible = false
		_reset_break()
		if Input.is_action_pressed("break") and _attack_cd <= 0.0:
			_attack_cd = Constants.PLAYER_ATTACK_COOLDOWN
			var knock: Vector3 = dir
			knock.y = 0.0
			mob_hit["mob"].take_damage(Constants.PLAYER_ATTACK_DAMAGE, knock.normalized())
		return

	if block_hit.is_empty():
		_highlight.visible = false
		_reset_break()
		return

	var bp: Vector3i = block_hit["pos"]
	_highlight.visible = true
	_highlight.global_position = Vector3(bp)

	if Input.is_action_pressed("break"):
		_handle_breaking(bp, block_hit["id"], delta)
	else:
		_reset_break()

	if Input.is_action_pressed("place") and _place_cd <= 0.0:
		_handle_placing(bp, block_hit["normal"])


func _handle_breaking(bp: Vector3i, id: int, delta: float) -> void:
	if GameMode.is_creative():
		# Instant break, any block, hold to keep chewing through terrain.
		if _creative_break_cd <= 0.0:
			_world.set_block(bp, BlockTypes.AIR)
			_creative_break_cd = Constants.CREATIVE_BREAK_DELAY
		return

	var hard := BlockTypes.hardness(id)
	if hard < 0.0:
		_reset_break()  # unbreakable (bedrock)
		return
	if bp != _break_target:
		_break_target = bp
		_break_progress = 0.0
	# Hold-to-mine: time scales with block hardness.
	_break_progress += delta / maxf(hard * Constants.BREAK_TIME_PER_HARDNESS, 0.05)
	if _break_progress >= 1.0:
		_world.set_block(bp, BlockTypes.AIR)
		# TODO: spawn an item-drop entity here once pickups exist.
		_reset_break()
	else:
		breaking.emit(_break_progress)


func _handle_placing(bp: Vector3i, normal: Vector3i) -> void:
	if _hotbar == null:
		_hotbar = get_tree().get_first_node_in_group("hotbar")
		if _hotbar == null:
			return
	var cell := bp + normal
	var current: int = _world.get_block(cell)
	# Only into air or replaceable fluid.
	if current != BlockTypes.AIR and not BlockTypes.is_fluid(current):
		return
	if _intersects_player(cell):
		return  # never build a block inside your own body
	# TODO: also reject cells overlapping mobs.
	_world.set_block(cell, _hotbar.selected_block())
	_place_cd = Constants.PLACE_REPEAT_DELAY


func _reset_break() -> void:
	if _break_progress != 0.0:
		breaking.emit(0.0)
	_break_progress = 0.0
	_break_target = Vector3i(0, -1000, 0)


## Voxel DDA (Amanatides & Woo): step the ray cell-by-cell through the block
## grid. At each boundary crossing we advance along whichever axis has the
## nearest crossing (smallest t_max), which visits every cell the ray touches
## in order. The face normal is simply minus the step direction of the axis
## we crossed last. The starting cell is intentionally skipped (you can't
## target the block your head is inside).
func _voxel_raycast(origin: Vector3, dir: Vector3, max_dist: float) -> Dictionary:
	var bp := Vector3i(origin.floor())
	var step := Vector3i(
		1 if dir.x > 0.0 else -1,
		1 if dir.y > 0.0 else -1,
		1 if dir.z > 0.0 else -1
	)
	var t_max := Vector3.ZERO   # ray distance to the next boundary per axis
	var t_delta := Vector3.ZERO # ray distance between consecutive boundaries
	for i in 3:
		if absf(dir[i]) < 1e-9:
			t_max[i] = INF
			t_delta[i] = INF
		else:
			t_delta[i] = absf(1.0 / dir[i])
			var boundary := float(bp[i] + (1 if dir[i] > 0.0 else 0))
			t_max[i] = (boundary - origin[i]) / dir[i]

	while true:
		var axis := 0
		if t_max.y < t_max.x:
			axis = 1
		if t_max.z < t_max[axis]:
			axis = 2
		var t: float = t_max[axis]
		if t > max_dist:
			return {}
		t_max[axis] += t_delta[axis]
		bp[axis] += step[axis]
		var normal := Vector3i.ZERO
		normal[axis] = -step[axis]
		var id: int = _world.get_block(bp)
		if BlockTypes.is_solid(id):
			return {"pos": bp, "normal": normal, "dist": t, "id": id}
	return {}


func _ray_mob(origin: Vector3, dir: Vector3) -> Dictionary:
	var space := _player.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		origin, origin + dir * Constants.REACH,
		0b100,  # layer 3 = mobs
		[_player.get_rid()]
	)
	var hit := space.intersect_ray(query)
	if hit.is_empty() or not hit["collider"] is MobBase:
		return {}
	return {"mob": hit["collider"], "dist": origin.distance_to(hit["position"])}


func _intersects_player(cell: Vector3i) -> bool:
	var p := _player.global_position  # feet
	var player_aabb := AABB(p - Vector3(0.36, 0.0, 0.36), Vector3(0.72, 1.85, 0.72))
	return player_aabb.intersects(AABB(Vector3(cell), Vector3.ONE))


## Wireframe cube (12 edges as a LINES surface), slightly inflated so it
## never z-fights the block faces it outlines.
func _build_highlight() -> void:
	var lo := -0.004
	var hi := 1.004
	var corners := [
		Vector3(lo, lo, lo), Vector3(hi, lo, lo), Vector3(hi, lo, hi), Vector3(lo, lo, hi),
		Vector3(lo, hi, lo), Vector3(hi, hi, lo), Vector3(hi, hi, hi), Vector3(lo, hi, hi),
	]
	var edges := [
		0, 1, 1, 2, 2, 3, 3, 0,  # bottom ring
		4, 5, 5, 6, 6, 7, 7, 4,  # top ring
		0, 4, 1, 5, 2, 6, 3, 7,  # verticals
	]
	var verts := PackedVector3Array()
	for e: int in edges:
		verts.push_back(corners[e])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.05, 0.05, 0.05)
	mesh.surface_set_material(0, mat)

	_highlight = MeshInstance3D.new()
	_highlight.mesh = mesh
	_highlight.visible = false
	_highlight.top_level = true  # world-space position, not relative to player
	add_child(_highlight)
