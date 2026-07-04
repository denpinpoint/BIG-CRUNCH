extends Node
## Block targeting, breaking, placing, and melee combat.
##
## Block targeting uses a manual voxel DDA raycast (Amanatides & Woo) rather
## than PhysicsRayQuery: it walks the exact grid cells the eye ray passes
## through, so the targeted block and hit face are always precise regardless
## of collider tessellation. Mobs, on the other hand, ARE physics bodies, so
## melee attacks use a physics ray on the mob layer; whichever hit is closer
## (mob vs block) wins the click.
##
## Survival mining shows a Minecraft-style crack overlay that deepens with
## progress (textures from BlockLibrary.crack_materials) — no UI bar.

@onready var _player: CharacterBody3D = get_parent()
@onready var _camera: Camera3D = get_parent().get_node("Head/Camera")

var _world: Node3D
var _furnaces: Node
var _hud: Node
var _highlight: MeshInstance3D
var _crack: MeshInstance3D

var _break_target := Vector3i(0, -1000, 0)
var _break_progress := 0.0
var _attack_cd := 0.0
var _place_cd := 0.0
var _creative_break_cd := 0.0
var _eat_time := 0.0

const EAT_TIME := 1.4  # seconds of holding right-click to finish a food


func _ready() -> void:
	# Siblings registered their groups in their own _ready (scene order puts
	# World before Player under Main).
	_world = get_tree().get_first_node_in_group("world")
	_build_overlays()


func _physics_process(delta: float) -> void:
	_attack_cd = maxf(_attack_cd - delta, 0.0)
	_place_cd = maxf(_place_cd - delta, 0.0)
	_creative_break_cd = maxf(_creative_break_cd - delta, 0.0)

	if not _player.can_interact():
		_hide_overlays()
		_reset_break()
		return

	var origin := _camera.global_position
	var dir := -_camera.global_transform.basis.z

	var mob_hit := _ray_mob(origin, dir)
	var block_hit := _voxel_raycast(origin, dir, Constants.REACH)

	# A mob in front of the targeted block soaks the click.
	if not mob_hit.is_empty() and (block_hit.is_empty() or mob_hit["dist"] < block_hit["dist"]):
		_hide_overlays()
		_reset_break()
		if Input.is_action_pressed("break") and _attack_cd <= 0.0:
			_attack_cd = Constants.PLAYER_ATTACK_COOLDOWN
			var knock: Vector3 = dir
			knock.y = 0.0
			# Held sword (or other item) sets the melee damage; fists otherwise.
			var dmg := BlockTypes.attack_damage(Inventory.selected_id())
			mob_hit["mob"].take_damage(dmg, knock.normalized())
		return

	if block_hit.is_empty():
		_hide_overlays()
		_reset_break()
		_eat_time = 0.0
		return

	var bp: Vector3i = block_hit["pos"]
	_highlight.visible = true
	_highlight.global_position = Vector3(bp)

	if Input.is_action_pressed("break"):
		_handle_breaking(bp, block_hit["id"], delta)
	else:
		_reset_break()

	if Input.is_action_pressed("place"):
		_handle_use(bp, block_hit["normal"], delta)
	else:
		_eat_time = 0.0


func _handle_breaking(bp: Vector3i, id: int, delta: float) -> void:
	if GameMode.is_creative():
		# Instant break, any block, hold to keep chewing through terrain.
		# Creative yields no drops.
		if _creative_break_cd <= 0.0:
			_break_block(bp, id, false)
			_creative_break_cd = Constants.CREATIVE_BREAK_DELAY
		return

	var hard := BlockTypes.hardness(id)
	if hard < 0.0:
		_reset_break()  # unbreakable (bedrock)
		return
	if bp != _break_target:
		_break_target = bp
		_break_progress = 0.0
	# Hold-to-mine: time scales with block hardness, sped up by the right
	# tool held in hand (pickaxe on stone, axe on wood, ...).
	var tool_mult := BlockTypes.tool_speed(Inventory.selected_id(), id)
	_break_progress += delta * tool_mult / maxf(hard * Constants.BREAK_TIME_PER_HARDNESS, 0.05)
	if _break_progress >= 1.0:
		_break_block(bp, id, true)
		_reset_break()
	else:
		# Progressive crack overlay on the block itself, like the original.
		var stage := clampi(
			int(_break_progress * BlockLibrary.CRACK_STAGES),
			0, BlockLibrary.CRACK_STAGES - 1
		)
		_crack.visible = true
		_crack.material_override = BlockLibrary.crack_materials[stage]
		_crack.global_position = Vector3(bp) + Vector3.ONE * 0.5


func _break_block(bp: Vector3i, id: int, give_drops: bool) -> void:
	if id == BlockTypes.FURNACE:
		_get_furnaces().on_broken(bp)  # eject its contents first
	if give_drops:
		var drop := BlockTypes.drop_for(id)
		if drop != BlockTypes.AIR:
			# Real drop entity that pops out of the block and gets vacuumed
			# up when you walk near it (Survival only — spawn() no-ops in
			# Creative).
			ItemDrop.spawn(_world, Vector3(bp) + Vector3.ONE * 0.5, drop, 1)
	_world.set_block(bp, BlockTypes.AIR)


## Right-click handler: use a block (furnace/table/bed), eat held food, or
## place the held block. Crouch forces "build against it" over "use it".
func _handle_use(bp: Vector3i, normal: Vector3i, delta: float) -> void:
	var target := _world.get_block(bp)
	if not Input.is_action_pressed("crouch") and _place_cd <= 0.0:
		match target:
			BlockTypes.FURNACE:
				_get_hud().open_furnace(bp)
				_place_cd = Constants.PLACE_REPEAT_DELAY
				_eat_time = 0.0
				return
			BlockTypes.CRAFTING_TABLE:
				_get_hud().open_table()
				_place_cd = Constants.PLACE_REPEAT_DELAY
				_eat_time = 0.0
				return
			BlockTypes.BED:
				_use_bed(bp)
				_place_cd = Constants.PLACE_REPEAT_DELAY
				_eat_time = 0.0
				return

	var id := Inventory.selected_id()

	# Hold-to-eat food that isn't a placeable block.
	if BlockTypes.food_value(id) > 0.0 and not BlockTypes.is_block(id):
		if GameMode.is_creative() or _player.stats.hunger >= Constants.MAX_HUNGER:
			return
		_eat_time += delta
		if _eat_time >= EAT_TIME:
			_eat_time = 0.0
			if _player.stats.try_eat_selected():
				_get_hud().show_message("Ate %s" % BlockTypes.block_name(id))
		return
	_eat_time = 0.0

	if _place_cd > 0.0 or id == 0 or not BlockTypes.is_block(id):
		return  # nothing placeable in hand
	var cell := bp + normal
	var current: int = _world.get_block(cell)
	# Only into air or replaceable fluid.
	if current != BlockTypes.AIR and not BlockTypes.is_fluid(current):
		return
	if _intersects_player(cell):
		return  # never build a block inside your own body
	# TODO: also reject cells overlapping mobs.
	# Stairs orient so their tall side points the way you're facing.
	var place_id := id
	if BlockTypes.is_stairs(id):
		place_id = BlockTypes.stair_variant(id, -_camera.global_transform.basis.z)
	_world.set_block(cell, place_id)
	if GameMode.is_survival():
		Inventory.consume_selected(1)
	_place_cd = Constants.PLACE_REPEAT_DELAY


## Sleeping in a bed just stores the spawn point (no fast-forward yet).
func _use_bed(bp: Vector3i) -> void:
	_player.spawn_point = Vector3(bp) + Vector3(0.5, 1.0, 0.5)
	_get_hud().show_message("Spawn point set")
	# TODO: skip to morning when it's night and no monsters are near.


func _reset_break() -> void:
	_break_progress = 0.0
	_break_target = Vector3i(0, -1000, 0)
	_crack.visible = false


func _hide_overlays() -> void:
	_highlight.visible = false
	_crack.visible = false


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


func _get_furnaces() -> Node:
	if _furnaces == null:
		_furnaces = get_tree().get_first_node_in_group("furnaces")
	return _furnaces


func _get_hud() -> Node:
	if _hud == null:
		_hud = get_tree().get_first_node_in_group("hud")
	return _hud


## Two overlay meshes that follow the targeted block:
##  * a wireframe cube (12 edges as a LINES surface), slightly inflated so it
##    never z-fights the block faces it outlines
##  * a crack box that shows BlockLibrary's progressive damage textures
func _build_overlays() -> void:
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

	var crack_box := BoxMesh.new()
	crack_box.size = Vector3.ONE * 1.006
	_crack = MeshInstance3D.new()
	_crack.mesh = crack_box
	_crack.visible = false
	_crack.top_level = true
	add_child(_crack)
