extends Node3D
class_name ViewModel
## Оружие от первого лица: модель c_* с руками, анимации из .mdl (draw/fire/reload),
## звуки по событиям из анимаций, прицеливание, осмотр, отдача.

signal fired(def: Dictionary)
signal ammo_changed
signal reloaded

const VM_LAYER := 2
const INSPECT_PIVOT := Vector3(0.08, -0.08, -0.32)

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
	for p in _json.get(id, {}).get("sounds", {}).get(def.shoot_sounds, []):
		shoot_streams.append(load(p))
	model = _load_scene(def.scene).instantiate()
	model.rotation_degrees.y = 90.0
	model.position = -INSPECT_PIVOT
	inspect_node.add_child(model)
	_fix_materials(model)
	anim = model.find_child("AnimationPlayer", true, false)
	muzzle = model.find_child("muzzle", true, false)
	if flash_mesh.get_parent() == null:
		add_child(flash_mesh)
		add_child(flash_light)
	if cam:
		cam.fov = Items.hfov_to_vfov(def.vm_fov)
	aiming = false
	_play_seq("draw", 0.0)
	state = "draw"
	state_len = min(_seq_len("draw"), 1.1)
	ammo_changed.emit()

func holster() -> void:
	if inspect_tween:
		inspect_tween.kill()
	inspect_node.rotation = Vector3.ZERO
	inspect_node.position = INSPECT_PIVOT
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
	aiming = not aiming

func reload(inv: Inventory) -> void:
	if not has_weapon() or state in ["reload", "draw"]:
		return
	if item.ammo >= def.clip or inv.count(def.ammo) <= 0:
		return
	_cancel_inspect()
	aiming = false
	_play_seq("reload")
	state = "reload"
	state_len = _seq_len("reload")
	reload_pending = 1

func inspect() -> void:
	if not has_weapon() or state != "idle":
		return
	aiming = false
	state = "inspect"
	state_time = 0.0
	state_len = 3.0
	if inspect_tween:
		inspect_tween.kill()
	inspect_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var p0 := INSPECT_PIVOT
	inspect_tween.tween_property(inspect_node, "rotation_degrees", Vector3(6, 18, 24), 0.55)
	inspect_tween.parallel().tween_property(inspect_node, "position", p0 + Vector3(-0.04, 0.025, 0.02), 0.55)
	inspect_tween.tween_property(inspect_node, "rotation_degrees", Vector3(8, 22, 28), 0.8)
	inspect_tween.tween_property(inspect_node, "rotation_degrees", Vector3(-6, -10, -26), 0.7)
	inspect_tween.parallel().tween_property(inspect_node, "position", p0 + Vector3(-0.02, 0.035, 0.0), 0.7)
	inspect_tween.tween_property(inspect_node, "rotation_degrees", Vector3(-8, -12, -30), 0.5)
	inspect_tween.tween_property(inspect_node, "rotation_degrees", Vector3.ZERO, 0.45)
	inspect_tween.parallel().tween_property(inspect_node, "position", p0, 0.45)
	var jingle := "res://assets/sounds/rifle_jingle-2.mp3"
	if ResourceLoader.exists(jingle):
		_play_sound(jingle)

func _cancel_inspect() -> void:
	if state == "inspect":
		if inspect_tween:
			inspect_tween.kill()
		var t := create_tween().set_trans(Tween.TRANS_SINE)
		t.tween_property(inspect_node, "rotation_degrees", Vector3.ZERO, 0.15)
		t.parallel().tween_property(inspect_node, "position", INSPECT_PIVOT, 0.15)
		state = "idle"

func _try_fire(now: float) -> void:
	if not has_weapon() or now < next_fire:
		return
	if state in ["draw", "reload"]:
		return
	if not def.auto and trigger_consumed:
		return
	_cancel_inspect()
	trigger_consumed = true
	next_fire = now + 60.0 / def.rpm
	if item.ammo <= 0:
		if def.dryfire != "":
			_play_seq(def.dryfire)
		_play_sound(def.dry_sound)
		trigger_consumed = true
		next_fire = now + 0.35
		return
	item.ammo -= 1
	var seq: String = def.fire_ads if aiming else def.fire[randi() % def.fire.size()]
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
		if state in ["draw", "fire", "reload"] and state_time >= state_len:
			state = "idle"
		if state == "inspect" and (inspect_tween == null or not inspect_tween.is_running()):
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
		ads_off = Items.vec_from_source(def.ads) * e
	bob_t += delta * (6.0 + 5.0 * move_amount)
	var bob_amt := move_amount * (1.0 - e * 0.85)
	var bob := Vector3(sin(bob_t) * 0.006, -abs(cos(bob_t)) * 0.006, 0.0) * bob_amt
	var breathe := Vector3(0.0, sin(bob_t * 0.25) * 0.0012, 0.0) * (1.0 - e)
	var sway_off := Vector3(-look_sway.x, look_sway.y, 0.0) * 0.00035 * (1.0 - e * 0.7)
	sway.position = ads_off + bob + breathe + sway_off
	sway.rotation = Vector3(look_sway.y * 0.0008, -look_sway.x * 0.0008, 0.0) * (1.0 - e * 0.7)
