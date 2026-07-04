extends Node
## Survival stats: health + hunger, damage, death and respawn. Lives as a
## child node of the Player. Everything here is inert in Creative mode —
## the player is invulnerable and the HUD hides these bars.

signal health_changed(health: float)
signal hunger_changed(hunger: float)
signal died
signal respawned

var health: float = Constants.MAX_HEALTH
var hunger: float = Constants.MAX_HUNGER
var alive := true

@onready var _player: CharacterBody3D = get_parent()


func _process(delta: float) -> void:
	if not alive or GameMode.is_creative() or _player.frozen:
		return

	# Hunger drains slowly with time, faster while sprinting.
	var drain := Constants.HUNGER_DRAIN_PER_SEC
	if _player.is_sprinting:
		drain += Constants.HUNGER_SPRINT_DRAIN_PER_SEC
	_set_hunger(hunger - drain * delta)

	if hunger >= Constants.HUNGER_REGEN_THRESHOLD and health < Constants.MAX_HEALTH:
		# Well fed: slowly regenerate.
		_set_health(minf(health + Constants.HEALTH_REGEN_PER_SEC * delta, Constants.MAX_HEALTH))
	elif hunger <= 0.0:
		# Starving: health ticks down.
		take_damage(Constants.STARVE_DAMAGE_PER_SEC * delta, "starvation")


func take_damage(amount: float, source: String = "") -> void:
	if not alive or GameMode.is_creative() or amount <= 0.0:
		return
	# Worn armor soaks a fraction of incoming damage. Each defense point cuts
	# 4% (capped at 80%), the classic simple armor model. Starvation and the
	# void bypass armor.
	var final := amount
	if source != "starvation" and source != "the void":
		var defense := Inventory.total_defense()
		final *= 1.0 - clampf(defense * 0.04, 0.0, 0.8)
	_set_health(maxf(health - final, 0.0))
	if health <= 0.0:
		_die()


## Try to eat the item currently held in the hotbar (Survival). Returns true
## if something was actually eaten (a food item and hunger wasn't full).
func try_eat_selected() -> bool:
	if GameMode.is_creative() or hunger >= Constants.MAX_HUNGER:
		return false
	var id := Inventory.selected_id()
	var value := BlockTypes.food_value(id)
	if value <= 0.0:
		return false
	_set_hunger(minf(hunger + value, Constants.MAX_HUNGER))
	Inventory.consume_selected(1)
	return true


func _die() -> void:
	alive = false
	# Drops nothing for now (stub) — TODO: drop inventory as item entities.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	died.emit()


func respawn() -> void:
	health = Constants.MAX_HEALTH
	hunger = Constants.MAX_HUNGER
	alive = true
	_player.respawn_at_spawn()
	health_changed.emit(health)
	hunger_changed.emit(hunger)
	respawned.emit()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Used by save/load to restore state without triggering death logic.
func restore(p_health: float, p_hunger: float) -> void:
	health = clampf(p_health, 1.0, Constants.MAX_HEALTH)
	hunger = clampf(p_hunger, 0.0, Constants.MAX_HUNGER)
	alive = true
	health_changed.emit(health)
	hunger_changed.emit(hunger)


func _set_health(v: float) -> void:
	if not is_equal_approx(v, health):
		health = v
		health_changed.emit(health)


func _set_hunger(v: float) -> void:
	if not is_equal_approx(v, hunger):
		hunger = v
		hunger_changed.emit(hunger)
