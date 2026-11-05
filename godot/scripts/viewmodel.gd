extends Node3D
class_name ViewModel
## Оружие от первого лица: модель c_* с руками, анимации из .mdl (draw/fire/reload),
## звуки по событиям из анимаций, прицеливание, осмотр, отдача, ближний бой (камень, нож).

signal fired(def: Dictionary)
signal ammo_changed
signal reloaded
signal reload_started

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
var shell_phase := ""
var phase_len := 0.0
var reload_inv: Inventory
var pump_pending := -1.0
var pump_seq := ""
var throw_pending := -1.0
var use_pending := -1.0
var redraw_pending := -1.0
var autoreload_pending := -1.0
var bow_state := ""               # "", drawing, drawn — натяжение лука
var bow_t := 0.0
var bow_draw_len := 0.6
var prev_trigger := false
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
	def = Items.get_def(id).duplicate()
	if def.has("ammo"):
		def["ammo"] = item.get("ammo_type", def.ammo)   # выбранный тип патронов (HUD и перезарядка берут def.ammo)
	anim_info = def.get("seqs", {})
	shoot_streams.clear()
	for p in def.get("sounds", {}).get("shoot_sound", []):
		shoot_streams.append(load(p))
	shell_phase = ""
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
	Attachments.attach_viewmodel(self, model, item, vm_skel)   # обвесы (attachments.gd)
	anim = model.find_child("AnimationPlayer", true, false)
	muzzle = model.find_child("muzzle", true, false)
	if flash_mesh.get_parent() == null:
		add_child(flash_mesh)
		add_child(flash_light)
	if cam:
		cam.fov = Items.hfov_to_vfov(def.vm_fov)
	aiming = false
	var dseq := _act("ACT_VM_DRAW_EMPTY") if item.get("ammo", 1) == 0 and _act("ACT_VM_DRAW_EMPTY") != "" else _act("ACT_VM_DRAW")
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
	throw_pending = -1.0
	use_pending = -1.0
	redraw_pending = -1.0
	pump_pending = -1.0
	shell_phase = ""
	bow_state = ""
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

func kind() -> String:
	return def.get("kind", "")

func is_melee() -> bool:
	return kind() == "melee"

## Нет магазина: ближний бой, взрывчатка, медицина, лук (стрелы берутся из инвентаря)
func no_clip() -> bool:
	if kind() == "bow":
		return not def.get("crossbow", false)
	return kind() in ["melee", "throw", "medical", "tool"]

## Первая последовательность с этой активностью (ACT_VM_*), как SendWeaponAnim в GMod
func _act(a: String, pick_random := false) -> String:
	var l: Array = def.get("acts", {}).get(a, [])
	if l.is_empty():
		return ""
	return l[randi() % l.size()] if pick_random else l[0]

func _act_any(names: Array, pick_random := true) -> String:
	for a in names:
		var s := _act(a, pick_random)
		if s != "":
			return s
	return ""

## Вернуть руки в позу покоя (последний кадр выстрела), чтобы не оставались «хвосты»
## перезарядки — например, барабан Python после reload
func _to_idle_pose(blend := 0.25) -> void:
	if anim == null:
		return
	var seq := ""
	if no_clip():
		seq = _act("ACT_VM_IDLE")
		if seq == "":
			return
	else:
		seq = _act("ACT_VM_PRIMARYATTACK")
		if _act("ACT_VM_PRIMARYATTACK_EMPTY") != "" and item.get("ammo", 1) == 0:
			seq = _act("ACT_VM_PRIMARYATTACK_EMPTY")
		if seq == "":
			return
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
	if not has_weapon() or no_clip() or state in ["reload", "draw"]:
		return
	if int(item.get("ammo", 0)) >= int(def.clip) or inv.count(def.ammo) <= 0:
		return
	if reload_pending:
		return
	_cancel_inspect()
	aiming = false
	reload_inv = inv
	if _act("ACT_SHOTGUN_RELOAD_START") != "":
		# дробовики и болтовка: начало, по патрону, конец (как rust_shotgun.lua)
		shell_phase = "start"
		_play_seq(_act("ACT_SHOTGUN_RELOAD_START"))
		state = "reload"
		state_len = 1e9
		phase_len = _seq_len(_act("ACT_SHOTGUN_RELOAD_START"))
		reload_started.emit()
		return
	var rseq := _act("ACT_VM_RELOAD_EMPTY") if item.ammo == 0 and _act("ACT_VM_RELOAD_EMPTY") != "" else _act("ACT_VM_RELOAD")
	_play_seq(rseq)
	state = "reload"
	state_len = _seq_len(rseq) if rseq != "" else max(_num_def("reload_time", 2.0), 1.0)
	reload_started.emit()
	reload_pending = 1

## Сменить тип патронов: разрядить магазин в инвентарь и перезарядить новым (как выбор AmmoType в gRust)
func set_ammo_type(ammo_id: String) -> void:
	if not has_weapon() or not def.has("ammo_types"):
		return
	if not ammo_id in def.ammo_types:
		return
	var inv: Inventory = player.inv if player else reload_inv
	if ammo_id == def.ammo:
		if inv:
			reload(inv)
		return
	if inv and int(item.get("ammo", 0)) > 0:
		inv.give(def.ammo, int(item.ammo))
	item["ammo"] = 0
	item["ammo_type"] = ammo_id
	def["ammo"] = ammo_id
	reload_pending = 0
	shell_phase = ""
	state = "idle"
	ammo_changed.emit()
	if inv:
		reload(inv)

func _num_def(k: String, d: float) -> float:
	var v = def.get(k)
	return float(v) if v != null else d

func _shell_step(delta: float) -> void:
	if shell_phase == "":
		return
	phase_len -= delta
	if phase_len > 0.0:
		return
	match shell_phase:
		"start", "insert":
			if shell_phase == "insert":
				item.ammo += reload_inv.take(def.ammo, 1)
				ammo_changed.emit()
			if item.ammo < def.clip and reload_inv.count(def.ammo) > 0 and not trigger:
				shell_phase = "insert"
				_play_seq(_act("ACT_VM_RELOAD"), 0.02)
				phase_len = max(_seq_len(_act("ACT_VM_RELOAD")), _num_def("shell_time", 0.4))
			else:
				shell_phase = "finish"
				var f := _act("ACT_SHOTGUN_RELOAD_FINISH")
				_play_seq(f, 0.05)
				phase_len = _seq_len(f) if f != "" else 0.2
		"finish":
			shell_phase = ""
			state = "idle"
			reloaded.emit()

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
	for e in anim_info.get(_act("ACT_VM_DRAW"), {}).get("events", []):
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
	if kind() == "bow" and not def.get("crossbow", false):
		return
	if state in ["draw"]:
		return
	if state == "reload":
		if shell_phase in ["start", "insert"] and item.ammo > 0:
			shell_phase = "insert"
			phase_len = 0.0       # прервать поштучную перезарядку выстрелом
		return
	if not def.get("auto", true) and trigger_consumed:
		return
	_cancel_inspect()
	trigger_consumed = true
	next_fire = now + 60.0 / max(def.get("rpm", 60.0), 1.0)
	match kind():
		"melee":
			_melee_swing()
			return
		"throw":
			_throw()
			return
		"medical":
			_use_medical()
			return
		"tool":
			var t := _act_any(["ACT_VM_PRIMARYATTACK", "ACT_VM_SWINGMISS"])
			_play_seq(t)
			state = "fire"
			state_len = _seq_len(t)
			return
		"bow":
			if not def.get("crossbow", false):
				return          # лук: натяжение и выстрел — в _bow_step (по отпусканию кнопки)
	if item.get("ammo", 0) <= 0:
		var dry := _act("ACT_VM_DRYFIRE")
		if dry != "":
			_play_seq(dry)
		_play_sound("res://assets/sounds/lr300-dryfire.mp3")
		next_fire = now + 0.35
		return
	item.ammo = int(item.ammo) - 1
	var seq := _act("ACT_VM_PRIMARYATTACK_1") if aiming and _act("ACT_VM_PRIMARYATTACK_1") != "" else _act("ACT_VM_PRIMARYATTACK", true)
	if item.get("ammo", 1) == 0 and _act("ACT_VM_PRIMARYATTACK_EMPTY") != "":
		seq = _act("ACT_VM_PRIMARYATTACK_EMPTY_1") if aiming and _act("ACT_VM_PRIMARYATTACK_EMPTY_1") != "" else _act("ACT_VM_PRIMARYATTACK_EMPTY")
	_play_seq(seq, 0.0)
	state = "fire"
	state_len = 60.0 / def.rpm
	# болтовка / помпа: передёрнуть после выстрела
	var pump := _act_any(["ACT_SHOTGUN_PUMP"])
	if pump == "" and def.get("id_hint", "") == "":
		pump = _act("ACT_VM_SECONDARYATTACK") if kind() == "gun" and def.get("rpm", 300) < 200 and _act("ACT_VM_SECONDARYATTACK") != "" and item.ammo > 0 else ""
	if pump != "" and item.get("ammo", 0) > 0:
		pump_pending = min(_seq_len(seq), 0.5)
		pump_seq = pump
		state_len = max(state_len, pump_pending + _seq_len(pump))
	if shoot_streams.size() > 0:
		var p := AudioStreamPlayer.new()
		p.stream = shoot_streams[randi() % shoot_streams.size()]
		p.volume_db = -2.0
		p.pitch_scale = randf_range(0.97, 1.03)
		add_child(p)
		p.play()
		p.finished.connect(p.queue_free)
	if kind() in ["gun", "shotgun", "launcher"]:
		flash_t = 0.05
	flash_mesh.rotation.z = randf() * TAU
	ammo_changed.emit()
	fired.emit(def)
	if def.get("crossbow", false) and player:
		autoreload_pending = max(_seq_len(seq), 0.3)

func _snd(key: String) -> void:
	var arr: Array = def.get("sounds", {}).get(key, [])
	if arr.size() > 0:
		var p := AudioStreamPlayer.new()
		p.stream = load(arr[randi() % arr.size()])
		add_child(p)
		p.play()
		p.finished.connect(p.queue_free)

func _melee_swing() -> void:
	var hit: Dictionary = player.melee_check(def.range) if player else {}
	var seq := _act_any(["ACT_VM_SWINGHIT", "ACT_VM_HITCENTER", "ACT_VM_HITLEFT", "ACT_VM_HITRIGHT"]) if not hit.is_empty() else ""
	if seq == "":
		seq = _act_any(["ACT_VM_SWINGMISS", "ACT_VM_MISSCENTER", "ACT_VM_MISSLEFT", "ACT_VM_MISSRIGHT", "ACT_VM_PRIMARYATTACK"])
	_play_seq(seq, 0.05)
	cur_events = []
	state = "fire"
	state_len = 60.0 / def.rpm
	_snd("swing_sound")
	melee_pending = def.hit_delay
	fired.emit(def)

## Граната / заряд: выдернуть чеку и бросить (ACT_VM_PULLPIN -> ACT_VM_THROW), предмет тратится
func _throw() -> void:
	# rust_explosive: ACT_VM_THROW, бросок сразу, через 1 с снова ACT_VM_DRAW; NextAttack = 1.4 с
	var th := _act_any(["ACT_VM_THROW", "ACT_VM_PULLPIN"])
	_play_seq(th, 0.05)
	cur_events = []
	state = "fire"
	throw_pending = clamp(_seq_len(th) * 0.35, 0.12, 0.35)
	state_len = 1.4
	next_fire = clock + 1.4
	fired.emit(def)

func _use_medical() -> void:
	var u := _act_any(["ACT_VM_PRIMARYATTACK", "ACT_VM_THROW"])
	_play_seq(u, 0.05)
	state = "fire"
	state_len = _seq_len(u) if u != "" else 1.5
	use_pending = state_len * 0.7

## Лук (rust_huntingbow.lua): держим кнопку — ACT_VM_DEPLOY (натяжение, стрела из инвентаря),
## отпускаем после натяжения — ACT_VM_PRIMARYATTACK и выстрел; отпустили раньше — ACT_VM_UNDEPLOY.
func _bow_step(delta: float, inv: Inventory) -> void:
	if autoreload_pending >= 0.0:
		autoreload_pending -= delta
		if autoreload_pending < 0.0 and int(item.get("ammo", 0)) == 0:
			reload(inv)
	if kind() != "bow" or def.get("crossbow", false):
		prev_trigger = trigger
		return
	var pressed := trigger and not prev_trigger
	var released := prev_trigger and not trigger
	prev_trigger = trigger
	if bow_state == "" and trigger and state in ["idle", "fire"] and clock >= next_fire:
		if int(item.get("ammo", 0)) <= 0:
			if inv.take(def.ammo, 1) <= 0:
				if pressed:
					_play_sound("res://assets/sounds/bow-draw-cancel.mp3")
				return
			item["ammo"] = 1
			ammo_changed.emit()
		var dep := _act("ACT_VM_DEPLOY")
		_play_seq(dep, 0.05)
		bow_draw_len = max(_seq_len(dep), 0.5)
		bow_state = "drawing"
		bow_t = 0.0
		state = "fire"
		state_len = 1e9
		var compound: bool = def.get("swep", "") == "tfa_compound_bow"
		_play_sound("res://assets/sounds/compound-bow-initial-pullback.mp3" if compound else "res://assets/sounds/bow-draw.mp3")
		return
	if bow_state == "":
		return
	bow_t += delta
	if bow_state == "drawing" and bow_t >= bow_draw_len:
		bow_state = "drawn"
		var hold := _act("ACT_VM_DEPLOYED_IDLE")
		if hold != "":
			_play_seq(hold, 0.1)
			_play_sound("res://assets/sounds/compound-bow-charge-up-complete.mp3")
	elif bow_state == "drawn" and anim and not anim.is_playing() and _act("ACT_VM_DEPLOYED_IDLE") != "":
		_play_seq(_act("ACT_VM_DEPLOYED_IDLE"), 0.0)
	if released or not trigger:
		if bow_state == "drawn":
			var sh := _act("ACT_VM_PRIMARYATTACK")
			_play_seq(sh, 0.02)
			item["ammo"] = 0
			if shoot_streams.size() > 0:
				_play_sound(shoot_streams[randi() % shoot_streams.size()])
			state = "fire"
			state_len = max(_seq_len(sh), 0.4)
			state_time = 0.0
			next_fire = clock + 60.0 / max(def.get("rpm", 60.0), 1.0)
			ammo_changed.emit()
			fired.emit(def)
		else:
			var un := _act("ACT_VM_UNDEPLOY")
			_play_seq(un, 0.05)
			_play_sound("res://assets/sounds/bow-draw-cancel.mp3")
			state = "fire"
			state_len = max(_seq_len(un), 0.2)
			state_time = 0.0
		bow_state = ""

## Расходуемый предмет (граната, бинт): минус один из стака, если кончился — убрать из рук
func _consume_item() -> void:
	if player:
		player.consume_active()

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
		_shell_step(delta)
		_bow_step(delta, inv)
		if pump_pending >= 0.0:
			pump_pending -= delta
			if pump_pending < 0.0:
				_play_seq(pump_seq, 0.05)
		if throw_pending >= 0.0:
			throw_pending -= delta
			if throw_pending < 0.0:
				if player:
					player.throw_explosive(def)
				_consume_item()
				redraw_pending = 0.9
		if redraw_pending >= 0.0:
			redraw_pending -= delta
			if redraw_pending < 0.0 and has_weapon():
				_play_seq(_act("ACT_VM_DRAW"), 0.1)
				state = "draw"
				state_len = min(_seq_len(_act("ACT_VM_DRAW")), 0.8)
		if use_pending >= 0.0:
			use_pending -= delta
			if use_pending < 0.0:
				if player:
					player.heal(def.get("heal", 10.0))
				_consume_item()
		if state == "reload" and reload_pending and state_time >= state_len * 0.82:
			reload_pending = 0
			var need: int = max(int(def.clip) - int(item.get("ammo", 0)), 0)
			item.ammo = int(item.get("ammo", 0)) + inv.take(def.ammo, need)
			ammo_changed.emit()
			reloaded.emit()
		if melee_pending >= 0.0:
			melee_pending -= delta
			if melee_pending < 0.0 and player:
				var hit: Dictionary = player.melee_check(def.range)
				if not hit.is_empty():
					_snd("hit_sound")
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
