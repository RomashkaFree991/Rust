extends RefCounted
class_name Inventory
## Инвентарь как в gRust: пояс 6 ячеек (0..5), рюкзак 24 (6..29), одежда 7 (30..36).

signal changed
signal attire_changed

const HOTBAR := 6
const MAIN := 24
const WEAR := 7
const MAIN_START := HOTBAR
const WEAR_START := HOTBAR + MAIN
const SIZE := HOTBAR + MAIN + WEAR

var slots: Array = []

func _init() -> void:
	slots.resize(SIZE)
	for i in SIZE:
		slots[i] = null

static func _w(id: String, ammo: int) -> Dictionary:
	return {"id": id, "amount": 1, "ammo": ammo}

func setup_default() -> void:
	slots[0] = _w("ak47u", 30)
	slots[1] = _w("python", 6)
	slots[2] = _w("lr300", 30)
	slots[3] = _w("mp5", 30)
	slots[4] = _w("rock", 0)
	slots[5] = _w("combatknife", 0)
	var i := MAIN_START
	for id in ["thompson", "customsmg", "m249", "sar", "m92", "revolver"]:
		slots[i] = _w(id, Items.get_def(id).clip)
		i += 1
	for a in [["ammo.rifle", 128], ["ammo.rifle", 128], ["ammo.rifle", 128], ["ammo.pistol", 128], ["ammo.pistol", 128], ["ammo.pistol", 128]]:
		slots[i] = {"id": a[0], "amount": a[1]}
		i += 1
	for id in ["roadsign_jacket", "heavy_plate_jacket", "heavy_plate_legs", "heavy_plate_helmet", "metal_mask", "bandana", "tshirt_long"]:
		slots[i] = {"id": id, "amount": 1}
		i += 1
	# надето
	var w := WEAR_START
	for id in ["jacket", "pants_hide", "shoes_boots", "hat_cap", "tactical_gloves"]:
		slots[w] = {"id": id, "amount": 1}
		w += 1
	changed.emit()
	attire_changed.emit()

func get_item(i: int):
	if i < 0 or i >= SIZE:
		return null
	return slots[i]

static func is_wear_slot(i: int) -> bool:
	return i >= WEAR_START

## Можно ли положить предмет it в ячейку i (с учётом обмена из from)
func can_place(it, i: int, from: int) -> bool:
	if it == null:
		return true
	if not is_wear_slot(i):
		return true
	var d := Items.get_def(it.id)
	if d.get("type") != "attire":
		return false
	# одна вещь каждой категории
	for k in range(WEAR_START, SIZE):
		if k == i or k == from:
			continue
		var o = slots[k]
		if o != null and Items.get_def(o.id).slot == d.slot:
			return false
	return true

## Переместить/поменять местами/объединить стаки. Возвращает true при успехе.
func move(from: int, to: int) -> bool:
	if from == to:
		return false
	var a = slots[from]
	var b = slots[to]
	if a == null:
		return false
	if b != null and a.id == b.id and Items.get_def(a.id).get("type") == "ammo":
		var cap: int = Items.get_def(a.id).get("stack", 128)
		var n: int = min(a.amount, cap - b.amount)
		b.amount += n
		a.amount -= n
		if a.amount <= 0:
			slots[from] = null
	else:
		if not can_place(a, to, from) or not can_place(b, from, to):
			return false
		slots[from] = b
		slots[to] = a
	changed.emit()
	if is_wear_slot(from) or is_wear_slot(to):
		attire_changed.emit()
	return true

## Быстро надеть/снять одежду (двойной тап)
func quick_toggle_wear(i: int) -> bool:
	var it = slots[i]
	if it == null or Items.get_def(it.id).get("type") != "attire":
		return false
	if is_wear_slot(i):
		for k in range(MAIN_START, WEAR_START):
			if slots[k] == null:
				return move(i, k)
		return false
	# заменить вещь той же категории или занять пустую ячейку
	var d := Items.get_def(it.id)
	for k in range(WEAR_START, SIZE):
		if slots[k] != null and Items.get_def(slots[k].id).slot == d.slot:
			return move(i, k)
	for k in range(WEAR_START, SIZE):
		if slots[k] == null:
			return move(i, k)
	return false

func worn() -> Array:
	var res := []
	for k in range(WEAR_START, SIZE):
		if slots[k] != null:
			res.append(slots[k].id)
	return res

func protection() -> float:
	var p := 0.0
	for id in worn():
		p += Items.get_def(id).get("prot", 0.0)
	return min(p, 0.8)

func count(id: String) -> int:
	var n := 0
	for it in slots:
		if it != null and it.id == id:
			n += it.amount
	return n

## Забрать до amount единиц предмета (сначала из рюкзака). Возвращает сколько забрали.
func take(id: String, amount: int) -> int:
	var got := 0
	for i in range(WEAR_START - 1, -1, -1):
		var it = slots[i]
		if it == null or it.id != id:
			continue
		var n: int = min(it.amount, amount - got)
		it.amount -= n
		got += n
		if it.amount <= 0:
			slots[i] = null
		if got >= amount:
			break
	if got > 0:
		changed.emit()
	return got
