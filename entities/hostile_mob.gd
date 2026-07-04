class_name HostileMob
extends MobBase
## The "Gnasher" — an original nocturnal brute. Wanders until the player gets
## within aggro range AND line of sight, then chases and bites on contact.
## Completely ignores Creative-mode players.

enum State { WANDER, CHASE }

const WANDER_SPEED := 1.2
const CHASE_SPEED := 3.4
const AGGRO_RADIUS := 14.0
const DEAGGRO_RADIUS := 22.0
const ATTACK_RANGE := 1.7
const ATTACK_DAMAGE := 3.0
const ATTACK_COOLDOWN := 1.2
const LOS_GRACE := 3.0  # keeps chasing this long after losing sight

var _state: State = State.WANDER
var _state_left := 1.0
var _wander_dir := Vector3.FORWARD
var _attack_cd := 0.0
var _los_left := 0.0


func _ready() -> void:
	max_health = 14.0
	super()
	add_to_group("hostile_mobs")


func _build_visual() -> void:
	var skin := Color(0.28, 0.42, 0.24)
	var dark := Color(0.18, 0.26, 0.16)
	add_box(Vector3(0.55, 0.7, 0.32), Vector3(0, 1.05, 0), skin)               # torso
	add_box(Vector3(0.5, 0.7, 0.3), Vector3(0, 0.35, 0), dark)                 # legs
	add_box(Vector3(0.46, 0.46, 0.46), Vector3(0, 1.63, 0), skin)              # head
	add_box(Vector3(0.16, 0.62, 0.28), Vector3(-0.38, 1.05, 0), dark)          # arms
	add_box(Vector3(0.16, 0.62, 0.28), Vector3(0.38, 1.05, 0), dark)
	add_box(Vector3(0.09, 0.07, 0.02), Vector3(-0.11, 1.7, -0.24), Color(1, 0.2, 0.1), true)  # glowing eyes
	add_box(Vector3(0.09, 0.07, 0.02), Vector3(0.11, 1.7, -0.24), Color(1, 0.2, 0.1), true)


func _ai(delta: float) -> void:
	_attack_cd = maxf(_attack_cd - delta, 0.0)

	# Mobs do not target or damage Creative players.
	var can_hunt := (
		GameMode.is_survival()
		and player != null and is_instance_valid(player)
		and player.stats.alive
	)

	match _state:
		State.WANDER:
			_wander(delta)
			if can_hunt:
				var dist := global_position.distance_to(player.global_position)
				if dist < AGGRO_RADIUS and _has_line_of_sight():
					_state = State.CHASE
					_los_left = LOS_GRACE
		State.CHASE:
			if not can_hunt:
				_state = State.WANDER
				return
			var dist := global_position.distance_to(player.global_position)
			_los_left = LOS_GRACE if _has_line_of_sight() else _los_left - delta
			if dist > DEAGGRO_RADIUS or _los_left <= 0.0:
				_state = State.WANDER
				return
			# Chasing: ledges are ignored, hunger wins over caution.
			steer_towards(player.global_position, CHASE_SPEED, false)
			if dist < ATTACK_RANGE and _attack_cd <= 0.0:
				_attack_cd = ATTACK_COOLDOWN
				player.stats.take_damage(ATTACK_DAMAGE, "Gnasher")
				# Shove the player back a bit.
				var knock := (player.global_position - global_position).normalized()
				player.velocity += knock * 6.0 + Vector3.UP * 3.0


func _wander(_delta: float) -> void:
	_state_left -= _delta
	if _state_left <= 0.0 or (is_on_floor() and is_on_wall()):
		if randf() < 0.4:
			_wander_dir = Vector3.ZERO
		else:
			var angle := randf() * TAU
			_wander_dir = Vector3(cos(angle), 0.0, sin(angle))
		_state_left = randf_range(2.0, 5.0)
	if _wander_dir == Vector3.ZERO:
		stop_moving()
	else:
		steer_towards(global_position + _wander_dir * 3.0, WANDER_SPEED, true)


## Eye-to-eye ray against terrain only: blocked = no aggro through walls.
func _has_line_of_sight() -> bool:
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3.UP * 1.6
	var to: Vector3 = player.global_position + Vector3.UP * Constants.EYE_HEIGHT
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)  # terrain layer
	return space.intersect_ray(query).is_empty()


func _drop_loot() -> void:
	# TODO: spawn a pickup entity; for now just a stub resource id.
	print("Gnasher dropped: 1x gloom_shard (item entities are a TODO)")

# TODO: ranged spitter / self-destruct variants extending this class.
