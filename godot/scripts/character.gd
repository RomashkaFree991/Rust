extends Node3D
class_name Character
## Модель игрока Rust (rust_model) с одеждой, оружием в руке и процедурной анимацией.
## Анимации тела — CC0-библиотеки Quaternius (Universal Animation Library 1 и 2), перенесённые
## на скелет ValveBiped (tools/godot_conversion/retarget.py) и смешиваемые в AnimationTree.
## Готовых анимаций с автоматом в свободном доступе нет: тело играет стойку с пистолетом,
## а кисти к автомату прижимаются IK поверх анимации (RifleHands).

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
var move_speed := 0.0          # 0..1 (1 — спринт)
var in_air := false
var recoil := 0.0
var anim_player: AnimationPlayer
var tree: AnimationTree
var hands: SkeletonModifier3D
static var _anim_lib: AnimationLibrary
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
	_setup_anim()
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
	recoil = move_toward(recoil, 0.0, delta * 6.0)
	if tree:
		tree.set("parameters/loco/blend_position", clamp(move_speed, 0.0, 1.0))
		tree.set("parameters/aim/blend_position", clamp(aim_pitch / 60.0, -1.0, 1.0))
		var armed := 1.0 if hold != "" else 0.0
		var cur: float = tree.get("parameters/armed/blend_amount")
		tree.set("parameters/armed/blend_amount", move_toward(cur, armed, delta * 5.0))
		tree.set("parameters/upper_kind/transition_request", "melee" if hold == "melee" else "gun")
		var st := "dead" if dead else ("air" if in_air else "ground")
		if tree.get("parameters/state/current_state") != st:
			tree.set("parameters/state/transition_request", st)
	_update_flash(delta)

# ---------- анимации ----------

const UPPER := ["Spine2", "Spine4", "Neck1", "Head1", "R_Clavicle", "R_UpperArm", "R_Forearm", "R_Hand",
	"L_Clavicle", "L_UpperArm", "L_Forearm", "L_Hand"]

func _setup_anim() -> void:
	if _anim_lib == null:
		var src: Node = load("res://assets/player/anims.glb").instantiate()
		var ap: AnimationPlayer = src.find_child("AnimationPlayer", true, false)
		_anim_lib = ap.get_animation_library("")
		for n in ["Death01", "Pistol_Shoot", "Pistol_Reload", "Sword_Attack", "Hit_Chest", "Hit_Head", "Chest_Open", "Jump_Start", "Jump_Land", "Punch_Jab", "Interact"]:
			if _anim_lib.has_animation(n):
				_anim_lib.get_animation(n).loop_mode = Animation.LOOP_NONE
		src.free()
	anim_player = AnimationPlayer.new()
	model.add_child(anim_player)
	anim_player.root_node = NodePath("..")
	anim_player.add_animation_library("", _anim_lib)
	var bt := AnimationNodeBlendTree.new()
	var loco := AnimationNodeBlendSpace1D.new()
	for pt in [["Idle", 0.0], ["Walk", 0.4], ["Jog_Fwd", 0.75], ["Sprint", 1.0]]:
		var a := AnimationNodeAnimation.new(); a.animation = pt[0]
		loco.add_blend_point(a, pt[1], -1, pt[0])
	loco.min_space = 0.0
	loco.max_space = 1.0
	bt.add_node("loco", loco, Vector2(0, 0))
	var aim := AnimationNodeBlendSpace1D.new()
	for pt in [["Pistol_Aim_Down", -1.0], ["Pistol_Aim_Neutral", 0.0], ["Pistol_Aim_Up", 1.0]]:
		var a := AnimationNodeAnimation.new(); a.animation = pt[0]
		aim.add_blend_point(a, pt[1], -1, pt[0])
	bt.add_node("aim", aim, Vector2(0, 200))
	var sword := AnimationNodeAnimation.new(); sword.animation = "Sword_Idle"
	bt.add_node("sword", sword, Vector2(0, 300))
	var kind := AnimationNodeTransition.new()
	kind.add_input("gun"); kind.add_input("melee")
	kind.xfade_time = 0.2
	bt.add_node("upper_kind", kind, Vector2(200, 250))
	bt.connect_node("upper_kind", 0, "aim")
	bt.connect_node("upper_kind", 1, "sword")
	var armed := AnimationNodeBlend2.new()
	_filter_upper(armed)
	bt.add_node("armed", armed, Vector2(400, 100))
	bt.connect_node("armed", 0, "loco")
	bt.connect_node("armed", 1, "upper_kind")
	var last := "armed"
	var y := 400
	for os in [["shoot", "Pistol_Shoot"], ["reload", "Pistol_Reload"], ["melee", "Sword_Attack"], ["hit", "Hit_Chest"], ["use", "Chest_Open"]]:
		var one := AnimationNodeOneShot.new()
		one.fadein_time = 0.08
		one.fadeout_time = 0.2
		if os[0] != "use":
			_filter_upper(one)
		var a := AnimationNodeAnimation.new(); a.animation = os[1]
		bt.add_node(os[1], a, Vector2(400, y))
		bt.add_node(os[0], one, Vector2(600, y))
		bt.connect_node(os[0], 0, last)
		bt.connect_node(os[0], 1, os[1])
		last = os[0]
		y += 100
	var air := AnimationNodeAnimation.new(); air.animation = "Jump"
	bt.add_node("air_anim", air, Vector2(600, 1000))
	var death := AnimationNodeAnimation.new(); death.animation = "Death01"
	bt.add_node("death_anim", death, Vector2(600, 1100))
	var state := AnimationNodeTransition.new()
	state.add_input("ground"); state.add_input("air"); state.add_input("dead")
	state.xfade_time = 0.15
	bt.add_node("state", state, Vector2(800, 600))
	bt.connect_node("state", 0, last)
	bt.connect_node("state", 1, "air_anim")
	bt.connect_node("state", 2, "death_anim")
	bt.connect_node("output", 0, "state")
	tree = AnimationTree.new()
	tree.tree_root = bt
	model.add_child(tree)
	tree.root_node = NodePath("..")
	tree.anim_player = tree.get_path_to(anim_player)
	tree.active = true
	hands = preload("res://scripts/rifle_hands.gd").new()
	hands.character = self
	sk.add_child(hands)

func _filter_upper(n: AnimationNode) -> void:
	n.filter_enabled = true
	for b in UPPER:
		n.set_filter_path(NodePath("rust_model_ARM/Skeleton3D:" + B + b), true)
	for side in ["L", "R"]:
		for fi in 5:
			for seg in ["", "1", "2"]:
				n.set_filter_path(NodePath("rust_model_ARM/Skeleton3D:%s%s_Finger%d%s" % [B, side, fi, seg]), true)

func _fire_oneshot(n: String) -> void:
	if tree:
		tree.set("parameters/%s/request" % n, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

func play_shoot() -> void:
	recoil = 1.0
	_fire_oneshot("shoot")

func play_reload() -> void: _fire_oneshot("reload")
func play_melee() -> void: _fire_oneshot("melee")
func play_hit() -> void: _fire_oneshot("hit")
func play_use() -> void: _fire_oneshot("use")

# ---------- руки на автомате (после анимации) ----------

func _g(n: String) -> Transform3D:
	return sk.get_bone_global_pose(idx[n])

func _set_g(n: String, t: Transform3D) -> void:
	sk.set_bone_global_pose(idx[n], t)

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

## Вызывается RifleHands после AnimationTree: оружие в руке и поворот головы к цели
func post_animation() -> void:
	if look_target != null and not dead:
		var hp := sk.global_transform * _g("Head1").origin
		var to: Vector3 = (sk.global_transform.affine_inverse() * (look_target as Vector3)) - (sk.global_transform.affine_inverse() * hp)
		var yaw: float = clamp(atan2(to.x, to.z), -1.0, 1.0)
		var cur := _g("Head1")
		_set_g("Head1", Transform3D(Basis(Vector3.UP, yaw) * cur.basis, cur.origin))
	if weapon_node == null:
		return
	if hold == "rifle" and not weapon_geo.is_empty() and not dead:
		var p: float = clamp(aim_pitch, -60, 60)
		var aim := Basis(Vector3.RIGHT, deg_to_rad(-p))
		var g := weapon_geo
		var bm := Basis((g.up as Vector3).cross(g.fwd), g.up, g.fwd)
		var bt := aim * Basis(Vector3.RIGHT, Vector3.UP, Vector3.BACK)
		var wbasis := bt * bm.inverse()
		var sh := _g("R_UpperArm").origin
		var butt_pos := sh + aim * Vector3(0.075, 0.055, 0.02 - recoil * 0.05)
		var wroot := Transform3D(wbasis, butt_pos - wbasis * (g.butt as Vector3))
		var hand_pos: Vector3 = wroot * (g.hand as Vector3)
		_ik("R_UpperArm", "R_Forearm", "R_Hand", hand_pos, aim * Vector3(-1.0, -0.15, -0.35), (wroot * weapon_hand_rest).basis)
		var fore_pt: Vector3 = wroot * ((g.hand as Vector3).lerp(g.tip, 0.5) - (g.up as Vector3) * 0.025)
		_ik("L_UpperArm", "L_Forearm", "L_Hand", fore_pt, aim * Vector3(0.3, -1.0, 0.05))
		weapon_node.transform = model.transform * wroot
	else:
		# пистолет / нож / камень — в правой кисти, как bonemerge в GMod
		var hand := _g("R_Hand")
		weapon_node.transform = model.transform * (hand * weapon_hand_rest.affine_inverse())

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
