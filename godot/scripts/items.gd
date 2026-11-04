extends RefCounted
class_name Items
## База предметов. Характеристики оружия — из Lua-скриптов TFA Rust (scripts/lua/weapons/rust_*/shared.lua),
## одежда — модели characters/clothing (gRust vanguard attire), иконки — icons/items и icons/ui/items.

## 1 юнит Source = 0.01905 м (так масштабирует импорт моделей)
const SU := 0.01905

static func vec_from_source(v: Vector3) -> Vector3:
	# GMod IronSightsPos: x — вправо, y — вперёд, z — вверх. В Godot камера смотрит в -Z.
	return Vector3(v.x * SU, v.z * SU, -v.y * SU)

static func hfov_to_vfov(h: float) -> float:
	# ViewModelFOV в GMod — горизонтальный угол для 4:3
	return rad_to_deg(2.0 * atan(tan(deg_to_rad(h) * 0.5) * 0.75))

static func _gun(name: String, desc: String, icon: String, id: String, ammo: String, clip: int, rpm: float, auto: bool,
		dmg: int, fov: float, ads: Vector3, fire: Array, snd: String, kick: Vector2, spread: float, dry := "", dryfire := "") -> Dictionary:
	return {
		"type": "weapon", "name": name, "desc": desc, "icon": "res://assets/icons/%s.png" % icon,
		"scene": "res://assets/weapons/%s.gltf" % id, "world": "res://assets/weapons/w_%s.gltf" % id,
		"ammo": ammo, "clip": clip, "rpm": rpm, "auto": auto, "damage": dmg, "vm_fov": fov, "ads": ads,
		"fire": fire, "fire_ads": "fire_ads", "dryfire": dryfire, "shoot_sounds": snd,
		"dry_sound": dry if dry != "" else "res://assets/sounds/lr300-dryfire.mp3",
		"kick": kick, "spread": spread, "hold": "pistol" if clip <= 15 else "rifle",
	}

static var DB := {}

static func _static_init() -> void:
	var R := "ammo.rifle"
	var P := "ammo.pistol"
	DB["ak47u"] = _gun("Assault Rifle", "Автомат. Высокий темп стрельбы, патроны 5.56.", "assault_rifle", "ak47u", R, 30, 450, true, 50, 71,
		Vector3(-6.115, -6.896, 3.703), ["fire1", "fire2"], "ak74u-attack", Vector2(1.1, 0.45), 1.0)
	DB["lr300"] = _gun("LR-300 Assault Rifle", "Штурмовая винтовка, меньше отдача, чем у АК.", "lr300", "lr300", R, 30, 500, true, 40, 65,
		Vector3(-4.407, 0, 1.05), ["fire"], "lr300-attack", Vector2(0.8, 0.3), 0.9, "res://assets/sounds/lr300-dryfire.mp3")
	DB["m249"] = _gun("M249", "Пулемёт на 100 патронов.", "m249", "m249", R, 100, 500, true, 65, 60,
		Vector3(-3.631, 0, 3.359), ["fire"], "m249-attack", Vector2(1.0, 0.5), 1.4)
	DB["sar"] = _gun("Semi-Automatic Rifle", "Полуавтоматическая винтовка.", "sar", "sar", R, 16, 343, false, 40, 60,
		Vector3(-5.18, -2.985, 2.519), ["fire"], "semi-auto-rifle-attack", Vector2(1.6, 0.3), 0.6)
	DB["mp5"] = _gun("MP5A4", "Пистолет-пулемёт с высоким темпом.", "mp5", "mp5", P, 30, 600, true, 35, 60,
		Vector3(-6.47, 0, 2.9), ["fire"], "mp5-attack", Vector2(0.6, 0.3), 1.1)
	DB["thompson"] = _gun("Thompson", "Пистолет-пулемёт. Пистолетные патроны.", "thompson", "thompson", P, 20, 462, true, 37, 60,
		Vector3(-5.0, -4.0, 3.0), ["fire"], "thompson-attack", Vector2(0.7, 0.3), 1.2)
	DB["customsmg"] = _gun("Custom SMG", "Самодельный пистолет-пулемёт.", "custom_smg", "customsmg", P, 24, 600, true, 30, 55,
		Vector3(-6.95, 0, 3.68), ["fire1", "fire2", "fire3"], "smg-attack", Vector2(0.6, 0.35), 1.3)
	DB["m92"] = _gun("M92 Pistol", "Полуавтоматический пистолет на 15 патронов.", "m92", "m92", P, 15, 400, false, 45, 60,
		Vector3(-3.711, 0, 1.799), ["fire"], "m92-attack", Vector2(2.0, 0.4), 0.8)
	DB["python"] = _gun("Python Revolver", "Револьвер на 6 патронов. Мощный, но медленный.", "python", "python", P, 6, 400, false, 55, 60,
		Vector3(-4.385, -5.453, 2.475), ["fire"], "python-attack", Vector2(3.2, 0.6), 0.8, "res://assets/sounds/python-dryfire.mp3", "dryfire")
	DB["revolver"] = _gun("Revolver", "Простой револьвер на 8 патронов.", "revolver", "revolver", P, 8, 343, false, 35, 60,
		Vector3(-3.32, 0, 0.839), ["fire"], "revolver-attack", Vector2(2.4, 0.5), 1.0, "res://assets/sounds/revolver-dryfire.mp3", "dryfire")
	DB["combatknife"] = {
		"type": "melee", "name": "Combat Knife", "desc": "Боевой нож. Быстрые удары.",
		"icon": "res://assets/icons/combat_knife.png", "scene": "res://assets/weapons/combatknife.gltf",
		"world": "res://assets/weapons/w_combatknife.gltf", "damage": 35, "rpm": 68.0, "range": 1.7, "vm_fov": 75,
		"miss": ["slash1", "slash2"], "hit": ["slash1_hit", "slash2_hit"], "hit_delay": 0.15,
		"swing_snd": "bone-knife-attack", "strike_snd": "bone-knife-strike", "hold": "melee",
	}
	DB["rock"] = {
		"type": "melee", "name": "Rock", "desc": "Камень. С него всё начинается.",
		"icon": "res://assets/icons/rock.png", "scene": "res://assets/weapons/rock.gltf",
		"world": "res://assets/weapons/w_rock.gltf", "damage": 35, "rpm": 48.0, "range": 1.7, "vm_fov": 60,
		"miss": ["slash"], "hit": ["slash_hit"], "hit_delay": 0.4,
		"swing_snd": "rock-attack", "strike_snd": "rock-strike", "hold": "melee",
	}
	DB["ammo.rifle"] = {"type": "ammo", "name": "5.56 Rifle Ammo", "desc": "Патроны для АК, LR-300, M249, SAR.",
		"icon": "res://assets/icons/rifle_ammo.png", "stack": 128}
	DB["ammo.pistol"] = {"type": "ammo", "name": "Pistol Bullet", "desc": "Патроны для пистолетов и ПП.",
		"icon": "res://assets/icons/pistol_bullet.png", "stack": 128}
	# одежда: slot — категория (одна вещь на категорию), hide — какие части тела прятать,
	# arms — какая модель рук от первого лица включается, prot — защита от пуль/ближнего боя
	_att("jacket", "Jacket", "attire_jacket", "torso", [], "", 0.15, 0.15, "Куртка. Тепло и немного защиты.")
	_att("tshirt_long", "Longsleeve T-Shirt", "attire_tshirt.long", "torso", ["Torso"], "", 0.05, 0.05, "Футболка с длинным рукавом.")
	_att("roadsign_jacket", "Road Sign Jacket", "attire_roadsign.jacket", "torso", [], "", 0.2, 0.2, "Броня из дорожных знаков.")
	_att("heavy_plate_jacket", "Heavy Plate Jacket", "attire_heavy.plate.jacket", "torso", ["Torso"], "", 0.25, 0.25, "Тяжёлая броня на торс.")
	_att("pants_hide", "Hide Pants", "attire_attire.hide.pants", "legs", ["Legs"], "", 0.1, 0.1, "Штаны из шкуры.")
	DB["pants_hide"]["show"] = ["Legs_01"]
	_att("heavy_plate_legs", "Heavy Plate Pants", "attire_heavy.plate.pants", "legs", ["Legs"], "", 0.25, 0.25, "Тяжёлая броня на ноги.")
	_att("shoes_boots", "Boots", "attire_shoes.boots", "feet", ["Feet"], "", 0.1, 0.1, "Ботинки.")
	_att("tactical_gloves", "Tactical Gloves", "attire_tactical.gloves", "hands", [], "TacticalGloves_vm", 0.05, 0.05, "Тактические перчатки.")
	_att("hat_cap", "Baseball Cap", "attire_hat.cap", "head", ["hair"], "", 0.05, 0.05, "Кепка.")
	_att("heavy_plate_helmet", "Heavy Plate Helmet", "attire_heavy.plate.helmet", "head", ["hair"], "", 0.4, 0.4, "Тяжёлый шлем. Отлично держит выстрел в голову.")
	_att("metal_mask", "Metal Facemask", "attire_metal.facemask", "face", ["beard"], "", 0.5, 0.5, "Металлическая маска.")
	_att("bandana", "Bandana Mask", "attire_mask.bandana", "face", ["beard"], "", 0.05, 0.05, "Бандана.")

static func _att(id: String, name: String, icon: String, slot: String, hide: Array, arms: String, proj: float, melee: float, desc: String) -> void:
	DB[id] = {"type": "attire", "name": name, "desc": desc, "icon": "res://assets/icons/%s.png" % icon,
		"scene": "res://assets/player/%s.gltf" % id, "slot": slot, "hide": hide, "arms": arms,
		"prot": proj, "melee_prot": melee, "stack": 1}

static func get_def(id: String) -> Dictionary:
	return DB.get(id, {})

static func is_weapon(id: String) -> bool:
	var t = get_def(id).get("type", "")
	return t == "weapon" or t == "melee"
