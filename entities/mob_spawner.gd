extends Node
## Mob spawning: runs on a timer with a fixed attempt budget per tick (so a
## bad tick can never hitch a frame), spawning into a ring around the player.
##
## Rules:
##  * Per-type caps + a global cap, counted via node groups.
##  * Passive mobs: daylight, on grass, on the surface.
##  * Hostile mobs: darkness — night on the surface, or deep carved caves at
##    any hour (Phase 3.5 caves are prime Gnasher real estate). Light is
##    approximated as day/night + depth-below-surface; see
##    DayNight.is_dark_at. TODO: real per-block light values.
##  * Never inside solid blocks (needs floor + 2 air), never near the player.

var _world: Node3D
var _player: CharacterBody3D
var _daynight: Node
var _timer := 0.0

const PASSIVE_SCENE := preload("res://entities/PassiveMob.tscn")
const HOSTILE_SCENE := preload("res://entities/HostileMob.tscn")


func _ready() -> void:
	_world = get_tree().get_first_node_in_group("world")
	_player = get_tree().get_first_node_in_group("player")
	_daynight = get_tree().get_first_node_in_group("daynight")


func _process(delta: float) -> void:
	if _player == null or _player.frozen:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = Constants.MOB_SPAWN_INTERVAL
	_spawn_tick()


func _spawn_tick() -> void:
	var total := get_tree().get_nodes_in_group("mobs").size()
	if total >= Constants.MOB_GLOBAL_CAP:
		return
	var passive_count := get_tree().get_nodes_in_group("passive_mobs").size()
	var hostile_count := get_tree().get_nodes_in_group("hostile_mobs").size()

	for _attempt in Constants.MOB_SPAWN_ATTEMPTS_PER_TICK:
		var want_hostile: bool = randf() < 0.5
		if want_hostile and hostile_count >= Constants.HOSTILE_MOB_CAP:
			want_hostile = false
		if not want_hostile and passive_count >= Constants.PASSIVE_MOB_CAP:
			want_hostile = true
			if hostile_count >= Constants.HOSTILE_MOB_CAP:
				return  # both types capped

		var spot := _find_spot(want_hostile)
		if spot == Vector3.INF:
			continue
		var mob: MobBase = (HOSTILE_SCENE if want_hostile else PASSIVE_SCENE).instantiate()
		get_parent().add_child(mob)
		mob.global_position = spot
		if want_hostile:
			hostile_count += 1
		else:
			passive_count += 1
		total += 1
		if total >= Constants.MOB_GLOBAL_CAP:
			return


## One candidate position in the spawn ring, or Vector3.INF if invalid.
func _find_spot(hostile: bool) -> Vector3:
	var angle := randf() * TAU
	var dist := randf_range(Constants.MOB_SPAWN_RING_MIN, Constants.MOB_SPAWN_RING_MAX)
	var wx := int(floor(_player.global_position.x + cos(angle) * dist))
	var wz := int(floor(_player.global_position.z + sin(angle) * dist))

	# Only spawn on generated ground.
	if not _world.is_chunk_loaded(Constants.block_to_chunk(Vector3i(wx, 0, wz))):
		return Vector3.INF

	var surface: int = _world.surface_y(wx, wz)
	if surface < 1:
		return Vector3.INF

	var floor_y := surface
	if hostile:
		if _daynight.is_night():
			pass  # surface spawn is fine at night
		else:
			# Daytime: only deep dark caves qualify. Probe a random depth for
			# an air pocket with a solid floor.
			floor_y = _find_cave_floor(wx, wz, surface)
			if floor_y < 0:
				return Vector3.INF
	else:
		# Passive: daylight + grass only.
		if _daynight.is_night():
			return Vector3.INF
		if _world.get_block(Vector3i(wx, surface, wz)) != BlockTypes.GRASS:
			return Vector3.INF

	# Feet cell + head cell must be clear (never spawn buried).
	var feet := Vector3i(wx, floor_y + 1, wz)
	if _world.get_block(feet) != BlockTypes.AIR:
		return Vector3.INF
	if _world.get_block(feet + Vector3i(0, 1, 0)) != BlockTypes.AIR:
		return Vector3.INF

	var pos := Vector3(wx + 0.5, floor_y + 1.05, wz + 0.5)
	if pos.distance_to(_player.global_position) < Constants.MOB_MIN_PLAYER_DISTANCE:
		return Vector3.INF
	return pos


## Random underground air pocket with a solid floor, dark enough for
## hostiles; -1 if the probe found nothing.
func _find_cave_floor(wx: int, wz: int, surface: int) -> int:
	var max_y := surface - Constants.HOSTILE_CAVE_DEPTH
	if max_y < 3:
		return -1
	var y := randi_range(2, max_y)
	# Walk down a little looking for solid-below-air.
	for _i in 6:
		var here := Vector3i(wx, y, wz)
		if (
			_world.get_block(here) == BlockTypes.AIR
			and _world.get_block(here + Vector3i(0, 1, 0)) == BlockTypes.AIR
			and _world.is_solid(here + Vector3i(0, -1, 0))
		):
			return y - 1  # floor block y
		y -= 1
		if y < 2:
			break
	return -1
