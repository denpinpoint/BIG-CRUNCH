extends Node
## Autoloaded as "Inventory" — the player's real inventory + worn armor.
##
## 36 slots: indices 0-8 are the hotbar, 9-35 the main grid. Plus 4 armor
## slots (helmet, chestplate, leggings, boots). Every slot is
## {"id": int, "count": int}; empty = id 0 / count 0. The player spawns with
## NOTHING — in Survival everything is mined/crafted, in Creative the palette
## tabs (inventory screen, E) hand out free stacks.
## Per-item stack limits come from BlockTypes.stack_max (tools/armor = 1).
## TODO: dropped-item entities for overflow instead of silently discarding.

signal changed
signal selection_changed(index: int)

const SIZE := 36
const HOTBAR_SIZE := 9
const ARMOR_SLOTS := 4  # 0 helmet, 1 chestplate, 2 leggings, 3 boots

var slots: Array[Dictionary] = []
var armor: Array[Dictionary] = []
var selected: int = 0


func _init() -> void:
	clear()


func clear() -> void:
	slots.clear()
	for i in SIZE:
		slots.append({"id": 0, "count": 0})
	armor.clear()
	for i in ARMOR_SLOTS:
		armor.append({"id": 0, "count": 0})
	changed.emit()


## Treat the returned Dictionary as read-only; write through set_slot().
func slot(i: int) -> Dictionary:
	return slots[i]


func set_slot(i: int, id: int, count: int) -> void:
	if count <= 0 or id == 0:
		slots[i] = {"id": 0, "count": 0}
	else:
		slots[i] = {"id": id, "count": mini(count, BlockTypes.stack_max(id))}
	changed.emit()


func armor_slot(i: int) -> Dictionary:
	return armor[i]


## Writes an armor slot but only accepts armor whose piece matches (or empty).
func set_armor(i: int, id: int, count: int) -> void:
	if count <= 0 or id == 0:
		armor[i] = {"id": 0, "count": 0}
	elif BlockTypes.armor_slot_of(id) == i:
		armor[i] = {"id": id, "count": 1}
	changed.emit()


## True when the id is armor that belongs in slot i (used by the UI to gate
## what can be dropped there).
func armor_fits(i: int, id: int) -> bool:
	return id == 0 or BlockTypes.armor_slot_of(id) == i


## Sum of defense points across worn armor.
func total_defense() -> int:
	var total := 0
	for a in armor:
		if a["id"] != 0:
			total += BlockTypes.armor_defense(a["id"])
	return total


## Adds items, merging into existing stacks first (hotbar first), then into
## empty slots. Returns the count that did NOT fit.
func add_item(id: int, count: int = 1) -> int:
	if id == 0 or count <= 0:
		return 0
	var cap := BlockTypes.stack_max(id)
	var left := count
	for i in SIZE:  # merge pass
		var s := slots[i]
		if s["id"] == id and s["count"] < cap:
			var take := mini(left, cap - s["count"])
			s["count"] += take
			left -= take
			if left == 0:
				break
	if left > 0:
		for i in SIZE:  # empty-slot pass
			if slots[i]["id"] == 0:
				var put := mini(left, cap)
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


func serialize() -> Dictionary:
	var main := []
	for s in slots:
		main.append([s["id"], s["count"]])
	var worn := []
	for a in armor:
		worn.append([a["id"], a["count"]])
	return {"slots": main, "armor": worn}


func deserialize(data: Variant) -> void:
	clear()
	# v2 saves stored a bare slots array; v3+ store {slots, armor}.
	var main: Array = data["slots"] if data is Dictionary else data
	for i in mini(main.size(), SIZE):
		var entry: Array = main[i]
		set_slot(i, int(entry[0]), int(entry[1]))
	if data is Dictionary and data.has("armor"):
		var worn: Array = data["armor"]
		for i in mini(worn.size(), ARMOR_SLOTS):
			var entry: Array = worn[i]
			set_armor(i, int(entry[0]), int(entry[1]))
	changed.emit()
