extends Node3D
class_name Character
## Модель игрока Rust (rust_model) с одеждой, оружием в руке и процедурной анимацией.
## Анимаций тела в репозитории нет (GMod берёт их из стандартного m_anm.mdl), поэтому
## стойка, ходьба, прицеливание и падение сделаны процедурно: IK рук + качание ног.

const SCALE := 1.22
const B := "ValveBiped.Bip01_"

var model: Node3D
var sk: Skeleton3D
var body_meshes := {}          # имя части -> MeshInstance3D
var attire_meshes := {}        # id -> Array[MeshInstance3D]
var weapon_node: Node3D        # w_ модель
var weapon_hand_rest := Transform3D.IDENTITY
var weapon_def: Dictionary = {}
var weapon_geo := {}           # ось ствола в пространстве модели: tip, butt, fwd, up
static var _geo_cache := {}
var hold := ""                 # rifle / pistol / melee / ""

var aim_pitch := 0.0           # градусы, + вверх
var move_speed := 0.0          # 0..1
var walk_phase := 0.0
var breathe := 0.0
var melee_swing := 0.0         # 0..1 анимация удара
var recoil := 0.0
var look_target = null         # Vector3 в глобальных координатах (поворот головы)
var dead := false
var layer_mask := 1
var cast_mode := GeometryInstance3D.SHADOW_CASTING_SETTING_ON

var idx := {}
var rest := {}                 # имя -> глобальная rest-трансформа
static var _cache := {}

static func _load(path: String) -> PackedScene:
	if not _cache.has(path):
		_cache[path] = load(path)
	return _cache[path]

func _ready() -> void:
	_build()

func _build() -> void:
	if model:
		return
	model = _load("res://assets/player/player.gltf").instantiate()
	model.scale = Vector3.ONE * SCALE
	add_child(model)
	sk = model.find_child("Skeleton3D", true, false)
	for m in sk.get_children():
		if m is MeshInstance3D:
			body_meshes[String(m.name)] = m
			_fix_mat(m, true)
	for n in ["Pelvis", "Spine", "Spine1", "Spine2", "Spine4", "Neck1", "Head1", "R_Clavicle", "R_UpperArm", "R_Forearm", "R_Hand",
			"L_Clavicle", "L_UpperArm", "L_Forearm", "L_Hand", "R_Thigh", "R_Calf", "R_Foot", "L_Thigh", "L_Calf", "L_Foot"]:
		var i := sk.find_bone(B + n)
		idx[n] = i
		rest[n] = sk.get_bone_global_rest(i)
	# базовое бельё (как у голого персонажа в Rust)
	_add_attire_meshes("underwear_pants", "res://assets/player/underwear_pants.gltf")
	_set_body_visible()
	set_process(true)

func _fix_mat(m: MeshInstance3D, skin: bool) -> void:
	for s in m.mesh.get_surface_count():
		var mat = m.get_active_material(s)
		if mat is StandardMaterial3D:
			var nm: StandardMaterial3D = mat.duplicate()
			nm.metallic = 0.0
			nm.roughness = 0.8
			nm.normal_scale = 0.6
			if skin and String(nm.resource_name).to_lower().contains("body") or String(nm.resource_name).to_lower().contains("face"):
				nm.albedo_color = Color(0.93, 0.76, 0.64)
			if String(nm.resource_name).to_lower().contains("hair") or String(nm.resource_name).to_lower().contains("eyelash"):
				nm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
				nm.alpha_scissor_threshold = 0.4
				nm.cull_mode = BaseMaterial3D.CULL_DISABLED
			else:
				nm.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
			m.set_surface_override_material(s, nm)

func set_layers(mask: int, cast: int) -> void:
	_build()
	layer_mask = mask
	cast_mode = cast
	for m in sk.find_children("*", "MeshInstance3D", true, false):
		m.layers = mask
		m.cast_shadow = cast
	if weapon_node:
		for m in weapon_node.find_children("*", "MeshInstance3D", true, false):
			m.layers = mask
			m.cast_shadow = cast

## Одежда: список id
func set_attire(ids: Array) -> void:
	_build()
	for id in attire_meshes.keys():
		if id == "underwear_pants":
			continue
		if not id in ids:
			for m in attire_meshes[id]:
				m.queue_free()
			attire_meshes.erase(id)
	for id in ids:
		if attire_meshes.has(id):
			continue
		var d := Items.get_def(id)
		if d.is_empty():
			continue
		_add_attire_meshes(id, d.scene)
	_set_body_visible(ids)

func _add_attire_meshes(id: String, path: String) -> void:
	var inst: Node3D = _load(path).instantiate()
	var cs: Skeleton3D = inst.find_child("Skeleton3D", true, false)
	var list := []
	for m in cs.get_children():
		if m is MeshInstance3D:
			cs.remove_child(m)
			m.owner = null
			sk.add_child(m)
			m.skeleton = NodePath("..")
			m.layers = layer_mask
			m.cast_shadow = cast_mode
			_fix_mat(m, false)
			list.append(m)
	inst.free()
	attire_meshes[id] = list

func _set_body_visible(ids: Array = []) -> void:
	var hide := {}
	var show := {}
	for id in ids:
		for h in Items.get_def(id).get("hide", []):
			hide[h] = true
		for h in Items.get_def(id).get("show", []):
			show[h] = true
	for n in body_meshes:
		var m: MeshInstance3D = body_meshes[n]
		var v := false
		if n.begins_with("Head_Male_Light01"): v = true
		elif n.begins_with("Torso_00"): v = not hide.has("Torso")
		elif n.begins_with("Hands_00"): v = true
		elif n.begins_with("Underwear_Legs"): v = not hide.has("Legs")
		elif n.begins_with("Legs_01"): v = show.has("Legs_01")
		elif n.begins_with("Feet_00"): v = not hide.has("Feet")
		elif n.begins_with("hairs_male_hairstyle_01"): v = not hide.has("hair")
		elif n.begins_with("hairs_male_facial_hair"): v = not hide.has("beard")
		m.visible = v
	if attire_meshes.has("underwear_pants"):
		for m in attire_meshes["underwear_pants"]:
			m.visible = not hide.has("Legs")

## Оружие в руке (модель w_*)
func set_weapon(id: String) -> void:
	_build()
	if weapon_node:
		weapon_node.queue_free()
		weapon_node = null
	weapon_def = Items.get_def(id) if id != "" else {}
	hold = weapon_def.get("hold", "")
	if weapon_def.is_empty():
		return
	weapon_node = _load(weapon_def.world).instantiate()
	add_child(weapon_node)
	var wsk: Skeleton3D = weapon_node.find_child("Skeleton3D", true, false)
	weapon_hand_rest = Transform3D.IDENTITY
	if wsk:
		var hi := wsk.find_bone(B + "R_Hand")
		if hi >= 0:
			weapon_hand_rest = wsk.get_bone_global_rest(hi)
	for m in weapon_node.find_children("*", "MeshInstance3D", true, false):
		m.layers = layer_mask
		m.cast_shadow = cast_mode
	weapon_geo = _weapon_geo(weapon_def.world, weapon_node)

func _weapon_geo(key: String, n: Node3D) -> Dictionary:
	if _geo_cache.has(key):
		return _geo_cache[key]
	var pts := PackedVector3Array()
	for m in n.find_children("*", "MeshInstance3D", true, false):
		for si in m.mesh.get_surface_count():
			pts.append_array(m.mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX])
	var ymax := -1e9
	var ymin := 1e9
	for v in pts:
		ymax = max(ymax, v.y)
		ymin = min(ymin, v.y)
	var tip := Vector3.ZERO
	var butt := Vector3.ZERO
	var tn := 0
	var bn := 0
	for v in pts:
		if v.y > ymax - 0.03:
			tip += v; tn += 1
		elif v.y < ymin + 0.03:
			butt += v; bn += 1
	tip /= max(tn, 1)
	butt /= max(bn, 1)
	var hand := weapon_hand_rest.origin
	var fwd := (tip - butt).normalized()
	var th := tip - hand
	var up := (th - fwd * th.dot(fwd)).normalized()
	var g := {"tip": tip, "butt": butt, "fwd": fwd, "up": up, "hand": hand}
	_geo_cache[key] = g
	return g

func _process(delta: float) -> void:
	if sk == null:
		return
	breathe += delta
	if move_speed > 0.05:
		walk_phase += delta * (5.0 + 4.0 * move_speed)
	recoil = move_toward(recoil, 0.0, delta * 6.0)
	if melee_swing > 0.0:
		melee_swing = max(0.0, melee_swing - delta * 2.2)
	_pose()
	_update_flash(delta)

# ---------- процедурная поза ----------

func _g(n: String) -> Transform3D:
	return sk.get_bone_global_pose(idx[n])

func _set_g(n: String, t: Transform3D) -> void:
	sk.set_bone_global_pose(idx[n], t)

## Повернуть кость (в пространстве скелета) на rot относительно её rest-ориентации, оставив позицию
func _rot_rest(n: String, rot: Basis) -> void:
	var cur := _g(n)
	_set_g(n, Transform3D(rot * rest[n].basis, cur.origin))

func _aim_x(n: String, dir: Vector3) -> void:
	var cur := _g(n)
	var x := cur.basis.x.normalized()
	if dir.length() < 0.0001:
		return
	var q := Quaternion(x, dir.normalized())
	_set_g(n, Transform3D(Basis(q) * cur.basis, cur.origin))

## IK двух костей: upper -> fore -> hand, цель target, подсказка локтя pole
func _ik(upper: String, fore: String, hand: String, target: Vector3, pole: Vector3, hand_basis = null) -> void:
	var s := _g(upper).origin
	var l1: float = (rest[fore].origin - rest[upper].origin).length()
	var l2: float = (rest[hand].origin - rest[fore].origin).length()
	var to := target - s
	var d: float = clamp(to.length(), 0.01, (l1 + l2) * 0.999)
	var dir := to.normalized()
	var a := (l1 * l1 - l2 * l2 + d * d) / (2.0 * d)
	var h := sqrt(max(l1 * l1 - a * a, 0.0))
	var perp := (pole - dir * pole.dot(dir))
	perp = perp.normalized() if perp.length() > 0.001 else Vector3.DOWN
	var e := s + dir * a + perp * h
	_aim_x(upper, e - s)
	_aim_x(fore, (s + dir * d) - _g(fore).origin)
	if hand_basis != null:
		var hc := _g(hand)
		_set_g(hand, Transform3D(hand_basis, hc.origin))

func _pose() -> void:
	if dead:
		return   # оставить последнюю позу (падение делает Bot)
	sk.reset_bone_poses()
	var b := sin(breathe * 1.6)
	# ноги: шаг
	var sw := sin(walk_phase) * 32.0 * move_speed
	var R := Vector3.RIGHT
	_rot_rest("R_Thigh", Basis(R, deg_to_rad(-sw)))
	_rot_rest("L_Thigh", Basis(R, deg_to_rad(sw)))
	var kr: float = max(0.0, -sin(walk_phase - 0.6)) * 45.0 * move_speed
	var kl: float = max(0.0, sin(walk_phase - 0.6)) * 45.0 * move_speed
	_rot_rest("R_Calf", Basis(R, deg_to_rad(-sw + kr)))
	_rot_rest("L_Calf", Basis(R, deg_to_rad(sw + kl)))
	_rot_rest("R_Foot", Basis(R, deg_to_rad(-sw + kr - 5)))
	_rot_rest("L_Foot", Basis(R, deg_to_rad(sw + kl - 5)))
	# корпус: наклон по прицелу, разворот вполоборота с оружием (как в Rust), дыхание
	var p: float = clamp(aim_pitch, -60, 60)
	var armed := (hold == "rifle" or hold == "pistol") and not weapon_geo.is_empty()
	var twist := 0.0
	if armed:
		twist = -28.0 if hold == "rifle" else -12.0
	var U := Vector3.UP
	_rot_rest("Spine2", Basis(U, deg_to_rad(twist * 0.45)) * Basis(R, deg_to_rad(-p * 0.25 + b * 0.8 + 3.0 * move_speed)))
	_rot_rest("Spine4", Basis(U, deg_to_rad(twist)) * Basis(R, deg_to_rad(-p * 0.5 + b * 1.0 + 3.0 * move_speed)))
	var head_down := 9.0 if hold == "rifle" else (5.0 if hold == "pistol" else 0.0)
	var head_roll := 9.0 if hold == "rifle" else 0.0
	_rot_rest("Neck1", Basis(U, deg_to_rad(twist * 0.5)) * Basis(R, deg_to_rad(-p * 0.6 + head_down * 0.5)))
	_rot_rest("Head1", Basis(Vector3.FORWARD, deg_to_rad(-head_roll)) * Basis(R, deg_to_rad(-p * 0.85 + head_down)))
	if look_target != null:
		var hp := sk.global_transform * _g("Head1").origin
		var to: Vector3 = (sk.global_transform.affine_inverse() * (look_target as Vector3)) - (sk.global_transform.affine_inverse() * hp)
		var yaw: float = clamp(atan2(to.x, to.z), -1.0, 1.0)
		var cur := _g("Head1")
		_set_g("Head1", Transform3D(Basis(Vector3.UP, yaw) * cur.basis, cur.origin))

	var aim := Basis(R, deg_to_rad(-p))   # направление вперёд (+Z) с учётом тангажа
	var chest := _g("Spine4").origin
	if armed:
		var g := weapon_geo
		var bm := Basis((g.up as Vector3).cross(g.fwd), g.up, g.fwd)        # оси модели оружия
		var bt := aim * Basis(Vector3.RIGHT, Vector3.UP, Vector3.BACK)      # ствол вперёд (+Z), верх вверх
		var wbasis := bt * bm.inverse()
		var wroot: Transform3D
		var sh := _g("R_UpperArm").origin
		if hold == "rifle":
			# приклад в правое плечо, оружие на уровне глаз
			var butt_pos := sh + aim * Vector3(0.075, 0.055 + b * 0.003, 0.02 - recoil * 0.05)
			wroot = Transform3D(wbasis, butt_pos - wbasis * (g.butt as Vector3))
		else:
			var grip_pos := chest + aim * Vector3(-0.035, 0.13 + b * 0.003, 0.4 - recoil * 0.06)
			wroot = Transform3D(wbasis, grip_pos - wbasis * (g.hand as Vector3))
		var hand_pos: Vector3 = wroot * (g.hand as Vector3)
		var rpole := aim * (Vector3(-1.0, -0.15, -0.35) if hold == "rifle" else Vector3(-0.7, -0.6, -0.2))
		_ik("R_UpperArm", "R_Forearm", "R_Hand", hand_pos, rpole, (wroot * weapon_hand_rest).basis)
		var fore_pt: Vector3
		if hold == "rifle":
			fore_pt = wroot * ((g.hand as Vector3).lerp(g.tip, 0.5) - (g.up as Vector3) * 0.025)
		else:
			fore_pt = hand_pos + aim * Vector3(0.035, -0.03, -0.005)
		var lpole := aim * (Vector3(0.3, -1.0, 0.05) if hold == "rifle" else Vector3(0.7, -0.6, -0.2))
		# левая кисть ладонью вверх под цевьём
		_ik("L_UpperArm", "L_Forearm", "L_Hand", fore_pt, lpole)
		var lh := _g("L_Hand")
		var palm_q := Quaternion(lh.basis.x.normalized(), (fore_pt + aim * Vector3(0.0, 0.0, 0.08) - lh.origin).normalized())
		_set_g("L_Hand", Transform3D(Basis(palm_q) * lh.basis, lh.origin))
		_curl("R", 62.0, 40.0)
		_curl("L", 55.0 if hold == "rifle" else 40.0, 35.0)
		if weapon_node:
			weapon_node.transform = model.transform * wroot
	elif hold == "melee":
		var s := melee_swing
		var swing_ang := sin(s * PI) * 80.0
		var hp := chest + Vector3(-0.22, -0.18 + sin(s * PI) * 0.25, 0.22 + sin(s * PI) * 0.15)
		_ik("R_UpperArm", "R_Forearm", "R_Hand", hp, Vector3(-0.5, -1, -0.4))
		var hand_xf := Transform3D(_g("R_Hand").basis, _g("R_Hand").origin)
		_relax_arm("L", b)
		_curl("R", 65.0, 25.0)
		_curl("L", 18.0, 5.0)
		if weapon_node:
			weapon_node.transform = model.transform * (hand_xf * weapon_hand_rest.affine_inverse())
	else:
		_relax_arm("R", b)
		_relax_arm("L", b)
		_curl("R", 18.0, 5.0)
		_curl("L", 18.0, 5.0)

## Согнуть пальцы (ось сгиба у костей ValveBiped — -Z, у большого пальца — -Y)
func _curl(side: String, ang: float, thumb: float) -> void:
	for fi in range(0, 5):
		for seg in ["", "1", "2"]:
			var bi := sk.find_bone("%s%s_Finger%d%s" % [B, side, fi, seg])
			if bi < 0:
				continue
			var a := thumb if fi == 0 else ang * (0.75 if seg == "" else 1.0)
			sk.set_bone_pose_rotation(bi, sk.get_bone_rest(bi).basis.get_rotation_quaternion() * Quaternion(Vector3(0, 0, -1) if fi != 0 else Vector3(0, -1, 0), deg_to_rad(a)))

func _relax_arm(side: String, b: float) -> void:
	var sgn := 1.0 if side == "L" else -1.0
	var sh := _g(side + "_UpperArm").origin
	var target := sh + Vector3(0.07 * sgn, -0.41 + b * 0.004, 0.03 + sin(walk_phase) * 0.12 * move_speed * -sgn)
	_ik(side + "_UpperArm", side + "_Forearm", side + "_Hand", target, Vector3(0.25 * sgn, 0, -1))

## Вспышка выстрела на конце ствола (вид от 3-го лица)
var _flash: MeshInstance3D
var _flash_light: OmniLight3D
var _flash_t := 0.0
func muzzle_flash() -> void:
	if weapon_node == null or weapon_geo.is_empty():
		return
	recoil = 1.0
	if _flash == null:
		_flash = MeshInstance3D.new()
		var q := QuadMesh.new(); q.size = Vector2(0.25, 0.25)
		var m := StandardMaterial3D.new()
		m.albedo_texture = load("res://assets/textures/muzzleflash.png")
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		q.material = m
		_flash.mesh = q
		_flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_flash)
		_flash_light = OmniLight3D.new()
		_flash_light.light_color = Color(1, 0.7, 0.35)
		_flash_light.omni_range = 4.0
		add_child(_flash_light)
	_flash_t = 0.05

func _update_flash(delta: float) -> void:
	if _flash == null:
		return
	_flash_t -= delta
	var on := _flash_t > 0.0
	_flash.visible = on
	_flash_light.light_energy = 2.0 if on else 0.0
	if on:
		var tip: Vector3 = weapon_node.global_transform * (weapon_geo.tip as Vector3)
		_flash.global_position = tip
		_flash_light.global_position = tip
		_flash.layers = layer_mask

## Локальные координаты кости для хитбоксов
func bone_global(n: String) -> Transform3D:
	return model.global_transform * _g(n)
