class_name ItemDrop
extends Node3D
## A dropped item in the world (Survival only): a floating billboard sprite
## with lightweight voxel physics (gravity + block-grid collision — no
## PhysicsBody needed), a magnet pull toward the player, and auto-pickup
## into the inventory. Despawns after a few minutes.
##
## Not persisted in save files. TODO: serialize live drops with the world.

const GRAVITY := 20.0
const MAGNET_RADIUS := 2.6
const PICKUP_RADIUS := 0.9
const PICKUP_DELAY := 0.5   # so freshly mined blocks visibly pop out first
const LIFETIME := 240.0

var item_id: int = 0
var count: int = 1

var _velocity := Vector3.ZERO
var _age := 0.0
var _sprite: Sprite3D
var _world: Node3D
var _player: Node3D


## The one way to create drops. Silently does nothing in Creative — drops
## are a Survival-only mechanic.
static func spawn(parent: Node, pos: Vector3, id: int, amount: int = 1) -> void:
	if GameMode.is_creative() or id == BlockTypes.AIR or amount <= 0:
		return
	var drop := ItemDrop.new()
	drop.item_id = id
	drop.count = amount
	parent.add_child(drop)
	drop.global_position = pos
	# Little celebratory toss with a random horizontal kick.
	var angle := randf() * TAU
	drop._velocity = Vector3(cos(angle) * 1.6, 4.0, sin(angle) * 1.6)


func _ready() -> void:
	add_to_group("item_drops")
	_world = get_tree().get_first_node_in_group("world")
	_player = get_tree().get_first_node_in_group("player")

	_sprite = Sprite3D.new()
	_sprite.texture = BlockLibrary.get_icon(item_id)
	_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	_sprite.pixel_size = 0.028
	_sprite.position = Vector3(0, 0.25, 0)
	add_child(_sprite)


func _physics_process(delta: float) -> void:
	_age += delta
	if _age > LIFETIME:
		queue_free()
		return

	var magnetized := _magnet_and_pickup(delta)
	if not magnetized:
		_velocity.y = maxf(_velocity.y - GRAVITY * delta, -30.0)

	var next := global_position + _velocity * delta

	if _world != null:
		# Horizontal voxel collision: refuse to slide into a solid block.
		var side_probe := Vector3(next.x, global_position.y + 0.1, next.z)
		if _world.is_solid(Constants.world_to_block(side_probe)):
			next.x = global_position.x
			next.z = global_position.z
			_velocity.x = 0.0
			_velocity.z = 0.0
		# Vertical: settle on top of the block below.
		if _velocity.y <= 0.0 and _world.is_solid(Constants.world_to_block(next)):
			next.y = floorf(next.y) + 1.0
			_velocity = Vector3.ZERO
	global_position = next

	# Idle bob so resting drops read as alive.
	_sprite.position.y = 0.25 + sin(_age * 2.2) * 0.05


## Pull toward a nearby (living, Survival) player; collect on contact.
## Returns true while the magnet overrides normal physics.
func _magnet_and_pickup(_delta: float) -> bool:
	if _age < PICKUP_DELAY or _player == null or not is_instance_valid(_player):
		return false
	if GameMode.is_creative() or not _player.stats.alive:
		return false
	var target: Vector3 = _player.global_position + Vector3.UP * 0.9
	var dist := global_position.distance_to(target)
	if dist < PICKUP_RADIUS:
		var leftover := Inventory.add_item(item_id, count)
		if leftover == 0:
			queue_free()
		else:
			count = leftover  # inventory full: keep what didn't fit
		return true
	if dist < MAGNET_RADIUS:
		_velocity = (target - global_position).normalized() * 6.5
		return true
	return false
