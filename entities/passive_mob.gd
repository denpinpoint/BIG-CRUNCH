class_name PassiveMob
extends MobBase
## The "Woolback" — an original, entirely made-up fluffy quadruped.
## Wanders, idles, grazes; flees for a few seconds when hit.

enum State { IDLE, WANDER, GRAZE, FLEE }

const WANDER_SPEED := 1.6
const FLEE_SPEED := 4.2
const FLEE_TIME := 4.0

var _state: State = State.IDLE
var _state_left := 1.0
var _wander_dir := Vector3.FORWARD
var _flee_from := Vector3.ZERO
var _head: MeshInstance3D


func _ready() -> void:
	max_health = 8.0
	super()
	add_to_group("passive_mobs")


func _build_visual() -> void:
	var wool := Color(0.92, 0.9, 0.86)
	var face := Color(0.82, 0.72, 0.62)
	var leg := Color(0.55, 0.48, 0.42)
	add_box(Vector3(0.8, 0.6, 1.1), Vector3(0, 0.75, 0), wool)          # fluffy body
	_head = add_box(Vector3(0.42, 0.42, 0.42), Vector3(0, 1.05, -0.72), face)  # head
	add_box(Vector3(0.5, 0.3, 0.35), Vector3(0, 1.2, -0.62), wool)      # wool cap
	for offset: Vector3 in [
		Vector3(-0.25, 0.25, -0.4), Vector3(0.25, 0.25, -0.4),
		Vector3(-0.25, 0.25, 0.4), Vector3(0.25, 0.25, 0.4),
	]:
		add_box(Vector3(0.18, 0.5, 0.18), offset, leg)


func _ai(delta: float) -> void:
	_state_left -= delta
	match _state:
		State.IDLE:
			stop_moving()
			if _state_left <= 0.0:
				_pick_next_state()
		State.GRAZE:
			stop_moving()
			_head.position.y = 0.75  # head down, munching
			if _state_left <= 0.0:
				_head.position.y = 1.05
				_pick_next_state()
		State.WANDER:
			steer_towards(global_position + _wander_dir * 3.0, WANDER_SPEED, true)
			if _state_left <= 0.0 or (is_on_floor() and is_on_wall()):
				_pick_next_state()
		State.FLEE:
			var away := global_position - _flee_from
			away.y = 0.0
			if away.length() < 0.1:
				away = _wander_dir
			# Panic: ledges are ignored while fleeing.
			steer_towards(global_position + away.normalized() * 4.0, FLEE_SPEED, false)
			if _state_left <= 0.0:
				_pick_next_state()


func _pick_next_state() -> void:
	var roll := randf()
	if roll < 0.35:
		_state = State.IDLE
		_state_left = randf_range(1.5, 4.0)
	elif roll < 0.6:
		_state = State.GRAZE
		_state_left = randf_range(2.0, 4.0)
	else:
		_state = State.WANDER
		var angle := randf() * TAU
		_wander_dir = Vector3(cos(angle), 0.0, sin(angle))
		_state_left = randf_range(2.0, 5.0)


func _on_hurt() -> void:
	_state = State.FLEE
	_state_left = FLEE_TIME
	_flee_from = player.global_position if player != null else global_position + Vector3.BACK


func _drop_loot() -> void:
	# 1-2 wool tufts (Survival only — spawn() no-ops in Creative).
	ItemDrop.spawn(get_parent(), global_position + Vector3.UP * 0.6, BlockTypes.WOOL, randi_range(1, 2))
