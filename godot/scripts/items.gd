extends RefCounted
class_name Items
## База предметов. Источник — реестр gRust (scripts/gamemodes/rust/gamemode/core/inventory/items/*.lua)
## и параметры оружия SWEP (scripts/gamemodes/rust/entities/weapons/*.lua), собранные
## tools/godot_conversion/gen_items.py в assets/data/items.json; одежда — assets/data/attire.json.

## 1 юнит Source = 0.01905 м (так масштабирует импорт моделей)
const SU := 0.01905
const CATEGORIES := [
	# как gRust.CreateCategory в core/inventory/item_sh.lua
	["Common", "servers"], ["Construction", "construction"], ["Items", "extinguish"], ["Resources", "servers"],
	["Clothing", "clothing"], ["Tools", "tools"], ["Medical", "medical"], ["Weapons", "weapon"], ["Ammo", "ammunition"],
	["Traps", "traps"], ["Electrical", "electrical"], ["Fun", "fun"], ["Components", "servers"], ["Attachments", "servers"], ["Other", "menu_dots"],
]

static var DB := {}
static var ORDER: Array = []

static func vec_from_source(v) -> Vector3:
	if v is Array:
		v = Vector3(v[0], v[1], v[2]) if v.size() >= 3 else Vector3.ZERO
	# GMod IronSightsPos: x — вправо, y — вперёд, z — вверх. В Godot камера смотрит в -Z.
	return Vector3(v.x * SU, v.z * SU, -v.y * SU)

static func hfov_to_vfov(h: float) -> float:
	# ViewModelFOV в GMod — горизонтальный угол для 4:3
	return rad_to_deg(2.0 * atan(tan(deg_to_rad(h) * 0.5) * 0.75))

static func _num(d: Dictionary, k: String, def: float) -> float:
	var v = d.get(k)
	return float(v) if v != null else def

static func _static_init() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/items.json"))
	var attire: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/attire.json"))
	var wj: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/weapons/weapons.json"))
	for id in data.order:
		var src: Dictionary = data.items[id]
		var d := src.duplicate(true)
		if d.icon == null:
			d.icon = "res://assets/icons/items/assault_rifle.png"
		match src.type:
			"weapon":
				if not src.has("scene"):
					continue   # нет вьюмодели (план строительства, провода)
				_setup_weapon(id, d, wj.get(src.get("vm_name", ""), {}))
			"attire_reg":
				continue    # заменены моделями из attire.json
		DB[id] = d
		ORDER.append(id)
	for id in attire:
		var a: Dictionary = attire[id]
		var d := a.duplicate(true)
		d["type"] = "attire"
		d["stack"] = 1
		d["category"] = "Clothing"
		d["recipe"] = [["cloth", 10]] if a.prot < 0.15 else [["cloth", 20], ["metal_fragments", 50]]
		d["craftable"] = true
		d["craft_amount"] = 1
		d["craft_time"] = 0.0
		DB[id] = d
		ORDER.append(id)

static func _setup_weapon(id: String, d: Dictionary, w: Dictionary) -> void:
	var seqs: Dictionary = w.get("seqs", {})
	var acts := {}
	for s in seqs:
		var a: String = seqs[s].activity
		if not acts.has(a):
			acts[a] = []
		acts[a].append(s)
	d["acts"] = acts
	d["seqs"] = seqs
	d["sounds"] = w.get("sounds", {})
	var kind: String = d.get("kind", "gun")
	if id == "hammer":
		kind = "melee"
	d["kind"] = kind
	d["type"] = "weapon"
	d["vm_fov"] = _num(d, "vm_fov", 60.0)
	# поза от 3-го лица
	if kind in ["gun", "shotgun", "launcher"]:
		d["hold"] = "pistol" if id in ["m92_pistol", "python_revolver", "revolver", "semi_automatic_pistol", "eoka_pistol", "nailgun"] else "rifle"
	elif kind == "bow":
		d["hold"] = "pistol"
	else:
		d["hold"] = "melee"
	if kind in ["gun", "shotgun", "bow", "launcher"]:
		var at = d.get("ammo_types")
		if at == null or at.is_empty():
			at = ["arrow"] if kind == "bow" else ["pistol_bullet"]
		if "wooden_arrow" in at:
			at = ["arrow"]
		d["ammo_types"] = at
		d["ammo"] = at[0]
		d["clip"] = int(_num(d, "clip", 1))
		d["rpm"] = _num(d, "rpm", 300.0)
		d["damage"] = _num(d, "damage", 30.0)
		d["bullets"] = int(_num(d, "bullets", 1))
		if id in ["waterpipe_shotgun", "double_barrel_shotgun", "eoka_pistol", "pump_shotgun", "spas_12_shotgun"]:
			d["bullets"] = max(d.bullets, 10)
		if d.get("auto") == null or d.bullets > 1 or kind in ["bow", "launcher"] or id == "crossbow":
			d["auto"] = d.get("auto", false) == true and d.bullets <= 1 and kind == "gun" and id != "crossbow"
		d["spread"] = clamp(_num(d, "cone", 0.3) * 2.0, 0.3, 4.0)
		if d.bullets > 1:
			d["spread"] = 3.5
		var rec = d.get("recoil", [])
		var k := Vector2(1.0, 0.4)
		if rec is Array and rec.size() > 0:
			var sx := 0.0
			var sy := 0.0
			for r in rec:
				sx += abs(r[0]); sy += abs(r[1])
			k = Vector2(sx / rec.size() * 0.35, sy / rec.size() * 0.15)
		if d.bullets > 1 or kind == "launcher":
			k = Vector2(4.0, 1.0)
		d["kick"] = k
		if d.get("ads") == null:
			d["ads"] = [0, 0, 0]
	elif kind == "melee":
		d["damage"] = _num(d, "damage", 20.0)
		d["rpm"] = _num(d, "attack_rate", 46.0)
		d["range"] = max(_num(d, "range", 1.5), 1.4) + 0.3
		d["hit_delay"] = clamp(_num(d, "attack_delay", 0.3), 0.1, 0.5)
	elif kind == "throw":
		d["damage"] = _num(d, "damage", 80.0)
		d["fuse"] = _num(d, "fuse", 3.0)
		d["radius"] = _num(d, "radius", 4.0)
	elif kind == "medical":
		d["heal"] = _num(d, "heal", 10.0) + _num(d, "healing", 0.0)

static func get_def(id: String) -> Dictionary:
	return DB.get(id, {})

static func is_weapon(id: String) -> bool:
	return get_def(id).get("type", "") == "weapon"

static func max_stack(id: String) -> int:
	return int(get_def(id).get("stack", 1))

## Все предметы категории (для меню крафта)
static func in_category(cat: String) -> Array:
	var res := []
	for id in ORDER:
		if DB[id].get("category", "Other") == cat:
			res.append(id)
	return res
