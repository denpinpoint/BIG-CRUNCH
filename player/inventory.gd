extends Node
## Autoloaded as "Inventory" — the player's real inventory.
##
## 36 slots: indices 0-8 are the hotbar, 9-35 the main grid. Every slot is
## {"id": int, "count": int}; empty = id 0 / count 0. The player spawns with
## NOTHING — in Survival everything is mined/crafted, in Creative the palette
## tabs (inventory screen, E) hand out free stacks.
## TODO: dropped-item entities for overflow instead of silently discarding.

signal changed
signal selection_changed(index: int)

const SIZE := 36
const HOTBAR_SIZE := 9

var slots: Array[Dictionary] = []
var selected: int = 0


func _init() -> void:
	clear()


func clear() -> void:
	slots.clear()
	for i in SIZE:
		slots.append({"id": 0, "count": 0})
	changed.emit()


## Treat the returned Dictionary as read-only; write through set_slot().
func slot(i: int) -> Dictionary:
	return slots[i]


func set_slot(i: int, id: int, count: int) -> void:
	if count <= 0 or id == 0:
		slots[i] = {"id": 0, "count": 0}
	else:
		slots[i] = {"id": id, "count": mini(count, Constants.STACK_MAX)}
	changed.emit()


## Adds items, merging into existing stacks first (hotbar first), then into
## empty slots. Returns the count that did NOT fit.
func add_item(id: int, count: int = 1) -> int:
	if id == 0 or count <= 0:
		return 0
	var left := count
	for i in SIZE:  # merge pass
		var s := slots[i]
		if s["id"] == id and s["count"] < Constants.STACK_MAX:
			var take := mini(left, Constants.STACK_MAX - s["count"])
			s["count"] += take
			left -= take
			if left == 0:
				break
	if left > 0:
		for i in SIZE:  # empty-slot pass
			if slots[i]["id"] == 0:
				var put := mini(left, Constants.STACK_MAX)
				slots[i] = {"id": id, "count": put}
				left -= put
				if left == 0:
					break
	changed.emit()
	return left


## Id in the selected hotbar slot (0 when empty).
func selected_id() -> int:
	var s := slots[selected]
	return s["id"] if s["count"] > 0 else 0


## Removes n items from the selected hotbar slot (Survival block placement).
func consume_selected(n: int = 1) -> void:
	var s := slots[selected]
	set_slot(selected, s["id"], s["count"] - n)


func select(i: int) -> void:
	selected = posmod(i, HOTBAR_SIZE)
	selection_changed.emit(selected)


func serialize() -> Array:
	var out := []
	for s in slots:
		out.append([s["id"], s["count"]])
	return out


func deserialize(data: Array) -> void:
	clear()
	for i in mini(data.size(), SIZE):
		var entry: Array = data[i]
		set_slot(i, int(entry[0]), int(entry[1]))
	changed.emit()
