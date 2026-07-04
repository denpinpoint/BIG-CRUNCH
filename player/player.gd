extends CharacterBody3D
## First-person player controller.
##
## Collision approach: chunks own ConcavePolygonShape3D trimesh colliders
## (built on worker threads from the exact same face data as the render mesh),
## and the player is a capsule CharacterBody3D using move_and_slide(). The
## capsule origin sits at the FEET; the camera rides in Head at eye height.
## TODO: 1-block step-up assist (for now: jump, like the reference game).

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera
@onready var stats: Node = $Stats

## True while the player must not simulate (spawn chunk not loaded yet).
var frozen := true
var flying := false
var spawn_point := Vector3(0.5, 40.0, 0.5)
var is_sprinting := false

var _fall_distance := 0.0
var _last_jump_press_ms: int = -10000
const _BASE_FOV := 80.0


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2  # layer 2 = player
	collision_mask = 1   # collide with terrain only
	camera.fov = _BASE_FOV
	GameMode.mode_changed.connect(_on_mode_changed)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * Constants.MOUSE_SENSITIVITY)
		head.rotate_x(-event.relative.y * Constants.MOUSE_SENSITIVITY)
		head.rotation.x = clampf(head.rotation.x, -PI / 2.0 + 0.01, PI / 2.0 - 0.01)
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		if not get_tree().paused and stats.alive:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("jump") and not event.is_echo():
		# Double-tap Space toggles flying (Creative only).
		var now := Time.get_ticks_msec()
		if GameMode.is_creative() and now - _last_jump_press_ms < 300:
			flying = not flying
			velocity = Vector3.ZERO
		_last_jump_press_ms = now


func _physics_process(delta: float) -> void:
	if frozen or not stats.alive:
		return
	if flying and GameMode.is_creative():
		_fly_move(delta)
	else:
		flying = false
		_walk_move(delta)
	_update_fov(delta)
	_void_check()


func _walk_move(delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var wish := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y))
	if wish.length_squared() > 1.0:
		wish = wish.normalized()

	var speed := Constants.WALK_SPEED
	is_sprinting = false
	if Input.is_action_pressed("crouch"):
		speed = Constants.CROUCH_SPEED
	elif Input.is_action_pressed("sprint") and input_dir.y < -0.1:
		# Sprinting needs food in Survival.
		if GameMode.is_creative() or stats.hunger > Constants.SPRINT_MIN_HUNGER:
			speed = Constants.SPRINT_SPEED
			is_sprinting = true

	velocity.x = wish.x * speed
	velocity.z = wish.z * speed

	velocity.y -= Constants.GRAVITY * delta
	velocity.y = maxf(velocity.y, -Constants.TERMINAL_VELOCITY)
	if velocity.y < 0.0:
		_fall_distance += -velocity.y * delta

	if is_on_floor() and Input.is_action_pressed("jump"):
		velocity.y = Constants.JUMP_VELOCITY

	move_and_slide()

	if is_on_floor():
		if _fall_distance > Constants.SAFE_FALL_BLOCKS and GameMode.is_survival():
			# Fall damage proportional to distance past the safe threshold.
			stats.take_damage(floorf(_fall_distance - Constants.SAFE_FALL_BLOCKS), "fall")
		_fall_distance = 0.0


func _fly_move(_delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var wish := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y))
	var speed := Constants.FLY_SPRINT_SPEED if Input.is_action_pressed("sprint") else Constants.FLY_SPEED

	velocity = wish * speed
	if Input.is_action_pressed("jump"):
		velocity.y = speed
	elif Input.is_action_pressed("crouch"):
		velocity.y = -speed
	else:
		velocity.y = 0.0

	is_sprinting = false
	_fall_distance = 0.0  # no fall damage from flight
	move_and_slide()


func _update_fov(delta: float) -> void:
	var target := _BASE_FOV + (8.0 if is_sprinting or (flying and Input.is_action_pressed("sprint")) else 0.0)
	camera.fov = lerpf(camera.fov, target, minf(delta * 10.0, 1.0))


func _void_check() -> void:
	if global_position.y < -12.0:
		# Fell out of the world: put the player back on solid ground.
		global_position = spawn_point
		velocity = Vector3.ZERO
		_fall_distance = 0.0
		if GameMode.is_survival():
			stats.take_damage(5.0, "the void")


## Interaction systems only run when actually playing.
func can_interact() -> bool:
	return (
		not frozen
		and stats.alive
		and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
		and not get_tree().paused
	)


func respawn_at_spawn() -> void:
	global_position = spawn_point
	velocity = Vector3.ZERO
	_fall_distance = 0.0
	flying = false


func _on_mode_changed(_mode: int) -> void:
	if GameMode.is_survival():
		flying = false  # grounded the moment you leave Creative
