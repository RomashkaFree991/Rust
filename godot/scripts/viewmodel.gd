extends Node3D
class_name ViewModel
## Оружие от первого лица: модель c_* с руками, анимации из .mdl (draw/fire/reload),
## звуки по событиям из анимаций, прицеливание, осмотр, отдача, ближний бой (камень, нож).

signal fired(def: Dictionary)
signal ammo_changed
signal reloaded

const VM_LAYER := 2
const INSPECT_PIVOT := Vector3(0.08, -0.08, -0.32)
var INSPECT_PIVOT_LOW := Vector3(0.04, -0.36, -0.04)
const ARM_MESHES := ["Hoodie_vm", "TacticalGloves_vm", "BurlapGloves_vm", "RoadsignGloves_vm"]

var cam: Camera3D                 # камера вьюмодели
var sway: Node3D
var inspect_node: Node3D
var model: Node3D
var anim: AnimationPlayer
var muzzle: Node3D
var flash_mesh: MeshInstance3D
var flash_light: OmniLight3D
var audio: AudioStreamPlayer
var audio2: AudioStreamPlayer

var item: Dictionary = {}         # предмет из инвентаря (хранит ammo)
var def: Dictionary = {}
var id := ""
var anim_info: Dictionary = {}    # weapons.json[id].seqs
var shoot_streams: Array = []

var state := "none"               # none, draw, idle, fire, reload, inspect
var state_time := 0.0
var state_len := 0.0
var next_fire := 0.0
var cur_events: Array = []
var ev_idx := 0
var aiming := false
var ads_t := 0.0
var trigger := false
var trigger_consumed := false
var flash_t := 0.0
var inspect_tween: Tween
var reload_pending := 0
var pivot := INSPECT_PIVOT
var player                        # Player: melee_check / melee_apply
var melee_pending := -1.0
var worn_arms: Array = []
var inspect_t := -1.0
var inspect_mod: InspectModifier
var vm_skel: Skeleton3D

var bob_t := 0.0
var clock := 0.0
var look_sway := Vector2.ZERO
var move_amount := 0.0

static var _scene_cache := {}
static var _json: Dictionary = {}

func _ready() -> void:
	if _json.is_empty():
		_json = JSON.parse_string(FileAccess.get_file_as_string("res://assets/weapons/weapons.json"))
	sway = Node3D.new(); sway.name = "Sway"; add_child(sway)
	inspect_node = Node3D.new(); inspect_node.name = "Inspect"; inspect_node.position = INSPECT_PIVOT
	sway.add_child(inspect_node)
	audio = AudioStreamPlayer.new(); audio.bus = "Master"; add_child(audio)
	audio2 = AudioStreamPlayer.new(); add_child(audio2)
	# вспышка выстрела
	flash_mesh = MeshInstance3D.new()
	var q := QuadMesh.new(); q.size = Vector2(0.075, 0.075)
	# текстура вспышки на чёрном фоне -> альфа из яркости (работает и в прозрачном SubViewport)
	var sh := Shader.new()
	sh.code = """shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;
uniform sampler2D tex : source_color, filter_linear_mipmap;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}
void fragment() {
	vec3 c = texture(tex, UV).rgb;
	float a = clamp(max(c.r, max(c.g, c.b)) * 1.4, 0.0, 1.0);
	ALBEDO = c / max(a, 0.001);
	ALPHA = a;
}"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("tex", load("res://assets/textures/muzzleflash.png"))
	q.material = m
	flash_mesh.mesh = q
	flash_mesh.layers = VM_LAYER
	flash_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flash_mesh.visible = false
	flash_light = OmniLight3D.new()
	flash_light.light_color = Color(1.0, 0.7, 0.35)
	flash_light.light_energy = 0.0
	flash_light.omni_range = 4.0

func _load_scene(path: String) -> PackedScene:
	if not _scene_cache.has(path):
		_scene_cache[path] = load(path)
	return _scene_cache[path]

func _fix_materials(n: Node) -> void:
	if n is VisualInstance3D:
		n.layers = VM_LAYER
	if n is GeometryInstance3D:
		n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if n is MeshInstance3D and n.mesh:
		for s in n.mesh.get_surface_count():
			var mat = n.get_active_material(s)
			if mat is StandardMaterial3D:
				var m: StandardMaterial3D = mat.duplicate()
				m.metallic = 0.0
				m.metallic_specular = 0.35
				m.roughness = 0.72
				m.normal_scale = 0.6
				if not String(n.name).begins_with("hand"):
					m.albedo_color = Color(1.7, 1.7, 1.7)
				m.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
				m.cull_mode = BaseMaterial3D.CULL_BACK
				n.set_surface_override_material(s, m)
	for c in n.get_children():
		_fix_materials(c)

func equip(new_item: Dictionary) -> void:
	holster()
	if new_item.is_empty():
		return
	item = new_item
	id = item.id
	def = Items.get_def(id)
	anim_info = _json.get(id, {}).get("seqs", {})
	shoot_streams.clear()
	for p in _json.get(id, {}).get("sounds", {}).get(def.get("shoot_sounds", ""), []):
		shoot_streams.append(load(p))
	model = _load_scene(def.scene).instantiate()
	pivot = INSPECT_PIVOT
	inspect_node.position = pivot
	model.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(90.0)), -pivot)
	inspect_node.add_child(model)
	_fix_materials(model)
	vm_skel = model.find_child("Skeleton3D", true, false)
	inspect_mod = null
	if vm_skel:
		inspect_mod = InspectModifier.new()
		vm_skel.add_child(inspect_mod)
		inspect_mod.setup(vm_skel)
	apply_arms(worn_arms)
	anim = model.find_child("AnimationPlayer", true, false)
	muzzle = model.find_child("muzzle", true, false)
	if flash_mesh.get_parent() == null:
		add_child(flash_mesh)
		add_child(flash_light)
	if cam:
		cam.fov = Items.hfov_to_vfov(def.vm_fov)
	aiming = false
	var dseq := "draw_empty" if item.get("ammo", 1) == 0 and anim_info.has("draw_empty") else "draw"
	_play_seq(dseq, 0.0)
	state = "draw"
	state_len = min(_seq_len(dseq), 1.1)
	ammo_changed.emit()

func holster() -> void:
	if inspect_tween:
		inspect_tween.kill()
	inspect_node.rotation = Vector3.ZERO
	inspect_node.position = pivot
	inspect_t = -1.0
	melee_pending = -1.0
	if model:
		model.queue_free()
	model = null
	anim = null
	item = {}
	def = {}
	id = ""
	state = "none"
	aiming = false
	cur_events = []
	ammo_changed.emit()

## Включить рукава/перчатки на руках от первого лица по надетой одежде
func apply_arms(names: Array) -> void:
	worn_arms = names
	if model == null:
		return
	for m in model.find_children("*", "MeshInstance3D", true, false):
		var n := String(m.name)
		for a in ARM_MESHES:
			if n.begins_with(a):
				m.visible = a in names
		if n.begins_with("hand_mesh"):
			m.visible = true

func is_melee() -> bool:
	return def.get("type", "") == "melee"

## Вернуть руки в позу покоя (последний кадр выстрела), чтобы не оставались «хвосты»
## перезарядки — например, барабан Python после reload
func _to_idle_pose(blend := 0.25) -> void:
	if anim == null:
		return
	var seq := ""
	if is_melee():
		seq = "idle" if anim_info.has("idle") else ""
		if seq == "":
			return
	else:
		seq = def.fire[0]
		if anim_info.has("fire_last") and item.get("ammo", 1) == 0:
			seq = "fire_last"
	var s: Dictionary = anim_info.get(seq, {})
	if s.is_empty():
		return
	anim.play(s.anim, blend, 0.0)
	anim.seek(anim.current_animation_length, true)
	cur_events = []

func has_weapon() -> bool:
	return model != null

func _seq_len(seq: String) -> float:
	var s: Dictionary = anim_info.get(seq, {})
	if s.is_empty():
		return 0.5
	return float(s.frames - 1) / float(s.fps)

func _play_seq(seq: String, blend := 0.08) -> void:
	var s: Dictionary = anim_info.get(seq, {})
	if s.is_empty() or anim == null:
		return
	var speed := float(s.fps) / 24.0  # glTF экспортирован с таймлайном 24 к/с
	anim.stop()
	anim.play(s.anim, blend, speed)
	cur_events = s.get("events", [])
	ev_idx = 0
	state_time = 0.0

func _play_sound(path_or_stream, player: AudioStreamPlayer = null) -> void:
	var p := player if player else audio2
	var st = path_or_stream
	if st is String:
		st = load(st)
	p.stream = st
	p.play()

func set_trigger(down: bool) -> void:
	trigger = down
	if not down:
		trigger_consumed = false

func toggle_aim() -> void:
	if not has_weapon():
		return
	if state == "reload" or state == "inspect":
		return
	if is_melee():
		return
	aiming = not aiming

func reload(inv: Inventory) -> void:
	if not has_weapon() or is_melee() or state in ["reload", "draw"]:
		return
	if item.ammo >= def.clip or inv.count(def.ammo) <= 0:
		return
	_cancel_inspect()
	aiming = false
	var rseq := "reload_empty" if item.ammo == 0 and anim_info.has("reload_empty") else "reload"
	_play_seq(rseq)
	state = "reload"
	state_len = _seq_len(rseq)
	reload_pending = 1

## Осмотр: плавно поднять оружие и повернуть сначала одной, потом другой стороной,
## с лёгким «дыханием» рук. Звуки — из анимации доставания этого же оружия.
var INSPECT_KEYS := [
	# время, поворот оружия в кистях (град: тангаж, рыскание, крен), подъём
	[0.0, Vector3(0, 0, 0), 0.0],
	[0.6, Vector3(4, -24, -18), 0.012],
	[1.5, Vector3(5, -27, -21), 0.014],
	[2.2, Vector3(12, 18, 38), 0.01],
	[3.0, Vector3(13, 20, 42), 0.012],
	[3.5, Vector3(0, 0, 0), 0.0],
]

func inspect() -> void:
	if not has_weapon() or state != "idle":
		return
	aiming = false
	state = "inspect"
	state_time = 0.0
	state_len = INSPECT_KEYS[-1][0]
	inspect_t = 0.0
	if inspect_tween:
		inspect_tween.kill()
	var snd: Array = []
	for e in anim_info.get("draw", {}).get("events", []):
		snd.append_array(e.sounds)
	if snd.size() > 0:
		_play_sound(snd[-1])
	elif ResourceLoader.exists("res://assets/sounds/rifle_jingle-2.mp3"):
		_play_sound("res://assets/sounds/rifle_jingle-2.mp3")

func _inspect_pose(t: float) -> Array:
	for i in range(1, INSPECT_KEYS.size()):
		var k0: Array = INSPECT_KEYS[i - 1]
		var k1: Array = INSPECT_KEYS[i]
		if t <= k1[0]:
			var u: float = (t - k0[0]) / (k1[0] - k0[0])
			u = u * u * u * (u * (u * 6.0 - 15.0) + 10.0)   # smootherstep
			return [(k0[1] as Vector3).lerp(k1[1], u), lerpf(k0[2], k1[2], u)]
	return [Vector3.ZERO, 0.0]

func _cancel_inspect() -> void:
	if state == "inspect":
		# быстро вернуть из текущей позы
		inspect_t = max(inspect_t, INSPECT_KEYS[-2][0])
		state = "idle"

func _try_fire(now: float) -> void:
	if not has_weapon() or now < next_fire:
		return
	if state in ["draw", "reload"]:
		return
	if not def.get("auto", true) and trigger_consumed:
		return
	_cancel_inspect()
	trigger_consumed = true
	next_fire = now + 60.0 / def.rpm
	if is_melee():
		_melee_swing()
		return
	if item.ammo <= 0:
		if def.dryfire != "":
			_play_seq(def.dryfire)
		_play_sound(def.dry_sound)
		trigger_consumed = true
		next_fire = now + 0.35
		return
	item.ammo -= 1
	var seq: String = def.fire_ads if aiming else def.fire[randi() % def.fire.size()]
	if item.ammo == 0 and anim_info.has("fire_last"):
		seq = "fire_last_ads" if aiming and anim_info.has("fire_last_ads") else "fire_last"
	_play_seq(seq, 0.0)
	state = "fire"
	state_len = 60.0 / def.rpm
	if shoot_streams.size() > 0:
		var p := AudioStreamPlayer.new()
		p.stream = shoot_streams[randi() % shoot_streams.size()]
		p.volume_db = -2.0
		p.pitch_scale = randf_range(0.97, 1.03)
		add_child(p)
		p.play()
		p.finished.connect(p.queue_free)
	flash_t = 0.05
	flash_mesh.rotation.z = randf() * TAU
	ammo_changed.emit()
	fired.emit(def)

func _snd(key: String) -> void:
	var arr: Array = _json.get(id, {}).get("sounds", {}).get(key, [])
	if arr.size() > 0:
		var p := AudioStreamPlayer.new()
		p.stream = load(arr[randi() % arr.size()])
		add_child(p)
		p.play()
		p.finished.connect(p.queue_free)

func _melee_swing() -> void:
	var hit: Dictionary = player.melee_check(def.range) if player else {}
	var list: Array = def.hit if not hit.is_empty() else def.miss
	_play_seq(list[randi() % list.size()], 0.05)
	cur_events = []
	state = "fire"
	state_len = 60.0 / def.rpm
	_snd(def.swing_snd)
	melee_pending = def.hit_delay
	fired.emit(def)

func process_weapon(delta: float, inv: Inventory, moving: float, look_delta: Vector2) -> void:
	clock += delta
	var now := clock
	move_amount = lerp(move_amount, moving, clamp(delta * 8.0, 0.0, 1.0))
	look_sway = look_sway.lerp(look_delta, clamp(delta * 10.0, 0.0, 1.0))

	if has_weapon():
		state_time += delta
		# звуки из событий анимации (как в .mdl)
		while ev_idx < cur_events.size() and state_time >= float(cur_events[ev_idx].t):
			var snds: Array = cur_events[ev_idx].sounds
			if snds.size() > 0:
				_play_sound(snds[randi() % snds.size()], audio)
			ev_idx += 1
		if state == "reload" and reload_pending and state_time >= state_len * 0.82:
			reload_pending = 0
			var need: int = def.clip - item.ammo
			item.ammo += inv.take(def.ammo, need)
			ammo_changed.emit()
			reloaded.emit()
		if melee_pending >= 0.0:
			melee_pending -= delta
			if melee_pending < 0.0 and player:
				var hit: Dictionary = player.melee_check(def.range)
				if not hit.is_empty():
					_snd(def.strike_snd)
					player.melee_apply(hit, def)
		if state in ["draw", "fire", "reload"] and state_time >= state_len:
			if state == "reload":
				_to_idle_pose(0.3)
			state = "idle"
		if state == "inspect" and inspect_t >= INSPECT_KEYS[-1][0]:
			state = "idle"
		if trigger:
			_try_fire(now)

	# вспышка
	if flash_t > 0.0:
		flash_t -= delta
		flash_mesh.visible = true
		var mp: Vector3 = muzzle.global_position if muzzle else global_position + global_basis * Vector3(0.1, -0.08, -0.6)
		flash_mesh.global_position = mp
		flash_light.global_position = mp
		flash_light.light_energy = 2.5
		var sc := randf_range(0.8, 1.25)
		flash_mesh.scale = Vector3(sc, sc, sc)
	else:
		flash_mesh.visible = false
		flash_light.light_energy = 0.0

	# прицеливание, покачивание, инерция
	ads_t = move_toward(ads_t, 1.0 if aiming else 0.0, delta * 5.0)
	var e := ads_t * ads_t * (3.0 - 2.0 * ads_t)
	var ads_off := Vector3.ZERO
	if has_weapon():
		ads_off = Items.vec_from_source(def.get("ads", Vector3.ZERO)) * e
	bob_t += delta * (6.0 + 5.0 * move_amount)
	var bob_amt := move_amount * (1.0 - e * 0.85)
	var bob := Vector3(sin(bob_t) * 0.006, -abs(cos(bob_t)) * 0.006, 0.0) * bob_amt
	var breathe := Vector3(0.0, sin(bob_t * 0.25) * 0.0012, 0.0) * (1.0 - e)
	var sway_off := Vector3(-look_sway.x, look_sway.y, 0.0) * 0.00035 * (1.0 - e * 0.7)
	sway.position = ads_off + bob + breathe + sway_off
	# осмотр: поворот оружия в кистях через InspectModifier
	if inspect_t >= 0.0 and inspect_mod and vm_skel:
		inspect_t += delta
		var pose := _inspect_pose(inspect_t)
		var env := sin(PI * clamp(inspect_t / INSPECT_KEYS[-1][0], 0.0, 1.0))
		var w := sin(inspect_t * 2.3) * 1.5 * env
		var r: Vector3 = (pose[0] + Vector3(w * 0.4, w * 0.3, w)) * (PI / 180.0)
		var rc := Basis.from_euler(r, EULER_ORDER_YXZ)
		var bs := (sway.global_transform.affine_inverse() * vm_skel.global_transform).basis.orthonormalized()
		inspect_mod.rot = bs.inverse() * rc * bs
		sway.position.y += pose[1]
		if inspect_t >= INSPECT_KEYS[-1][0]:
			inspect_t = -1.0
			inspect_mod.rot = Basis()
	sway.rotation = Vector3(look_sway.y * 0.0008, -look_sway.x * 0.0008, 0.0) * (1.0 - e * 0.7)
