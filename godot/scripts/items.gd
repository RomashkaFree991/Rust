extends RefCounted
class_name Items
## База предметов: оружие и патроны. Данные взяты из Lua-скриптов TFA Rust (scripts/lua/weapons/rust_*/shared.lua).

## 1 юнит Source = 0.01905 м (так масштабирует импорт моделей)
const SU := 0.01905

static func vec_from_source(v: Vector3) -> Vector3:
	# GMod IronSightsPos: x — вправо, y — вперёд, z — вверх. В Godot камера смотрит в -Z.
	return Vector3(v.x * SU, v.z * SU, -v.y * SU)

static func hfov_to_vfov(h: float) -> float:
	# ViewModelFOV в GMod — горизонтальный угол для 4:3
	return rad_to_deg(2.0 * atan(tan(deg_to_rad(h) * 0.5) * 0.75))

const DB := {
	"ak47u": {
		"type": "weapon",
		"name": "Assault Rifle",
		"desc": "Автомат. Высокий темп стрельбы, патроны 5.56.",
		"icon": "res://assets/icons/assault_rifle.png",
		"scene": "res://assets/weapons/ak47u.glb",
		"ammo": "ammo.rifle",
		"clip": 30,
		"rpm": 450.0,
		"auto": true,
		"damage": 50,
		"vm_fov": 71.0,
		"ads": Vector3(-6.115, -6.896, 3.703),
		"fire": ["fire1", "fire2"],
		"fire_ads": "fire_ads",
		"dryfire": "",
		"shoot_sounds": "ak74u-attack",
		"dry_sound": "res://assets/sounds/lr300-dryfire.mp3",
		"kick": Vector2(1.1, 0.45),
		"spread": 1.0,
	},
	"thompson": {
		"type": "weapon",
		"name": "Thompson",
		"desc": "Пистолет-пулемёт. Пистолетные патроны.",
		"icon": "res://assets/icons/thompson.png",
		"scene": "res://assets/weapons/thompson.glb",
		"ammo": "ammo.pistol",
		"clip": 20,
		"rpm": 462.0,
		"auto": true,
		"damage": 37,
		"vm_fov": 60.0,
		"ads": Vector3(-5.0, -4.0, 3.0),
		"fire": ["fire"],
		"fire_ads": "fire_ads",
		"dryfire": "",
		"shoot_sounds": "thompson-attack",
		"dry_sound": "res://assets/sounds/lr300-dryfire.mp3",
		"kick": Vector2(0.7, 0.3),
		"spread": 1.2,
	},
	"python": {
		"type": "weapon",
		"name": "Python Revolver",
		"desc": "Револьвер на 6 патронов. Мощный, но медленный.",
		"icon": "res://assets/icons/python.png",
		"scene": "res://assets/weapons/python.glb",
		"ammo": "ammo.pistol",
		"clip": 6,
		"rpm": 400.0,
		"auto": false,
		"damage": 55,
		"vm_fov": 60.0,
		"ads": Vector3(-4.385, -5.453, 2.475),
		"fire": ["fire"],
		"fire_ads": "fire_ads",
		"dryfire": "dryfire",
		"shoot_sounds": "python-attack",
		"dry_sound": "res://assets/sounds/python-dryfire.mp3",
		"kick": Vector2(3.2, 0.6),
		"spread": 0.8,
	},
	"ammo.rifle": {
		"type": "ammo",
		"name": "5.56 Rifle Ammo",
		"desc": "Патроны для автомата.",
		"icon": "res://assets/icons/rifle_ammo.png",
		"stack": 128,
	},
	"ammo.pistol": {
		"type": "ammo",
		"name": "Pistol Bullet",
		"desc": "Патроны для Thompson и Python.",
		"icon": "res://assets/icons/pistol_bullet.png",
		"stack": 128,
	},
}

static func get_def(id: String) -> Dictionary:
	return DB.get(id, {})
