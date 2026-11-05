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
var wounded := false
var dead_lying := false        # умер после ранения — лежит
var move_local := Vector2.ZERO  # направление движения: x — вправо, y — вперёд
var body_yaw := 0.0             # поворот ног к направлению движения (рад)
var recoil := 0.0
var anim_player: AnimationPlayer
var tree: AnimationTree
var hands: SkeletonModifier3D
static var _anim_lib: AnimationLibrary
static var _tints: Dictionary = {}
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
	if _tints.is_empty():
		_tints = JSON.parse_string(FileAccess.get_file_as_string("res://assets/player/tints.json"))
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

func _fix_mat(m: MeshInstance3D, skin: bool, grow := 0.0) -> void:
	for s in m.mesh.get_surface_count():
		var mat = m.get_active_material(s)
		if mat is StandardMaterial3D:
			var nm: StandardMaterial3D = mat.duplicate()
			nm.metallic = 0.0
			nm.roughness = 0.8
			nm.normal_scale = 0.6
			# оттенок материала из VMT ($color2 / $color), как в Source
			var key := String(nm.resource_name).to_lower().get_slice(".", 0)
			if _tints.has(key):
				var t: Array = _tints[key]
				nm.albedo_color = Color(min(t[0] * 1.5, 1.0), min(t[1] * 1.5, 1.0), min(t[2] * 1.5, 1.0))
			if String(nm.resource_name).to_lower().contains("hair") or String(nm.resource_name).to_lower().contains("eyelash"):
				nm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
				nm.alpha_scissor_threshold = 0.4
				nm.cull_mode = BaseMaterial3D.CULL_DISABLED
			else:
				nm.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
			if grow > 0.0:
				# одежда чуть «раздута» по нормалям, чтобы тело не просвечивало сквозь неё в движении
				nm.grow = true
				nm.grow_amount = grow
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

## Слои одежды: бельё ближе к телу, броня и пончо — поверх рубашек
static func _grow_for(id: String) -> float:
	if id == "underwear_pants" or id == "maleunderwear_coconut":
		return 0.0015
	var sl: String = Items.get_def(id).get("slot", "")
	match sl:
		"chest", "kilt", "kneepads", "back", "suit":
			return 0.009
		"full":
			return 0.0
		"head", "face", "eyes":
			return 0.003
	return 0.005

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
			_fix_mat(m, false, _grow_for(id))
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
	var all := hide.has("all")
	for n in body_meshes:
		var m: MeshInstance3D = body_meshes[n]
		var v := false
		if n.begins_with("Head_Male_Light01"): v = true
		elif n.begins_with("Torso_00"): v = not hide.has("Torso")
		elif n.begins_with("Hands_00"): v = true
		elif n.begins_with("Underwear_Legs"): v = not hide.has("Legs")
		elif n.begins_with("Legs_01"): v = show.has("Legs_01")
		elif n.begins_with("Torso_01"): v = show.has("Torso_01")
		elif n.begins_with("Feet_00"): v = not hide.has("Feet")
		elif n.begins_with("hairs_male_hairstyle_01"): v = not hide.has("hair")
		elif n.begins_with("hairs_male_facial_hair"): v = not hide.has("beard")
		m.visible = v and not all
	if attire_meshes.has("underwear_pants"):
		for m in attire_meshes["underwear_pants"]:
			m.visible = not hide.has("Legs") and not all

## Оружие в руке (модель w_*)
var weapon_side := "R"          # к какой кисти прикреплена модель (у луков — к левой)

## Поза от 3-го лица по типу предмета
static func hold_for(d: Dictionary, id: String) -> String:
	if d.is_empty():
		return ""
	var k: String = d.get("kind", "")
	match k:
		"gun", "shotgun":
			return "pistol" if d.get("hold", "") == "pistol" else "rifle"
		"launcher":
			return "launcher" if id == "rocket_launcher" else "rifle"
		"bow":
			return "rifle" if id == "crossbow" else "bow"
		"melee":
			return "melee"
		"throw", "medical", "tool":
			return "item"
	return d.get("hold", "item")

func set_weapon(id: String) -> void:
	_build()
	if weapon_node:
		weapon_node.queue_free()
		weapon_node = null
	weapon_def = Items.get_def(id) if id != "" else {}
	hold = hold_for(weapon_def, id)
	weapon_geo = {}
	if weapon_def.is_empty() or not weapon_def.has("world"):
		hold = ""
		return
	weapon_node = _load(weapon_def.world).instantiate()
	add_child(weapon_node)
	Attachments.attach_world(self, weapon_node, id)   # обвесы (attachments.gd)
	var wsk: Skeleton3D = weapon_node.find_child("Skeleton3D", true, false)
	weapon_hand_rest = Transform3D.IDENTITY
	weapon_side = "R"
	if wsk:
		# кость, к которой привязана сетка (bonemerge в GMod): у охотничьего лука — левая кисть
		var bound := ""
		for m in weapon_node.find_children("*", "MeshInstance3D", true, false):
			if m.skin and m.skin.get_bind_count() > 0:
				bound = String(m.skin.get_bind_name(0))
				break
		var bi := wsk.find_bone(bound) if bound != "" else -1
		if bi < 0:
			bi = wsk.find_bone(B + "R_Hand")
		if bi < 0:
			bi = wsk.find_bone(B + "L_Hand")
		if bi >= 0:
			weapon_hand_rest = wsk.get_bone_global_rest(bi)
			weapon_side = "L" if wsk.get_bone_name(bi).contains("L_Hand") else "R"
	for m in weapon_node.find_children("*", "MeshInstance3D", true, false):
		m.layers = layer_mask
		m.cast_shadow = cast_mode
	weapon_geo = _weapon_geo(weapon_def.world + "|" + hold, weapon_node)

## Геометрия оружия в пространстве модели: ось ствола (по направлению пальцев кисти, как держит GMod),
## дуло/приклад, «верх», точка хвата
func _weapon_geo(key: String, n: Node3D) -> Dictionary:
	if _geo_cache.has(key):
		return _geo_cache[key]
	var pts := PackedVector3Array()
	for m in n.find_children("*", "MeshInstance3D", true, false):
		for si in m.mesh.get_surface_count():
			pts.append_array(m.mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX])
	var hand := weapon_hand_rest.origin
	var lo := Vector3(1e9, 1e9, 1e9)
	var hi := -lo
	for v in pts:
		lo = lo.min(v)
		hi = hi.max(v)
	var ext := hi - lo
	var hx := weapon_hand_rest.basis.x.normalized()
	if hold in ["melee", "item"]:
		# клинок/рукоять: от кисти к самой дальней точке
		var far := hand
		for v in pts:
			if (v - hand).length() > (far - hand).length():
				far = v
		var bd := (far - hand).normalized()
		var fd := (hx - bd * hx.dot(bd)).normalized()
		var gm := {"tip": far, "butt": hand, "fwd": bd, "up": fd, "hand": hand, "center": (lo + hi) * 0.5, "len": (far - hand).length()}
		_geo_cache[key] = gm
		return gm
	if hold == "bow":
		# лук: длинная ось — плечи лука (вертикаль), стрела — по пальцам кисти
		var la := 0
		for i in 3:
			if ext[i] > ext[la]:
				la = i
		var upb := Vector3.ZERO
		upb[la] = 1.0
		var fb := (hx - upb * hx.dot(upb)).normalized()
		var gb := {"tip": hand + fb * 0.3, "butt": hand - fb * 0.1, "fwd": fb, "up": upb, "hand": hand, "center": (lo + hi) * 0.5, "len": ext[la]}
		_geo_cache[key] = gb
		return gb
	# 1) ось по пальцам кисти (как держит GMod), дуло/приклад — крайние точки по ней
	var ax := 0
	for i in 3:
		if abs(hx[i]) > abs(hx[ax]):
			ax = i
	var a0 := Vector3.ZERO
	a0[ax] = signf(hx[ax])
	var ends := _ends(pts, a0)
	var tip0: Vector3 = ends[0]
	var butt: Vector3 = ends[1]
	# 2) «верх» — та из поперечных осей, по которой ствол дальше всего от кисти
	var th := tip0 - hand
	var bu := -1
	for i in 3:
		if i != ax and (bu == -1 or abs(th[i]) > abs(th[bu])):
			bu = i
	var u0 := Vector3.ZERO
	u0[bu] = signf(th[bu]) if th[bu] != 0.0 else 1.0
	var fixed_axes := false
	for k in GEO_UP:
		if key.contains(k):
			u0 = GEO_UP[k]
			fixed_axes = true
	# 3) линия ствола — по верхней трети модели (ствол / затвор, без магазина и рукояти)
	var umax := -1e9
	var umin := 1e9
	for v in pts:
		umax = max(umax, v.dot(u0)); umin = min(umin, v.dot(u0))
	var topv := PackedVector3Array()
	for v in pts:
		if v.dot(u0) > umax - (umax - umin) * 0.3:
			topv.append(v)
	var te := _ends(topv, a0)
	var fwd: Vector3 = ((te[0] as Vector3) - (te[1] as Vector3)).normalized()
	var tip: Vector3 = te[0]
	if fixed_axes:
		fwd = (tip0 - butt).normalized()
		tip = tip0
	var up := (u0 - fwd * u0.dot(fwd)).normalized()
	var pmax := -1e9
	var pmin := 1e9
	for v in pts:
		pmax = max(pmax, v.dot(fwd)); pmin = min(pmin, v.dot(fwd))
	var g := {"tip": tip, "butt": butt, "fwd": fwd, "up": up, "hand": hand, "center": (lo + hi) * 0.5,
		"len": pmax - pmin}
	_geo_cache[key] = g
	return g

static func _ends(pts: PackedVector3Array, a: Vector3) -> Array:
	var pmax := -1e9
	var pmin := 1e9
	for v in pts:
		var d := v.dot(a)
		pmax = max(pmax, d); pmin = min(pmin, d)
	var band: float = max((pmax - pmin) * 0.05, 0.012)
	var t := Vector3.ZERO
	var b := Vector3.ZERO
	var tn := 0
	var bn := 0
	for v in pts:
		var d := v.dot(a)
		if d > pmax - band:
			t += v; tn += 1
		elif d < pmin + band:
			b += v; bn += 1
	return [t / max(tn, 1), b / max(bn, 1)]

func _process(delta: float) -> void:
	if sk == null:
		return
	recoil = move_toward(recoil, 0.0, delta * 6.0)
	if tree:
		tree.set("parameters/loco/blend_position", clamp(move_speed, 0.0, 1.0))
		# ходьба вбок/назад: ноги поворачиваются к направлению движения, назад — анимация задом наперёд
		var want := 0.0
		var back := false
		if move_speed > 0.08 and move_local.length() > 0.2:
			var ang := atan2(move_local.x, move_local.y)
			if abs(ang) > deg_to_rad(105.0):
				back = true
				ang = ang - signf(ang) * PI
			# ноги поворачиваются не больше чем на 55° — остальное корпус, без перекрута живота
			want = clamp(ang, -deg_to_rad(55.0), deg_to_rad(55.0))
		body_yaw = lerp_angle(body_yaw, want, clamp(delta * 8.0, 0.0, 1.0))
		model.rotation.y = -body_yaw
		tree.set("parameters/loco_ts/scale", -1.0 if back else 1.0)
		tree.set("parameters/aim/blend_position", clamp(aim_pitch / 60.0, -1.0, 1.0))
		var armed := 1.0 if hold in ["rifle", "pistol", "bow", "launcher", "melee"] else 0.0
		var cur: float = tree.get("parameters/armed/blend_amount")
		tree.set("parameters/armed/blend_amount", move_toward(cur, armed, delta * 5.0))
		tree.set("parameters/upper_kind/transition_request", "melee" if hold == "melee" else "gun")
		var st := "ground"
		if dead:
			st = "lying" if dead_lying else "dead"
		elif wounded:
			st = "wounded"
		elif in_air:
			st = "air"
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
		if _anim_lib.has_animation("Native_wounded"):
			_anim_lib.get_animation("Native_wounded").loop_mode = Animation.LOOP_LINEAR
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
	var lts := AnimationNodeTimeScale.new()
	bt.add_node("loco_ts", lts, Vector2(150, 0))
	bt.connect_node("loco_ts", 0, "loco")
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
	bt.connect_node("armed", 0, "loco_ts")
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
	var wnd := AnimationNodeAnimation.new(); wnd.animation = "Native_wounded"
	bt.add_node("wounded_anim", wnd, Vector2(600, 1200))
	var wts := AnimationNodeTimeScale.new()
	bt.add_node("wounded_ts", wts, Vector2(700, 1200))
	bt.connect_node("wounded_ts", 0, "wounded_anim")
	var state := AnimationNodeTransition.new()
	state.add_input("ground"); state.add_input("air"); state.add_input("dead"); state.add_input("wounded"); state.add_input("lying")
	var lying := AnimationNodeAnimation.new(); lying.animation = "Native_sleep"
	bt.add_node("lying_anim", lying, Vector2(600, 1300))
	state.xfade_time = 0.15
	bt.add_node("state", state, Vector2(800, 600))
	bt.connect_node("state", 0, last)
	bt.connect_node("state", 1, "air_anim")
	bt.connect_node("state", 2, "death_anim")
	bt.connect_node("state", 3, "wounded_ts")
	bt.connect_node("state", 4, "lying_anim")
	bt.connect_node("output", 0, "state")
	tree = AnimationTree.new()
	tree.tree_root = bt
	model.add_child(tree)
	tree.root_node = NodePath("..")
	tree.anim_player = tree.get_path_to(anim_player)
	tree.active = true
	tree.set("parameters/wounded_ts/scale", 15.0 / 24.0)   # нативная анимация модели 15 к/с
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

## Модели, у которых «верх» не определяется автоматически (плечи арбалета шире приклада)
const GEO_UP := {"w_crossbow": Vector3(0, 0, -1)}

## Настройки стоек (пространство скелета, без масштаба; ось Z — вперёд, X — влево персонажа)
const RIFLE_BUTT := Vector3(-0.035, -0.05, 0.05)    # приклад относительно правого плечевого сустава
const PISTOL_GRIP := Vector3(-0.045, 0.115, 0.34)   # рукоять относительно груди (Spine4)
const LAUNCHER_GRIP := Vector3(-0.12, -0.10, 0.16)    # рукоять трубы относительно правого плеча
const BOW_GRIP := Vector3(0.0, 0.03, 0.41)        # рукоять лука относительно левого плеча
const ARM_FWD := 10.0                               # на сколько градусов вывести руки вперёд в Idle/Walk
const ITEM_GRIP := Vector3(0.03, -0.24, 0.27)       # граната / бинт у груди

## Вызывается RifleHands после AnimationTree: корпус, голова, оружие и кисти (IK)
func post_animation() -> void:
	if sk == null:
		return
	if dead or wounded:
		if weapon_node:
			var hw := _g(weapon_side + "_Hand")
			weapon_node.transform = model.transform * (hw * weapon_hand_rest.affine_inverse())
		return
	var using: bool = tree != null and bool(tree.get("parameters/use/active"))
	var gun := hold in ["rifle", "pistol", "bow", "launcher"] and not weapon_geo.is_empty() and not using
	var p: float = clamp(aim_pitch, -60.0, 60.0)
	# --- корпус: выпрямить, развернуть грудь к прицелу (ноги могут смотреть в сторону движения) ---
	var twist := 0.0
	if gun:
		twist = -22.0 if hold in ["rifle", "launcher"] else (-8.0 if hold == "pistol" else -30.0)
	var total_yaw := body_yaw + deg_to_rad(twist)
	var upright := 0.9 if gun else (0.45 if hold == "" or hold == "item" else 0.2)
	var spine := [["Spine", 0.2, 0.15], ["Spine1", 0.4, 0.2], ["Spine2", 0.7, 0.3], ["Spine4", 1.0, 0.35]]
	for sp in spine:
		var bi: int = sk.find_bone(B + sp[0])
		if bi < 0:
			continue
		var cur := sk.get_bone_global_pose(bi)
		var rq := Quaternion(sk.get_bone_global_rest(bi).basis.orthonormalized())
		var aq := Quaternion(cur.basis.orthonormalized())
		var ub := Basis(aq.slerp(rq, upright))
		var lean := deg_to_rad(-p * float(sp[2])) if gun else 0.0
		var nb := Basis(Vector3.UP, total_yaw * float(sp[1])) * Basis(Vector3.RIGHT, lean) * ub
		sk.set_bone_global_pose(bi, Transform3D(nb, cur.origin))
	# голова: смотрит прямо по прицелу; с автоматом чуть к прикладу
	var head_yaw := body_yaw - total_yaw
	var tilt := 0.0
	var roll := 0.0
	if gun and hold == "rifle":
		tilt = 3.0
		roll = -6.0
	for hp in [["Neck1", 0.4], ["Head1", 1.0]]:
		var cur := _g(hp[0])
		var rq := Quaternion(rest[hp[0]].basis.orthonormalized())
		var aq := Quaternion(cur.basis.orthonormalized())
		var ub := Basis(aq.slerp(rq, 0.7))
		var pitch_head := deg_to_rad((-p * 0.55 + tilt) * float(hp[1])) if gun else deg_to_rad(-p * 0.4 * float(hp[1]))
		var nb := Basis(Vector3.UP, total_yaw + head_yaw * float(hp[1])) * Basis(Vector3.FORWARD, deg_to_rad(roll * float(hp[1]))) * Basis(Vector3.RIGHT, pitch_head) * ub
		_set_g(hp[0], Transform3D(nb, cur.origin))
	# свободные руки: у Idle/Walk из библиотеки руки отведены назад — вернуть вперёд к бёдрам
	if not gun and hold != "melee" and not using:
		var lat := Basis(Vector3.UP, total_yaw) * Vector3.RIGHT
		var fw := Basis(Vector3.UP, total_yaw) * Vector3.BACK
		for side in ["L", "R"]:
			if side == "R" and hold == "item":
				continue
			var sg := 1.0 if side == "L" else -1.0
			var cur := _g(side + "_UpperArm")
			var nb := Basis(fw, deg_to_rad(-5.0 * sg)) * Basis(lat, deg_to_rad(-ARM_FWD)) * cur.basis
			_set_g(side + "_UpperArm", Transform3D(nb, cur.origin))
			# стоя на месте — руки свободно опущены вдоль тела (у Idle кулаки перед животом)
			var w: float = clamp(1.0 - move_speed * 3.0, 0.0, 1.0)
			if w > 0.01:
				var shp := _g(side + "_UpperArm").origin
				var hb := _g(side + "_Hand")
				var relaxed := shp + Basis(Vector3.UP, total_yaw) * Vector3(0.07 * sg, -0.425, 0.03)
				_ik(side + "_UpperArm", side + "_Forearm", side + "_Hand", hb.origin.lerp(relaxed, w), Basis(Vector3.UP, total_yaw) * Vector3(0.3 * sg, 0.0, -1.0), hb.basis)
	if look_target != null:
		var hpos := sk.global_transform * _g("Head1").origin
		var to: Vector3 = (sk.global_transform.affine_inverse() * (look_target as Vector3)) - (sk.global_transform.affine_inverse() * hpos)
		var yaw: float = clamp(atan2(to.x, to.z) - body_yaw, -0.8, 0.8)
		var cur := _g("Head1")
		_set_g("Head1", Transform3D(Basis(Vector3.UP, yaw) * cur.basis, cur.origin))
	if weapon_node == null:
		return
	# --- оружие ---
	var aim := Basis(Vector3.UP, body_yaw) * Basis(Vector3.RIGHT, deg_to_rad(-p))
	if not gun:
		var swinging: bool = tree != null and bool(tree.get("parameters/melee/active"))
		if hold == "melee" and not using and not swinging and not weapon_geo.is_empty():
			_place_melee(aim)
		elif hold == "item" and not using:
			_place_item(aim)
		var hand := _g(weapon_side + "_Hand")
		weapon_node.transform = model.transform * (hand * weapon_hand_rest.affine_inverse())
		return
	var g := weapon_geo
	var bm := Basis((g.up as Vector3).cross(g.fwd), g.up, g.fwd)        # оси модели оружия
	var bt := aim * Basis(Vector3.RIGHT, Vector3.UP, Vector3.BACK)      # ствол вперёд (+Z), верх вверх
	var wbasis := bt * bm.inverse()
	var wroot: Transform3D
	var kick := recoil * 0.05
	match hold:
		"rifle":
			var sh := _g("R_UpperArm").origin
			var bp := sh + aim * (RIFLE_BUTT + Vector3(0, 0, -kick))
			wroot = Transform3D(wbasis, bp - wbasis * (g.butt as Vector3))
		"pistol":
			var ch := _g("Spine4").origin
			var gp := ch + aim * (PISTOL_GRIP + Vector3(0, 0, -kick))
			wroot = Transform3D(wbasis, gp - wbasis * (g.hand as Vector3))
		"launcher":
			var sh2 := _g("R_UpperArm").origin
			var gp2 := sh2 + aim * LAUNCHER_GRIP
			wroot = Transform3D(wbasis, gp2 - wbasis * (g.hand as Vector3))
		"bow":
			var lsh := _g("L_UpperArm").origin
			var gp3 := lsh + aim * BOW_GRIP
			wroot = Transform3D(wbasis, gp3 - wbasis * (g.hand as Vector3))
	var grip := wroot * weapon_hand_rest
	var right := aim * Vector3(-1, 0, 0)      # вправо от персонажа
	var mirror := _reflect(right)   # отражение относительно плоскости ствола
	if hold == "bow":
		# левая рука держит лук, правая — у тетивы возле щеки
		_ik("L_UpperArm", "L_Forearm", "L_Hand", grip.origin, aim * Vector3(0.6, -1.0, -0.2), grip.basis)
		var string_pt: Vector3 = _g("R_UpperArm").origin + aim * Vector3(0.1, 0.1, 0.1)
		var rhb := _mirror_hand(mirror, grip.basis, grip.origin, aim)
		_ik("R_UpperArm", "R_Forearm", "R_Hand", string_pt, aim * Vector3(-1.0, -0.1, -0.6), rhb)
	else:
		var rpole := aim * (Vector3(-1.0, -0.5, -0.25) if hold in ["rifle", "launcher"] else Vector3(-0.6, -1.0, -0.15))
		_ik("R_UpperArm", "R_Forearm", "R_Hand", grip.origin, rpole, grip.basis)
		var lpt: Vector3
		if hold == "pistol":
			# левая ладонь обхватывает правую снизу-слева
			lpt = grip.origin + aim * Vector3(0.04, -0.035, 0.005)
		elif hold == "launcher":
			lpt = wroot * ((g.hand as Vector3).lerp(g.tip, 0.55) - (g.up as Vector3) * 0.05)
		else:
			lpt = wroot * ((g.hand as Vector3).lerp(g.tip, 0.48) - (g.up as Vector3) * 0.03)
		var lhb := _mirror_hand(mirror, grip.basis, grip.origin, aim)
		var lpole := aim * (Vector3(0.5, -1.0, 0.0) if hold != "pistol" else Vector3(0.6, -1.0, -0.15))
		_ik("L_UpperArm", "L_Forearm", "L_Hand", lpt, lpole, lhb)
	weapon_node.transform = model.transform * wroot

static func _reflect(n: Vector3) -> Basis:
	# I - 2 n nᵀ (столбцы)
	return Basis(Vector3(1, 0, 0) - n * (2.0 * n.x), Vector3(0, 1, 0) - n * (2.0 * n.y), Vector3(0, 0, 1) - n * (2.0 * n.z))

## Хват левой рукой — зеркальная копия хвата правой (ValveBiped: L = M·R·diag(1,1,-1))
func _mirror_hand(m: Basis, rb: Basis, _o: Vector3, _aim: Basis) -> Basis:
	var mb := m * rb
	return Basis(mb.x, mb.y, -mb.z).orthonormalized()

## Оружие ближнего боя в правой руке перед грудью, клинок вверх-вперёд (как в Rust)
const MELEE_GRIP := Vector3(-0.06, -0.30, 0.27)
func _place_melee(aim: Basis) -> void:
	var g := weapon_geo
	var sh := _g("R_UpperArm").origin
	var target := sh + aim * MELEE_GRIP
	var bdir := (aim * Vector3(0.12, 0.85, 0.5)).normalized()
	var fdir := aim * Vector3(1, 0, 0)
	fdir = (fdir - bdir * fdir.dot(bdir)).normalized()
	var src := Basis(g.up, g.fwd, (g.up as Vector3).cross(g.fwd))
	var dst := Basis(fdir, bdir, fdir.cross(bdir))
	var wbasis := dst * src.inverse()
	var hb := (wbasis * weapon_hand_rest.basis).orthonormalized()
	_ik("R_UpperArm", "R_Forearm", "R_Hand", target, aim * Vector3(-0.7, -1.0, -0.3), hb)

## Граната / бинт / шприц / инструмент: правая кисть с предметом перед грудью
func _place_item(aim: Basis) -> void:
	var sh := _g("R_UpperArm").origin
	var target := sh + aim * ITEM_GRIP
	var rb: Basis = rest["R_Hand"].basis.orthonormalized()
	# пальцы вперёд-вниз, ладонь внутрь
	var want_x := (aim * Vector3(0.15, -0.35, 1.0)).normalized()
	var q := Quaternion(rb.x.normalized(), want_x)
	var hb := Basis(q) * rb
	hb = Basis(want_x, deg_to_rad(-80.0)) * hb
	_ik("R_UpperArm", "R_Forearm", "R_Hand", target, aim * Vector3(-0.6, -1.0, -0.4), hb)

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
