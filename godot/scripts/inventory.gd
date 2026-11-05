extends RefCounted
class_name Inventory
## Инвентарь как в gRust: пояс 6 ячеек (0..5), рюкзак 24 (6..29), одежда 7 (30..36).

signal changed
signal attire_changed

const HOTBAR := 6
const MAIN := 24
const WEAR := 7
const LOOT := 48                     # большой деревянный ящик
const MAIN_START := HOTBAR
const WEAR_START := HOTBAR + MAIN
const LOOT_START := HOTBAR + MAIN + WEAR
const SIZE := LOOT_START + LOOT

var slots: Array = []

func _init() -> void:
	slots.resize(SIZE)
	for i in SIZE:
		slots[i] = null

static func _w(id: String, ammo: int) -> Dictionary:
	return {"id": id, "amount": 1, "ammo": ammo}

static func make(id: String, amount := 1) -> Dictionary:
	var d := Items.get_def(id)
	var it := {"id": id, "amount": amount}
	if d.get("type") == "weapon" and d.has("clip"):
		it["ammo"] = int(d.clip)
	return it

func _put(i: int, id: String, amount := 1) -> void:
	if Items.DB.has(id):
		slots[i] = make(id, amount)

func setup_default() -> void:
	var belt := ["assault_rifle", "python_revolver", "pump_shotgun", "rock", "combat_knife", "f1_grenade"]
	for i in belt.size():
		_put(i, belt[i])
	var main := [["556_rifle_ammo", 128], ["556_rifle_ammo", 128], ["pistol_bullet", 128], ["pistol_bullet", 128],
		["handmade_shell", 64], ["handmade_shell", 64], ["arrow", 64], ["rocket", 3], ["40mm_he_grenade", 6],
		["bandage", 3], ["medical_syringe", 3], ["large_medkit", 1]]
	var k := MAIN_START
	for m in main:
		if Items.DB.has(m[0]):
			_put(k, m[0], min(m[1], Items.max_stack(m[0])))
			k += 1
	var w := WEAR_START
	for id in ["jacket", "pants_hide", "shoes_boots", "hat_cap", "tactical_gloves"]:
		_put(w, id)
		w += 1
	changed.emit()
	attire_changed.emit()

## Содержимое ящиков: всё оружие, вся одежда, все патроны и предметы из реестра gRust
static func chest_contents() -> Array:
	var groups := {"ОГНЕСТРЕЛ": [], "БЛИЖНИЙ БОЙ И ВЗРЫВЧАТКА": [], "ОДЕЖДА": [], "ПАТРОНЫ И МЕДИЦИНА": [], "ПРЕДМЕТЫ": []}
	for id in Items.ORDER:
		var d: Dictionary = Items.DB[id]
		var amount := Items.max_stack(id)
		match d.type:
			"weapon":
				if d.get("kind") in ["gun", "shotgun", "bow", "launcher"]:
					groups["ОГНЕСТРЕЛ"].append(make(id))
				else:
					groups["БЛИЖНИЙ БОЙ И ВЗРЫВЧАТКА"].append(make(id, amount if d.get("kind") in ["throw", "medical"] else 1))
			"attire":
				groups["ОДЕЖДА"].append(make(id))
			"ammo", "medical_item", "food":
				groups["ПАТРОНЫ И МЕДИЦИНА"].append(make(id, amount))
			_:
				groups["ПРЕДМЕТЫ"].append(make(id, amount))
	var res := []
	for g in groups:
		var arr: Array = groups[g]
		var n := 0
		var part := 1
		while n < arr.size() or n == 0:
			var chunk := arr.slice(n, n + LOOT)
			var title: String = g if arr.size() <= LOOT else "%s %d" % [g, part]
			res.append({"title": title, "items": chunk})
			n += LOOT
			part += 1
			if arr.is_empty():
				break
	return res

## Открыть ящик: его содержимое попадает в ячейки LOOT_START..; при закрытии — обратно
var open_chest: Dictionary = {}
func load_chest(c: Dictionary) -> void:
	open_chest = c
	for i in LOOT:
		slots[LOOT_START + i] = c.items[i] if i < c.items.size() else null
	changed.emit()

func save_chest() -> void:
	if open_chest.is_empty():
		return
	var arr := []
	for i in LOOT:
		arr.append(slots[LOOT_START + i])
	open_chest.items = arr
	open_chest = {}

static func is_loot_slot(i: int) -> bool:
	return i >= LOOT_START

## Быстро переложить (двойной тап при открытом ящике): ящик <-> рюкзак/пояс
func quick_move(i: int) -> bool:
	if slots[i] == null:
		return false
	var rng: Array = range(MAIN_START, WEAR_START) + range(0, HOTBAR) if is_loot_slot(i) else range(LOOT_START, SIZE)
	# сначала объединить стак
	for k in rng:
		var o = slots[k]
		if o != null and o.id == slots[i].id and Items.max_stack(o.id) > 1 and o.amount < Items.max_stack(o.id):
			move(i, k)
			if slots[i] == null:
				return true
	for k in rng:
		if slots[k] == null:
			return move(i, k)
	return false

func get_item(i: int):
	if i < 0 or i >= SIZE:
		return null
	return slots[i]

static func is_wear_slot(i: int) -> bool:
	return i >= WEAR_START and i < LOOT_START

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
	for k in range(WEAR_START, LOOT_START):
		if k == i or k == from:
			continue
		var o = slots[k]
		if o == null:
			continue
		var os: String = Items.get_def(o.id).slot
		# одна вещь каждой категории; полный костюм несовместим ни с чем
		if os == d.slot or os == "full" or d.slot == "full":
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
	if b != null and a.id == b.id and Items.max_stack(a.id) > 1:
		var cap: int = Items.max_stack(a.id)
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
	for k in range(WEAR_START, LOOT_START):
		if slots[k] != null and (Items.get_def(slots[k].id).slot == d.slot):
			return move(i, k)
	for k in range(WEAR_START, LOOT_START):
		if slots[k] == null:
			return move(i, k)
	return false

func worn() -> Array:
	var res := []
	for k in range(WEAR_START, LOOT_START):
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
	for k in WEAR_START:
		var it = slots[k]
		if it != null and it.id == id:
			n += it.amount
	return n

## Добавить предмет в инвентарь (пояс/рюкзак), со складыванием в стаки. Возвращает сколько не поместилось.
func give(id: String, amount: int) -> int:
	var cap := Items.max_stack(id)
	var left := amount
	if cap > 1:
		for k in WEAR_START:
			var o = slots[k]
			if o != null and o.id == id and o.amount < cap:
				var n: int = min(cap - o.amount, left)
				o.amount += n
				left -= n
				if left <= 0:
					break
	while left > 0:
		var free := -1
		for k in range(MAIN_START, WEAR_START) + range(0, HOTBAR):
			if slots[k] == null:
				free = k
				break
		if free == -1:
			break
		var n: int = min(cap, left)
		slots[free] = make(id, n)
		left -= n
	changed.emit()
	return left

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
