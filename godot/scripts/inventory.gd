extends RefCounted
class_name Inventory
## Инвентарь в стиле Rust: 6 ячеек хотбара (0..5) + 24 ячейки рюкзака (6..29).

signal changed

const HOTBAR := 6
const MAIN := 24
const SIZE := HOTBAR + MAIN

var slots: Array = []

func _init() -> void:
	slots.resize(SIZE)
	for i in SIZE:
		slots[i] = null

func setup_default() -> void:
	slots[0] = {"id": "ak47u", "amount": 1, "ammo": 30}
	slots[1] = {"id": "python", "amount": 1, "ammo": 6}
	slots[6] = {"id": "thompson", "amount": 1, "ammo": 20}
	slots[7] = {"id": "ammo.rifle", "amount": 128}
	slots[8] = {"id": "ammo.rifle", "amount": 128}
	slots[9] = {"id": "ammo.pistol", "amount": 128}
	slots[10] = {"id": "ammo.pistol", "amount": 96}
	changed.emit()

func get_item(i: int):
	if i < 0 or i >= SIZE:
		return null
	return slots[i]

## Переместить/поменять местами/объединить стаки
func move(from: int, to: int) -> void:
	if from == to:
		return
	var a = slots[from]
	var b = slots[to]
	if a != null and b != null and a.id == b.id and Items.get_def(a.id).get("type") == "ammo":
		var cap: int = Items.get_def(a.id).get("stack", 128)
		var n: int = min(a.amount, cap - b.amount)
		b.amount += n
		a.amount -= n
		if a.amount <= 0:
			slots[from] = null
	else:
		slots[from] = b
		slots[to] = a
	changed.emit()

func count(id: String) -> int:
	var n := 0
	for it in slots:
		if it != null and it.id == id:
			n += it.amount
	return n

## Забрать до amount единиц предмета (сначала из рюкзака). Возвращает сколько забрали.
func take(id: String, amount: int) -> int:
	var got := 0
	for i in range(SIZE - 1, -1, -1):
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
