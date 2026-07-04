class_name MobBase
extends CharacterBody3D
## Shared mob behavior: health, gravity/physics, hurt flash + knockback,
## death with a loot stub, distance despawning, and lightweight steering.
##
## Navigation is HONEST steering, not pathfinding: mobs walk toward a target
## on the XZ plane, auto-jump 1-block steps when they bump a wall, and (for
## non-panicked movement) stop at ledges. On a streaming voxel world a baked
## navmesh isn't practical.
## TODO: upgrade to voxel A* over the block grid (or NavigationServer3D
## regions rebuilt per chunk) for real path following around obstacles.

@export var max_health: float = 10.0
@export var jump_velocity: float = 7.8

var health: float
var world: Node3D
var player: CharacterBody3D
var visual: Node3D  # root of the blocky body parts

var _flash_left := 0.0
var _flashed_meshes: Array[MeshInstance3D] = []
var _despawn_timer := 0.0
var _yaw_target := 0.0


func _ready() -> void:
	health = max_health
	add_to_group("mobs")
	collision_layer = 4  # layer 3 = mobs
	collision_mask = 1   # collide with terrain
	world = get_tree().get_first_node_in_group("world")
	player = get_tree().get_first_node_in_group("player")
	visual = Node3D.new()
	add_child(visual)
	_build_visual()


## Override: assemble the blocky body under `visual`.
func _build_visual() -> void:
	pass


## Override: per-frame AI. Set velocity.x/z (and jump); gravity is handled here.
func _ai(_delta: float) -> void:
	pass


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= Constants.GRAVITY * delta
		velocity.y = maxf(velocity.y, -Constants.TERMINAL_VELOCITY)
	_ai(delta)
	move_and_slide()
	_face_movement(delta)
	_update_flash(delta)
	_despawn_check(delta)


# --- Steering helpers -------------------------------------------------------

## Walk toward a world position on the XZ plane. Auto-jumps 1-block steps.
## If avoid_ledges is true the mob refuses to walk off drops of 3+ blocks.
func steer_towards(target: Vector3, speed: float, avoid_ledges: bool) -> void:
	var to := target - global_position
	to.y = 0.0
	if to.length() < 0.3:
		stop_moving()
		return
	var dir := to.normalized()
	if avoid_ledges and is_on_floor() and _ledge_ahead(dir):
		stop_moving()
		return
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	# Bumped into something while grounded -> try hopping one block up.
	# (Also hops at 2-block walls, harmlessly. TODO: probe wall height first.)
	if is_on_floor() and is_on_wall():
		velocity.y = jump_velocity


func stop_moving() -> void:
	velocity.x = move_toward(velocity.x, 0.0, 1.0)
	velocity.z = move_toward(velocity.z, 0.0, 1.0)


## True if the column just ahead drops 3+ blocks (sampled via block data —
## cheaper and more reliable than a physics ray on trimesh colliders).
func _ledge_ahead(dir: Vector3) -> bool:
	var probe := global_position + dir * 0.8 + Vector3.UP * 0.1
	var bp := Constants.world_to_block(probe)
	for i in range(1, 4):
		if world.is_solid(bp + Vector3i(0, -i, 0)):
			return false
	return true


func _face_movement(delta: float) -> void:
	var flat := Vector2(velocity.x, velocity.z)
	if flat.length_squared() > 0.05:
		_yaw_target = atan2(-velocity.x, -velocity.z)
	visual.rotation.y = lerp_angle(visual.rotation.y, _yaw_target, minf(delta * 8.0, 1.0))


# --- Damage / death ---------------------------------------------------------

func take_damage(amount: float, knock_dir: Vector3) -> void:
	if health <= 0.0:
		return
	health -= amount
	velocity = knock_dir * 6.0 + Vector3.UP * 4.5
	_start_flash()
	_on_hurt()
	if health <= 0.0:
		_die()


## Override for reactions (e.g. passive mobs flee).
func _on_hurt() -> void:
	pass


func _die() -> void:
	_drop_loot()
	queue_free()


## Override: loot stub until item entities exist.
func _drop_loot() -> void:
	pass


func _start_flash() -> void:
	if _flashed_meshes.is_empty():
		_collect_meshes(visual)
	var flash := StandardMaterial3D.new()
	flash.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash.albedo_color = Color(1.0, 0.25, 0.25)
	for m in _flashed_meshes:
		m.material_override = flash
	_flash_left = 0.13


func _update_flash(delta: float) -> void:
	if _flash_left <= 0.0:
		return
	_flash_left -= delta
	if _flash_left <= 0.0:
		for m in _flashed_meshes:
			m.material_override = null


func _collect_meshes(node: Node) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			_flashed_meshes.append(child)
		_collect_meshes(child)


# --- Despawning -------------------------------------------------------------

func _despawn_check(delta: float) -> void:
	_despawn_timer += delta
	if _despawn_timer < 1.0:
		return
	_despawn_timer = 0.0
	if player == null or not is_instance_valid(player):
		return
	if global_position.distance_to(player.global_position) > Constants.MOB_DESPAWN_DISTANCE:
		queue_free()


# --- Visual helper ----------------------------------------------------------

## Blocky body part: a colored BoxMesh at a local offset.
func add_box(size: Vector3, pos: Vector3, color: Color, emissive := false) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	if emissive:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 1.6
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	visual.add_child(mi)
	return mi
